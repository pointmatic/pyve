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
Integration test for bug: pyve --init --force should prompt for backend choice
when both environment.yml and pyproject.toml exist (ambiguous case).

Bug report: When running `pyve --init --force` on a project with both files,
it uses venv backend without prompting, instead of asking the user to choose.
"""

import os
import pytest
from pathlib import Path


class TestForceAmbiguousPrompt:
    """Test that --force prompts for backend choice in ambiguous cases."""
    
    def test_force_prompts_for_backend_in_ambiguous_case(self, pyve, project_builder):
        """
        Test that pyve --init --force prompts for backend choice when both
        environment.yml and pyproject.toml exist.
        
        This is a regression test for the bug where --force would use venv
        without prompting in ambiguous cases.
        """
        # Step 1: Create BOTH environment.yml and pyproject.toml (ambiguous)
        project_builder.create_environment_yml("test-env")
        project_builder.create_pyproject_toml("test-project")
        
        # Step 2: Initialize with venv backend
        result = pyve.run("init", "--backend", "venv")
        assert result.returncode == 0
        
        # Verify venv was created
        config_path = project_builder.project_dir / ".pyve" / "config"
        assert config_path.exists()
        config_content = config_path.read_text()
        assert "backend: venv" in config_content
        
        # Step 3: Run --init --force and answer 'y' to use micromamba
        # The system should prompt: "Initialize with micromamba backend? [Y/n]:"
        result = pyve.run("init", "--force", input="y\ny\n")  # y for force confirmation, y for micromamba
        
        # Step 4: Verify it prompted and used the user's choice (micromamba)
        assert result.returncode == 0, f"Command failed: {result.stderr}"
        
        # Check that config was recreated with micromamba backend (user's choice)
        assert config_path.exists()
        config_content = config_path.read_text()
        
        # This assertion will fail if the bug exists - it will be venv instead of micromamba
        assert "backend: micromamba" in config_content, \
            f"Expected micromamba backend after user chose 'y', but config shows:\n{config_content}"
    
    def test_force_respects_no_response_in_ambiguous_case(self, pyve, project_builder):
        """
        Test that pyve --init --force respects 'n' response to use venv
        when both files exist.
        """
        # Step 1: Create BOTH environment.yml and pyproject.toml (ambiguous)
        project_builder.create_environment_yml("test-env")
        project_builder.create_pyproject_toml("test-project")
        
        # Step 2: Initialize with venv backend
        result = pyve.run("init", "--backend", "venv")
        assert result.returncode == 0
        
        # Step 3: Run --init --force and answer 'n' to use venv
        result = pyve.run("init", "--force", input="y\nn\n")  # y for force confirmation, n for venv
        
        # Step 4: Verify it used venv (user's choice)
        assert result.returncode == 0
        
        config_path = project_builder.project_dir / ".pyve" / "config"
        config_content = config_path.read_text()
        assert "backend: venv" in config_content
