# Copyright (c) 2026 Pointmatic (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Integration tests for the polyglot `pyve init` scaffold (Story N.ad).

N.t shipped Node detection as advisory-only: when `package.json` was
present, `pyve init` surfaced a note but left `pyve.toml` plugin-free,
deferring the real scaffold to Subphase N-4. N.ad closes that hole — when
both Python and Node fire at root, `pyve init` now writes a polyglot
manifest with explicit `[plugins.python]` (root) + `[plugins.node]`
(sub-path) blocks, resolving the S4+S5 collision (declaring any plugin
disables the implicit-Python rule, and two plugins at path="." is an S4
cardinality error — so Node must land at a distinct sub-path).

A single full `pyve init` run proves the scaffold orchestrator is wired
into the init flow (a bats unit test of the helper alone can't). The
branch logic (0/1/2+ conventions, `--node-path`, idempotence) is pinned
fast in tests/unit/test_polyglot_scaffold.bats; this asserts the
end-to-end scaffold and the `--node-path` override together in one (slow)
init.
"""

import pytest


@pytest.mark.venv
class TestPolyglotInitScaffold:
    """`pyve init` polyglot scaffold — Python at root, Node at a sub-path."""

    def test_init_writes_polyglot_manifest_when_node_detected(self, pyve, project_builder):
        """package.json at root → init writes [plugins.python] + [plugins.node]."""
        # A Python signal so init proceeds down the venv path, plus a
        # package.json so the Node detection hook fires.
        (pyve.cwd / "pyproject.toml").write_text(
            '[project]\nname = "demo"\nversion = "0.0.0"\n'
        )
        (pyve.cwd / "package.json").write_text('{"name": "demo"}\n')

        result = pyve.run(
            "init",
            "--backend", "venv",
            "--no-direnv",
            "--force",
            "--no-project-guide",
            check=False,
            timeout=300,
        )

        assert "Polyglot project detected" in result.stdout, (
            f"Expected polyglot scaffold banner in stdout; got:\n{result.stdout!r}"
        )
        toml_text = (pyve.cwd / "pyve.toml").read_text()
        assert "[plugins.python]" in toml_text, (
            f"Polyglot scaffold must declare [plugins.python]; pyve.toml was:\n{toml_text}"
        )
        assert "[plugins.node]" in toml_text, (
            f"Polyglot scaffold must declare [plugins.node]; pyve.toml was:\n{toml_text}"
        )
        # No conventions present + non-interactive (CI) → default sub-path.
        assert 'path = "src/frontend"' in toml_text, (
            f"Default Node sub-path expected; pyve.toml was:\n{toml_text}"
        )

    def test_init_node_path_flag_overrides_detection(self, pyve, project_builder):
        """--node-path wins over convention inference for scripted use."""
        (pyve.cwd / "pyproject.toml").write_text(
            '[project]\nname = "demo"\nversion = "0.0.0"\n'
        )
        (pyve.cwd / "package.json").write_text('{"name": "demo"}\n')

        result = pyve.run(
            "init",
            "--backend", "venv",
            "--no-direnv",
            "--force",
            "--no-project-guide",
            "--node-path", "apps/web",
            check=False,
            timeout=300,
        )

        assert result.returncode == 0, f"init failed:\n{result.stdout}\n{result.stderr}"
        toml_text = (pyve.cwd / "pyve.toml").read_text()
        assert 'path = "apps/web"' in toml_text, (
            f"--node-path override expected in pyve.toml; was:\n{toml_text}"
        )
