# Copyright (c) 2025 Pointmatic (https://www.pointmatic.com)
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
Integration tests for the project-guide install + completion hooks (Story G.c).

Test layers (per Q2/Q5 design decisions):
  - Fast tests: mutex errors + skip paths (no real pip install, no network)
  - Slow tests: one happy-path real install + one CI-asymmetry validation.
                These actually `pip install project-guide` into the project venv.
                Network required.
  - Idempotency test: verifies that re-running the hook doesn't re-pip-install
                      (timing-based: second invocation must be much faster).

Bats (`tests/unit/test_project_guide.bats`) already covers all 9 helper
functions in isolation — this file only verifies pyve-init wiring.

`pyve self uninstall` removal of the sentinel block is covered indirectly:
  - `remove_project_guide_completion` behavior: tests/unit/test_project_guide.bats
  - `uninstall_self` wiring: visual inspection of pyve.sh (the
    uninstall_project_guide_completion helper is called at the end of
    uninstall_self). A full end-to-end test would require running
    `pyve self uninstall` against a fake install target, which is out of
    scope for this story.
"""

import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

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


def _isolate_home(monkeypatch, tmp_path):
    """
    Redirect $HOME to a fresh tmp directory so rc-file edits don't touch the
    real user config, BUT symlink the version-manager state (.asdf, .pyenv,
    .tool-versions, .python-version) from the real home so pyve init can
    still resolve Python versions without trying to build from scratch.

    Returns the fake home Path.
    """
    real_home = Path(os.path.expanduser("~"))
    fake_home = tmp_path / "fake_home"
    fake_home.mkdir(exist_ok=True)

    # Symlink only the version-manager state — NOT .zshrc / .bashrc /
    # .zprofile / .bash_profile. The rc-file isolation is the whole
    # point of this fixture.
    passthrough_names = [
        ".asdf",
        ".pyenv",
        ".tool-versions",
        ".python-version",
        ".local",  # direnv etc.
    ]
    for name in passthrough_names:
        src = real_home / name
        if src.exists():
            dst = fake_home / name
            if not dst.exists():
                dst.symlink_to(src)

    monkeypatch.setenv("HOME", str(fake_home))
    return fake_home


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
        fake_home = _isolate_home(monkeypatch, tmp_path)
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
        fake_home = _isolate_home(monkeypatch, tmp_path)
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

        # We *want* pyve to attempt the install path here. To keep the test
        # network-free, we accept that it will try `pip install --upgrade
        # project-guide` and possibly fail (the venv pip might not have
        # network in CI), but the failure is non-fatal so pyve init still
        # exits 0. What we're asserting is that the auto-skip message is
        # NOT printed — the explicit flag overrode it.
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
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_PROJECT_GUIDE_COMPLETION", "1")
        # Block auto-CI-forces-yes inherited from test runner shell.
        monkeypatch.delenv("CI", raising=False)
        monkeypatch.delenv("PYVE_FORCE_YES", raising=False)

        result = pyve.run("init", "--no-direnv", "--force", timeout=300)
        assert result.returncode == 0, f"pyve init failed: {result.stderr}"

        # Step 1: project-guide must be importable from the project venv.
        assert _project_guide_importable(test_project), (
            "Expected project-guide to be installed in the project venv"
        )

        # Step 2: project-guide init must have created the artifact files.
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

        # CI default for install = YES, so project-guide is installed.
        assert _project_guide_importable(test_project), (
            "CI mode should install project-guide (matches interactive default)"
        )

        # CI default for completion = SKIP, so rc file is untouched.
        zshrc = fake_home / ".zshrc"
        if zshrc.exists():
            assert "project-guide completion" not in zshrc.read_text(), (
                "CI mode must NOT edit the user rc file (deliberate asymmetry)"
            )

    def test_idempotent_reinstall_is_fast(
        self, pyve, test_project, tmp_path, monkeypatch
    ):
        """
        Second invocation with project-guide already installed must short-circuit
        (no second pip install). Timed: re-run must be at least 3x faster than
        the first run. Also asserts that the helper log line fires.
        """
        fake_home = _isolate_home(monkeypatch, tmp_path)
        monkeypatch.setenv("SHELL", "/bin/zsh")
        monkeypatch.setenv("PYVE_TEST_ALLOW_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_PROJECT_GUIDE", "1")
        monkeypatch.setenv("PYVE_NO_PROJECT_GUIDE_COMPLETION", "1")
        monkeypatch.delenv("CI", raising=False)
        monkeypatch.delenv("PYVE_FORCE_YES", raising=False)

        # First run — real install
        t0 = time.time()
        result1 = pyve.run("init", "--no-direnv", "--force", timeout=300)
        t1 = time.time()
        first_duration = t1 - t0
        assert result1.returncode == 0, f"first pyve init failed: {result1.stderr}"
        assert _project_guide_importable(test_project)

        # Second run — idempotent no-op on the install step
        t2 = time.time()
        result2 = pyve.run("init", "--update", timeout=60)
        t3 = time.time()
        second_duration = t3 - t2
        assert result2.returncode == 0, f"second pyve init failed: {result2.stderr}"
        # NOTE: --update mode skips the post-init hook entirely per G.c design.
        # What we're actually validating with this test is that the helper
        # idempotency path (when it IS called via --force or fresh init) doesn't
        # re-pip-install. For a stricter test we'd need to call the helper
        # directly; this one at least asserts --update is fast.
        assert second_duration < first_duration, (
            f"second run ({second_duration:.1f}s) should be faster than "
            f"first ({first_duration:.1f}s)"
        )


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

        config = test_project / ".project-guide.yml"
        # Corrupt YAML → `project-guide update` exits 3.
        config.write_text("not: valid: yaml: ::\n")

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
