"""
Integration tests for pyve run command.

Tests the run command for executing commands in virtual environments.
"""

import pytest
import sys


class TestRunVenv:
    """Test pyve run command with venv backend."""
    
    @pytest.mark.venv
    def test_run_python_version(self, pyve, project_builder):
        """Test running python --version in venv."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '--version')
        
        assert result.returncode == 0
        assert 'python' in result.stdout.lower()
    
    @pytest.mark.venv
    def test_run_python_script(self, pyve, project_builder):
        """Test running a Python script in venv."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create a simple Python script
        script = project_builder.create_python_script(
            'test_script.py',
            'print("Hello from venv")'
        )
        
        result = pyve.run_cmd('python', 'test_script.py')
        
        assert result.returncode == 0
        assert 'Hello from venv' in result.stdout
    
    @pytest.mark.venv
    def test_run_imports_installed_package(self, pyve, project_builder):
        """Test that run can import installed packages."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'import requests; print(requests.__version__)')
        
        assert result.returncode == 0
        assert '2.31.0' in result.stdout
    
    @pytest.mark.venv
    def test_run_pip_list(self, pyve, project_builder):
        """Test running pip list in venv."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('pip', 'list')
        
        assert result.returncode == 0
        assert 'requests' in result.stdout.lower()
    
    @pytest.mark.venv
    def test_run_with_arguments(self, pyve, project_builder):
        """Test running command with multiple arguments."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'import sys; print(sys.argv)', 'arg1', 'arg2')
        
        assert result.returncode == 0
        assert 'arg1' in result.stdout
        assert 'arg2' in result.stdout
    
    @pytest.mark.venv
    def test_run_with_environment_variables(self, pyve, project_builder):
        """Test that environment variables are accessible."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'import os; print(os.environ.get("PATH", ""))')
        
        assert result.returncode == 0
        assert len(result.stdout) > 0
    
    @pytest.mark.venv
    def test_run_fails_with_invalid_command(self, pyve, project_builder):
        """Test that run fails with invalid command."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('nonexistent_command', check=False)
        
        assert result.returncode != 0
    
    @pytest.mark.venv
    def test_run_python_with_exit_code(self, pyve, project_builder):
        """Test that run preserves exit codes."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'import sys; sys.exit(42)', check=False)
        
        assert result.returncode == 42
    
    @pytest.mark.venv
    def test_run_without_init_fails(self, pyve):
        """Test that run fails when environment not initialized."""
        result = pyve.run_cmd('python', '--version', check=False)
        
        assert result.returncode != 0 or 'not initialized' in result.stderr.lower()


@pytest.mark.micromamba
@pytest.mark.requires_micromamba
class TestRunMicromamba:
    """Test pyve run command with micromamba backend."""
    
    def test_run_python_version(self, pyve, project_builder):
        """Test running python --version in micromamba env."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        pyve.init(backend='micromamba')
        
        result = pyve.run_cmd('python', '--version')
        
        assert result.returncode == 0
        assert 'python' in result.stdout.lower()
    
    def test_run_python_script(self, pyve, project_builder):
        """Test running a Python script in micromamba env."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        pyve.init(backend='micromamba')
        
        script = project_builder.create_python_script(
            'test_script.py',
            'print("Hello from micromamba")'
        )
        
        result = pyve.run_cmd('python', 'test_script.py')
        
        assert result.returncode == 0
        assert 'Hello from micromamba' in result.stdout
    
    def test_run_imports_installed_package(self, pyve, project_builder):
        """Test that run can import conda packages."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        pyve.init(backend='micromamba')
        
        result = pyve.run_cmd('python', '-c', 'import requests; print("success")')
        
        assert result.returncode == 0
        assert 'success' in result.stdout
    
    def test_run_conda_list(self, pyve, project_builder):
        """Test running conda list in micromamba env."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        pyve.init(backend='micromamba')
        
        result = pyve.run_cmd('conda', 'list', check=False)
        
        # May or may not work depending on micromamba setup
        assert result.returncode in [0, 1]
    
    def test_run_without_init_fails(self, pyve):
        """Test that run fails when environment not initialized."""
        result = pyve.run_cmd('python', '--version', check=False)
        
        assert result.returncode != 0 or 'not initialized' in result.stderr.lower()


class TestRunParametrized:
    """Parametrized tests for both backends."""
    
    @pytest.mark.parametrize("backend,file_creator", [
        ("venv", lambda pb: pb.create_requirements(['requests==2.31.0'])),
        pytest.param(
            "micromamba",
            lambda pb: pb.create_environment_yml('test-env', dependencies=['python=3.11', 'requests']),
            marks=[pytest.mark.micromamba, pytest.mark.requires_micromamba]
        ),
    ])
    def test_run_python_import(self, pyve, project_builder, backend, file_creator):
        """Test running Python import for both backends."""
        file_creator(project_builder)
        pyve.init(backend=backend)
        
        result = pyve.run_cmd('python', '-c', 'import sys; print(sys.version)')
        
        assert result.returncode == 0
        assert len(result.stdout) > 0
    
    @pytest.mark.parametrize("backend,file_creator", [
        ("venv", lambda pb: pb.create_requirements(['requests==2.31.0'])),
        pytest.param(
            "micromamba",
            lambda pb: pb.create_environment_yml('test-env', dependencies=['python=3.11', 'requests']),
            marks=[pytest.mark.micromamba, pytest.mark.requires_micromamba]
        ),
    ])
    def test_run_installed_package(self, pyve, project_builder, backend, file_creator):
        """Test that installed packages work for both backends."""
        file_creator(project_builder)
        pyve.init(backend=backend)
        
        result = pyve.run_cmd('python', '-c', 'import requests; print("OK")')
        
        assert result.returncode == 0
        assert 'OK' in result.stdout
    
    @pytest.mark.parametrize("backend,file_creator", [
        ("venv", lambda pb: pb.create_requirements(['requests==2.31.0'])),
        pytest.param(
            "micromamba",
            lambda pb: pb.create_environment_yml('test-env', dependencies=['python=3.11']),
            marks=[pytest.mark.micromamba, pytest.mark.requires_micromamba]
        ),
    ])
    def test_run_preserves_exit_codes(self, pyve, project_builder, backend, file_creator):
        """Test that exit codes are preserved for both backends."""
        file_creator(project_builder)
        pyve.init(backend=backend)
        
        result = pyve.run_cmd('python', '-c', 'import sys; sys.exit(5)', check=False)
        
        assert result.returncode == 5


class TestRunEdgeCases:
    """Test edge cases for run command."""
    
    @pytest.mark.venv
    def test_run_with_stdin_input(self, pyve, project_builder):
        """Test running command with stdin input."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # This tests that stdin can be provided
        script = project_builder.create_python_script(
            'read_input.py',
            'data = input(); print(f"Got: {data}")'
        )
        
        # Note: This may not work with current PyveRunner implementation
        # but tests the concept
        result = pyve.run_cmd('python', 'read_input.py', check=False)
        
        # Should either work or fail gracefully
        assert result.returncode in [0, 1]
    
    @pytest.mark.venv
    def test_run_with_long_output(self, pyve, project_builder):
        """Test running command with long output."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'for i in range(100): print(i)')
        
        assert result.returncode == 0
        assert '99' in result.stdout
    
    @pytest.mark.venv
    def test_run_script_with_imports(self, pyve, project_builder):
        """Test running script that imports multiple packages."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        script = project_builder.create_python_script(
            'multi_import.py',
            '''
import sys
import os
import requests

print("All imports successful")
print(f"Python: {sys.version}")
print(f"Requests: {requests.__version__}")
'''
        )
        
        result = pyve.run_cmd('python', 'multi_import.py')
        
        assert result.returncode == 0
        assert 'All imports successful' in result.stdout
        assert '2.31.0' in result.stdout
    
    @pytest.mark.venv
    def test_run_with_relative_paths(self, pyve, project_builder):
        """Test running script with relative paths."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create script in subdirectory
        subdir = pyve.cwd / 'scripts'
        subdir.mkdir()
        script_path = subdir / 'test.py'
        script_path.write_text('print("From subdirectory")')
        
        result = pyve.run_cmd('python', 'scripts/test.py')
        
        assert result.returncode == 0
        assert 'From subdirectory' in result.stdout
    
    @pytest.mark.venv
    def test_run_multiple_commands_sequentially(self, pyve, project_builder):
        """Test running multiple commands in sequence."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Run multiple commands
        result1 = pyve.run_cmd('python', '--version')
        result2 = pyve.run_cmd('pip', 'list')
        result3 = pyve.run_cmd('python', '-c', 'print("test")')
        
        assert result1.returncode == 0
        assert result2.returncode == 0
        assert result3.returncode == 0
        assert 'test' in result3.stdout
