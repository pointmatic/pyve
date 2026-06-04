# Copyright (c) 2026 Pointmatic (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Integration tests for the Node plugin's scaffold-time detection consult
in `pyve init` (Story N.t, Task 4).

Decision (advisory-only consult): when `package.json` is present, the init
wizard *consults* the Node plugin's detection hook and surfaces an advisory
note, but it does NOT mutate the scaffolded `pyve.toml`. Auto-writing a
`[plugins.node]` block is deferred to the composed-activation subphase
(N-4): a root-level package.json next to a Python project can't be expressed
as a valid polyglot manifest, because declaring any plugin switches off the
implicit-Python rule and two plugins at path="." is an S4 cardinality error.

These tests pin the advisory behavior and the no-mutation guarantee.
"""

import pytest


@pytest.mark.venv
class TestNodeDetectionConsult:
    """`pyve init` Node detection consult — advisory only, no manifest write.

    A single full `pyve init` run proves the helper is actually wired into
    the init flow (a bats unit test of the helper alone can't). The advisory
    wording, no-mutation guarantee, and pure-Python silence are pinned fast
    in tests/unit/test_n_t_node_plugin.bats; this asserts the end-to-end
    consult and the no-mutation guarantee together in one (slow) init.
    """

    def test_init_consults_node_detection_without_mutating_manifest(self, pyve, project_builder):
        """package.json present → init surfaces the advisory AND leaves pyve.toml plugin-free."""
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

        assert "Node project detected" in result.stdout, (
            f"Expected Node advisory in stdout; got:\n{result.stdout!r}"
        )
        toml_text = (pyve.cwd / "pyve.toml").read_text()
        assert "[plugins" not in toml_text, (
            f"Advisory must not write a plugins block; pyve.toml was:\n{toml_text}"
        )
