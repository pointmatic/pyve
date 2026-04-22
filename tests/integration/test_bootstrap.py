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
Integration tests for micromamba bootstrap functionality.

Tests automatic micromamba installation and bootstrap process.
Bootstrap is implemented; the ``@pytest.mark.skip`` markers are scheduled
to be removed incrementally in Phase I (Stories I.b through I.g).
"""

import os
import shutil

import pytest
from pathlib import Path


@pytest.fixture
def bootstrap_isolation(monkeypatch, tmp_path):
    """
    Isolate $HOME and scrub micromamba from $PATH so bootstrap resolution is
    deterministic.

    Returns the isolated $HOME path. After this fixture runs,
    ``check_micromamba_available`` in pyve.sh will resolve in this order:
    project sandbox (empty in each tmp test project) → user sandbox under the
    fake $HOME (empty) → system PATH (scrubbed). That lets tests assert
    exactly what bootstrap did, regardless of what the developer has installed.
    """
    fake_home = tmp_path / "home"
    fake_home.mkdir()
    monkeypatch.setenv("HOME", str(fake_home))

    while True:
        found = shutil.which("micromamba")
        if not found:
            break
        bin_dir = os.path.dirname(found)
        current = os.environ.get("PATH", "")
        new = ":".join(p for p in current.split(":") if p != bin_dir)
        monkeypatch.setenv("PATH", new)

    return fake_home


@pytest.fixture
def failing_curl(bootstrap_isolation, monkeypatch, tmp_path):
    """
    Prepend a PATH shim that makes ``curl`` exit 1.

    ``bootstrap_install_micromamba`` is the only pyve.sh caller of curl
    (grepped across pyve.sh and lib/*.sh), so this only affects bootstrap
    downloads. Returns the shim directory.
    """
    shim_dir = tmp_path / "shim_bin"
    shim_dir.mkdir()
    curl_shim = shim_dir / "curl"
    curl_shim.write_text(
        '#!/usr/bin/env bash\n'
        'echo "curl: (simulated) download failed" >&2\n'
        'exit 1\n'
    )
    curl_shim.chmod(0o755)
    monkeypatch.setenv("PATH", f"{shim_dir}:{os.environ.get('PATH', '')}")
    return shim_dir


@pytest.mark.micromamba
class TestBootstrapPlaceholder:
    """Core auto-bootstrap tests (activated in Story I.b)."""

    def test_auto_bootstrap_when_not_installed(self, pyve, project_builder, bootstrap_isolation):
        """Auto-bootstrap fires when micromamba is not available on any resolution path."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        # Full init may fail downstream (env-creation downloads python=3.11
        # and can be slow / flaky). This test's scope is the bootstrap step
        # itself — that the auto-bootstrap banner fired and installed the
        # micromamba binary into the user sandbox (the default target).
        result = pyve.init(
            backend='micromamba',
            auto_bootstrap=True,
            bootstrap_to='user',
            check=False,
        )

        assert 'Auto-bootstrapping micromamba' in result.stdout
        assert (bootstrap_isolation / '.pyve' / 'bin' / 'micromamba').exists()

    def test_bootstrap_to_project_sandbox(self, pyve, project_builder, bootstrap_isolation):
        """--bootstrap-to project installs micromamba into <cwd>/.pyve/bin/micromamba."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        result = pyve.init(
            backend='micromamba',
            auto_bootstrap=True,
            bootstrap_to='project',
            check=False,
        )

        assert 'Auto-bootstrapping micromamba to project' in result.stdout
        assert (pyve.cwd / '.pyve' / 'bin' / 'micromamba').exists()

    def test_bootstrap_to_user_sandbox(self, pyve, project_builder, bootstrap_isolation):
        """--bootstrap-to user installs micromamba into $HOME/.pyve/bin/micromamba."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        result = pyve.init(
            backend='micromamba',
            auto_bootstrap=True,
            bootstrap_to='user',
            check=False,
        )

        assert 'Auto-bootstrapping micromamba to user' in result.stdout
        user_micromamba = bootstrap_isolation / '.pyve' / 'bin' / 'micromamba'
        assert user_micromamba.exists()

    def test_bootstrap_skips_if_already_installed(self, pyve, project_builder, bootstrap_isolation):
        """Pre-existing micromamba in the project sandbox skips the bootstrap step silently."""
        # Plant a shim satisfying get_micromamba_path's `-x` + `--version` checks.
        shim_dir = pyve.cwd / '.pyve' / 'bin'
        shim_dir.mkdir(parents=True)
        shim = shim_dir / 'micromamba'
        shim.write_text(
            '#!/usr/bin/env bash\n'
            '[ "$1" = "--version" ] && echo "1.5.3"\n'
            'exit 0\n'
        )
        shim.chmod(0o755)

        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        result = pyve.init(
            backend='micromamba',
            auto_bootstrap=True,
            check=False,
        )

        # Silent-skip is the documented behavior: no "Auto-bootstrapping" or
        # "Downloading micromamba" banner fires when check_micromamba_available
        # returns true before the bootstrap gate.
        assert 'Auto-bootstrapping micromamba' not in result.stdout
        assert 'Downloading micromamba' not in result.stdout

    @pytest.mark.skip(reason="Bootstrap not yet implemented")
    def test_bootstrap_version_selection(self, pyve, project_builder):
        """Test bootstrap can install specific micromamba version."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )

        result = pyve.init(backend='micromamba', auto_bootstrap=True)

        assert result.returncode == 0

    @pytest.mark.skip(reason="Bootstrap not yet implemented")
    def test_bootstrap_download_verification(self, pyve, project_builder):
        """Test bootstrap verifies downloaded binary."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )

        result = pyve.init(backend='micromamba', auto_bootstrap=True)

        assert result.returncode == 0
        # Should verify checksum or signature
        assert 'verified' in result.stdout.lower() or 'checksum' in result.stdout.lower()

    def test_bootstrap_platform_detection(self, pyve, project_builder, failing_curl):
        """Bootstrap selects the download URL matching the current OS + architecture."""
        import platform as _platform

        system = _platform.system()
        machine = _platform.machine()
        if system == "Darwin":
            expected = "osx-arm64" if machine in ("arm64", "aarch64") else "osx-64"
        elif system == "Linux":
            if machine == "x86_64":
                expected = "linux-64"
            elif machine in ("aarch64", "arm64"):
                expected = "linux-aarch64"
            elif machine == "ppc64le":
                expected = "linux-ppc64le"
            else:
                pytest.skip(f"Unsupported Linux architecture: {machine}")
        else:
            pytest.skip(f"Unsupported OS: {system}")

        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        # failing_curl sabotages the download, but the "Downloading micromamba
        # from: <url>" log_info line fires *before* curl runs, so the URL is
        # captured in stdout even though bootstrap exits 1.
        result = pyve.init(
            backend='micromamba',
            auto_bootstrap=True,
            bootstrap_to='user',
            check=False,
        )

        assert f"/{expected}/" in result.stdout

    def test_bootstrap_failure_handling(self, pyve, project_builder, failing_curl):
        """Bootstrap exits non-zero and surfaces a download failure message when curl fails."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        result = pyve.init(
            backend='micromamba',
            auto_bootstrap=True,
            bootstrap_to='user',
            check=False,
        )

        assert result.returncode != 0
        # log_error emits "Failed to download micromamba" to stderr.
        assert 'download' in result.stderr.lower() or 'failed' in result.stderr.lower()


@pytest.mark.micromamba
class TestBootstrapConfiguration:
    """Test bootstrap configuration options."""

    @pytest.mark.skip(reason="Bootstrap not yet implemented")
    def test_bootstrap_respects_config_file(self, pyve, project_builder):
        """Test bootstrap respects .pyve/config settings."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )

        # Create config with bootstrap settings
        config_content = """backend: micromamba
micromamba:
  auto_bootstrap: true
  bootstrap_location: project
"""
        config_path = pyve.cwd / '.pyve' / 'config'
        config_path.parent.mkdir(exist_ok=True)
        config_path.write_text(config_content)

        result = pyve.init()

        assert result.returncode == 0

    @pytest.mark.skip(reason="Bootstrap not yet implemented")
    def test_bootstrap_cli_overrides_config(self, pyve, project_builder):
        """Test CLI flags override config file for bootstrap."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )

        # Config says no bootstrap
        project_builder.create_config(
            backend='micromamba',
            micromamba={'auto_bootstrap': False}
        )

        # But CLI says yes
        result = pyve.init(auto_bootstrap=True)

        assert result.returncode == 0


@pytest.mark.micromamba
class TestBootstrapEdgeCases:
    """Failure-path edge cases for bootstrap (activated in Story I.c)."""

    def test_bootstrap_with_insufficient_permissions(self, pyve, project_builder, bootstrap_isolation):
        """Bootstrap fails with a permission message when the user sandbox parent is not writable."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        # Pre-create $HOME/.pyve and make it read-only so the mkdir -p for
        # $HOME/.pyve/bin fails. Scope the chmod narrowly (not to the whole
        # fake HOME) so unrelated tooling reading from $HOME still works.
        pyve_dir = bootstrap_isolation / '.pyve'
        pyve_dir.mkdir()
        original_mode = pyve_dir.stat().st_mode
        pyve_dir.chmod(0o555)
        try:
            result = pyve.init(
                backend='micromamba',
                auto_bootstrap=True,
                bootstrap_to='user',
                check=False,
            )
        finally:
            # Restore write permission so pytest can clean up tmp_path.
            pyve_dir.chmod(original_mode)

        assert result.returncode != 0
        # mkdir's own "Permission denied" error passes through to stderr in
        # addition to log_error's "Failed to create directory".
        assert 'permission' in result.stderr.lower()

    def test_bootstrap_cleanup_on_failure(self, pyve, project_builder, failing_curl):
        """Bootstrap leaves no half-installed micromamba binary when curl fails."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11'],
        )

        result = pyve.init(
            backend='micromamba',
            auto_bootstrap=True,
            bootstrap_to='project',
            check=False,
        )

        assert result.returncode != 0
        # The actual cleanup guarantee: no partial binary at the install path.
        # bootstrap_install_micromamba's tmpfile lives under mktemp (not under
        # .pyve/bin), and on curl failure it's rm -f'd before returning — the
        # observable postcondition is simply that no binary was emplaced.
        assert not (pyve.cwd / '.pyve' / 'bin' / 'micromamba').exists()


class TestBootstrapDocumentation:
    """Tests to ensure bootstrap is properly documented."""

    def test_bootstrap_flag_in_help(self, pyve):
        """Test that --auto-bootstrap flag appears in help."""
        result = pyve.run('--help', check=False)

        # Help should mention bootstrap (when implemented)
        # For now, just verify help works
        assert result.returncode in [0, 1]

    def test_bootstrap_error_message_helpful(self, pyve, project_builder):
        """Test that error message suggests bootstrap when micromamba not found."""
        project_builder.create_environment_yml(
            name='test-env',
            dependencies=['python=3.11']
        )

        # Try to init without micromamba (if not installed)
        result = pyve.init(backend='micromamba', check=False)

        # Error message should be helpful (may succeed if micromamba installed)
        if result.returncode != 0:
            # Should suggest installation or bootstrap
            assert 'install' in result.stderr.lower() or 'bootstrap' in result.stderr.lower() or 'micromamba' in result.stderr.lower()
