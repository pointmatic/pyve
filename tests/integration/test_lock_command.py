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
Integration tests for the `pyve lock` command (FR-15, FR-16).

Tests cover the guard conditions (backend check, conda-lock availability,
environment.yml presence), the --check flag (mtime-only verification), and
— when conda-lock is available — the end-to-end behavior including output
filtering.
"""

import os
import pytest
from pathlib import Path


class TestLockCommandGuards:
    """Guard conditions that must fire before conda-lock is invoked."""

    def test_lock_fails_on_venv_backend(self, pyve, project_builder):
        """
        pyve lock on a venv project must fail immediately with a clear
        'micromamba projects only' message — not 'environment.yml not found'.
        The venv backend check must fire before any conda-lock logic.
        """
        project_builder.create_pyproject_toml("test-project")
        result = pyve.run("--init", "--backend", "venv")
        assert result.returncode == 0

        result = pyve.run("lock")
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "micromamba projects only" in combined
        # Must NOT reach the environment.yml check
        assert "environment.yml not found" not in combined

    def test_lock_fails_without_environment_yml(self, pyve, project_builder):
        """
        pyve lock without an environment.yml must fail with a clear error
        that includes a 'pyve --init --backend micromamba' hint.
        No .pyve/config exists so the venv guard does not apply.
        """
        # No project files — no config, no environment.yml
        result = pyve.run("lock")
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "environment.yml not found" in combined
        assert "micromamba" in combined

    def test_lock_fails_without_conda_lock_installed(self, pyve, project_builder, monkeypatch):
        """
        pyve lock with environment.yml but no conda-lock binary on PATH
        must fail with instructions to add conda-lock to environment.yml.
        """
        project_builder.create_environment_yml("test-env")

        # Strip PATH down to dirs that definitely don't have conda-lock
        monkeypatch.setenv("PATH", "/usr/bin:/bin")

        result = pyve.run("lock")
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "conda-lock is not available" in combined
        assert "environment.yml" in combined  # install hint

    def test_lock_venv_backend_message_does_not_mention_environment_yml(
        self, pyve, project_builder
    ):
        """
        The venv-backend error message must be self-contained: it should tell
        the user the real reason for failure without pointing them at
        environment.yml (which would be confusing — the issue is the backend).
        """
        project_builder.create_environment_yml("test-env")  # file exists but backend is venv
        project_builder.create_pyproject_toml("test-project")
        result = pyve.run("--init", "--backend", "venv")
        assert result.returncode == 0

        result = pyve.run("lock")
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "micromamba projects only" in combined
        # The user already has environment.yml — don't confuse them about it
        assert "environment.yml not found" not in combined


@pytest.mark.skipif(
    not os.environ.get("MICROMAMBA_AVAILABLE"),
    reason="Micromamba not available",
)
class TestLockCommandEndToEnd:
    """
    End-to-end tests that require conda-lock to be installed in the
    project environment. These only run when MICROMAMBA_AVAILABLE is set.
    """

    def test_lock_generates_conda_lock_yml(self, pyve, project_builder):
        """
        pyve lock on a micromamba project with environment.yml should produce
        conda-lock.yml in the project directory.
        """
        project_builder.create_environment_yml("test-env")
        result = pyve.run("--init", "--backend", "micromamba", "--auto-bootstrap", "--no-lock")
        assert result.returncode == 0

        lock_path = project_builder.project_dir / "conda-lock.yml"
        assert not lock_path.exists(), "Precondition: no lock file yet (used --no-lock)"

        result = pyve.run("lock")
        assert result.returncode == 0
        assert lock_path.exists(), "conda-lock.yml should be created by pyve lock"

    def test_lock_success_output_references_pyve_init_force(self, pyve, project_builder):
        """
        On a successful run, pyve lock should print guidance referencing
        'pyve --init --force' — not raw conda-lock commands.
        """
        project_builder.create_environment_yml("test-env")
        pyve.run("--init", "--backend", "micromamba", "--auto-bootstrap", "--no-lock")

        result = pyve.run("lock")
        assert result.returncode == 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "pyve --init --force" in combined

    def test_lock_success_output_does_not_contain_misleading_install_message(
        self, pyve, project_builder
    ):
        """
        pyve lock must suppress conda-lock's post-run 'conda-lock install'
        message, which describes a non-Pyve workflow.
        """
        project_builder.create_environment_yml("test-env")
        pyve.run("--init", "--backend", "micromamba", "--auto-bootstrap", "--no-lock")

        result = pyve.run("lock")
        assert result.returncode == 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "conda-lock install" not in combined
        assert "Install lock using" not in combined

    def test_lock_already_up_to_date(self, pyve, project_builder):
        """
        Running pyve lock twice without changing environment.yml should
        produce an 'already up to date' message on the second run and
        leave conda-lock.yml's mtime unchanged.
        """
        project_builder.create_environment_yml("test-env")
        pyve.run("--init", "--backend", "micromamba", "--auto-bootstrap", "--no-lock")

        # First run — generates lock file
        result = pyve.run("lock")
        assert result.returncode == 0

        lock_path = project_builder.project_dir / "conda-lock.yml"
        mtime_after_first = lock_path.stat().st_mtime

        # Second run — spec unchanged
        result = pyve.run("lock")
        assert result.returncode == 0
        combined = (result.stdout or "") + (result.stderr or "")

        # Either the "already up to date" message appears, or the file mtime
        # is unchanged (both are acceptable outcomes depending on conda-lock version)
        mtime_after_second = lock_path.stat().st_mtime
        assert (
            "already up to date" in combined or mtime_after_second == mtime_after_first
        ), "Second pyve lock run should be a no-op"


class TestLockCheckFlag:
    """Tests for `pyve lock --check` — mtime-only verification (FR-16)."""

    def test_check_exits_1_when_conda_lock_yml_missing(self, pyve, project_builder):
        """
        pyve lock --check must exit non-zero with a clear message when
        conda-lock.yml does not exist. conda-lock need not be installed.
        """
        project_builder.create_environment_yml("test-env")

        result = pyve.run("lock", "--check")
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "conda-lock.yml not found" in combined
        assert "pyve lock" in combined

    def test_check_exits_1_when_lock_is_stale(self, pyve, project_builder):
        """
        pyve lock --check must exit non-zero when environment.yml is newer
        than conda-lock.yml, with a message referencing 'pyve lock'.
        """
        import os
        import time

        project_dir = project_builder.project_dir
        lock_path = project_dir / "conda-lock.yml"
        env_path = project_dir / "environment.yml"

        project_builder.create_environment_yml("test-env")

        # Write lock file and back-date it so environment.yml appears newer
        lock_path.write_text("# placeholder lock\n")
        old_time = time.time() - 120  # 2 minutes ago
        os.utime(lock_path, (old_time, old_time))
        # Touch environment.yml to ensure it is newer
        os.utime(env_path, None)

        result = pyve.run("lock", "--check")
        assert result.returncode != 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "stale" in combined
        assert "pyve lock" in combined

    def test_check_exits_0_when_lock_is_current(self, pyve, project_builder):
        """
        pyve lock --check must exit 0 with an up-to-date message when
        conda-lock.yml is newer than environment.yml.
        Does not require conda-lock to be on PATH.
        """
        import os
        import time

        project_dir = project_builder.project_dir
        lock_path = project_dir / "conda-lock.yml"
        env_path = project_dir / "environment.yml"

        project_builder.create_environment_yml("test-env")

        # Back-date environment.yml, then write a newer lock file
        old_time = time.time() - 120
        os.utime(env_path, (old_time, old_time))
        lock_path.write_text("# placeholder lock\n")

        result = pyve.run("lock", "--check")
        assert result.returncode == 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "up to date" in combined

    def test_check_does_not_invoke_conda_lock(self, pyve, project_builder, monkeypatch):
        """
        pyve lock --check must not attempt to run conda-lock — the mtime check
        should succeed even when conda-lock is not on PATH.
        """
        import os
        import time

        project_dir = project_builder.project_dir
        lock_path = project_dir / "conda-lock.yml"
        env_path = project_dir / "environment.yml"

        project_builder.create_environment_yml("test-env")

        old_time = time.time() - 120
        os.utime(env_path, (old_time, old_time))
        lock_path.write_text("# placeholder lock\n")

        # Strip conda-lock from PATH entirely
        monkeypatch.setenv("PATH", "/usr/bin:/bin")

        result = pyve.run("lock", "--check")
        assert result.returncode == 0
        combined = (result.stdout or "") + (result.stderr or "")
        assert "up to date" in combined
