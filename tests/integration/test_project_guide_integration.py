# Copyright (c) 2025-2026 Pointmatic (https://www.pointmatic.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Integration tests for the project-guide install + completion hooks, and the
isolated-$HOME harness those hooks (and any provisioning path) must run in.

=== Harness contract (_isolate_home) ===

Every test that can reach $HOME-relative resolution or writes — rc-file
edits, hosting provisioning (`self install` / `self provision` /
pyve_project_guide_ensure), version-manager reads — runs inside the
fully self-contained sandbox built by `_isolate_home`.

What is FAKED (in-sandbox, no real-home reach):
  - $HOME itself, plus every $HOME-derived resolution root pyve consults:
    PYENV_ROOT, ASDF_DATA_DIR, XDG_DATA_HOME / XDG_STATE_HOME /
    XDG_CONFIG_HOME / XDG_CACHE_HOME — all pinned inside the fake home.
  - The version managers: a fake `pyenv` and a fake `asdf` on a sanitized
    PATH answer the subset pyve drives (detection, version listing, pin
    writing, prefix resolution) from fixture prefixes inside the sandbox.
  - PATH: the inherited PATH minus every entry that resolves into the real
    home (version-manager shims, ~/.local/bin, repo venvs), with the
    sandbox bin dir prepended.

What is INJECTED BY VALUE (the top-precedence override seams):
  - The interpreter: PYVE_PYTHON is pinned to the binary running this test
    process — pyve never *discovers* an interpreter through real-home
    version-manager state.
  - project-guide: PYVE_PROJECT_GUIDE_BIN is pinned to the network-free
    stub via `_install_pg_stub`. Internal callsites resolve project-guide
    by HOSTED absolute path (deliberately ignoring PATH), so a PATH-only
    stub is silently bypassed — the env seam is the only honest redirect.

What a new test must NEVER do:
  - Run a pyve command that can provision hosting without `_isolate_home`
    (and, unless it deliberately tests real provisioning, without
    `_install_pg_stub`). The provisioning write path targets
    $HOME-relative state; outside the sandbox that is the developer's
    real home. The suite-level guard in conftest.py
    (real_home_mutation_guard) fails the run if the real
    ~/.local/bin/project-guide shim or toolchain tree changes.
  - Symlink real-home state (~/.asdf, ~/.pyenv, ~/.local, …) into the
    fake home. That was the original leak: provisioning tests wrote
    through the symlinks into real developer state, which dangled when
    the tmpdir was reaped (the 2026-06-09 incident).
  - Rely on a PATH-only project-guide stub (see the seam note above).

=== Test layers ===

  - Fast tests: mutex errors + skip paths (no install, no network).
  - Hook tests: drive the pyve-hosted project-guide contract against the
    stub (`init`/`update` with backup/restore) — network-free.
  - TestProvisioningIsSandboxed: the one REAL provisioning run
    (`pyve self provision`), contained in the sandbox; its pip layer
    needs network and degrades to a warning without it.

Bats (`tests/unit/test_project_guide.bats`) already covers the helper
functions in isolation — this file verifies pyve-init wiring.

`pyve self uninstall` removal of the sentinel block is covered indirectly:
  - `remove_project_guide_completion` behavior: tests/unit/test_project_guide.bats
  - `uninstall_self` wiring: visual inspection of pyve.sh (the
    uninstall_project_guide_completion helper is called at the end of
    uninstall_self).
"""

import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

from home_guard import diff_hosting_state, snapshot_hosting_state

# project-guide requires Python >= 3.11. The pyve CI matrix runs Python 3.10,
# 3.11, and 3.12 — the 3.10 entry can't run real-install tests because pip
# refuses to install project-guide on 3.10. The tests that require an actual
# install of project-guide (TestRealInstall) are gated on the runner's
# detected pyenv/asdf Python version, since that's the version pyve will
# pin into the project venv via the auto-pin in PyveRunner.run().
#
# We also accept the host's sys.version_info as a fallback when the version
# manager doesn't pick anything up — that mirrors what pyve.sh's
# `_detect_version_manager_python_version` does in its third fallback path.
PROJECT_GUIDE_MIN_PYTHON = (3, 11)


def _detected_python_tuple():
    """
    Detect the Python version pyve will use in the project venv. Mirrors the
    detection chain in tests/helpers/pyve_test_helpers.py: pyenv → asdf →
    python3 on PATH. Returns a (major, minor) tuple, or None if undetectable.
    """
    # Reuse the helper detection logic so we always agree with the auto-pin.
    helpers_path = Path(__file__).parent.parent / "helpers"
    sys.path.insert(0, str(helpers_path))
    try:
        from pyve_test_helpers import _detect_version_manager_python_version
    finally:
        sys.path.pop(0)

    detected = _detect_version_manager_python_version(os.environ.copy())
    if not detected:
        return None
    parts = detected.split(".")
    if len(parts) < 2:
        return None
    try:
        return (int(parts[0]), int(parts[1]))
    except ValueError:
        return None


def _python_version_too_old_for_project_guide():
    """True if the detected runner Python is older than PROJECT_GUIDE_MIN_PYTHON."""
    py = _detected_python_tuple()
    if py is None:
        return False  # Unknown — let the test run; it'll fail loudly if pip rejects.
    return py < PROJECT_GUIDE_MIN_PYTHON


SKIP_PYTHON_TOO_OLD = pytest.mark.skipif(
    _python_version_too_old_for_project_guide(),
    reason=(
        f"project-guide requires Python >= "
        f"{PROJECT_GUIDE_MIN_PYTHON[0]}.{PROJECT_GUIDE_MIN_PYTHON[1]}; "
        f"detected runner Python is older. Skipping real-install tests."
    ),
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _venv_python(project_dir):
    """Path to the venv's python executable for a pyve-initialized project."""
    return project_dir / ".venv" / "bin" / "python"


def _project_guide_importable(project_dir) -> bool:
    """Return True if `import project_guide` succeeds from the project venv."""
    py = _venv_python(project_dir)
    if not py.exists():
        return False
    result = subprocess.run(
        [str(py), "-c", "import project_guide"],
        capture_output=True,
    )
    return result.returncode == 0


# ---------------------------------------------------------------------------
# project-guide stub
#
# Under N.aw, project-guide is a Pyve-managed GLOBAL tool resolved on PATH
# (toolchain venv + ~/.local/bin shim), NOT a per-project pip install. These
# integration tests therefore put a network-free `project-guide` stub on PATH
# that emulates the contract pyve drives (`init`/`update` with backup/restore,
# per lib/project_guide.sh + lib/utils.sh), instead of a real PyPI install.
# ---------------------------------------------------------------------------

# Canonical content the stub writes for the managed template; tests assert a
# user-tampered copy is restored to exactly this and backed up.
_PG_STUB_CANON = "CANONICAL debug-guide -- managed by project-guide (stub)"

_PG_STUB_SCRIPT = """#!/usr/bin/env bash
# Network-free project-guide stub. Emulates `project-guide init/update
# --no-input --quiet` as pyve invokes them, in the project cwd.
set -euo pipefail
CANON="__CANON__"
tmpl="docs/project-guide/developer/debug-guide.md"
sub="${1:-}"
case "$sub" in
  --version) echo "project-guide 2.13.0 (stub)"; exit 0 ;;
  init)
    mkdir -p "docs/project-guide/developer"
    printf '%s\\n' "$CANON" > "$tmpl"
    cat > .project-guide.yml <<'YML'
installed_version: 2.13.0
target_dir: docs/project-guide
current_mode: code_test_first
pyve_version: stub
env_spec_path: docs/specs/env-dependencies.md
YML
    exit 0
    ;;
  update)
    if [ "${PG_STUB_FAIL_UPDATE:-0}" = "1" ]; then
      echo "project-guide update: simulated failure" >&2
      exit 1
    fi
    if [ ! -f .project-guide.yml ]; then
      echo "project-guide update: No .project-guide.yml found" >&2
      exit 1
    fi
    mkdir -p "docs/project-guide/developer"
    if [ -f "$tmpl" ] && [ "$(cat "$tmpl")" != "$CANON" ]; then
      cp "$tmpl" "$tmpl.bak.$(date +%s)"
    fi
    printf '%s\\n' "$CANON" > "$tmpl"
    exit 0
    ;;
  *) echo "project-guide stub: unknown subcommand: $sub" >&2; exit 2 ;;
esac
"""


def _install_pg_stub(monkeypatch, tmp_path):
    """Put the network-free `project-guide` stub first on PATH.

    Returns the bin dir. Pair with PYVE_TEST_ALLOW_PROJECT_GUIDE=1 so pyve's
    orchestration actually runs the hook (the test-runner default otherwise
    sets PYVE_NO_PROJECT_GUIDE=1).
    """
    bin_dir = tmp_path / "pg_stub_bin"
    bin_dir.mkdir(exist_ok=True)
    stub = bin_dir / "project-guide"
    stub.write_text(_PG_STUB_SCRIPT.replace("__CANON__", _PG_STUB_CANON))
    stub.chmod(0o755)
    monkeypatch.setenv("PATH", f"{bin_dir}{os.pathsep}{os.environ['PATH']}")
    # pyve's internal callsites resolve project-guide by HOSTED absolute path
    # (toolchain venv → ~/.local/bin shim), which deliberately ignores PATH
    # (lib/toolchain_python.sh § pyve_project_guide). A PATH-only stub is
    # therefore never invoked — pyve runs whatever real project-guide the
    # runner has hosted. Pin the override seam to this stub so the hook
    # genuinely routes here and stays network-free + runner-independent.
    monkeypatch.setenv("PYVE_PROJECT_GUIDE_BIN", str(stub))
    return bin_dir


def _base_interpreter() -> str:
    """
    Absolute, version-manager-independent path to the interpreter running
    this test process, resolved past venv indirection and shims. This is
    the ONE real-machine artifact the sandbox is seeded with — injected by
    value (a path to a known-runnable binary), never discovered through
    real-home version-manager state.
    """
    base = getattr(sys, "_base_executable", None) or sys.executable
    return os.path.realpath(base)


def _write_exec_shim(path: Path, target: str) -> None:
    """Write a regular-file exec shim (NOT a symlink) forwarding to <target>."""
    path.write_text(f'#!/bin/sh\nexec "{target}" "$@"\n')
    path.chmod(0o755)


# Minimal in-sandbox pyenv, mirroring the CI harness shape (real pyenv with a
# symlinked setup-python interpreter) but fully inside the fake $HOME. It
# emulates only the subset pyve and the test helpers drive; anything else
# fails loudly so a new dependency on pyenv behavior surfaces immediately.
_FAKE_PYENV_SCRIPT = """#!/usr/bin/env bash
# In-sandbox fake pyenv for the isolated-$HOME harness.
set -euo pipefail
cmd="${1:-}"
case "$cmd" in
  version-name) echo "__VERSION__" ;;
  version)      echo "__VERSION__ (set by fake pyenv)" ;;
  versions)     echo "__VERSION__" ;;   # same output with or without --bare
  prefix)
    ver="${2:-__VERSION__}"
    if [ "$ver" = "__VERSION__" ]; then
      echo "__PREFIX__"
    else
      echo "pyenv: version \\`$ver' not installed (fake pyenv)" >&2
      exit 1
    fi
    ;;
  install)
    if [ "${2:-}" = "--list" ] || [ "${2:-}" = "-l" ]; then
      echo "  __VERSION__"
    else
      echo "pyenv(fake): refusing to install inside the test sandbox" >&2
      exit 1
    fi
    ;;
  local)  [ -n "${2:-}" ] && printf '%s\\n' "$2" > .python-version ;;
  rehash) : ;;
  init)   : ;;   # `eval "$(pyenv init -)"` in profile sourcing — nothing to emit
  root)   echo "__PYENV_ROOT__" ;;
  *)
    echo "pyenv(fake): unsupported subcommand: $cmd" >&2
    exit 1
    ;;
esac
"""


# Minimal in-sandbox asdf. pyve PREFERS asdf over pyenv when both resolve,
# so the sandbox must answer the asdf surface pyve drives (detection, version
# listing, pin writing, toolchain prefix resolution) from sandbox fixtures —
# otherwise a real /opt/homebrew/bin/asdf on the developer's PATH wins
# detection and then fails against the empty fake $ASDF_DATA_DIR.
_FAKE_ASDF_SCRIPT = """#!/usr/bin/env bash
# In-sandbox fake asdf for the isolated-$HOME harness.
set -euo pipefail
case "${1:-}|${2:-}|${3:-}" in
  "plugin|list|")        echo "python" ;;
  "list|all|python")     echo "__VERSION__" ;;
  "list|python|")        echo "  __VERSION__" ;;
  "current|python|")     printf 'python  __VERSION__  %s\\n' "$PWD/.tool-versions" ;;
  "where|python|__VERSION__") echo "__PREFIX__" ;;
  "where|python|"*)
    echo "asdf(fake): version not installed: ${3:-}" >&2
    exit 1
    ;;
  "set|python|"*|"local|python|"*)
    printf 'python %s\\n' "$3" > .tool-versions
    ;;
  "reshim|python|") : ;;
  "install|python|"*)
    echo "asdf(fake): refusing to install inside the test sandbox" >&2
    exit 1
    ;;
  *)
    echo "asdf(fake): unsupported invocation: $*" >&2
    exit 1
    ;;
esac
"""


def _isolate_home(monkeypatch, tmp_path):
    """
    Redirect $HOME (and every $HOME-derived resolution root) to a fully
    self-contained sandbox. NOTHING inside it symlinks into the real home
    — the old harness passed `~/.asdf` / `~/.pyenv` / `~/.local` through,
    so provisioning tests wrote hosting artifacts into REAL developer
    state that dangled when the tmpdir was reaped (the 2026-06-09
    triggering incident).

    The sandbox supplies, in-sandbox:
      - `python` / `python3` on a sanitized PATH (exec shims to the
        interpreter running this test process — injected by value);
      - a fake pyenv whose versions/prefix answers are backed by a fixture
        prefix under the fake `$PYENV_ROOT`;
      - PYVE_PYTHON pinned to the same interpreter (pyve's internal
        toolchain seam);
      - PYENV_ROOT / ASDF_DATA_DIR / XDG_* pinned inside the fake home so
        inherited shell env can't redirect a write outside it.

    PATH is the inherited PATH minus every entry that resolves into the
    real home (version-manager shims, ~/.local/bin, repo venvs), with the
    sandbox bin dir prepended. Returns the fake home Path.
    """
    real_home = Path(os.path.expanduser("~")).resolve()
    fake_home = tmp_path / "fake_home"
    fake_home.mkdir(exist_ok=True)

    interpreter = _base_interpreter()
    probe = subprocess.run(
        [interpreter, "--version"], capture_output=True, text=True
    )
    match = re.search(r"(\d+\.\d+\.\d+)", (probe.stdout or "") + (probe.stderr or ""))
    assert match, f"cannot version-probe the sandbox interpreter {interpreter}"
    version = match.group(1)
    major_minor = ".".join(version.split(".")[:2])
    python_names = ("python", "python3", f"python{major_minor}")

    # Fixture pyenv prefix: <PYENV_ROOT>/versions/<ver>/bin/python…
    pyenv_root = fake_home / ".pyenv"
    prefix_bin = pyenv_root / "versions" / version / "bin"
    prefix_bin.mkdir(parents=True, exist_ok=True)
    for name in python_names:
        _write_exec_shim(prefix_bin / name, interpreter)

    # Fixture asdf prefix: <ASDF_DATA_DIR>/installs/python/<ver>/bin/python…
    asdf_data = fake_home / ".asdf"
    asdf_prefix_bin = asdf_data / "installs" / "python" / version / "bin"
    asdf_prefix_bin.mkdir(parents=True, exist_ok=True)
    for name in python_names:
        _write_exec_shim(asdf_prefix_bin / name, interpreter)

    # Sandbox PATH bin: python shims + the fake version managers.
    sandbox_bin = fake_home / "sandbox-bin"
    sandbox_bin.mkdir(exist_ok=True)
    for name in python_names:
        _write_exec_shim(sandbox_bin / name, interpreter)
    fake_pyenv = sandbox_bin / "pyenv"
    fake_pyenv.write_text(
        _FAKE_PYENV_SCRIPT
        .replace("__VERSION__", version)
        .replace("__PREFIX__", str(prefix_bin.parent))
        .replace("__PYENV_ROOT__", str(pyenv_root))
    )
    fake_pyenv.chmod(0o755)
    fake_asdf = sandbox_bin / "asdf"
    fake_asdf.write_text(
        _FAKE_ASDF_SCRIPT
        .replace("__VERSION__", version)
        .replace("__PREFIX__", str(asdf_prefix_bin.parent))
    )
    fake_asdf.chmod(0o755)

    # Sanitized PATH: drop every inherited entry that resolves into the
    # real home so neither command resolution nor writes can reach real
    # developer state.
    kept = []
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        if entry and not _resolves_into(Path(entry), real_home):
            kept.append(entry)
    monkeypatch.setenv("PATH", os.pathsep.join([str(sandbox_bin), *kept]))

    monkeypatch.setenv("HOME", str(fake_home))
    monkeypatch.setenv("PYENV_ROOT", str(pyenv_root))
    monkeypatch.setenv("ASDF_DATA_DIR", str(fake_home / ".asdf"))
    monkeypatch.setenv("XDG_DATA_HOME", str(fake_home / ".local" / "share"))
    monkeypatch.setenv("XDG_STATE_HOME", str(fake_home / ".local" / "state"))
    monkeypatch.setenv("XDG_CONFIG_HOME", str(fake_home / ".config"))
    monkeypatch.setenv("XDG_CACHE_HOME", str(fake_home / ".cache"))
    monkeypatch.setenv("PYVE_PYTHON", interpreter)
    # Pin pyve's default Python to the ONE version this sandbox can serve.
    # Strict toolchain provisioning (v3.2.1) builds toolchain/<V>/venv only
    # from a real <V> interpreter — never a PATH fallback — so without the
    # pin, provisioning inside the sandbox correctly refuses whenever the
    # pytest interpreter's version differs from pyve's shipped default
    # (every CI matrix job), and no toolchain venv can ever materialize.
    # Pinning keeps the slot truthful: <V> is the version actually served.
    monkeypatch.setenv("PYVE_DEFAULT_PYTHON_VERSION", version)
    return fake_home


def _resolves_into(path: Path, root: Path) -> bool:
    """True if <path> (following symlinks) lands inside <root>."""
    try:
        resolved = Path(os.path.realpath(path))
    except OSError:
        return False
    return resolved == root or str(resolved).startswith(str(root) + os.sep)


# ---------------------------------------------------------------------------
# Harness contract: the isolated $HOME is fully self-contained
# ---------------------------------------------------------------------------

class TestIsolatedHomeIsSelfContained:
    """
    Contract tests for the _isolate_home harness.

    The sandbox must be fully self-contained: no entry inside it may
    symlink into the real home, no $HOME-derived resolution root
    (version-manager data dirs, XDG roots) may escape it, and the PATH
    handed to pyve subprocesses may not reach real developer state.
    The interpreter is injected BY VALUE via PYVE_PYTHON — never
    discovered through real-home version-manager state.
    """

    def test_sandbox_is_fully_self_contained(self, monkeypatch, tmp_path):
        real_home = Path(os.path.expanduser("~")).resolve()
        fake_home = _isolate_home(monkeypatch, tmp_path)

        # $HOME is redirected to the sandbox.
        assert os.environ["HOME"] == str(fake_home)

        # Nothing inside the sandbox symlinks into the real home — a
        # symlinked ~/.local / ~/.asdf / ~/.pyenv is exactly how the suite
        # used to write hosting artifacts into real developer state.
        offenders = [
            str(p) for p in fake_home.rglob("*")
            if p.is_symlink() and _resolves_into(p, real_home)
        ]
        assert offenders == [], (
            f"sandbox entries symlink into the real home: {offenders}"
        )

        # No PATH entry reaches into the real home (version-manager shims,
        # ~/.local/bin, repo venvs) — writes can't land there and command
        # resolution can't silently depend on it.
        bad_path = [
            e for e in os.environ["PATH"].split(os.pathsep)
            if e and _resolves_into(Path(e), real_home)
        ]
        assert bad_path == [], (
            f"PATH entries reach into the real home: {bad_path}"
        )

        # Every $HOME-derived resolution root pyve consults is pinned
        # inside the sandbox, so even env vars inherited from the
        # developer's shell can't redirect a write outside it.
        for var in (
            "PYENV_ROOT",
            "ASDF_DATA_DIR",
            "XDG_DATA_HOME",
            "XDG_STATE_HOME",
            "XDG_CONFIG_HOME",
            "XDG_CACHE_HOME",
        ):
            value = os.environ.get(var, "")
            assert value.startswith(str(fake_home)), (
                f"{var}={value!r} escapes the sandbox {fake_home}"
            )

        # The internal-interpreter seam is supplied by value and runnable.
        py = os.environ.get("PYVE_PYTHON", "")
        assert py and os.access(py, os.X_OK), (
            "PYVE_PYTHON must hand the sandbox a runnable interpreter"
        )

    def test_sandbox_supplies_a_working_python_and_version_manager(
        self, monkeypatch, tmp_path
    ):
        """pyve init needs `python` and a version manager to resolve inside
        the sandbox without real-home state: a PATH `python3`, and a pyenv
        whose versions/prefix answers are backed by sandbox fixtures."""
        fake_home = _isolate_home(monkeypatch, tmp_path)
        env = os.environ.copy()

        probe = subprocess.run(
            ["python3", "--version"], capture_output=True, text=True, env=env
        )
        assert probe.returncode == 0, probe.stderr

        version = subprocess.run(
            ["pyenv", "version-name"], capture_output=True, text=True, env=env
        )
        assert version.returncode == 0, version.stderr
        ver = version.stdout.strip()
        assert ver

        prefix = subprocess.run(
            ["pyenv", "prefix", ver], capture_output=True, text=True, env=env
        )
        assert prefix.returncode == 0, prefix.stderr
        prefix_dir = Path(prefix.stdout.strip())
        assert _resolves_into(prefix_dir, fake_home), (
            f"pyenv prefix {prefix_dir} is not inside the sandbox"
        )
        assert os.access(prefix_dir / "bin" / "python", os.X_OK)

        # pyve PREFERS asdf when it resolves — the sandbox asdf must answer
        # from sandbox fixtures (a real asdf on PATH would win detection and
        # then fail against the empty fake $ASDF_DATA_DIR).
        plugins = subprocess.run(
            ["asdf", "plugin", "list"], capture_output=True, text=True, env=env
        )
        assert plugins.returncode == 0 and "python" in plugins.stdout

        where = subprocess.run(
            ["asdf", "where", "python", ver],
            capture_output=True, text=True, env=env,
        )
        assert where.returncode == 0, where.stderr
        asdf_prefix = Path(where.stdout.strip())
        assert _resolves_into(asdf_prefix, fake_home), (
            f"asdf prefix {asdf_prefix} is not inside the sandbox"
        )
        assert os.access(asdf_prefix / "bin" / "python", os.X_OK)


# ---------------------------------------------------------------------------
# Real provisioning is sandboxed (slow — builds the toolchain venv; the pip
# layer needs network and degrades to a warning without it)
# ---------------------------------------------------------------------------

@pytest.mark.venv
class TestProvisioningIsSandboxed:
    """
    `pyve self provision` — the REAL provisioning path (toolchain venv
    build + hosted project-guide pip install + shim link) — must land every
    artifact inside the fake $HOME (positive) and never touch the real
    home's hosting state (negative). This is the write path that used to
    escape through the old harness's ~/.local symlink and corrupt real
    developer state.
    """

    def test_self_provision_lands_in_fake_home_only(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        # Snapshot the REAL home's hosting artifacts before entering the
        # sandbox ($HOME still points at the real home here).
        real_home = Path(os.path.expanduser("~"))
        real_xdg = os.environ.get("XDG_DATA_HOME")
        before = snapshot_hosting_state(real_home, real_xdg)

        fake_home = _isolate_home(monkeypatch, tmp_path)
        result = pyve.run("self", "provision", timeout=600)
        assert result.returncode == 0, f"self provision failed: {result.stderr}"

        # Positive: the toolchain venv materialized inside the sandbox.
        toolchain = fake_home / ".local" / "share" / "pyve" / "toolchain"
        venv_pythons = list(toolchain.glob("*/venv/bin/python"))
        assert venv_pythons, (
            f"expected a toolchain venv under {toolchain}; "
            f"provision output:\n{result.stdout}\n{result.stderr}"
        )

        # Positive (network-dependent): when the hosted project-guide
        # install succeeded, its shim must live in the fake home and
        # resolve inside it. Offline, `self provision` warns and skips —
        # the sandbox containment below still holds.
        combined = (result.stdout or "") + (result.stderr or "")
        if "Installed project-guide into the Pyve toolchain" in combined:
            fake_shim = fake_home / ".local" / "bin" / "project-guide"
            assert fake_shim.is_symlink(), (
                "expected the project-guide shim inside the fake home"
            )
            assert _resolves_into(fake_shim, fake_home), (
                f"shim {fake_shim} resolves outside the sandbox"
            )

        # Negative: the REAL home's hosting artifacts are untouched.
        after = snapshot_hosting_state(real_home, real_xdg)
        assert diff_hosting_state(before, after) == []


# ---------------------------------------------------------------------------
# Mutex errors (fast — exit before venv creation)
# ---------------------------------------------------------------------------

class TestMutexFlags:
    """--project-guide and --no-project-guide are mutually exclusive."""

    def test_install_flags_mutex(self, pyve, test_project):
        result = pyve.run(
            "init", "--project-guide", "--no-project-guide", check=False
        )
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "mutually exclusive" in combined
        assert "--project-guide" in combined

    def test_completion_flags_mutex(self, pyve, test_project):
        result = pyve.run(
            "init",
            "--project-guide-completion",
            "--no-project-guide-completion",
            check=False,
        )
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "mutually exclusive" in combined
        assert "--project-guide-completion" in combined


# ---------------------------------------------------------------------------
# Skip paths (fast — venv created, but no pip install, no rc edit)
# ---------------------------------------------------------------------------

@pytest.mark.venv
class TestSkipPaths:
    """--no-project-guide and PYVE_NO_PROJECT_GUIDE skip the entire hook."""

    def test_no_project_guide_flag_skips_install_and_rc_edit(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        fake_home = _isolate_home(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")

        result = pyve.run("init", "--no-direnv", "--force", "--no-project-guide")
        assert result.returncode == 0

        # project-guide must NOT be installed
        assert not _project_guide_importable(test_project)

        # No rc-file edit
        assert not (fake_home / ".zshrc").exists() or (
            "project-guide completion" not in (fake_home / ".zshrc").read_text()
        )

    def test_env_var_skip(self, pyve, test_project, tmp_path, monkeypatch):
        fake_home = _isolate_home(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("PYVE_NO_PROJECT_GUIDE", "1")

        result = pyve.run("init", "--no-direnv", "--force")
        assert result.returncode == 0
        assert not _project_guide_importable(test_project)
        assert not (fake_home / ".zshrc").exists() or (
            "project-guide completion" not in (fake_home / ".zshrc").read_text()
        )

    def test_no_completion_flag_accepted_alongside_no_project_guide(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        --no-project-guide-completion is parsed independently of --no-project-guide.
        Both flags together → install skipped AND completion skipped (silent).
        Network-free: --no-project-guide blocks the pip install.
        """
        fake_home = _isolate_home(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")

        result = pyve.run(
            "init",
            "--no-direnv",
            "--force",
            "--no-project-guide",
            "--no-project-guide-completion",
        )
        assert result.returncode == 0
        # Neither install nor completion happened.
        assert not _project_guide_importable(test_project)
        assert not (fake_home / ".zshrc").exists() or (
            "project-guide completion" not in (fake_home / ".zshrc").read_text()
        )


# ---------------------------------------------------------------------------
# Auto-skip safety mechanism (fast — no network)
# ---------------------------------------------------------------------------

@pytest.mark.venv
class TestAutoSkipWhenInProjectDeps:
    """
    When project-guide is declared in pyproject.toml / requirements.txt /
    environment.yml, pyve auto-skips its install/upgrade with an INFO
    message — preventing a version conflict with the user's pin.
    """

    def test_auto_skip_when_in_pyproject_toml(
        self, pyve, test_project, project_builder, tmp_path, monkeypatch
    ):
        fake_home = _isolate_home(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        # Opt in to the project-guide hook (overrides the test-runner default
        # of PYVE_NO_PROJECT_GUIDE=1) so the auto-skip code path can run.
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        # Don't set --no-project-guide — test relies on auto-skip detection.
        monkeypatch.delenv("PYVE_PROJECT_GUIDE", raising=False)
        monkeypatch.delenv("PYVE_NO_PROJECT_GUIDE", raising=False)

        # User has project-guide pinned in their project deps.
        project_builder.create_pyproject_toml(
            "myapp", dependencies=["requests", "project-guide==2.0.20"]
        )

        result = pyve.run("init", "--no-direnv", "--force")
        assert result.returncode == 0

        # Auto-skip info message must be present.
        combined = (result.stdout or "") + (result.stderr or "")
        assert "Detected 'project-guide' in your project dependencies" in combined
        assert "--project-guide" in combined  # override hint

        # project-guide was NOT auto-installed by pyve (pyve init didn't run
        # `pip install -e .` because we used --no-install-deps via the test
        # runner default), so it must NOT be importable.
        assert not _project_guide_importable(test_project)

        # No rc-file edit (auto-skip aborted before completion step).
        assert not (fake_home / ".zshrc").exists() or (
            "project-guide completion" not in (fake_home / ".zshrc").read_text()
        )

    def test_auto_skip_when_in_requirements_txt(
        self, pyve, test_project, project_builder, tmp_path, monkeypatch
    ):
        _isolate_home(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        monkeypatch.delenv("PYVE_PROJECT_GUIDE", raising=False)
        monkeypatch.delenv("PYVE_NO_PROJECT_GUIDE", raising=False)

        project_builder.create_requirements_txt(["requests", "project-guide==2.0.20"])

        result = pyve.run("init", "--no-direnv", "--force")
        assert result.returncode == 0

        combined = (result.stdout or "") + (result.stderr or "")
        assert "Detected 'project-guide' in your project dependencies" in combined

    def test_explicit_project_guide_flag_overrides_auto_skip(
        self, pyve, test_project, project_builder, tmp_path, monkeypatch
    ):
        """
        --project-guide is an explicit user override: even when project-guide
        is in project deps, the flag forces pyve to manage it. The auto-skip
        info message must NOT appear.
        """
        _isolate_home(monkeypatch, tmp_path)
        # Pin the hook to the network-free stub: without the override seam
        # the explicit --project-guide flag drives pyve_project_guide_ensure,
        # which really provisions hosting (toolchain venv build + network
        # pip + shim write). The assertion here is about the auto-skip
        # message — decided before any install — so the stub is sufficient.
        _install_pg_stub(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        # Opt in to the project-guide hook (the explicit --project-guide flag
        # below would otherwise be neutralised by the test-runner default).
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        monkeypatch.delenv("PYVE_PROJECT_GUIDE", raising=False)
        monkeypatch.delenv("PYVE_NO_PROJECT_GUIDE", raising=False)
        # Skip the rc-file edit to keep the test network/file-edit free.
        monkeypatch.setenv("PYVE_NO_PROJECT_GUIDE_COMPLETION", "1")

        project_builder.create_pyproject_toml(
            "myapp", dependencies=["project-guide==2.0.20"]
        )

        # We *want* pyve to take the install path here (stubbed). What we're
        # asserting is that the auto-skip message is NOT printed — the
        # explicit flag overrode it.
        result = pyve.run("init", "--no-direnv", "--force", "--project-guide", timeout=300)
        assert result.returncode == 0

        combined = (result.stdout or "") + (result.stderr or "")
        assert "Detected 'project-guide' in your project dependencies" not in combined


# ---------------------------------------------------------------------------
# Real install happy path (slow — network required)
# ---------------------------------------------------------------------------

@pytest.mark.venv
@SKIP_PYTHON_TOO_OLD
class TestRealInstall:
    """End-to-end validation that project-guide is actually installed and wired.

    Skipped entirely on Python 3.10 runners because project-guide requires
    Python >= 3.11 — pip refuses to install on older Pythons. The pyve CI
    matrix runs on 3.10/3.11/3.12; this class runs on the 3.11 and 3.12
    entries only.
    """

    def test_install_with_completion_wires_everything(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        Three-step hook end-to-end:
          1. pip install --upgrade project-guide
          2. project-guide init --no-input  (creates .project-guide.yml)
          3. shell completion block in ~/.zshrc

        Setup: PYVE_PROJECT_GUIDE=1, PYVE_PROJECT_GUIDE_COMPLETION=1,
        SHELL=/bin/zsh, isolated $HOME.
        """
        fake_home = _isolate_home(monkeypatch, tmp_path)
        _install_pg_stub(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_PROJECT_GUIDE_COMPLETION", "1")
        # Block auto-CI-forces-yes inherited from test runner shell.
        monkeypatch.delenv("CI", raising=False)
        monkeypatch.delenv("PYVE_FORCE_YES", raising=False)

        result = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result.returncode == 0, f"pyve init failed: {result.stderr}"

        # project-guide is toolchain-hosted (resolved on PATH),
        # NOT installed into the project venv — so the assertion is that pyve
        # drove the hosted `project-guide init` to scaffold, not that the
        # package imports from .venv.
        assert (test_project / ".project-guide.yml").exists(), (
            "Expected .project-guide.yml to be created by 'project-guide init'"
        )
        assert (test_project / "docs" / "project-guide").is_dir(), (
            "Expected docs/project-guide/ to be created by 'project-guide init'"
        )

        # Step 3: sentinel block must be present in the fake $HOME/.zshrc.
        zshrc = fake_home / ".zshrc"
        assert zshrc.exists(), "Expected $HOME/.zshrc to be created by pyve init"
        content = zshrc.read_text()
        assert "# >>> project-guide completion (added by pyve) >>>" in content
        assert "# <<< project-guide completion <<<" in content
        assert "_PROJECT_GUIDE_COMPLETE=zsh_source" in content
        assert "command -v project-guide" in content

    def test_ci_asymmetry_install_yes_completion_no(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        CI mode: install flow defaults to INSTALL (matches interactive default),
        completion flow defaults to SKIP (deliberate asymmetry — don't touch rc
        files in unattended environments).
        """
        fake_home = _isolate_home(monkeypatch, tmp_path)
        _install_pg_stub(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("CI", "1")
        # Opt in to the project-guide hook so the CI default path runs.
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        # Block PYVE_FORCE_YES from being inherited indirectly.
        monkeypatch.delenv("PYVE_FORCE_YES", raising=False)
        # Don't set PYVE_PROJECT_GUIDE — we're testing the CI default path.
        monkeypatch.delenv("PYVE_PROJECT_GUIDE", raising=False)
        monkeypatch.delenv("PYVE_NO_PROJECT_GUIDE", raising=False)
        monkeypatch.delenv("PYVE_PROJECT_GUIDE_COMPLETION", raising=False)
        monkeypatch.delenv("PYVE_NO_PROJECT_GUIDE_COMPLETION", raising=False)

        result = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result.returncode == 0, f"pyve init failed: {result.stderr}"

        # CI default for install = YES, so pyve drives the hosted
        # `project-guide init` (toolchain model — not a project-venv install).
        assert (test_project / ".project-guide.yml").exists(), (
            "CI mode should scaffold project-guide (matches interactive default)"
        )

        # CI default for completion = SKIP, so rc file is untouched.
        zshrc = fake_home / ".zshrc"
        if zshrc.exists():
            assert "project-guide completion" not in zshrc.read_text(), (
                "CI mode must NOT edit the user rc file (deliberate asymmetry)"
            )

    def test_update_refreshes_managed_templates(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        Toolchain model: `pyve init` scaffolds via the hosted `project-guide
        init`; the lightweight `pyve update` then drives `project-guide
        update` to REFRESH managed templates (restoring a user-tampered file
        and leaving a `.bak.<ts>` sibling) — without rebuilding the venv or
        re-scaffolding from scratch.
        """
        _isolate_home(monkeypatch, tmp_path)
        _install_pg_stub(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_NO_PROJECT_GUIDE_COMPLETION", "1")
        monkeypatch.delenv("CI", raising=False)
        monkeypatch.delenv("PYVE_FORCE_YES", raising=False)

        # First run — scaffold via the hosted `project-guide init`.
        result1 = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result1.returncode == 0, f"first pyve init failed: {result1.stderr}"
        tmpl = test_project / TestRefreshOnReinit.TEMPLATE_FILE
        assert (test_project / ".project-guide.yml").exists()
        assert tmpl.exists(), "first init should scaffold the managed template"

        # User tampers the managed template; `pyve update` must refresh it.
        marker = "PYVE_UPDATE_REFRESH_SENTINEL"
        tmpl.write_text(f"# tampered\n{marker}\n")

        result2 = pyve.run("update", timeout=60)
        assert result2.returncode == 0, f"pyve update failed: {result2.stderr}"

        assert marker not in tmpl.read_text(), (
            "Expected `pyve update` to refresh the managed template via "
            "`project-guide update`"
        )
        backups = list(tmpl.parent.glob(f"{tmpl.name}.bak.*"))
        assert backups, "Expected `project-guide update` to back up the user's edits"


# ---------------------------------------------------------------------------
# Refresh on reinit (Story G.h — slow, network required)
# ---------------------------------------------------------------------------

@pytest.mark.venv
@SKIP_PYTHON_TOO_OLD
class TestRefreshOnReinit:
    """
    Story G.h: `pyve init --force` refreshes the project-guide scaffolding.

    Branching on `.project-guide.yml` presence:
      - present → `project-guide update --no-input` (preserves state,
                  creates `.bak.<timestamp>` siblings for modified files)
      - absent  → `project-guide init --no-input` (first-time path,
                  unchanged from Story G.c)

    `--no-project-guide` still fully skips the hook. `project-guide update`
    failures (e.g., corrupt config, future `SchemaVersionError`) surface as
    warnings and do not abort `pyve init`.
    """

    def _first_install(self, pyve, monkeypatch, tmp_path):
        """Run pyve init to install + scaffold project-guide. Returns fake_home."""
        fake_home = _isolate_home(monkeypatch, tmp_path)
        _install_pg_stub(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_NO_PROJECT_GUIDE_COMPLETION", "1")
        # Auto-confirm the re-init "Proceed? [y/N]:" prompt that fires on the
        # second `pyve init --force` (once a venv exists). Does not affect
        # project-guide install/completion decisions here — those are already
        # pinned by PYVE_PROJECT_GUIDE=1 / PYVE_NO_PROJECT_GUIDE_COMPLETION=1.
        monkeypatch.setenv("PYVE_FORCE_YES", "1")
        monkeypatch.delenv("CI", raising=False)

        result = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result.returncode == 0, f"first pyve init failed: {result.stderr}"
        return fake_home

    # A template file under docs/project-guide/ that `project-guide update`
    # hash-compares and refreshes. (`go.md` is intentionally excluded — it's
    # a dynamically rendered artifact, not a template, and `update` leaves
    # it alone even when modified. Template files like debug-guide.md are
    # the right target for verifying the refresh behaviour.)
    TEMPLATE_FILE = Path("docs") / "project-guide" / "developer" / "debug-guide.md"

    def test_force_reinit_restores_modified_template_with_backup(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        After `pyve init --force`, a user-modified managed template file
        must be restored to the shipped template and a `.bak.<timestamp>`
        sibling must be created containing the user's edits.

        Today this fails: `project-guide init --no-input` no-ops with
        'already initialized' when .project-guide.yml exists, so the
        user's edit persists and no backup is created.
        """
        self._first_install(pyve, monkeypatch, tmp_path)

        tmpl = test_project / self.TEMPLATE_FILE
        assert tmpl.exists(), f"expected first init to create {self.TEMPLATE_FILE}"

        marker = "PYVE_REFRESH_TEST_SENTINEL_DO_NOT_COMMIT"
        tmpl.write_text(f"# Tampered by test\n{marker}\n")

        result = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result.returncode == 0, f"reinit failed: {result.stderr}"

        assert marker not in tmpl.read_text(), (
            f"Expected {self.TEMPLATE_FILE} to be restored by "
            "`project-guide update` during `pyve init --force`; got the "
            "user's tampered content still in place. The refresh hook did "
            "not run (init --no-input no-ops when .project-guide.yml exists)."
        )

        backups = list(tmpl.parent.glob(f"{tmpl.name}.bak.*"))
        assert backups, (
            f"Expected `project-guide update` to create "
            f"{tmpl.name}.bak.<timestamp> before overwriting the "
            f"user-modified file"
        )
        assert marker in backups[0].read_text(), (
            "Backup file should contain the original user-modified content"
        )

    def test_force_reinit_skipped_by_no_project_guide(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        `pyve init --force --no-project-guide` leaves project-guide scaffolding
        alone: user's edits intact, no backups created, no refresh performed.
        """
        self._first_install(pyve, monkeypatch, tmp_path)

        tmpl = test_project / self.TEMPLATE_FILE
        marker = "PYVE_NO_REFRESH_SENTINEL"
        tmpl.write_text(f"# User edits\n{marker}\n")

        monkeypatch.delenv("PYVE_PROJECT_GUIDE", raising=False)

        result = pyve.run(
            "init", "--no-direnv", "--force", "--no-project-guide", timeout=300
        )
        assert result.returncode == 0, f"reinit failed: {result.stderr}"

        assert marker in tmpl.read_text(), (
            f"Expected --no-project-guide to suppress the refresh; "
            f"{self.TEMPLATE_FILE} was rewritten anyway"
        )

        backups = list(tmpl.parent.glob(f"{tmpl.name}.bak.*"))
        assert not backups, (
            f"Expected no backups when --no-project-guide is set, found: {backups}"
        )

    def test_force_reinit_falls_back_to_init_when_config_absent(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        With `docs/project-guide/` present but `.project-guide.yml` missing,
        `pyve init --force` must run `project-guide init` (not `update`,
        which would abort with "No .project-guide.yml found").
        """
        self._first_install(pyve, monkeypatch, tmp_path)

        config = test_project / ".project-guide.yml"
        assert config.exists()
        config.unlink()

        result = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result.returncode == 0, f"reinit failed: {result.stderr}"

        assert config.exists(), (
            "Expected `project-guide init` to recreate .project-guide.yml "
            "when config is absent"
        )

        combined = (result.stdout or "") + (result.stderr or "")
        assert "project-guide init" in combined, (
            f"Expected 'project-guide init' in log for fall-through path, "
            f"got:\n{combined}"
        )

    def test_force_reinit_update_failure_is_non_fatal(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        If `project-guide update` exits non-zero (e.g., corrupt config, or a
        future `SchemaVersionError`), `pyve init` surfaces a warning and
        continues with exit 0. Pyve never auto-runs `init --force` — that's
        destructive and must stay opt-in for the user.
        """
        self._first_install(pyve, monkeypatch, tmp_path)

        # Force the hosted `project-guide update` to exit non-zero (stands in
        # for a corrupt config / future SchemaVersionError). The stub honors
        # PG_STUB_FAIL_UPDATE=1; .project-guide.yml stays present so the
        # orchestration takes the update (not init) branch.
        monkeypatch.setenv("PG_STUB_FAIL_UPDATE", "1")

        result = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result.returncode == 0, (
            f"reinit aborted on project-guide update failure: {result.stderr}"
        )

        combined = (result.stdout or "") + (result.stderr or "")
        combined_lower = combined.lower()
        assert "project-guide update" in combined_lower and (
            "fail" in combined_lower or "warning" in combined_lower
        ), (
            f"Expected a `project-guide update` failure warning in output; "
            f"got:\n{combined}"
        )
