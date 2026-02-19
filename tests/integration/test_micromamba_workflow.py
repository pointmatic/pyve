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
Integration tests for micromamba backend workflow.

Tests the complete workflow: init -> doctor -> run -> purge
"""

import pytest
from pathlib import Path


@pytest.mark.micromamba
@pytest.mark.requires_micromamba
class TestMicromambaWorkflow:
    """Test micromamba backend complete workflow."""
    
    def test_init_creates_environment(self, pyve, project_builder):
        """Test that --init creates a micromamba environment."""
        # Create an environment.yml
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        
        # Initialize with micromamba backend
        result = pyve.init(backend='micromamba')
        
        assert result.returncode == 0
        # Environment should be created
        assert 'test-env' in result.stdout or 'created' in result.stdout.lower()
    
    def test_init_with_env_name(self, pyve, project_builder):
        """Test --init with custom environment name."""
        project_builder.create_environment_yml(
            name='default-name',
            dependencies=['python=3.11']
        )
        
        # Initialize with custom env name
        result = pyve.init(backend='micromamba', env_name='custom-env')
        
        assert result.returncode == 0
    
    def test_init_with_conda_lock(self, pyve, project_builder):
        """Test --init with conda-lock.yml for reproducibility."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        # Create a mock conda-lock.yml (simplified)
        lock_file = pyve.cwd / 'conda-lock.yml'
        lock_file.write_text('# Mock conda-lock file\n')
        
        result = pyve.init(backend='micromamba', check=False)
        
        # Should handle lock file (may succeed or need actual lock file)
        assert result.returncode in [0, 1]
    
    def test_doctor_shows_micromamba_status(self, pyve, project_builder):
        """Test that doctor command shows micromamba status."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        pyve.init(backend='micromamba')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert 'micromamba' in result.stdout.lower()
    
    def test_run_executes_in_environment(self, pyve, project_builder):
        """Test that pyve run executes commands in micromamba environment."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        pyve.init(backend='micromamba')
        
        # Run python command to check environment
        result = pyve.run_cmd('python', '-c', 'import sys; print(sys.prefix)')
        
        assert result.returncode == 0
        # Should be running in micromamba environment
        assert 'envs' in result.stdout or 'micromamba' in result.stdout.lower()
    
    def test_run_with_installed_package(self, pyve, project_builder):
        """Test running Python code that uses installed package."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        pyve.init(backend='micromamba')
        
        # Run code that imports requests
        result = pyve.run_cmd('python', '-c', 'import requests; print("success")')
        
        assert result.returncode == 0
        assert 'success' in result.stdout
    
    def test_purge_removes_environment(self, pyve, project_builder):
        """Test that --purge removes micromamba environment."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        pyve.init(backend='micromamba')
        
        # Purge with auto-yes
        result = pyve.purge(auto_yes=True)
        
        assert result.returncode == 0
    
    def test_reinit_after_purge(self, pyve, project_builder):
        """Test that we can re-initialize after purge."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        # Init, purge, init again
        pyve.init(backend='micromamba')
        pyve.purge(auto_yes=True)
        result = pyve.init(backend='micromamba')
        
        assert result.returncode == 0
    
    def test_init_from_directory_name(self, pyve, project_builder):
        """Test environment name derived from directory when not in environment.yml."""
        # Create environment.yml without name field
        env_file = pyve.cwd / 'environment.yml'
        env_file.write_text("""
channels:
  - conda-forge
dependencies:
  - python=3.11
""")
        
        result = pyve.init(backend='micromamba', check=False)
        
        # Should derive name from directory or succeed
        assert result.returncode in [0, 1]
    
    def test_gitignore_updated_for_micromamba(self, pyve, project_builder):
        """Test that .gitignore has template entries and .pyve/envs but not env name."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        pyve.init(backend='micromamba')
        
        gitignore_path = pyve.cwd / '.gitignore'
        assert gitignore_path.exists()
        
        gitignore_content = gitignore_path.read_text()
        lines = gitignore_content.splitlines()
        
        # Template section headers and entries should be present
        assert '# Python build and test artifacts' in lines
        assert '# Pyve virtual environment' in lines
        assert '__pycache__' in lines
        assert '*.egg-info' in lines
        
        # Micromamba-specific entries in Pyve section
        assert '.pyve/envs' in lines
        assert '.env' in lines
        assert '.envrc' in lines
        assert '.pyve/testenv' in lines
        
        # Environment name should NOT be in gitignore
        assert 'test-env' not in gitignore_content


@pytest.mark.micromamba
@pytest.mark.requires_micromamba
class TestMicromambaEdgeCases:
    """Test micromamba backend edge cases and error handling."""
    
    def test_init_without_environment_yml(self, pyve):
        """Test --init without environment.yml."""
        result = pyve.init(backend='micromamba', check=False)
        
        # Should fail or create minimal environment
        assert result.returncode != 0 or 'environment.yml' in result.stderr.lower()
    
    def test_init_with_invalid_environment_yml(self, pyve):
        """Test --init with invalid environment.yml."""
        env_file = pyve.cwd / 'environment.yml'
        env_file.write_text('invalid: yaml: content: [')
        
        result = pyve.init(backend='micromamba', check=False)
        
        assert result.returncode != 0
    
    def test_run_without_init(self, pyve):
        """Test pyve run without initializing first."""
        result = pyve.run_cmd('python', '--version', check=False)
        
        # Should fail or warn
        assert result.returncode != 0 or 'not initialized' in result.stderr.lower()
    
    def test_doctor_without_init(self, pyve):
        """Test doctor command without initialization."""
        result = pyve.doctor(check=False)
        
        # Should succeed but show not initialized
        assert 'not initialized' in result.stdout.lower() or result.returncode != 0
    
    def test_purge_without_init(self, pyve):
        """Test --purge without initialization."""
        result = pyve.purge(auto_yes=True, check=False)
        
        # Should handle gracefully
        assert result.returncode in [0, 1]
    
    def test_double_init(self, pyve, project_builder):
        """Test running --init twice."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        pyve.init(backend='micromamba')
        result = pyve.init(backend='micromamba', check=False)
        
        # Should either skip or reinitialize
        assert result.returncode in [0, 1]
    
    def test_init_with_reserved_env_name(self, pyve, project_builder):
        """Test --init with reserved environment name."""
        project_builder.create_environment_yml(
            name='base',  # Reserved name
            dependencies=['python=3.11']
        )
        
        result = pyve.init(backend='micromamba', check=False)
        
        # Should fail with reserved name error
        assert result.returncode != 0 or 'reserved' in result.stderr.lower()
    
    def test_stale_lock_file_warning(self, pyve, project_builder):
        """Test warning when lock file is stale."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        # Create old lock file
        lock_file = pyve.cwd / 'conda-lock.yml'
        lock_file.write_text('# Old lock file\n')
        lock_file.touch()
        
        # Touch environment.yml to make it newer
        import time
        time.sleep(0.1)
        env_file = pyve.cwd / 'environment.yml'
        env_file.touch()
        
        result = pyve.init(backend='micromamba', check=False)
        
        # May warn about stale lock file
        assert result.returncode in [0, 1]


@pytest.mark.micromamba
@pytest.mark.requires_micromamba
class TestMicromambaBootstrap:
    """Test micromamba bootstrap functionality."""
    
    @pytest.mark.skip(reason="Bootstrap not yet implemented in v0.8.4")
    def test_auto_bootstrap_micromamba(self, pyve, project_builder):
        """Test automatic micromamba bootstrap."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        # This would test auto-bootstrap if micromamba not found
        # Skipped for now as bootstrap is planned for later version
        result = pyve.init(backend='micromamba', auto_bootstrap=True)
        
        assert result.returncode == 0
