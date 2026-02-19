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
Pyve Test Helpers

Helper classes and utilities for pytest integration tests.
"""

import re
import os
import subprocess
from pathlib import Path
from typing import List, Optional, Union


def _detect_version_manager_python_version(env: dict) -> Optional[str]:
    try:
        result = subprocess.run(
            ["pyenv", "version-name"],
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
        if result.returncode == 0:
            version = result.stdout.strip()
            if version and version not in {"system", ""}:
                return version
    except FileNotFoundError:
        pass

    try:
        result = subprocess.run(
            ["asdf", "current", "python"],
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
        if result.returncode == 0:
            line = result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""
            match = re.search(r"\b(\d+\.\d+\.\d+)\b", line)
            if match:
                return match.group(1)
    except FileNotFoundError:
        pass

    # Fallback: use whatever python3 is on PATH.  This covers the case
    # where tests run in a tmp directory with no .tool-versions / .python-version
    # so asdf/pyenv cannot resolve a project-local version.
    try:
        result = subprocess.run(
            ["python3", "--version"],
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
        if result.returncode == 0:
            match = re.search(r"(\d+\.\d+\.\d+)", result.stdout)
            if match:
                return match.group(1)
    except FileNotFoundError:
        pass

    return None


def get_pyve_version(script_path: Path) -> str:
    """
    Extract the VERSION from pyve.sh.
    
    Args:
        script_path: Path to pyve.sh script
        
    Returns:
        Version string (e.g., "0.8.14")
    """
    content = script_path.read_text()
    match = re.search(r'^VERSION="([^"]+)"', content, re.MULTILINE)
    if not match:
        raise ValueError(f"Could not find VERSION in {script_path}")
    return match.group(1)


class PyveRunner:
    """Helper class to run pyve commands in tests."""
    
    def __init__(self, script_path: Path, cwd: Path):
        """
        Initialize PyveRunner.
        
        Args:
            script_path: Path to pyve.sh script
            cwd: Working directory for commands
        """
        # When PYVE_KCOV_OUTDIR is set, use the kcov wrapper to collect
        # Bash line coverage during integration tests.
        if os.environ.get("PYVE_KCOV_OUTDIR"):
            wrapper = Path(__file__).parent / "kcov-wrapper.sh"
            self.script_path = wrapper if wrapper.exists() else script_path
        else:
            self.script_path = script_path
        self.cwd = cwd
    
    # Default timeout (seconds) for subprocess calls.  Prevents tests from
    # hanging indefinitely when, e.g., a Python version build is triggered.
    DEFAULT_TIMEOUT = 120

    def run(
        self,
        *args: str,
        check: bool = False,
        capture: bool = True,
        input: Optional[str] = None,
        timeout: Optional[int] = None,
    ) -> subprocess.CompletedProcess:
        """
        Run pyve command.
        
        Args:
            *args: Command arguments
            check: Raise exception on non-zero exit code
            capture: Capture stdout/stderr
            input: Input to send to stdin
            timeout: Seconds before the subprocess is killed (default: DEFAULT_TIMEOUT)
            
        Returns:
            CompletedProcess instance
        """
        cmd = [str(self.script_path)] + list(args)
        kwargs = {
            'cwd': self.cwd,
            'check': check,
            'timeout': timeout if timeout is not None else self.DEFAULT_TIMEOUT,
        }
        
        if capture:
            kwargs['capture_output'] = True
            kwargs['text'] = True
        
        if input is not None:
            kwargs['input'] = input
            kwargs['text'] = True
        
        # Pass current environment to subprocess (includes PYENV_ROOT, PATH, etc.)
        if 'env' not in kwargs:
            env = os.environ.copy()
            if "PYTEST_CURRENT_TEST" in env:
                # When running under pytest, allow `pyve test` to auto-install pytest into
                # the dev/test runner env without prompting.
                env.setdefault("PYVE_TEST_AUTO_INSTALL_PYTEST", "1")
                # Always pin to the installed Python version under pytest to
                # avoid triggering a slow Python build when the default
                # version is not yet installed.
                env.setdefault("PYVE_TEST_PIN_PYTHON", "1")
                # In CI, tests must be non-interactive.
                if env.get("CI") == "true":
                    env.setdefault("PYVE_FORCE_YES", "1")
            kwargs['env'] = env
        
        return subprocess.run(cmd, **kwargs)
    
    def init(
        self,
        backend: Optional[str] = None,
        venv_dir: Optional[str] = None,
        **kwargs
    ) -> subprocess.CompletedProcess:
        """
        Run pyve --init.
        
        Args:
            backend: Backend to use (venv, micromamba, auto)
            venv_dir: Custom venv directory
            **kwargs: Additional flags (converted to --flag-name) and subprocess options
            
        Returns:
            CompletedProcess instance
        """
        args = ['--init']

        # pyve.sh uses a positional argument for custom venv directory name.
        # The test helper accepts venv_dir=... for convenience.
        legacy_venv_dir = kwargs.pop('venv_dir', None)
        effective_venv_dir = venv_dir or legacy_venv_dir
        if effective_venv_dir:
            args.append(str(effective_venv_dir))

        args.extend(['--no-direnv', '--force'])

        if "python_version" not in kwargs and backend in (None, "venv", "auto"):
            env = os.environ.copy()
            # Always pin to the installed Python version under pytest to
            # avoid triggering a slow Python build (the env var is now set
            # automatically by run(); check it here as well for callers
            # that set it manually).
            if (os.environ.get("CI") == "true"
                    or os.environ.get("PYVE_TEST_PIN_PYTHON") == "1"
                    or os.environ.get("PYTEST_CURRENT_TEST")):
                detected = _detect_version_manager_python_version(env)
                if detected:
                    kwargs["python_version"] = detected
        
        if backend:
            args.extend(['--backend', backend])
        
        # Separate subprocess options from pyve flags
        subprocess_opts = {}
        if 'check' in kwargs:
            subprocess_opts['check'] = kwargs.pop('check')
        if 'input' in kwargs:
            subprocess_opts['input'] = kwargs.pop('input')
        
        for key, value in kwargs.items():
            flag = f"--{key.replace('_', '-')}"
            if value is True:
                args.append(flag)
            elif value is not False and value is not None:
                args.extend([flag, str(value)])
        
        return self.run(*args, **subprocess_opts)
    
    def doctor(self, check: bool = True, **kwargs) -> subprocess.CompletedProcess:
        """
        Run pyve doctor.
        
        Args:
            check: If True, raise CalledProcessError on non-zero exit (default: True)
            **kwargs: Additional arguments passed to run()
        
        Returns:
            CompletedProcess instance
        """
        return self.run('doctor', check=check, **kwargs)
    
    def run_cmd(self, *cmd_args: str, **kwargs) -> subprocess.CompletedProcess:
        """
        Run pyve run <cmd>.
        
        Args:
            *cmd_args: Command and arguments to run
            **kwargs: Additional arguments passed to run()
            
        Returns:
            CompletedProcess instance
        """
        return self.run('run', *cmd_args, **kwargs)
    
    def purge(self, force: bool = False, auto_yes: bool = False, **kwargs) -> subprocess.CompletedProcess:
        """
        Run pyve --purge.
        
        Args:
            force: Skip confirmation prompt (deprecated, use auto_yes)
            auto_yes: Skip confirmation prompt
            **kwargs: Additional arguments passed to run()
            
        Returns:
            CompletedProcess instance
        """
        args = ['--purge']
        if force or auto_yes:
            # Send 'y' to confirmation prompt
            return self.run(*args, input='y\n', **kwargs)
        return self.run(*args, **kwargs)
    
    def config(self) -> subprocess.CompletedProcess:
        """Run pyve --config."""
        return self.run('--config')
    
    def version(self) -> subprocess.CompletedProcess:
        """Run pyve --version."""
        return self.run('--version')


class ProjectBuilder:
    """Helper class to build test project structures."""
    
    def __init__(self, base_path: Path):
        """
        Initialize ProjectBuilder.
        
        Args:
            base_path: Base directory for project
        """
        self.base_path = base_path
        self.base_path.mkdir(parents=True, exist_ok=True)
    
    def create_requirements(self, packages: List[str]) -> Path:
        """Alias for create_requirements_txt."""
        return self.create_requirements_txt(packages)
    
    def create_requirements_txt(self, packages: List[str]) -> Path:
        """
        Create requirements.txt file.
        
        Args:
            packages: List of package specifications
            
        Returns:
            Path to created file
        """
        file_path = self.base_path / 'requirements.txt'
        file_path.write_text('\n'.join(packages) + '\n')
        return file_path
    
    def create_environment_yml(
        self,
        name: str,
        channels: Optional[List[str]] = None,
        dependencies: Optional[List[str]] = None,
    ) -> Path:
        """
        Create environment.yml file.
        
        Args:
            name: Environment name
            channels: List of conda channels
            dependencies: List of dependencies
            
        Returns:
            Path to created file
        """
        if channels is None:
            channels = ['conda-forge']
        if dependencies is None:
            dependencies = ['python=3.11']
        
        content = f"name: {name}\n"
        content += "channels:\n"
        for channel in channels:
            content += f"  - {channel}\n"
        content += "dependencies:\n"
        for dep in dependencies:
            content += f"  - {dep}\n"
        
        file_path = self.base_path / 'environment.yml'
        file_path.write_text(content)
        return file_path
    
    def create_config(
        self,
        backend: Optional[str] = None,
        **kwargs
    ) -> Path:
        """Alias for create_pyve_config."""
        return self.create_pyve_config(backend=backend, **kwargs)
    
    def create_pyve_config(
        self,
        backend: Optional[str] = None,
        include_version: bool = True,
        venv_dir: Optional[str] = None,
        **kwargs
    ) -> Path:
        """
        Create .pyve/config file.
        
        Args:
            backend: Backend to configure
            include_version: Whether to include pyve_version field
            venv_dir: Custom venv directory
            **kwargs: Additional config options
            
        Returns:
            Path to created file
        """
        config_dir = self.base_path / '.pyve'
        config_dir.mkdir(exist_ok=True)
        
        content = ""
        
        # Add version if requested (default for v0.8.8+)
        if include_version:
            content += 'pyve_version: "0.8.8"\n'
        
        if backend:
            content += f"backend: {backend}\n"
        
        # Add venv directory if specified
        if venv_dir:
            content += "venv:\n"
            content += f"  directory: {venv_dir}\n"
        
        for key, value in kwargs.items():
            if isinstance(value, dict):
                content += f"{key}:\n"
                for subkey, subvalue in value.items():
                    content += f"  {subkey}: {subvalue}\n"
            else:
                content += f"{key}: {value}\n"
        
        file_path = config_dir / 'config'
        file_path.write_text(content)
        return file_path
    
    def create_pyproject_toml(
        self,
        name: str,
        version: str = "0.1.0",
        dependencies: Optional[List[str]] = None,
    ) -> Path:
        """
        Create pyproject.toml file.
        
        Args:
            name: Project name
            version: Project version
            dependencies: List of dependencies
            
        Returns:
            Path to created file
        """
        if dependencies is None:
            dependencies = []
        
        content = f"""[project]
name = "{name}"
version = "{version}"
"""
        
        if dependencies:
            content += "dependencies = [\n"
            for dep in dependencies:
                content += f'    "{dep}",\n'
            content += "]\n"
        
        file_path = self.base_path / 'pyproject.toml'
        file_path.write_text(content)
        return file_path
    
    def create_python_script(
        self,
        name: str,
        content: str,
    ) -> Path:
        """
        Create a Python script file.
        
        Args:
            name: Script filename
            content: Script content
            
        Returns:
            Path to created file
        """
        file_path = self.base_path / name
        file_path.write_text(content)
        return file_path
    
    @property
    def project_dir(self):
        """Alias for base_path for compatibility."""
        return self.base_path
    
    def create_venv(self, venv_dir: str = ".venv"):
        """
        Create a venv directory structure (for testing without running pyve --init).
        
        Args:
            venv_dir: Virtual environment directory name
        """
        venv_path = self.base_path / venv_dir
        venv_path.mkdir(parents=True, exist_ok=True)
        (venv_path / "bin").mkdir(exist_ok=True)
        return venv_path

    def init_venv(
        self,
        pyve_script: Optional[Path] = None,
        python_version: Optional[str] = None,
        venv_dir: Optional[str] = None,
    ) -> subprocess.CompletedProcess:
        """
        Initialize a venv project by running pyve --init --backend venv.

        Args:
            pyve_script: Path to pyve.sh (auto-detected if None)
            python_version: Python version to use (auto-detected if None)
            venv_dir: Custom venv directory name

        Returns:
            CompletedProcess instance
        """
        if pyve_script is None:
            pyve_script = Path(__file__).parent.parent.parent / "pyve.sh"

        runner = PyveRunner(pyve_script, self.base_path)
        return runner.init(backend="venv", python_version=python_version, venv_dir=venv_dir)

    def init_micromamba(
        self,
        pyve_script: Optional[Path] = None,
        env_name: Optional[str] = None,
    ) -> subprocess.CompletedProcess:
        """
        Initialize a micromamba project by running pyve --init --backend micromamba.

        Args:
            pyve_script: Path to pyve.sh (auto-detected if None)
            env_name: Environment name

        Returns:
            CompletedProcess instance
        """
        if pyve_script is None:
            pyve_script = Path(__file__).parent.parent.parent / "pyve.sh"

        runner = PyveRunner(pyve_script, self.base_path)
        kwargs = {}
        if env_name:
            kwargs["env_name"] = env_name
        return runner.init(backend="micromamba", **kwargs)


def assert_file_exists(path: Union[Path, str], message: Optional[str] = None):
    """
    Assert that a file exists.
    
    Args:
        path: Path to check
        message: Optional custom error message
    """
    path = Path(path)
    if message is None:
        message = f"Expected file to exist: {path}"
    assert path.exists(), message
    assert path.is_file(), f"Expected path to be a file: {path}"


def assert_dir_exists(path: Union[Path, str], message: Optional[str] = None):
    """
    Assert that a directory exists.
    
    Args:
        path: Path to check
        message: Optional custom error message
    """
    path = Path(path)
    if message is None:
        message = f"Expected directory to exist: {path}"
    assert path.exists(), message
    assert path.is_dir(), f"Expected path to be a directory: {path}"


def assert_command_success(
    result: subprocess.CompletedProcess,
    message: Optional[str] = None,
):
    """
    Assert that a command completed successfully.
    
    Args:
        result: CompletedProcess instance
        message: Optional custom error message
    """
    if message is None:
        message = f"Command failed with exit code {result.returncode}"
    if result.returncode != 0:
        if hasattr(result, 'stderr') and result.stderr:
            message += f"\nstderr: {result.stderr}"
        if hasattr(result, 'stdout') and result.stdout:
            message += f"\nstdout: {result.stdout}"
    assert result.returncode == 0, message


def assert_in_output(
    result: subprocess.CompletedProcess,
    expected: str,
    message: Optional[str] = None,
):
    """
    Assert that expected text is in command output.
    
    Args:
        result: CompletedProcess instance
        expected: Expected text
        message: Optional custom error message
    """
    output = result.stdout if hasattr(result, 'stdout') else ""
    if message is None:
        message = f"Expected '{expected}' in output"
    assert expected in output, f"{message}\nActual output: {output}"
