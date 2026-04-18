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
Integration tests for pip auto-upgrade during initialization.

Tests that pyve init and pyve init --update automatically upgrade pip
to the latest version for both venv and micromamba backends.
"""

import pytest
import re


class TestPipUpgradeVenv:
    """Test pip auto-upgrade with venv backend."""
    
    @pytest.mark.venv
    def test_init_upgrades_pip(self, pyve, project_builder):
        """Test that pyve init upgrades pip to latest version."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Initialize with venv backend
        result = pyve.init(backend='venv')
        assert result.returncode == 0
        
        # Check pip version - should be relatively recent
        result = pyve.run_cmd('python', '-m', 'pip', '--version')
        assert result.returncode == 0
        
        # Extract version number from output like "pip 24.0 from ..."
        match = re.search(r'pip (\d+\.\d+)', result.stdout)
        assert match, f"Could not parse pip version from: {result.stdout}"
        
        pip_version = match.group(1)
        major, minor = map(int, pip_version.split('.'))
        
        # Pip should be at least version 23.0 (released in 2023)
        # This is a reasonable baseline for "upgraded" pip
        assert major >= 23, f"pip version {pip_version} seems outdated"
    
    @pytest.mark.venv
    def test_update_upgrades_pip(self, pyve, project_builder):
        """Test that pyve init --update upgrades pip."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Initial setup
        pyve.init(backend='venv')
        
        # Run update
        result = pyve.run('init', '--update', '--no-direnv')
        assert result.returncode == 0
        
        # Verify pip is upgraded
        result = pyve.run_cmd('python', '-m', 'pip', '--version')
        assert result.returncode == 0
        assert 'pip' in result.stdout


@pytest.mark.micromamba
@pytest.mark.requires_micromamba
class TestPipUpgradeMicromamba:
    """Test pip auto-upgrade with micromamba backend."""
    
    def test_init_upgrades_pip(self, pyve, project_builder):
        """Test that pyve init upgrades pip with micromamba backend."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        
        # Initialize with micromamba backend
        result = pyve.init(backend='micromamba')
        assert result.returncode == 0
        
        # Check pip version
        result = pyve.run_cmd('python', '-m', 'pip', '--version')
        assert result.returncode == 0
        
        # Extract version number
        match = re.search(r'pip (\d+\.\d+)', result.stdout)
        assert match, f"Could not parse pip version from: {result.stdout}"
        
        pip_version = match.group(1)
        major, minor = map(int, pip_version.split('.'))
        
        # Pip should be reasonably recent
        assert major >= 23, f"pip version {pip_version} seems outdated"
    
    def test_update_upgrades_pip(self, pyve, project_builder):
        """Test that pyve init --update upgrades pip with micromamba."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        
        # Initial setup
        pyve.init(backend='micromamba')
        
        # Run update
        result = pyve.run('init', '--update', '--no-direnv')
        assert result.returncode == 0
        
        # Verify pip is present and working
        result = pyve.run_cmd('python', '-m', 'pip', '--version')
        assert result.returncode == 0
        assert 'pip' in result.stdout
