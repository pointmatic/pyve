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
        manifest_path = project_builder.project_dir / "pyve.toml"
        assert manifest_path.exists()
        manifest_content = manifest_path.read_text()
        assert 'backend = "micromamba"' in manifest_content
        
        # Step 3: Run --init --force (this should purge and re-detect backend)
        result = pyve.run("init", "--force", "--auto-bootstrap", input="y\n")
        
        # Step 4: Verify it detected micromamba backend from environment.yml
        assert result.returncode == 0
        
        # Check that config was recreated with micromamba backend
        assert manifest_path.exists()
        manifest_content = manifest_path.read_text()
        assert 'backend = "micromamba"' in manifest_content, \
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
        manifest_path = project_builder.project_dir / "pyve.toml"
        assert manifest_path.exists()
        manifest_content = manifest_path.read_text()
        assert 'backend = "micromamba"' in manifest_content
        
        # Step 3: Run --init --force WITHOUT --backend flag
        # This should preserve micromamba backend despite ambiguity
        result = pyve.run("init", "--force", "--auto-bootstrap", input="y\n")
        
        # Step 4: Verify it preserved micromamba backend
        assert result.returncode == 0
        
        # Check that config was recreated with micromamba backend (not venv)
        assert manifest_path.exists()
        manifest_content = manifest_path.read_text()
        assert 'backend = "micromamba"' in manifest_content, \
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
        manifest_path = project_builder.project_dir / "pyve.toml"
        assert manifest_path.exists()
        manifest_content = manifest_path.read_text()
        assert 'backend = "venv"' in manifest_content
        
        # Step 3: Run --init --force (this should purge and re-detect backend)
        result = pyve.run("init", "--force", input="y\n")
        
        # Step 4: Verify it detected venv backend from pyproject.toml
        assert result.returncode == 0
        
        # Check that config was recreated with venv backend
        assert manifest_path.exists()
        manifest_content = manifest_path.read_text()
        assert 'backend = "venv"' in manifest_content
        
        # Verify venv exists
        venv_dir = project_builder.project_dir / ".venv"
        assert venv_dir.exists(), "Venv directory should exist"
    
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
        manifest_path = project_builder.project_dir / "pyve.toml"
        manifest_content = manifest_path.read_text()
        assert 'backend = "venv"' in manifest_content

        venv_dir = project_builder.project_dir / ".venv"
        assert venv_dir.exists()

    def test_force_switch_venv_to_micromamba_without_environment_yml(self, pyve, project_builder):
        """
        Regression: --force switching venv→micromamba in a directory with no
        environment.yml must scaffold a starter environment.yml during the
        pre-flight (matching the non-force flow at pyve.sh:789) instead of
        hard-erroring with "Neither 'environment.yml' nor 'conda-lock.yml'".

        The non-force path (`pyve init --backend micromamba` on a fresh dir)
        already scaffolds environment.yml before lock validation. The --force
        pre-flight duplicated the lock validation but forgot the scaffold step,
        so it failed on directories that the non-force path handles fine.
        """
        # Initialize with venv backend → records backend = "venv" in pyve.toml.
        result = pyve.run("init", "--backend", "venv")
        assert result.returncode == 0
        assert not (project_builder.project_dir / "environment.yml").exists()

        # Force-switch to micromamba without authoring environment.yml first.
        # The pre-flight is what fails in the bug; we don't need micromamba to
        # be available to prove the regression — the scaffold step runs before
        # the bootstrap attempt, so environment.yml should be on disk either
        # way if the pre-flight ran scaffold.
        result = pyve.run(
            "init", "--force", "--backend", "micromamba",
            "--auto-bootstrap", input="y\n",
        )

        combined = (result.stdout or "") + (result.stderr or "")
        assert "Neither 'environment.yml' nor 'conda-lock.yml'" not in combined, \
            f"Pre-flight rejected fresh dir; scaffold did not run in --force path.\n{combined}"
        assert (project_builder.project_dir / "environment.yml").exists(), \
            "Expected environment.yml to be scaffolded by --force pre-flight"
