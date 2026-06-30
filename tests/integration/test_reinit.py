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
Integration tests for pyve smart re-initialization.

Tests re-initialization scenarios including --force flag, interactive
prompts, and conflict detection.
"""

import os
import pytest
from pathlib import Path
from pyve_test_helpers import get_pyve_version


@pytest.fixture(autouse=True)
def _suppress_asdf_install_prompt(clean_env):
    """Auto-accept the (flaky) asdf "Install Python <ver>?" prompt.

    N.am test-hardening. ``pyve init`` runs ``ensure_python_version_installed``,
    whose asdf-list check is intermittently flaky under rapid repeated
    invocation: it reports an already-installed version as missing and fires an
    interactive ``Install Python <ver>? [y/n]`` prompt. That prompt consumes the
    test's stdin (the menu/confirm input that follows) and derails whichever
    reinit test happens to hit the transient — a different one each full-file
    run. ``PYVE_FORCE_YES=1`` auto-accepts it; the version is in fact installed,
    so the "install" is a ~0ms no-op. It also skips the ``--force`` confirmation,
    so the one test that asserts on that confirm unsets it (see below).

    Depends on ``clean_env`` so it runs *after* the PYVE_* stripper.
    """
    clean_env.setenv("PYVE_FORCE_YES", "1")
    return clean_env


class TestReinitForce:
    """Test pyve init --force (destructive re-initialization)."""
    
    def test_force_purges_existing_venv(self, pyve, project_builder):
        """Test that --force purges existing venv."""
        pyve.init()

        venv_marker = project_builder.project_dir / ".venv" / "marker.txt"
        venv_marker.write_text("test marker")

        result = pyve.run("init", "--force", input="y\n")

        assert result.returncode == 0, result.stdout + result.stderr
        # The "Force re-initialization" notice is emitted via warn(), which the
        # lib/ui/core.sh primitives route to stdout (not stderr).
        assert "Force re-initialization" in result.stdout
        assert not venv_marker.exists()

    def test_force_rebuilds_on_v3_only_project(self, pyve, project_builder):
        """--force rebuilds the env even with no `.pyve/config` (v3-native).

        Regression (Story P.i.1): the re-init/--force gate keyed off
        `config_file_exists`, so on a `.pyve/config`-less v3 project the entire
        reinit/purge block was skipped — `--force` fell through to "already
        exists, skipping" and never rebuilt the env. The gate now fires on
        manifest presence (`pyve.toml`) too.
        """
        pyve.init(backend="venv")

        # Simulate a v3-native project: drop the v2 read-compat file, keeping
        # `pyve.toml` (which now records the backend) and the materialized .venv.
        config = project_builder.project_dir / ".pyve" / "config"
        if config.exists():
            config.unlink()
        assert (project_builder.project_dir / "pyve.toml").exists()

        marker = project_builder.project_dir / ".venv" / "marker.txt"
        marker.write_text("test marker")

        result = pyve.run("init", "--force", input="y\n")

        assert result.returncode == 0, result.stdout + result.stderr
        assert "Force re-initialization" in result.stdout
        assert "already exists, skipping" not in result.stdout
        assert not marker.exists()

    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_force_prompts_for_confirmation(self, pyve, project_builder, clean_env):
        """Test that --force prompts for confirmation."""
        pyve.init()

        # This call must SHOW the --force confirmation, which the autouse
        # PYVE_FORCE_YES suppresses — so unset it for this invocation. Answering
        # "n" cancels at the confirm, which runs *before* version-ensure, so the
        # flaky asdf install prompt is unreachable here regardless.
        clean_env.delenv("PYVE_FORCE_YES", raising=False)
        result = pyve.run("init", "--force", input="n\n")

        assert result.returncode == 0
        # The confirmation presents a purge/rebuild summary (via info(), stdout)
        # before the "Proceed [y/N]" prompt; answering "n" cancels cleanly.
        assert "Purge:" in result.stdout
        assert "Rebuild:" in result.stdout
        assert "cancelled" in result.stdout.lower()
    
    def test_force_allows_backend_change(self, pyve, project_builder):
        """Test that --force allows backend changes."""
        pyve.init()
        
        result = pyve.run("init", "--backend", "venv", "--force", input="y\n")
        
        assert result.returncode == 0
        assert "Purging" in result.stdout or "purge" in result.stdout.lower()


class TestReinitInteractive:
    """Test interactive re-initialization prompts."""
    
    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_interactive_option_1_updates(self, pyve, project_builder):
        """Test interactive mode option 1 (update)."""
        pyve.init()
        
        result = pyve.run("init", input="1\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout
        assert "Configuration updated" in result.stdout
    
    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_interactive_option_2_purges(self, pyve, project_builder):
        """Test interactive mode option 2 (purge and re-init)."""
        pyve.init()

        result = pyve.run("init", input="2\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout
        assert "Purging" in result.stdout or "purge" in result.stdout.lower()
    
    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_interactive_option_3_cancels(self, pyve, project_builder):
        """Test interactive mode option 3 (cancel)."""
        pyve.init()
        
        result = pyve.run("init", input="3\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout
        assert "cancelled" in result.stdout.lower()
    
    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_interactive_invalid_choice(self, pyve, project_builder):
        """Test interactive mode with invalid choice."""
        pyve.init()
        
        result = pyve.run("init", input="5\n")
        
        assert result.returncode == 1
        assert "Invalid choice" in result.stderr or "invalid" in result.stdout.lower()
    
    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_interactive_shows_version_info(self, pyve, project_builder):
        """Test that interactive prompt shows version info."""
        # Get current version from pyve.sh
        current_version = get_pyve_version(pyve.script_path)
        old_version = "0.8.7"
        
        pyve.init()
        
        # Manually set config to old version
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        config_content = config_content.replace(f'pyve_version: "{current_version}"', f'pyve_version: "{old_version}"')
        config_path.write_text(config_content)
        
        result = pyve.run("init", input="3\n")
        
        assert old_version in result.stdout
        assert current_version in result.stdout


class TestConflictDetection:
    """Test conflict detection during re-initialization."""
    
    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_backend_conflict_in_interactive_mode(self, pyve, project_builder):
        """Test backend conflict detection in interactive mode."""
        pyve.init()
        
        result = pyve.run("init", "--backend", "micromamba", input="1\n")

        assert result.returncode == 1
        # warn()/fail() route to stdout via lib/ui/core.sh.
        assert (
            "Cannot update in-place" in result.stdout
            or "Use option 2 to purge" in result.stdout
        )
    
    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_no_conflict_without_backend_flag(self, pyve, project_builder):
        """Test no conflict when backend not specified."""
        pyve.init()

        result = pyve.run("init", input="1\n")
        
        assert result.returncode == 0
        assert "Configuration updated" in result.stdout


class TestLegacyProjects:
    """Test re-initialization of legacy projects without version field."""
    
    def test_interactive_legacy_project(self, pyve, project_builder):
        """Test interactive mode on legacy project."""
        project_builder.create_pyve_config(backend="venv", include_version=False)
        project_builder.create_venv()
        
        result = pyve.run("init", input="1\n")
        
        assert result.returncode == 0
        assert "What would you like to do?" in result.stdout


class TestConfigCreation:
    """Test that config files are created with version tracking."""
    
    def test_venv_init_creates_config(self, pyve, project_builder):
        """Test that venv init creates config with version."""
        result = pyve.run("init")
        
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
        
        result = pyve.run("init", "--backend", "micromamba", "--auto-bootstrap")
        
        assert result.returncode == 0
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        
        config_content = config_path.read_text()
        assert "pyve_version" in config_content
        assert "backend: micromamba" in config_content


class TestEdgeCases:
    """Test edge cases in re-initialization."""
    
    def test_force_with_missing_venv(self, pyve, project_builder):
        """Test force re-init when venv is missing."""
        project_builder.create_pyve_config(backend="venv")

        result = pyve.run("init", "--force", input="y\n")

        assert result.returncode == 0, result.stdout + result.stderr
    

class TestReinitUpdateMissingEnv:
    """Test that interactive option 1 creates the environment when it is missing (clone scenario).

    When a project is cloned from GitHub, .pyve/config exists (committed) but .venv does
    not (gitignored).  Interactive option 1 must detect the missing environment directory
    and create it instead of silently returning success.
    """

    @pytest.mark.skipif(os.environ.get('CI') == 'true', reason="Interactive prompts skipped in CI")
    def test_interactive_option1_creates_missing_venv(self, pyve, project_builder):
        """Interactive option 1 should create .venv when config exists but .venv does not."""
        project_builder.create_pyve_config(backend="venv")
        project_builder.create_pyproject_toml("test-project")

        result = pyve.run("init", input="1\n")

        assert result.returncode == 0
        assert (project_builder.project_dir / ".venv").is_dir()


import os
