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
Integration test for bug: pyve init --force should detect environment.yml
and use micromamba backend after purge.

Bug report: When running `pyve init --force` on a micromamba environment,
it doesn't check for environment.yml and reinstall micromamba. It just switches to venv.
"""

import os
import pytest
from pathlib import Path


class TestForceBackendDetection:
    """Test that --force respects backend auto-detection after purge."""
    
    @pytest.mark.skipif(
        not os.environ.get("MICROMAMBA_AVAILABLE"),
        reason="Micromamba not available"
    )
    def test_force_reinit_detects_environment_yml(self, pyve, project_builder):
        """
        Test that pyve init --force on a micromamba environment
        detects environment.yml and reinstalls micromamba backend.
        
        This is a regression test for the bug where --force would
        purge the config and then default to venv instead of
        re-detecting the backend from environment.yml.
        """
        # Step 1: Create environment.yml
        project_builder.create_environment_yml()
        
        # Step 2: Initialize with micromamba backend
        result = pyve.run("init", "--backend", "micromamba", "--auto-bootstrap")
        assert result.returncode == 0
        
        # Verify micromamba environment was created
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: micromamba" in config_content
        
        # Step 3: Run --init --force (this should purge and re-detect backend)
        result = pyve.run("init", "--force", "--auto-bootstrap", input="y\n")
        
        # Step 4: Verify it detected micromamba backend from environment.yml
        assert result.returncode == 0
        
        # Check that config was recreated with micromamba backend
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: micromamba" in config_content, \
            "Expected micromamba backend after --force, but got venv (bug reproduced)"
        
        # Verify micromamba environment exists
        env_dir = project_builder.project_dir / ".pyve" / "envs"
        assert env_dir.exists(), "Micromamba environment directory should exist"
    
    @pytest.mark.skipif(
        not os.environ.get("MICROMAMBA_AVAILABLE"),
        reason="Micromamba not available"
    )
    def test_force_reinit_preserves_backend_when_ambiguous(self, pyve, project_builder):
        """
        Test that pyve init --force preserves the backend when both
        environment.yml and pyproject.toml exist (ambiguous case).
        
        This is the exact bug scenario reported: when both conda and Python
        package files exist, --force should preserve the original backend
        choice rather than defaulting to venv.
        """
        # Step 1: Create BOTH environment.yml and pyproject.toml (ambiguous)
        project_builder.create_environment_yml()
        project_builder.create_pyproject_toml("test-project")
        
        # Step 2: Initialize with micromamba backend explicitly
        result = pyve.run("init", "--backend", "micromamba", "--auto-bootstrap")
        assert result.returncode == 0
        
        # Verify micromamba environment was created
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: micromamba" in config_content
        
        # Step 3: Run --init --force WITHOUT --backend flag
        # This should preserve micromamba backend despite ambiguity
        result = pyve.run("init", "--force", "--auto-bootstrap", input="y\n")
        
        # Step 4: Verify it preserved micromamba backend
        assert result.returncode == 0
        
        # Check that config was recreated with micromamba backend (not venv)
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: micromamba" in config_content, \
            "Expected micromamba backend to be preserved after --force in ambiguous case"
        
        # Verify micromamba environment exists
        env_dir = project_builder.project_dir / ".pyve" / "envs"
        assert env_dir.exists(), "Micromamba environment directory should exist"
    
    def test_force_reinit_detects_pyproject_toml(self, pyve, project_builder):
        """
        Test that pyve init --force on a venv environment
        detects pyproject.toml and reinstalls venv backend.
        """
        # Step 1: Create pyproject.toml
        project_builder.create_pyproject_toml("test-project")
        
        # Step 2: Initialize with venv backend
        result = pyve.run("init")
        assert result.returncode == 0
        
        # Verify venv was created
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: venv" in config_content
        
        # Step 3: Run --init --force (this should purge and re-detect backend)
        result = pyve.run("init", "--force", input="y\n")
        
        # Step 4: Verify it detected venv backend from pyproject.toml
        assert result.returncode == 0
        
        # Check that config was recreated with venv backend
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: venv" in config_content
        
        # Verify venv exists
        venv_dir = project_builder.project_dir / ".venv"
        assert venv_dir.exists(), "Venv directory should exist"
    
    def test_force_reinit_prompts_and_respects_venv_choice_in_ambiguous_case(self, pyve, project_builder):
        """
        Test that pyve init --force prompts for backend choice when both
        environment.yml and pyproject.toml exist, and respects user choosing venv.

        Prompt order after F.k/F.l fixes:
          1. "Initialize with micromamba backend? [Y/n]:"  ← backend detection (skip config)
          2. "Proceed? [y/N]:"                             ← force confirmation
        """
        # Step 1: Create BOTH environment.yml and pyproject.toml (ambiguous)
        project_builder.create_environment_yml("test-env")
        project_builder.create_pyproject_toml("test-project")

        # Step 2: Initialize with venv backend explicitly
        result = pyve.run("init", "--backend", "venv")
        assert result.returncode == 0

        # Verify venv was created
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: venv" in config_content

        # Step 3: Run --init --force
        # Prompt 1 (backend): 'n' → choose venv (not micromamba)
        # Prompt 2 (confirmation): 'y' → proceed with purge
        result = pyve.run("init", "--force", input="n\ny\n")

        # Step 4: Verify the backend prompt was shown (proving skip_config worked)
        combined = (result.stdout or "") + (result.stderr or "")
        assert "Initialize with micromamba backend?" in combined, \
            "Expected backend detection prompt — skip_config should bypass stale venv config"

        # Verify it used venv (user chose 'n')
        assert result.returncode == 0

        # Check that config was recreated with venv backend
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: venv" in config_content, \
            "Expected venv backend after user chose 'n' in backend prompt"

        # Verify venv exists
        venv_dir = project_builder.project_dir / ".venv"
        assert venv_dir.exists(), "Venv directory should exist"

    def test_force_reinit_ignores_stale_config_backend(self, pyve, project_builder):
        """
        Regression test for F.l: --force pre-flight must bypass .pyve/config (Priority 2)
        and re-detect the backend from project files.

        Scenario: project has both environment.yml + pyproject.toml (ambiguous).
        Initial --init --backend venv writes backend: venv to config. A subsequent
        --init --force must skip the stale config and show the backend detection
        prompt (proving file detection ran).

        If skip_config were NOT working, Priority 2 would return "venv" immediately
        and the backend prompt would never appear. The assert below would then fail,
        catching the regression.
        """
        # Step 1: Create ambiguous project files
        project_builder.create_environment_yml("test-env")
        project_builder.create_pyproject_toml("test-project")

        # Step 2: Initialize with venv explicitly → writes backend: venv to config
        result = pyve.run("init", "--backend", "venv")
        assert result.returncode == 0

        config_path = project_builder.project_dir / ".pyve" / "config"
        assert "backend: venv" in config_path.read_text()

        # Step 3: Force reinit interactively
        # Prompt 1 (backend, ambiguous): 'y' → choose micromamba
        # Prompt 2 (confirmation):        'y' → proceed with purge
        result = pyve.run("init", "--force", input="y\ny\n")

        # Step 4: Verify the backend detection prompt appeared (proving skip_config worked)
        combined = (result.stdout or "") + (result.stderr or "")
        assert "Initialize with micromamba backend?" in combined, \
            "Expected backend detection prompt — skip_config should have bypassed backend: venv in .pyve/config"
    
    @pytest.mark.skipif(
        not os.environ.get("MICROMAMBA_AVAILABLE"),
        reason="Micromamba not available"
    )
    def test_force_with_explicit_backend_overrides_detection(self, pyve, project_builder):
        """
        Test that --force with explicit --backend flag overrides auto-detection.
        """
        # Create environment.yml (suggests micromamba)
        project_builder.create_environment_yml()
        
        # Initialize with micromamba
        result = pyve.run("init", "--backend", "micromamba", "--auto-bootstrap")
        assert result.returncode == 0
        
        # Force reinit with explicit venv backend (should override detection)
        result = pyve.run("init", "--force", "--backend", "venv", input="y\n")
        assert result.returncode == 0
        
        # Verify venv backend was used despite environment.yml
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        assert "backend: venv" in config_content
        
        venv_dir = project_builder.project_dir / ".venv"
        assert venv_dir.exists()
