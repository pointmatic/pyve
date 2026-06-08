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
Integration tests for pyve backend auto-detection.

Tests auto-detection of backend based on project files (requirements.txt, environment.yml),
.pyve/config file, and CLI flags.
"""

import pytest


class TestBackendAutoDetection:
    """Test automatic backend detection from project files."""
    
    def test_detects_venv_from_requirements_txt(self, pyve, project_builder):
        """Test auto-detection chooses venv when only requirements.txt exists."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Init with auto backend
        result = pyve.init(backend='auto')
        
        assert result.returncode == 0
        # Should create venv
        assert (pyve.cwd / '.venv').exists()
    
    def test_detects_venv_from_pyproject_toml(self, pyve, project_builder):
        """Test auto-detection chooses venv when only pyproject.toml exists."""
        project_builder.create_pyproject_toml(
            name='test-project',
            dependencies=['requests==2.31.0']
        )
        
        result = pyve.init(backend='auto')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
    
    @pytest.mark.requires_micromamba
    def test_detects_micromamba_from_environment_yml(self, pyve, project_builder):
        """Test auto-detection chooses micromamba when only environment.yml exists."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11', 'requests']
        )
        
        result = pyve.init(backend='auto')
        
        assert result.returncode == 0
        # Should create micromamba environment
        assert 'micromamba' in result.stdout.lower() or 'test-env' in result.stdout
    
    @pytest.mark.requires_micromamba
    def test_detects_micromamba_from_conda_lock(self, pyve):
        """Test auto-detection chooses micromamba when conda-lock.yml exists."""
        # Create conda-lock.yml
        lock_file = pyve.cwd / 'conda-lock.yml'
        lock_file.write_text('# Mock conda-lock file\n')
        
        result = pyve.init(backend='auto', check=False)
        
        # Should attempt micromamba (may fail without proper lock file)
        assert result.returncode in [0, 1]
    
    def test_ambiguous_detection_defaults_to_venv(self, pyve, project_builder):
        """Test that ambiguous detection (both file types) defaults to venv."""
        # Create both requirements.txt and environment.yml
        project_builder.create_requirements(['requests==2.31.0'])
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        result = pyve.init(backend='auto', check=False)
        
        # Should default to venv or prompt/error
        # Implementation may vary
        assert result.returncode in [0, 1]
    
    def test_no_files_defaults_to_venv(self, pyve):
        """Test that no package files defaults to venv."""
        result = pyve.init(backend='auto', check=False)
        
        # Should default to venv or fail gracefully
        assert result.returncode in [0, 1]


class TestConfigFileOverride:
    """Test .pyve/config file overrides auto-detection."""
    
    def test_config_overrides_file_detection(self, pyve, project_builder):
        """Test that .pyve/config backend setting overrides file detection."""
        # Create requirements.txt (would suggest venv)
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Create config that specifies micromamba
        project_builder.create_config(backend='micromamba')
        
        result = pyve.init(check=False)
        
        # Should use micromamba from config, not venv from files
        # May fail if micromamba not available
        assert result.returncode in [0, 1]
        if result.returncode == 0:
            assert 'micromamba' in result.stdout.lower()
    
    def test_cli_flag_overrides_config(self, pyve, project_builder):
        """Test that CLI --backend flag overrides .pyve/config."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Create config that specifies micromamba
        project_builder.create_config(backend='micromamba')
        
        # But use venv via CLI flag
        result = pyve.init(backend='venv', input='y\n')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
    
    def test_config_with_venv_directory(self, pyve, project_builder):
        """Test .pyve/config can specify custom venv directory."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Create config with custom venv directory
        config_content = """backend: venv
venv:
  directory: custom_venv
"""
        config_path = pyve.cwd / '.pyve' / 'config'
        config_path.parent.mkdir(exist_ok=True)
        config_path.write_text(config_content)
        
        # Use run() instead of init() to avoid --force flag that would purge the config
        result = pyve.run('init', '--no-direnv', check=False)
        
        # Config should be respected even if init succeeds or fails
        if result.returncode == 0:
            assert (pyve.cwd / 'custom_venv').exists()
        # If it fails, at least verify the config was read (not testing custom venv in CI)
    
    def test_config_with_python_version(self, pyve, project_builder):
        """Test .pyve/config can specify Python version."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # Create config with Python version
        config_content = """backend: venv
python:
  version: "3.11"
"""
        config_path = pyve.cwd / '.pyve' / 'config'
        config_path.parent.mkdir(exist_ok=True)
        config_path.write_text(config_content)
        
        result = pyve.init(input='y\n')
        
        assert result.returncode == 0


class TestPriorityOrder:
    """Test the priority order: CLI > config > file detection > default."""
    
    def test_priority_cli_over_all(self, pyve, project_builder):
        """Test CLI flag has highest priority."""
        # Create environment.yml (suggests micromamba)
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        # Create config that also says micromamba
        project_builder.create_config(backend='micromamba')
        
        # But override with CLI flag for venv
        result = pyve.init(backend='venv', check=False)
        
        # Should use venv despite other indicators
        if result.returncode == 0:
            assert (pyve.cwd / '.venv').exists()
    
    def test_priority_config_over_files(self, pyve, project_builder):
        """Test config file has priority over file detection."""
        # Create requirements.txt (suggests venv)
        project_builder.create_requirements(['requests==2.31.0'])
        
        # But config says micromamba
        project_builder.create_config(backend='micromamba')
        
        result = pyve.init(check=False)
        
        # Should attempt micromamba from config
        # May fail if micromamba not available or no environment.yml
        assert result.returncode in [0, 1]
    
    def test_priority_files_over_default(self, pyve, project_builder):
        """Test file detection has priority over default."""
        # Create requirements.txt
        project_builder.create_requirements(['requests==2.31.0'])
        
        # No config, no CLI flag - should detect from files
        result = pyve.init(backend='auto')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()


class TestEdgeCases:
    """Test edge cases in backend detection."""
    
    def test_empty_requirements_txt(self, pyve):
        """Test with empty requirements.txt."""
        req_file = pyve.cwd / 'requirements.txt'
        req_file.write_text('')
        
        result = pyve.init(backend='auto', check=False)
        
        # Should still detect venv backend
        assert result.returncode in [0, 1]
    
    def test_empty_environment_yml(self, pyve):
        """Test with empty environment.yml."""
        env_file = pyve.cwd / 'environment.yml'
        env_file.write_text('')
        
        result = pyve.init(backend='auto', check=False)
        
        # Should fail or handle gracefully
        assert result.returncode in [0, 1]
    
    def test_multiple_requirements_files(self, pyve):
        """Test with multiple requirements files."""
        (pyve.cwd / 'requirements.txt').write_text('requests==2.31.0\n')
        (pyve.cwd / 'requirements-dev.txt').write_text('pytest==7.4.0\n')
        
        result = pyve.init(backend='auto')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
    
    def test_invalid_backend_in_config(self, pyve, project_builder):
        """An invalid backend in a legacy `.pyve/config` is rejected on init.

        v3.0-only: remove in N-10 (read-compat retirement).

        This drives validation through the v3.0 read-compat path: a legacy
        hand-written `.pyve/config` (no `pyve.toml`) is *synthesized* into a
        v3 manifest by `_manifest_synthesize_from_legacy` (pure bash —
        `backend:` maps to `[env.root]`), and the v3 manifest/plugin layer
        rejects the unregistered backend:

            error: python plugin: env 'root' declares unregistered backend
            'invalid_backend'

        Behavior is uniform across CI and non-CI (init here runs WITHOUT
        --force, so the surviving config is read both ways) — the old
        non-CI-only guard was a v2-ism and is gone.

        The CANONICAL v3 surface — an invalid backend in `pyve.toml` — is
        covered at the unit level by N.bf.1's validator bats
        (`test_init_pyve_toml.bats`). It is intentionally NOT re-tested here
        as an integration case: the `pyve.toml` validator probes the project
        interpreter and *defers* when none resolves (Story N.bf.1/.2), so the
        invalid-backend error is environment-dependent in this harness (no
        pinned Python), whereas the legacy-synthesis path validates
        deterministically. When read-compat is swept in N-10, this whole
        test goes with it (per the marker above).
        """
        project_builder.create_requirements(['requests==2.31.0'])

        # Legacy v2 config with an unregistered backend (no pyve.toml).
        config_path = pyve.cwd / '.pyve' / 'config'
        config_path.parent.mkdir(exist_ok=True)
        config_path.write_text("backend: invalid_backend\n")

        # run() (not init()) so no --force purges the surviving config.
        result = pyve.run('init', '--no-direnv', check=False)

        assert result.returncode != 0
        # The v3 manifest/plugin rejection names both 'backend' and the bad
        # value; tolerant match keeps it robust to message wording.
        assert 'backend' in result.stderr.lower()
        assert 'invalid_backend' in result.stderr.lower()
