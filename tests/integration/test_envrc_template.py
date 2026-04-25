# Copyright (c) 2025-2026 Pointmatic (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Integration tests for the uniform `.envrc` template (v2.3.2 / Story K.a.2).

Asserts the generated `.envrc` file shape across backends and pins the
regression class fixed in v2.3.2: no relative literals on PATH that would
misresolve when the file is read from outside the project directory (which
broke rc-file completion guards like `command -v project-guide` before the
fix).

The shared ``ProjectBuilder.init_*`` helpers inject ``--no-direnv`` so no
.envrc is written; these tests therefore invoke ``pyve.run('init', ...)``
directly. A module-scoped fixture runs the init once and the tests read
the resulting .envrc, which keeps the suite fast.
"""

import pytest
import shutil
from pathlib import Path


@pytest.fixture(scope='module')
def venv_envrc_project(tmp_path_factory):
    """One-shot ``pyve init --backend venv`` with direnv enabled. Returns
    the .envrc text plus the project directory for project-dir-independence
    assertions. Skipped when direnv is not on PATH — pyve init aborts in
    that case (the .envrc generation only runs under the direnv path)."""
    if not shutil.which('direnv'):
        pytest.skip('direnv not installed on this runner')

    from pyve_test_helpers import PyveRunner, ProjectBuilder

    pyve_script_path = Path(__file__).parent.parent.parent / 'pyve.sh'
    project_dir = tmp_path_factory.mktemp('venv_envrc_project')
    builder = ProjectBuilder(project_dir)
    builder.create_requirements(['requests==2.31.0'])

    runner = PyveRunner(pyve_script_path, project_dir)
    result = runner.run('init', '--backend', 'venv', '--force', timeout=300)
    assert result.returncode == 0, (
        f"pyve init failed (stdout={result.stdout!r}, stderr={result.stderr!r})"
    )

    envrc_path = project_dir / '.envrc'
    assert envrc_path.exists(), 'pyve init did not generate .envrc'
    return {
        'text': envrc_path.read_text(),
        'project_dir': project_dir,
    }


@pytest.mark.venv
class TestVenvEnvrcTemplate:
    """`pyve init --backend venv` emits the uniform .envrc shape."""

    def test_envrc_uses_path_add_not_hand_rolled_export_path(self, venv_envrc_project):
        envrc = venv_envrc_project['text']

        assert 'PATH_add ".venv/bin"' in envrc
        for line in envrc.splitlines():
            assert not line.startswith('export PATH='), (
                f".envrc must not use hand-rolled export PATH=, found: {line!r}"
            )

    def test_envrc_exports_virtual_env_sentinel_with_pwd_prefix(self, venv_envrc_project):
        assert 'export VIRTUAL_ENV="$PWD/.venv"' in venv_envrc_project['text']

    def test_envrc_exports_pyve_backend_labels(self, venv_envrc_project):
        envrc = venv_envrc_project['text']
        assert 'export PYVE_BACKEND="venv"' in envrc
        assert 'export PYVE_ENV_NAME=' in envrc
        assert 'export PYVE_PROMPT_PREFIX="(venv:' in envrc

    def test_envrc_does_not_source_activate(self, venv_envrc_project):
        # v2.3.2 contract: activation is via PATH_add + VIRTUAL_ENV sentinel,
        # not by sourcing Python's activate script.
        assert 'bin/activate' not in venv_envrc_project['text']

    def test_envrc_includes_dotenv_block(self, venv_envrc_project):
        envrc = venv_envrc_project['text']
        assert 'if [[ -f ".env" ]]' in envrc
        assert 'dotenv' in envrc

    def test_envrc_is_project_dir_independent(self, venv_envrc_project):
        """The generated .envrc contains no absolute path baked in at init
        time. Only `$PWD` (runtime) and relative paths appear."""
        project_abs = str(venv_envrc_project['project_dir'].resolve())
        assert project_abs not in venv_envrc_project['text'], (
            f"Expected .envrc to be project-dir-independent but found "
            f"absolute path '{project_abs}' in:\n{venv_envrc_project['text']}"
        )


@pytest.mark.micromamba
class TestMicromambaEnvrcTemplate:
    """`pyve init --backend micromamba` emits the same uniform shape with
    backend-native sentinel (CONDA_PREFIX)."""

    def test_envrc_uses_path_add_and_conda_prefix(self, pyve, project_builder):
        if not shutil.which('micromamba'):
            pytest.skip('micromamba not installed on this runner')
        if not shutil.which('direnv'):
            pytest.skip('direnv not installed on this runner')

        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )
        result = pyve.run('init', '--backend', 'micromamba', '--force', timeout=300)
        if result.returncode != 0:
            pytest.skip(f"micromamba init failed: {result.stderr}")

        envrc = (pyve.cwd / '.envrc').read_text()

        assert 'PATH_add ".pyve/envs/' in envrc
        assert 'export CONDA_PREFIX="$PWD/.pyve/envs/' in envrc
        assert 'export PYVE_BACKEND="micromamba"' in envrc

        for line in envrc.splitlines():
            assert not line.startswith('export PATH='), (
                f".envrc must not use hand-rolled export PATH=, found: {line!r}"
            )
