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
update`, including the ordering (config + manifest exist before compose) and
polyglot plugin enumeration.
"""

import pytest

MANAGED_START = "# >>> pyve:managed:start >>>"
MANAGED_END = "# <<< pyve:managed:end <<<"


@pytest.mark.venv
class TestComposedEnvrc:
    """End-to-end `.envrc` composition through `pyve init` / `pyve update`."""

    def test_venv_init_composes_managed_envrc(self, pyve, project_builder):
        """`pyve init --backend venv` writes a composed, sentinel-marked .envrc."""
        result = pyve.run(
            "init",
            "--backend", "venv",
            "--force",
            "--no-project-guide",
            check=False,
            timeout=300,
        )
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

    def test_polyglot_init_composes_both_plugin_sections(self, pyve, project_builder):
        """Python+Node at root → composed .envrc carries both plugin sections."""
        (pyve.cwd / "pyproject.toml").write_text(
            '[project]\nname = "demo"\nversion = "0.0.0"\n'
        )
        (pyve.cwd / "package.json").write_text('{"name": "demo"}\n')

        result = pyve.run(
            "init",
            "--backend", "venv",
            "--force",
            "--no-project-guide",
            "--node-path", "src/frontend",
            check=False,
            timeout=300,
        )
        assert result.returncode == 0, f"init failed:\n{result.stdout}\n{result.stderr}"

        text = (pyve.cwd / ".envrc").read_text()
        assert "# >>> pyve:plugin:python:activate >>>" in text, (
            f"polyglot .envrc must carry the python section; got:\n{text}"
        )
        assert "# >>> pyve:plugin:node:activate >>>" in text, (
            f"polyglot .envrc must carry the node section; got:\n{text}"
        )
        assert 'PATH_add "src/frontend/node_modules/.bin"' in text, (
            f"node section must PATH_add the sub-path bin dir; got:\n{text}"
        )

    def test_update_refreshes_envrc_preserving_user_content(self, pyve, project_builder):
        """`pyve update` refreshes the managed section, preserving the user tail."""
        init = pyve.run(
            "init", "--backend", "venv", "--force", "--no-project-guide",
            check=False, timeout=300,
        )
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
