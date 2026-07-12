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
pytest fixtures for Pyve integration tests.
"""

import os
import pytest
from pathlib import Path
import sys

# Add helpers to path
helpers_path = Path(__file__).parent.parent / 'helpers'
sys.path.insert(0, str(helpers_path))

from pyve_test_helpers import PyveRunner, ProjectBuilder
from home_guard import diff_hosting_state, snapshot_hosting_state


@pytest.fixture(scope="session", autouse=True)
def real_home_mutation_guard():
    """
    Suite-level regression guard for the test-isolation leak: the suite
    must NEVER mutate the real home's Pyve hosting artifacts (the
    ~/.local/bin/project-guide shim and the toolchain tree under
    ${XDG_DATA_HOME:-~/.local/share}/pyve/toolchain). Their state is
    recorded before the first test; teardown fails the run if it changed.

    PYVE_TEST_GUARD_HOME overrides the guarded home for manual
    verification of the guard itself.
    """
    home = Path(os.environ.get("PYVE_TEST_GUARD_HOME") or os.path.expanduser("~"))
    xdg = os.environ.get("XDG_DATA_HOME")
    before = snapshot_hosting_state(home, xdg)
    yield
    problems = diff_hosting_state(before, snapshot_hosting_state(home, xdg))
    if problems:
        pytest.fail(
            f"Integration suite mutated real Pyve hosting state under {home}:\n  "
            + "\n  ".join(problems)
            + "\nEvery test that can reach provisioning must run inside "
            "_isolate_home's self-contained sandbox "
            "(tests/integration/test_project_guide_integration.py).",
            pytrace=False,
        )


@pytest.fixture
def pyve_script():
    """Path to pyve.sh script."""
    return Path(__file__).parent.parent.parent / "pyve.sh"


@pytest.fixture
def test_project(tmp_path):
    """Create a temporary test project directory."""
    project_dir = tmp_path / "test_project"
    project_dir.mkdir()
    return project_dir


@pytest.fixture
def pyve(pyve_script, test_project):
    """Pyve runner fixture."""
    return PyveRunner(pyve_script, test_project)


@pytest.fixture
def project_builder(test_project):
    """Project builder fixture."""
    return ProjectBuilder(test_project)


@pytest.fixture(autouse=True)
def clean_env(monkeypatch):
    """Clean environment variables."""
    # Remove any pyve-related env vars
    import os
    for key in list(os.environ.keys()):
        if key.startswith('PYVE_'):
            monkeypatch.delenv(key, raising=False)
    return monkeypatch
