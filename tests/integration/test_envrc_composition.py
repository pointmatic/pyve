# Copyright (c) 2026 Pointmatic (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Integration tests for the composed `.envrc` (Story N.ae.5).

`pyve init` (without `--no-direnv`) now emits `.envrc` via the composer
(`compose_project_envrc`): after `.pyve/config` and `pyve.toml` are written,
the manifest/registry are reloaded and every active plugin's activate
snippet is assembled into one managed section (`# >>> pyve:managed:start >>>`
… `# <<< pyve:managed:end <<<`). `pyve update` refreshes that managed
section in place, preserving user content below the end marker.

The composer's mechanics (PC-1 validation, atomic write, `.envrc.prev`,
preservation) are pinned fast in tests/unit/test_n_ae_3*/4*/5*.bats; these
slow tests prove the end-to-end wiring through real `pyve init` / `pyve
update`, including the ordering (config + manifest exist before compose).

Note on polyglot coverage: the polyglot case (both Python + Node sections in
one composed .envrc) is covered at the unit level —
tests/unit/test_n_ae_3_envrc_composer.bats (composed body with both
sections) and tests/unit/test_n_ae_5_compose_project_wiring.bats (the reload
surfacing a freshly-scaffolded node plugin). It is intentionally NOT a real-
`pyve init` test here: a polyglot fixture flips asdf's view of the pinned
Python version to "not installed", tripping a pre-existing non-interactive
prompt loop in prompt_yes_no (lib/utils.sh) — unrelated to the composer. The
two real-init tests below pass a fail-fast stdin guard so they surface that
environment condition quickly rather than hanging.
"""

# Stdin guard: if a real init hits the python-install prompt (asdf reports
# the pinned version uninstalled), decline so init aborts fast. Since N.ae.6
# made prompt_yes_no EOF-safe (EOF → decline), an empty stdin no longer
# hangs; this explicit decline is belt-and-suspenders and keeps behavior the
# same across bash versions. The normal path never prompts (Python resolved +
# PYVE_NO_INSTALL_DEPS), so this is inert there.
_DECLINE = "n\n" * 5

import shutil

import pytest

MANAGED_START = "# >>> pyve:managed:start >>>"
MANAGED_END = "# <<< pyve:managed:end <<<"


def _skip_if_python_unresolvable(result):
    """Skip (don't fail) when a real `pyve init` could not resolve the pinned
    Python non-interactively.

    On a cold asdf cache, `ensure_python_version_installed` reports the pinned
    version as "not installed but available via asdf" and prompts to install;
    our `_DECLINE` stdin cancels init. That is a pre-existing, suite-wide
    environment condition (see the module docstring + the prompt_yes_no EOF
    bug noted in stories.md § N.ae.5), unrelated to the composer under test.
    Treat it as a skip so the composition assertions only run when the
    environment actually built the venv.
    """
    if result.returncode != 0 and "Install Python" in (result.stdout or ""):
        pytest.skip(
            "environment could not resolve the pinned Python non-interactively "
            "(asdf cold-cache install prompt); composer logic is unit-covered"
        )


@pytest.mark.venv
@pytest.mark.skipif(
    shutil.which("direnv") is None,
    reason="direnv not installed on this runner",
)
class TestComposedEnvrc:
    """End-to-end `.envrc` composition through `pyve init` / `pyve update`.

    These tests deliberately run *without* ``--no-direnv`` to exercise the
    composed ``.envrc`` path; ``pyve init`` aborts when direnv is absent, so
    the whole class is skipped on runners that lack it (mirrors
    test_envrc_template.py).
    """

    def test_venv_init_composes_managed_envrc(self, pyve, project_builder):
        """`pyve init --backend venv` writes a composed, sentinel-marked .envrc."""
        result = pyve.run(
            "init",
            "--backend", "venv",
            "--force",
            "--no-project-guide",
            check=False,
            input=_DECLINE,
            timeout=300,
        )
        _skip_if_python_unresolvable(result)
        assert result.returncode == 0, f"init failed:\n{result.stdout}\n{result.stderr}"

        envrc = pyve.cwd / ".envrc"
        assert envrc.exists(), "init (without --no-direnv) must write .envrc"
        text = envrc.read_text()
        assert MANAGED_START in text and MANAGED_END in text, (
            f"composed .envrc must carry the managed markers; got:\n{text}"
        )
        assert "# >>> pyve:plugin:python:activate >>>" in text, (
            f"composed .envrc must carry the python plugin section; got:\n{text}"
        )
        assert 'export VIRTUAL_ENV="$PWD/.venv"' in text, (
            f"python section must export VIRTUAL_ENV; got:\n{text}"
        )

        # Story N.af: init also composes a managed .gitignore section.
        gitignore = pyve.cwd / ".gitignore"
        assert gitignore.exists(), "init must compose .gitignore"
        gtext = gitignore.read_text()
        assert "# >>> pyve:managed:gitignore >>>" in gtext, (
            f"composed .gitignore must carry the managed markers; got:\n{gtext}"
        )
        assert "__pycache__" in gtext, (
            f"composed .gitignore must carry the python plugin entries; got:\n{gtext}"
        )

    # (Polyglot composition — both Python + Node sections in one .envrc — is
    # covered at the unit level; see the module docstring for why it is not a
    # real-`pyve init` test here.)

    def test_update_refreshes_envrc_preserving_user_content(self, pyve, project_builder):
        """`pyve update` refreshes the managed section, preserving the user tail."""
        init = pyve.run(
            "init", "--backend", "venv", "--force", "--no-project-guide",
            check=False, input=_DECLINE, timeout=300,
        )
        _skip_if_python_unresolvable(init)
        assert init.returncode == 0, f"init failed:\n{init.stdout}\n{init.stderr}"

        envrc = pyve.cwd / ".envrc"
        # User appends custom content below the managed end marker.
        envrc.write_text(envrc.read_text() + 'export MY_TOKEN="keepme"\n')

        upd = pyve.run("update", "--no-project-guide", check=False, timeout=120)
        assert upd.returncode == 0, f"update failed:\n{upd.stdout}\n{upd.stderr}"

        text = envrc.read_text()
        assert 'export MY_TOKEN="keepme"' in text, (
            f"update must preserve user content below the end marker; got:\n{text}"
        )
        assert MANAGED_START in text, "update must keep the managed section"
        assert (pyve.cwd / ".envrc.prev").exists(), (
            "update must back the prior .envrc up to .envrc.prev"
        )
