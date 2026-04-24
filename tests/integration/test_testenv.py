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

import os
import re
import subprocess
import pytest


class TestTestenvRun:
    """Test pyve testenv run <command>."""

    @pytest.mark.venv
    def test_testenv_run_no_command_shows_error(self, pyve, project_builder):
        """testenv run with no command exits 1 with usage hint."""
        project_builder.create_requirements([])
        pyve.init(backend='venv')
        # Ensure testenv exists
        pyve.run('testenv', 'init')

        result = pyve.run('testenv', 'run', check=False)
        assert result.returncode == 1
        assert 'no command' in result.stderr.lower() or 'usage' in result.stderr.lower()

    @pytest.mark.venv
    def test_testenv_run_before_init_shows_error(self, pyve, project_builder):
        """testenv run before --init exits 1 with init hint."""
        project_builder.create_requirements([])
        pyve.init(backend='venv')
        # pyve init auto-creates the testenv, so remove it to test the guard
        import shutil
        testenv_venv = pyve.cwd / '.pyve' / 'testenv' / 'venv'
        if testenv_venv.exists():
            shutil.rmtree(testenv_venv)

        result = pyve.run('testenv', 'run', 'python', '--version', check=False)
        assert result.returncode == 1
        assert 'not initialized' in result.stderr.lower()
        # H.f.3 standardized the hint on v2.0 grammar (`pyve testenv init`)
        # instead of the deprecated `pyve testenv --init` flag form.
        assert 'testenv init' in result.stderr.lower()

    @pytest.mark.venv
    def test_testenv_run_python_version(self, pyve, project_builder):
        """testenv run python --version succeeds."""
        project_builder.create_requirements([])
        pyve.init(backend='venv')
        pyve.run('testenv', 'init')

        result = pyve.run('testenv', 'run', 'python', '--version')
        assert result.returncode == 0
        assert 'python' in result.stdout.lower()

    @pytest.mark.venv
    def test_testenv_run_propagates_exit_code(self, pyve, project_builder):
        """testenv run propagates non-zero exit code from command."""
        project_builder.create_requirements([])
        pyve.init(backend='venv')
        pyve.run('testenv', 'init')

        result = pyve.run('testenv', 'run', 'python', '-c', 'import sys; sys.exit(42)', check=False)
        assert result.returncode == 42


def test_testenv_survives_force_reinit(pyve, project_builder):
    pyve.init(backend="venv")

    # `pyve test` should auto-create the dev/test runner env and (in tests/CI)
    # auto-install pytest without prompting.
    testenv_python = project_builder.project_dir / ".pyve" / "testenv" / "venv" / "bin" / "python"

    result = pyve.run("test", "-q", check=False)
    # If there are no tests, pytest exits 5. Accept that as success signal for wiring.
    assert result.returncode in (0, 5)

    assert testenv_python.exists()

    # Force re-init should purge the project env but preserve testenv.
    os.environ["PYVE_FORCE_YES"] = "1"
    result = pyve.run("init", "--force", "--no-direnv")
    assert result.returncode == 0

    assert testenv_python.exists()

    # Confirm pytest still runs via the preserved test runner env.
    result = pyve.run("test", "-q", check=False)
    # If there are no tests, pytest exits 5. Accept that as success signal for wiring.
    assert result.returncode in (0, 5)


@pytest.mark.venv
def test_testenv_rebuilt_when_python_version_stale(pyve, project_builder):
    """ensure_testenv_exists must rebuild the testenv when its Python version
    differs from the project Python.

    Regression test for: pyve init --force called purge --keep-testenv, so a
    testenv built with an older Python was preserved even after the project's
    Python version changed. The fix: ensure_testenv_exists() compares the
    testenv's pyvenv.cfg version against the current 'python' shim and rebuilds
    on mismatch.
    """
    project_builder.create_requirements([])
    pyve.init(backend='venv')

    testenv_venv = pyve.cwd / '.pyve' / 'testenv' / 'venv'
    assert testenv_venv.exists(), "testenv was not created by pyve init"

    pyvenv_cfg = testenv_venv / 'pyvenv.cfg'
    assert pyvenv_cfg.exists(), "pyvenv.cfg missing from testenv"

    # Corrupt pyvenv.cfg to simulate a stale testenv from a different Python
    # version (e.g., testenv was 3.14.4, project was changed to 3.12.13).
    original = pyvenv_cfg.read_text()
    stale = re.sub(r'(?m)^version\s*=.*$', 'version = 9.9.9', original)
    pyvenv_cfg.write_text(stale)
    assert 'version = 9.9.9' in pyvenv_cfg.read_text()

    # Running testenv --init should detect the version mismatch and rebuild.
    result = pyve.run('testenv', 'init')
    assert result.returncode == 0

    # After rebuild, pyvenv.cfg must no longer report 9.9.9.
    rebuilt_cfg = pyvenv_cfg.read_text()
    assert 'version = 9.9.9' not in rebuilt_cfg, (
        "ensure_testenv_exists() did not rebuild the testenv after detecting "
        "a Python version mismatch (pyvenv.cfg still says 9.9.9). "
        "This is the regression: pyve init --force preserves a stale testenv "
        "via --keep-testenv without checking whether the Python version changed."
    )
