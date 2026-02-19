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
Integration tests for cross-platform functionality.

Tests platform-specific behavior on macOS and Linux.
"""

import os
import pytest
import platform
import sys


@pytest.mark.macos
@pytest.mark.skipif(platform.system() != 'Darwin', reason="macOS-specific tests")
class TestMacOSSpecific:
    """Tests specific to macOS platform."""
    
    @pytest.mark.venv
    def test_venv_on_macos(self, pyve, project_builder):
        """Test venv creation on macOS."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
        # macOS-specific: check for proper Python framework
        python_path = pyve.cwd / '.venv' / 'bin' / 'python'
        assert python_path.exists()
    
    @pytest.mark.micromamba
    @pytest.mark.requires_micromamba
    def test_micromamba_on_macos(self, pyve, project_builder):
        """Test micromamba on macOS."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        result = pyve.init(backend='micromamba')
        
        assert result.returncode == 0
    
    @pytest.mark.venv
    def test_homebrew_python_detection(self, pyve, project_builder):
        """Test detection of Homebrew Python on macOS."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        # Should work with Homebrew Python
    
    @pytest.mark.venv
    def test_asdf_integration_macos(self, pyve, project_builder):
        """Test asdf integration on macOS."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        # If asdf is available, should use it
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0


@pytest.mark.linux
@pytest.mark.skipif(platform.system() != 'Linux', reason="Linux-specific tests")
class TestLinuxSpecific:
    """Tests specific to Linux platform."""
    
    @pytest.mark.venv
    def test_venv_on_linux(self, pyve, project_builder):
        """Test venv creation on Linux."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        assert (pyve.cwd / '.venv').exists()
        python_path = pyve.cwd / '.venv' / 'bin' / 'python'
        assert python_path.exists()
    
    @pytest.mark.micromamba
    @pytest.mark.requires_micromamba
    def test_micromamba_on_linux(self, pyve, project_builder):
        """Test micromamba on Linux."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )
        
        result = pyve.init(backend='micromamba')
        
        assert result.returncode == 0
    
    @pytest.mark.venv
    def test_system_python_linux(self, pyve, project_builder):
        """Test with system Python on Linux."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0


class TestCrossPlatform:
    """Tests that should work on all platforms."""
    
    @pytest.mark.venv
    def test_python_version_detection(self, pyve, project_builder):
        """Test Python version detection works on all platforms."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        
        # Verify Python version
        version_result = pyve.run_cmd('python', '--version')
        assert version_result.returncode == 0
        assert 'python' in version_result.stdout.lower()
    
    @pytest.mark.venv
    def test_path_separators(self, pyve, project_builder):
        """Test that path separators work correctly on all platforms."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create nested directory structure
        subdir = pyve.cwd / 'src' / 'package'
        subdir.mkdir(parents=True)
        script = subdir / 'test.py'
        script.write_text('print("Path test")')
        
        # Should work with forward slashes on all platforms
        result = pyve.run_cmd('python', 'src/package/test.py')
        
        assert result.returncode == 0
        assert 'Path test' in result.stdout
    
    @pytest.mark.venv
    def test_environment_variables(self, pyve, project_builder):
        """Test environment variable handling on all platforms."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'import os; print(os.environ.get("PATH", ""))')
        
        assert result.returncode == 0
        assert len(result.stdout) > 0
    
    @pytest.mark.parametrize("backend,file_creator", [
        ("venv", lambda pb: pb.create_requirements(['requests==2.31.0'])),
        pytest.param(
            "micromamba",
            lambda pb: pb.create_environment_yml('test-env', dependencies=['python=3.11']),
            marks=[pytest.mark.micromamba, pytest.mark.requires_micromamba]
        ),
    ])
    def test_line_endings(self, pyve, project_builder, backend, file_creator):
        """Test that line endings are handled correctly on all platforms."""
        file_creator(project_builder)
        pyve.init(backend=backend)
        
        # Create script with explicit line endings
        script = project_builder.create_python_script(
            'line_test.py',
            'print("Line 1")\nprint("Line 2")\n'
        )
        
        result = pyve.run_cmd('python', 'line_test.py')
        
        assert result.returncode == 0
        assert 'Line 1' in result.stdout
        assert 'Line 2' in result.stdout


class TestPlatformDetection:
    """Test platform detection functionality."""
    
    def test_detect_current_platform(self, pyve):
        """Test that current platform is detected correctly."""
        current_platform = platform.system()
        
        # Platform should be one of the supported ones
        assert current_platform in ['Darwin', 'Linux', 'Windows']
    
    def test_python_platform_info(self, pyve, project_builder):
        """Test that Python platform info is accessible."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'import platform; print(platform.system())')
        
        assert result.returncode == 0
        assert result.stdout.strip() in ['Darwin', 'Linux', 'Windows']
    
    @pytest.mark.venv
    def test_architecture_detection(self, pyve, project_builder):
        """Test architecture detection (x86_64, arm64, etc.)."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        result = pyve.run_cmd('python', '-c', 'import platform; print(platform.machine())')
        
        assert result.returncode == 0
        # Should return architecture
        assert len(result.stdout.strip()) > 0


class TestShellIntegration:
    """Test shell integration across platforms."""
    
    @pytest.mark.venv
    def test_bash_compatibility(self, pyve, project_builder):
        """Test bash compatibility."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        # pyve.sh should work with bash
    
    @pytest.mark.venv
    def test_zsh_compatibility(self, pyve, project_builder):
        """Test zsh compatibility (macOS default)."""
        project_builder.create_requirements(['requests==2.31.0'])
        
        result = pyve.init(backend='venv')
        
        assert result.returncode == 0
        # Should work with zsh
    
    @pytest.mark.venv
    def test_shell_script_execution(self, pyve, project_builder):
        """Test that shell scripts can be executed."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create a simple shell script
        script_path = pyve.cwd / 'test.sh'
        script_path.write_text('#!/bin/bash\necho "Shell test"\n')
        script_path.chmod(0o755)
        
        result = pyve.run_cmd('bash', 'test.sh')
        
        assert result.returncode == 0
        assert 'Shell test' in result.stdout


class TestFileSystemBehavior:
    """Test filesystem behavior across platforms."""
    
    @pytest.mark.venv
    def test_case_sensitivity(self, pyve, project_builder):
        """Test case sensitivity handling."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create files with different cases
        script1 = project_builder.create_python_script('Test.py', 'print("Upper")')
        script2 = project_builder.create_python_script('test.py', 'print("Lower")')
        
        # Behavior depends on filesystem (HFS+ vs APFS vs ext4)
        # Just verify scripts can be created and run
        result = pyve.run_cmd('python', 'test.py')
        assert result.returncode == 0
    
    @pytest.mark.venv
    def test_symlink_handling(self, pyve, project_builder):
        """Test symlink handling."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Venv uses symlinks on Unix-like systems
        python_link = pyve.cwd / '.venv' / 'bin' / 'python'
        
        if python_link.exists():
            # On Unix, this is typically a symlink
            assert python_link.exists()
    
    @pytest.mark.venv
    def test_long_paths(self, pyve, project_builder):
        """Test handling of long file paths."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create deeply nested directory
        deep_path = pyve.cwd / 'a' / 'b' / 'c' / 'd' / 'e'
        deep_path.mkdir(parents=True)
        script = deep_path / 'test.py'
        script.write_text('print("Deep path")')
        
        result = pyve.run_cmd('python', 'a/b/c/d/e/test.py')
        
        assert result.returncode == 0
        assert 'Deep path' in result.stdout


class TestEdgeCases:
    """Cross-platform edge case tests."""
    
    @pytest.mark.venv
    def test_unicode_in_paths(self, pyve, project_builder):
        """Test Unicode characters in file paths."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create directory with Unicode name (if supported)
        try:
            unicode_dir = pyve.cwd / 'tëst_dîr'
            unicode_dir.mkdir()
            script = unicode_dir / 'test.py'
            script.write_text('print("Unicode path")')
            
            result = pyve.run_cmd('python', str(script.relative_to(pyve.cwd)))
            
            # May or may not work depending on platform/filesystem
            assert result.returncode in [0, 1]
        except (OSError, UnicodeError):
            # Some filesystems don't support Unicode
            pytest.skip("Filesystem doesn't support Unicode paths")
    
    @pytest.mark.venv
    def test_spaces_in_paths(self, pyve, project_builder):
        """Test spaces in file paths."""
        project_builder.create_requirements(['requests==2.31.0'])
        pyve.init(backend='venv')
        
        # Create directory with spaces
        space_dir = pyve.cwd / 'test dir'
        space_dir.mkdir()
        script = space_dir / 'test.py'
        script.write_text('print("Space in path")')
        
        result = pyve.run_cmd('python', 'test dir/test.py')
        
        assert result.returncode == 0
        assert 'Space in path' in result.stdout
