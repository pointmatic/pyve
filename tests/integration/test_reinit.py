"""
Integration tests for pyve smart re-initialization.

Tests re-initialization scenarios including --update flag, --force flag,
interactive prompts, and conflict detection.
"""

import os
import pytest
from pathlib import Path


class TestReinitUpdate:
    """Test pyve --init --update (safe update mode)."""
    
    def test_update_preserves_venv(self, pyve, project_builder):
        """Test that --update preserves existing venv."""
        # Initialize first
        pyve.init()
        
        venv_marker = project_builder.project_dir / ".venv" / "marker.txt"
        venv_marker.write_text("test marker")
        
        result = pyve.run("--init", "--update")
        
        assert result.returncode == 0
        assert "Updating existing Pyve installation" in result.stdout
        assert "Configuration updated" in result.stdout
        assert venv_marker.exists()
    
    def test_update_updates_version(self, pyve, project_builder):
        """Test that --update updates version in config."""
        # Initialize first
        pyve.init()
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = config_content.replace('pyve_version: "0.8.9"', 'pyve_version: "0.8.7"')
        config_path.write_text(config_content)
        
        result = pyve.run("--init", "--update")
        
        assert result.returncode == 0
        assert "0.8.7" in result.stdout
        assert "0.8.9" in result.stdout
    
    def test_update_rejects_backend_change(self, pyve, project_builder):
        """Test that --update rejects backend changes."""
        # Initialize with venv first
        pyve.init()
        
        result = pyve.run("--init", "--backend", "micromamba", "--update")
        
        assert result.returncode == 1
        assert "Cannot update in-place" in result.stderr or "Backend change detected" in result.stderr
    
    def test_update_allows_same_backend(self, pyve, project_builder):
        """Test that --update allows same backend."""
        # Initialize with venv first
        pyve.init()
        
        result = pyve.run("--init", "--backend", "venv", "--update")
        
        assert result.returncode == 0
        assert "Configuration updated" in result.stdout


class TestReinitForce:
    """Test pyve --init --force (destructive re-initialization)."""
    
    def test_force_purges_existing_venv(self, pyve, project_builder):
        """Test that --force purges existing venv."""
        pyve.init()
        
        venv_marker = project_builder.project_dir / ".venv" / "marker.txt"
        venv_marker.write_text("test marker")
        
        result = pyve.run("--init", "--force", input="y\n")
        
        assert result.returncode == 0
        assert "Force re-initialization" in result.stdout
    
    def test_force_prompts_for_confirmation(self, pyve, project_builder):
        """Test that --force prompts for confirmation."""
        pyve.init()
        
        result = pyve.run("--init", "--force", input="n\n")
        
        assert result.returncode == 0
        assert "Continue?" in result.stdout
        assert "cancelled" in result.stdout.lower()
    
    def test_force_allows_backend_change(self, pyve, project_builder):
        """Test that --force allows backend changes."""
        pyve.init()
        
        result = pyve.run("--init", "--backend", "venv", "--force", input="y\n")
        
        assert result.returncode == 0
        assert "Purging" in result.stdout or "purge" in result.stdout.lower()


class TestReinitInteractive:
    """Test interactive re-initialization prompts."""
    
    def test_interactive_option_1_updates(self, pyve, project_builder):
        """Test interactive mode option 1 (update)."""
        pyve.init()
        
        result = pyve.run("--init", input="1\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout
        assert "Configuration updated" in result.stdout
    
    def test_interactive_option_2_purges(self, pyve, project_builder):
        """Test interactive mode option 2 (purge and re-init)."""
        pyve.init()
        
        result = pyve.run("--init", input="2\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout
        assert "Purging" in result.stdout or "purge" in result.stdout.lower()
    
    def test_interactive_option_3_cancels(self, pyve, project_builder):
        """Test interactive mode option 3 (cancel)."""
        pyve.init()
        
        result = pyve.run("--init", input="3\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout
        assert "cancelled" in result.stdout.lower()
    
    def test_interactive_invalid_choice(self, pyve, project_builder):
        """Test interactive mode with invalid choice."""
        pyve.init()
        
        result = pyve.run("--init", input="5\n")
        
        assert result.returncode == 1
        assert "Invalid choice" in result.stderr or "invalid" in result.stdout.lower()
    
    def test_interactive_shows_version_info(self, pyve, project_builder):
        """Test that interactive prompt shows version info."""
        pyve.init()
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = config_content.replace('pyve_version: "0.8.9"', 'pyve_version: "0.8.7"')
        config_path.write_text(config_content)
        
        result = pyve.run("--init", input="3\n")
        
        assert "0.8.7" in result.stdout
        assert "0.8.9" in result.stdout


class TestConflictDetection:
    """Test conflict detection during re-initialization."""
    
    def test_backend_conflict_in_interactive_mode(self, pyve, project_builder):
        """Test backend conflict detection in interactive mode."""
        pyve.init()
        
        result = pyve.run("--init", "--backend", "micromamba", input="1\n")
        
        assert result.returncode == 1
        assert "Cannot update in-place" in result.stderr or "Backend change" in result.stderr
    
    def test_no_conflict_without_backend_flag(self, pyve, project_builder):
        """Test no conflict when backend not specified."""
        pyve.init()
        
        result = pyve.run("--init", input="1\n")
        
        assert result.returncode == 0
        assert "Configuration updated" in result.stdout


class TestLegacyProjects:
    """Test re-initialization of legacy projects without version field."""
    
    def test_update_legacy_project(self, pyve, project_builder):
        """Test updating legacy project without version field."""
        project_builder.create_pyve_config(backend="venv", include_version=False)
        project_builder.create_venv()
        
        result = pyve.run("--init", "--update")
        
        assert result.returncode == 0
        assert "Configuration updated" in result.stdout
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        assert "pyve_version" in config_content
    
    def test_interactive_legacy_project(self, pyve, project_builder):
        """Test interactive mode on legacy project."""
        project_builder.create_pyve_config(backend="venv", include_version=False)
        project_builder.create_venv()
        
        result = pyve.run("--init", input="1\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout


class TestConfigCreation:
    """Test that config files are created with version tracking."""
    
    def test_venv_init_creates_config(self, pyve, project_builder):
        """Test that venv init creates config with version."""
        result = pyve.run("--init")
        
        assert result.returncode == 0
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        
        config_content = config_path.read_text()
        assert "pyve_version" in config_content
        assert "backend: venv" in config_content
    
    @pytest.mark.skipif(
        not os.environ.get("MICROMAMBA_AVAILABLE"),
        reason="Micromamba not available"
    )
    def test_micromamba_init_creates_config(self, pyve, project_builder):
        """Test that micromamba init creates config with version."""
        project_builder.create_environment_yml()
        
        result = pyve.run("--init", "--backend", "micromamba", "--auto-bootstrap")
        
        assert result.returncode == 0
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        
        config_content = config_path.read_text()
        assert "pyve_version" in config_content
        assert "backend: micromamba" in config_content


class TestEdgeCases:
    """Test edge cases in re-initialization."""
    
    def test_update_with_corrupted_config(self, pyve, project_builder):
        """Test update with corrupted config file."""
        project_builder.project_dir.joinpath(".pyve").mkdir(exist_ok=True)
        project_builder.project_dir.joinpath(".pyve/config").write_text("invalid: yaml: content:")
        
        result = pyve.run("--init", "--update")
        
        assert result.returncode != 0
    
    def test_force_with_missing_venv(self, pyve, project_builder):
        """Test force re-init when venv is missing."""
        project_builder.create_pyve_config(backend="venv")
        
        result = pyve.run("--init", "--force", input="y\n")
        
        assert result.returncode == 0
    
    def test_update_preserves_custom_venv_dir(self, pyve, project_builder):
        """Test that update preserves custom venv directory."""
        project_builder.create_pyve_config(backend="venv", venv_dir="custom_venv")
        project_builder.create_venv(venv_dir="custom_venv")
        
        result = pyve.run("--init", "--update")
        
        assert result.returncode == 0
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        assert "custom_venv" in config_content


import os
