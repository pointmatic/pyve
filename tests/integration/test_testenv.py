import os
from pathlib import Path


def test_testenv_survives_force_reinit(pyve, project_builder):
    pyve.init(backend="venv")

    # Create the dev/test runner env and install pytest into it.
    result = pyve.run("testenv", "--init")
    assert result.returncode == 0

    result = pyve.run("testenv", "--install")
    assert result.returncode == 0

    testenv_python = project_builder.project_dir / ".pyve" / "testenv" / "venv" / "bin" / "python"
    assert testenv_python.exists()

    # Force re-init should purge the project env but preserve testenv.
    os.environ["PYVE_FORCE_YES"] = "1"
    result = pyve.run("--init", "--force", "--no-direnv")
    assert result.returncode == 0

    assert testenv_python.exists()

    # Confirm pytest runs via the test runner env.
    result = pyve.run("test", "-q")
    # If there are no tests, pytest exits 5. Accept that as success signal for wiring.
    assert result.returncode in (0, 5)
