"""
Integration tests for pyve --validate command.

Tests validation functionality including version compatibility checks,
structure validation, and exit codes.
"""

import re

import pytest
import os
from pathlib import Path


class TestValidateCommand:
    """Test pyve --validate command functionality."""
    
    def test_validate_no_project(self, pyve, test_project):
        """Test validate command with no initialized project."""
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 1
        assert "not configured" in result.stdout or "missing" in result.stdout.lower()
    
    def test_validate_venv_project_success(self, pyve, project_builder):
        """Test validate command on healthy venv project."""
        pyve.init(backend='venv')
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 0
        assert "All validations passed" in result.stdout
    
    def test_validate_missing_venv(self, pyve, project_builder):
        """Test validate command when venv directory is missing."""
        # Create config but no venv
        project_builder.create_pyve_config(backend="venv")
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 1
        assert "missing" in result.stdout.lower()
    
    @pytest.mark.skipif(
        not os.environ.get("MICROMAMBA_AVAILABLE"),
        reason="Micromamba not available"
    )
    def test_validate_micromamba_project_success(self, pyve, project_builder):
        """Test validate command on healthy micromamba project."""
        # Initialize micromamba project
        project_builder.init_micromamba()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
        assert "✓" in result.stdout or "All validations passed" in result.stdout
    
    def test_validate_missing_environment_yml(self, pyve, project_builder):
        """Test validate command when environment.yml is missing."""
        # Create config for micromamba but no environment.yml
        project_builder.create_pyve_config(backend="micromamba")
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 1
        assert "environment.yml" in result.stdout.lower()
    
    def test_validate_version_mismatch_older(self, pyve, project_builder):
        """Test validate command with older version in config."""
        pyve.init(backend='venv')
        
        # Manually set older version in config
        config_path = pyve.cwd / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = re.sub(r'pyve_version: "[^"]+"', 'pyve_version: "0.6.6"', config_content)
        config_path.write_text(config_content)
        
        result = pyve.run("--validate", check=False)
        
        # Should warn but not fail
        assert result.returncode == 2
        assert "0.6.6" in result.stdout
    
    def test_validate_version_mismatch_newer(self, pyve, project_builder):
        """Test validate command with newer version in config."""
        pyve.init(backend='venv')
        
        # Manually set newer version in config
        config_path = pyve.cwd / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = re.sub(r'pyve_version: "[^"]+"', 'pyve_version: "99.0.0"', config_content)
        config_path.write_text(config_content)
        
        result = pyve.run("--validate", check=False)
        
        # Should warn but not fail
        assert result.returncode == 2
        assert "99.0.0" in result.stdout
    
    def test_validate_legacy_project_no_version(self, pyve, project_builder):
        """Test validate command on legacy project without version field."""
        # Initialize then strip the version from config to simulate legacy
        pyve.init(backend='venv')
        config_path = pyve.cwd / ".pyve" / "config"
        config_content = re.sub(r'pyve_version: "[^"]+"\n', '', config_path.read_text())
        config_path.write_text(config_content)
        
        result = pyve.run("--validate", check=False)
        
        # Should suggest adding version
        assert result.returncode == 2
        assert "not recorded" in result.stdout or "legacy" in result.stdout.lower()
    
    def test_validate_exit_code_success(self, pyve, project_builder):
        """Test validate command returns 0 on success."""
        pyve.init(backend='venv')
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 0
    
    def test_validate_exit_code_errors(self, pyve, project_builder):
        """Test validate command returns 1 on errors."""
        # Create incomplete project
        project_builder.create_pyve_config(backend="venv")
        # Don't create venv
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 1
    
    def test_validate_exit_code_warnings(self, pyve, project_builder):
        """Test validate command returns 2 on warnings only."""
        pyve.init(backend='venv')
        
        # Set older version to trigger warning
        config_path = pyve.cwd / ".pyve" / "config"
        config_content = re.sub(
            r'pyve_version: "[^"]+"', 'pyve_version: "0.6.6"',
            config_path.read_text(),
        )
        config_path.write_text(config_content)
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 2
    
    def test_validate_output_format(self, pyve, project_builder):
        """Test validate command output format."""
        pyve.init(backend='venv')
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 0
        assert "Pyve Installation Validation" in result.stdout
        assert "Backend" in result.stdout
    
    def test_validate_checks_backend(self, pyve, project_builder):
        """Test validate command checks backend configuration."""
        pyve.init(backend='venv')
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 0
        assert "Backend: venv" in result.stdout
    
    def test_validate_checks_python_version(self, pyve, project_builder):
        """Test validate command checks Python version."""
        pyve.init(backend='venv')
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 0
        assert "Python version:" in result.stdout
    
    def test_validate_checks_direnv(self, pyve, project_builder):
        """Test validate command checks direnv integration."""
        pyve.init(backend='venv')
        
        result = pyve.run("--validate", check=False)
        
        assert result.returncode == 0
        assert "direnv integration:" in result.stdout


@pytest.mark.skip(reason="--validate command not yet implemented (run_full_validation function missing)")
class TestValidateWithDoctor:
    """Test validate integration with doctor command."""
    
    def test_doctor_includes_version_check(self, pyve, project_builder):
        """Test doctor command includes version validation."""
        # Initialize project with old version
        project_builder.init_venv()
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = f'pyve_version: "0.6.6"\n{config_content}'
        config_path.write_text(config_content)
        
        result = pyve.run("doctor")
        
        # Doctor should show version warning
        assert result.returncode == 0
        # Output should mention version or show warning
        assert "0.6.6" in result.stdout or "version" in result.stdout.lower()
    
    def test_doctor_with_matching_version(self, pyve, project_builder):
        """Test doctor command with matching version."""
        project_builder.init_venv()
        
        result = pyve.run("doctor")
        
        assert result.returncode == 0
        # Should not show version warnings
        output_lower = result.stdout.lower()
        assert "backend" in output_lower or "environment" in output_lower


@pytest.mark.skip(reason="--validate command not yet implemented (run_full_validation function missing)")
class TestValidateEdgeCases:
    """Test validate command edge cases."""
    
    def test_validate_corrupted_config(self, pyve, project_builder):
        """Test validate with corrupted config file."""
        project_builder.project_dir.joinpath(".pyve").mkdir(exist_ok=True)
        project_builder.project_dir.joinpath(".pyve/config").write_text("invalid: yaml: content:")
        
        result = pyve.run("--validate")
        
        # Should handle gracefully
        assert result.returncode == 1
    
    def test_validate_empty_config(self, pyve, project_builder):
        """Test validate with empty config file."""
        project_builder.project_dir.joinpath(".pyve").mkdir(exist_ok=True)
        project_builder.project_dir.joinpath(".pyve/config").write_text("")
        
        result = pyve.run("--validate")
        
        assert result.returncode == 1
        assert "backend" in result.stdout.lower() or "missing" in result.stdout.lower()
    
    def test_validate_with_custom_venv_dir(self, pyve, project_builder):
        """Test validate with custom venv directory."""
        # Create config with custom venv directory
        project_builder.create_pyve_config(
            backend="venv",
            venv_dir="custom_venv"
        )
        project_builder.create_venv(venv_dir="custom_venv")
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
        assert "custom_venv" in result.stdout or "✓" in result.stdout
    
    def test_validate_multiple_issues(self, pyve, project_builder):
        """Test validate with multiple validation issues."""
        # Create config but missing everything else
        project_builder.create_pyve_config(backend="venv", include_version=False)
        
        result = pyve.run("--validate")
        
        # Should report multiple issues
        assert result.returncode == 1
        # Check for multiple error indicators
        error_count = result.stdout.count("✗") + result.stdout.count("missing")
        assert error_count > 0


@pytest.mark.skip(reason="--validate command not yet implemented (run_full_validation function missing)")
@pytest.mark.macos
class TestValidateMacOS:
    """macOS-specific validation tests."""
    
    def test_validate_with_asdf(self, pyve, project_builder):
        """Test validate with asdf version manager."""
        if not Path.home().joinpath(".asdf").exists():
            pytest.skip("asdf not installed")
        
        project_builder.init_venv()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0


@pytest.mark.skip(reason="--validate command not yet implemented (run_full_validation function missing)")
@pytest.mark.linux
class TestValidateLinux:
    """Linux-specific validation tests."""
    
    def test_validate_with_pyenv(self, pyve, project_builder):
        """Test validate with pyenv version manager."""
        if not Path.home().joinpath(".pyenv").exists():
            pytest.skip("pyenv not installed")
        
        project_builder.init_venv()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
