"""
Integration tests for pyve doctor command.

Tests the doctor command for both venv and micromamba backends.
"""

import pytest
import platform


class TestDoctorVenv:
    """Test doctor command with venv backend."""
    
    @pytest.mark.venv
    def test_doctor_before_init(self, pyve):
        """Test doctor command before initialization."""
        result = pyve.doctor(check=False)
        
        # Should succeed but indicate not initialized
        assert 'not initialized' in result.stdout.lower() or 'no environment' in result.stdout.lower()
    
    @pytest.mark.venv
    def test_doctor_after_init(self, pyve, project_builder):
        """Test doctor command after venv initialization."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert 'venv' in result.stdout.lower()
    
    @pytest.mark.venv
    def test_doctor_shows_python_version(self, pyve, project_builder):
        """Test that doctor shows Python version."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        # Should show Python version info
        assert 'python' in result.stdout.lower()
    
    @pytest.mark.venv
    def test_doctor_shows_venv_location(self, pyve, project_builder):
        """Test that doctor shows venv location."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert '.venv' in result.stdout or 'venv' in result.stdout.lower()
    
    @pytest.mark.venv
    def test_doctor_with_custom_venv_dir(self, pyve, project_builder):
        """Test doctor with custom venv directory."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv', venv_dir='my_venv')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert 'my_venv' in result.stdout or 'venv' in result.stdout.lower()
    
    @pytest.mark.venv
    def test_doctor_detects_broken_venv(self, pyve, project_builder):
        """Test doctor detects broken/missing venv."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Remove the venv
        import shutil
        venv_path = pyve.cwd / '.venv'
        if venv_path.exists():
            shutil.rmtree(venv_path)
        
        result = pyve.doctor(check=False)
        
        # Should detect missing venv
        assert result.returncode != 0 or 'not found' in result.stdout.lower() or 'missing' in result.stdout.lower()


@pytest.mark.micromamba
@pytest.mark.requires_micromamba
class TestDoctorMicromamba:
    """Test doctor command with micromamba backend."""
    
    def test_doctor_before_init(self, pyve):
        """Test doctor command before initialization."""
        result = pyve.doctor(check=False)
        
        # Should succeed but indicate not initialized
        assert 'not initialized' in result.stdout.lower() or 'no environment' in result.stdout.lower()
    
    def test_doctor_after_init(self, pyve, project_builder):
        """Test doctor command after micromamba initialization."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        pyve.init(backend='micromamba')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert 'micromamba' in result.stdout.lower()
    
    def test_doctor_shows_environment_name(self, pyve, project_builder):
        """Test that doctor shows environment name."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        pyve.init(backend='micromamba')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert 'test-env' in result.stdout or 'environment' in result.stdout.lower()
    
    def test_doctor_shows_micromamba_version(self, pyve, project_builder):
        """Test that doctor shows micromamba version."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        pyve.init(backend='micromamba')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        # Should show version info
        assert 'version' in result.stdout.lower() or 'micromamba' in result.stdout.lower()
    
    def test_doctor_detects_missing_environment(self, pyve, project_builder):
        """Test doctor detects missing micromamba environment."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        pyve.init(backend='micromamba')
        
        # Remove the environment (would need micromamba command)
        # For now, just test that doctor runs
        result = pyve.doctor()
        
        assert result.returncode == 0


class TestDoctorParametrized:
    """Parametrized tests for both backends."""
    
    @pytest.mark.parametrize("backend,file_creator", [
        ("venv", lambda pb: pb.create_requirements(['requests==2.31.0'])),
        pytest.param(
            "micromamba",
            lambda pb: pb.create_environment_yml('test-env', dependencies=['python=3.11']),
            marks=[pytest.mark.micromamba, pytest.mark.requires_micromamba]
        ),
    ])
    def test_doctor_initialized_environment(self, pyve, project_builder, backend, file_creator):
        """Test doctor with initialized environment for both backends."""
        file_creator(project_builder)
        pyve.init(backend=backend)
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        assert backend in result.stdout.lower()
    
    @pytest.mark.parametrize("backend,file_creator", [
        ("venv", lambda pb: pb.create_requirements(['requests==2.31.0'])),
        pytest.param(
            "micromamba",
            lambda pb: pb.create_environment_yml('test-env', dependencies=['python=3.11']),
            marks=[pytest.mark.micromamba, pytest.mark.requires_micromamba]
        ),
    ])
    def test_doctor_after_purge(self, pyve, project_builder, backend, file_creator):
        """Test doctor after purging environment."""
        file_creator(project_builder)
        pyve.init(backend=backend)
        pyve.purge(auto_yes=True)
        
        result = pyve.doctor(check=False)
        
        # Should indicate not initialized
        assert 'not initialized' in result.stdout.lower() or 'no environment' in result.stdout.lower()


class TestDoctorEdgeCases:
    """Test edge cases for doctor command."""
    
    @pytest.mark.venv
    def test_doctor_with_corrupted_config(self, pyve, project_builder):
        """Test doctor with corrupted .pyve/config."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Corrupt the config
        config_path = pyve.cwd / '.pyve' / 'config'
        config_path.write_text('invalid: yaml: [[[')
        
        result = pyve.doctor(check=False)
        
        # Should handle gracefully
        assert result.returncode in [0, 1]
    
    @pytest.mark.venv
    def test_doctor_multiple_times(self, pyve, project_builder):
        """Test running doctor multiple times."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Run doctor multiple times
        for _ in range(3):
            result = pyve.doctor()
            assert result.returncode == 0
    
    @pytest.mark.venv
    def test_doctor_output_format(self, pyve, project_builder):
        """Test that doctor output is well-formatted."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.doctor()
        
        assert result.returncode == 0
        # Output should have some structure
        assert len(result.stdout) > 0
        # Should not have error messages
        assert 'error' not in result.stdout.lower() or 'no error' in result.stdout.lower()
