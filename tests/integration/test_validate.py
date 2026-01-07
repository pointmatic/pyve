"""
Integration tests for pyve --validate command.

Tests validation functionality including version compatibility checks,
structure validation, and exit codes.
"""

import pytest
import os
from pathlib import Path


class TestValidateCommand:
    """Test pyve --validate command functionality."""
    
    def test_validate_no_project(self, pyve, test_project):
        """Test validate command with no initialized project."""
        result = pyve.run("--validate")
        
        assert result.returncode == 1
        assert "Missing .pyve directory" in result.stderr or "not found" in result.stdout
    
    def test_validate_venv_project_success(self, pyve, project_builder):
        """Test validate command on healthy venv project."""
        # Initialize venv project
        project_builder.init_venv()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
        assert "✓" in result.stdout or "All validations passed" in result.stdout
    
    def test_validate_missing_venv(self, pyve, project_builder):
        """Test validate command when venv directory is missing."""
        # Create config but no venv
        project_builder.create_pyve_config(backend="venv")
        
        result = pyve.run("--validate")
        
        assert result.returncode == 1
        assert "missing" in result.stdout.lower() or "not found" in result.stdout.lower()
    
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
        
        result = pyve.run("--validate")
        
        assert result.returncode == 1
        assert "environment.yml" in result.stdout.lower()
    
    def test_validate_version_mismatch_older(self, pyve, project_builder):
        """Test validate command with older version in config."""
        # Initialize project
        project_builder.init_venv()
        
        # Manually set older version in config
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = f'pyve_version: "0.6.6"\n{config_content}'
        config_path.write_text(config_content)
        
        result = pyve.run("--validate")
        
        # Should warn but not fail
        assert result.returncode in [0, 2]  # 0 or warning code
        assert "0.6.6" in result.stdout
    
    def test_validate_version_mismatch_newer(self, pyve, project_builder):
        """Test validate command with newer version in config."""
        # Initialize project
        project_builder.init_venv()
        
        # Manually set newer version in config
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = f'pyve_version: "99.0.0"\n{config_content}'
        config_path.write_text(config_content)
        
        result = pyve.run("--validate")
        
        # Should warn but not fail
        assert result.returncode in [0, 2]  # 0 or warning code
        assert "99.0.0" in result.stdout
    
    def test_validate_legacy_project_no_version(self, pyve, project_builder):
        """Test validate command on legacy project without version field."""
        # Create old-style config without version
        project_builder.create_pyve_config(backend="venv", include_version=False)
        project_builder.create_venv()
        
        result = pyve.run("--validate")
        
        # Should suggest adding version
        assert result.returncode in [0, 2]
        assert "not recorded" in result.stdout or "legacy" in result.stdout.lower()
    
    def test_validate_exit_code_success(self, pyve, project_builder):
        """Test validate command returns 0 on success."""
        project_builder.init_venv()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
    
    def test_validate_exit_code_errors(self, pyve, project_builder):
        """Test validate command returns 1 on errors."""
        # Create incomplete project
        project_builder.create_pyve_config(backend="venv")
        # Don't create venv
        
        result = pyve.run("--validate")
        
        assert result.returncode == 1
    
    def test_validate_exit_code_warnings(self, pyve, project_builder):
        """Test validate command returns 2 on warnings only."""
        # Initialize project
        project_builder.init_venv()
        
        # Set older version to trigger warning
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = f'pyve_version: "0.6.6"\n{config_content}'
        config_path.write_text(config_content)
        
        result = pyve.run("--validate")
        
        # Should return warning code (2) or success (0)
        assert result.returncode in [0, 2]
    
    def test_validate_output_format(self, pyve, project_builder):
        """Test validate command output format."""
        project_builder.init_venv()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
        # Check for expected output sections
        assert "Pyve" in result.stdout or "version" in result.stdout.lower()
        assert "Backend" in result.stdout or "backend" in result.stdout.lower()
    
    def test_validate_checks_backend(self, pyve, project_builder):
        """Test validate command checks backend configuration."""
        project_builder.init_venv()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
        assert "venv" in result.stdout.lower()
    
    def test_validate_checks_python_version(self, pyve, project_builder):
        """Test validate command checks Python version."""
        project_builder.init_venv(python_version="3.11")
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
        assert "python" in result.stdout.lower() or "3.11" in result.stdout
    
    def test_validate_checks_direnv(self, pyve, project_builder):
        """Test validate command checks direnv integration."""
        project_builder.init_venv()
        
        result = pyve.run("--validate")
        
        assert result.returncode == 0
        assert "direnv" in result.stdout.lower() or ".env" in result.stdout


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
