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
pytest fixtures for Pyve integration tests.
"""

import pytest
from pathlib import Path
import sys

# Add helpers to path
helpers_path = Path(__file__).parent.parent / 'helpers'
sys.path.insert(0, str(helpers_path))

from pyve_test_helpers import PyveRunner, ProjectBuilder


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
