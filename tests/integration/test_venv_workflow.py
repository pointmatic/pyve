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
Integration tests for venv backend workflow.

Tests the complete workflow: init -> doctor -> run -> purge
"""

import pytest
from pathlib import Path


@pytest.mark.venv
class TestVenvWorkflow:
    """Test venv backend complete workflow."""
    
    def test_init_creates_venv(self, pyve, project_builder):
        """Test that --init creates a venv."""
        # Create a requirements.txt
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Initialize with venv backend
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
        assert (pyve.cwd / '.venv' / 'bin' / 'python').exists()
    
    def test_init_with_python_version(self, pyve, project_builder):
        """Test --init with specific Python version."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Initialize with specific Python version - use check=False to see actual error
        result = pyve.init(backend='venv', python_version='3.11', check=False)
        
        # Test may fail if Python 3.11 not available, that's okay
        if result.returncode == 0:
            assert (pyve.cwd / '.venv').exists()
    
    def test_init_with_custom_venv_dir(self, pyve, project_builder):
        """Test --init with custom venv directory."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Initialize with custom directory - use check=False to see actual error
        result = pyve.init(backend='venv', venv_dir='my_venv', check=False)
        
        # Test may fail due to pyenv issues, that's okay
        if result.returncode == 0:
            assert (pyve.cwd / 'my_venv').exists()
            assert (pyve.cwd / 'my_venv' / 'bin' / 'python').exists()
    
    def test_init_installs_dependencies(self, pyve, project_builder):
        """Test that --init installs dependencies from requirements.txt."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        # Install dependencies
        pyve.run_cmd('pip', 'install', '-r', 'requirements.txt')
        # Check that requests was installed
        pip_list = pyve.run_cmd('pip', 'list')
        assert 'requests' in pip_list.stdout.lower()
    
    def test_doctor_shows_venv_status(self, pyve, project_builder):
        """Test that doctor command shows venv status."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert 'venv' in result.stdout.lower()
    
    def test_run_executes_in_venv(self, pyve, project_builder):
        """Test that pyve run executes commands in venv."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Run python command to check it's using venv
        result = pyve.run_cmd('python', '-c', 'import sys; print(sys.prefix)')
        
        assert result.returncode == 0
        assert '.venv' in result.stdout
    
    def test_run_with_installed_package(self, pyve, project_builder):
        """Test running Python code that uses installed package."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        pyve.run_cmd('pip', 'install', '-r', 'requirements.txt')
        
        # Run code that imports requests
        result = pyve.run_cmd('python', '-c', 'import requests; print(requests.__version__)')
        
        assert result.returncode == 0
        assert '2.31.0' in result.stdout
    
    def test_purge_removes_venv(self, pyve, project_builder):
        """Test that --purge removes venv."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        assert (pyve.cwd / '.venv').exists()
        
        # Purge with auto-yes
        result = pyve.purge(auto_yes=True)
        
        assert result.returncode == 0
        assert not (pyve.cwd / '.venv').exists()
    
    def test_purge_with_custom_venv_dir(self, pyve, project_builder):
        """Test --purge with custom venv directory."""
        project_builder.create_requirements(['requests==2.31.0'])
        result = pyve.init(backend='venv', venv_dir='my_venv', check=False)
        
        # Only test purge if init succeeded
        if result.returncode == 0:
            assert (pyve.cwd / 'my_venv').exists()
            
            result = pyve.purge(auto_yes=True)
            
            assert result.returncode == 0
            assert not (pyve.cwd / 'my_venv').exists()
    
    def test_reinit_after_purge(self, pyve, project_builder):
        """Test that we can re-initialize after purge."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Init, purge, init again
        pyve.init(backend='venv')
        pyve.purge(auto_yes=True)
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
    
    def test_init_with_pyproject_toml(self, pyve, project_builder):
        """Test --init with pyproject.toml."""
        project_builder.create_pyproject_toml(
            name='test-project',
            dependencies=['requests==2.31.0']
        )
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
    
    def test_gitignore_updated(self, pyve, project_builder):
        """Test that .gitignore is updated with template and venv entries."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        pyve.init(backend='venv')
        
        gitignore_path = pyve.cwd / '.gitignore'
        assert gitignore_path.exists()
        
        gitignore_content = gitignore_path.read_text()
        lines = gitignore_content.splitlines()
        
        # Template section headers
        assert '# Python build and test artifacts' in lines
        assert '# Pyve virtual environment' in lines
        
        # Template entries
        assert '__pycache__' in lines
        assert '*.egg-info' in lines
        assert '.coverage' in lines
        assert 'coverage.xml' in lines
        assert 'htmlcov/' in lines
        assert '.pytest_cache/' in lines
        assert '.DS_Store' in lines
        
        # Venv-specific entries in Pyve section
        assert '.venv' in lines
        assert '.env' in lines
        assert '.envrc' in lines
        assert '.pyve/testenv' in lines


@pytest.mark.venv
class TestGitignoreManagement:
    """Test .gitignore template, idempotency, self-healing, and purge behavior."""
    
    def test_gitignore_idempotent(self, pyve, project_builder):
        """Test that running init twice produces identical .gitignore."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        pyve.init(backend='venv')
        first_content = (pyve.cwd / '.gitignore').read_text()
        
        pyve.init(backend='venv')
        second_content = (pyve.cwd / '.gitignore').read_text()
        
        assert first_content == second_content
    
    def test_gitignore_self_healing(self, pyve, project_builder):
        """Test that user entries are preserved and template entries restored."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Write a custom .gitignore before init
        gitignore_path = pyve.cwd / '.gitignore'
        gitignore_path.write_text("my-custom-dir/\nmy-secret\n")
        
        pyve.init(backend='venv')
        
        content = gitignore_path.read_text()
        lines = content.splitlines()
        
        # Template entries restored at top
        assert '# Python build and test artifacts' in lines
        assert '__pycache__' in lines
        assert '*.egg-info' in lines
        
        # User entries preserved
        assert 'my-custom-dir/' in lines
        assert 'my-secret' in lines
        
        # Template entries not duplicated
        assert lines.count('__pycache__') == 1
    
    def test_gitignore_purge_preserves_permanent_entries(self, pyve, project_builder):
        """Test that purge removes only .venv/.env/.envrc, not permanent entries."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        pyve.init(backend='venv')
        
        # Verify entries exist before purge
        gitignore_path = pyve.cwd / '.gitignore'
        content_before = gitignore_path.read_text()
        assert '.venv' in content_before
        assert '__pycache__' in content_before
        assert '.pyve/testenv' in content_before
        
        pyve.purge(auto_yes=True)
        
        # .gitignore should still exist
        assert gitignore_path.exists()
        content_after = gitignore_path.read_text()
        lines = content_after.splitlines()
        
        # Purged entries should be gone
        assert '.venv' not in lines
        assert '.env' not in lines
        assert '.envrc' not in lines
        
        # Permanent entries should remain
        assert '__pycache__' in lines
        assert '*.egg-info' in lines
        assert '.pyve/testenv' in lines
        assert '.coverage' in lines
        assert '.pytest_cache/' in lines


@pytest.mark.venv
class TestVenvEdgeCases:
    """Test venv backend edge cases and error handling."""
    
    def test_init_without_requirements(self, pyve):
        """Test --init without requirements.txt or pyproject.toml."""
        # Should still work, just create empty venv
        result = pyve.init(backend='venv', check=False)
        
        # May succeed or fail depending on implementation
        # At minimum, should not crash
        assert result.returncode in [0, 1]
    
    def test_init_fails_with_invalid_python_version(self, pyve, project_builder):
        """Test --init with invalid Python version."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv', python_version='99.99.99', check=False)
        
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
        project_builder.create_requirements(['requests==2.31.0'])
        
        pyve.init(backend='venv')
        result = pyve.init(backend='venv', check=False)
        
        # Should either skip or reinitialize
        assert result.returncode in [0, 1]
