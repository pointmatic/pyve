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

import os


def test_testenv_survives_force_reinit(pyve, project_builder):
    pyve.init(backend="venv")

    # `pyve test` should auto-create the dev/test runner env and (in tests/CI)
    # auto-install pytest without prompting.
    testenv_python = project_builder.project_dir / ".pyve" / "testenv" / "venv" / "bin" / "python"

    result = pyve.run("test", "-q", check=False)
    # If there are no tests, pytest exits 5. Accept that as success signal for wiring.
    assert result.returncode in (0, 5)

    assert testenv_python.exists()

    # Force re-init should purge the project env but preserve testenv.
    os.environ["PYVE_FORCE_YES"] = "1"
    result = pyve.run("--init", "--force", "--no-direnv")
    assert result.returncode == 0

    assert testenv_python.exists()

    # Confirm pytest still runs via the preserved test runner env.
    result = pyve.run("test", "-q", check=False)
    # If there are no tests, pytest exits 5. Accept that as success signal for wiring.
    assert result.returncode in (0, 5)
