# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Unit-style tests for the real-home mutation guard helpers
(tests/helpers/home_guard.py).

The guard snapshots the Pyve hosting artifacts a test run must never
touch — the project-guide shim (~/.local/bin/project-guide) and the
toolchain tree (${XDG_DATA_HOME:-~/.local/share}/pyve/toolchain) — and
diffs the snapshots at session teardown. These tests drive the snapshot
and diff functions directly against a throwaway "home" so the
teardown-failure behavior is verified without mutating anything real.
"""

import sys
from pathlib import Path

# Match conftest's helpers-path setup so the module resolves when this
# file is run standalone.
sys.path.insert(0, str(Path(__file__).parent.parent / "helpers"))

from home_guard import diff_hosting_state, snapshot_hosting_state  # noqa: E402


def _make_home(tmp_path: Path) -> Path:
    """A throwaway 'real home' with hosted project-guide artifacts."""
    home = tmp_path / "guarded_home"
    bin_dir = home / ".local" / "bin"
    bin_dir.mkdir(parents=True)
    toolchain = home / ".local" / "share" / "pyve" / "toolchain" / "3.12.13" / "venv"
    (toolchain / "bin").mkdir(parents=True)
    (toolchain / "bin" / "python").write_text("#!/bin/sh\n")
    (toolchain / "bin" / "project-guide").write_text("#!/usr/bin/env python\n")
    (bin_dir / "project-guide").symlink_to(toolchain / "bin" / "project-guide")
    return home


class TestSnapshotAndDiff:
    def test_untouched_home_diffs_clean(self, tmp_path):
        home = _make_home(tmp_path)
        before = snapshot_hosting_state(home)
        after = snapshot_hosting_state(home)
        assert diff_hosting_state(before, after) == []

    def test_absent_artifacts_diff_clean(self, tmp_path):
        home = tmp_path / "empty_home"
        home.mkdir()
        before = snapshot_hosting_state(home)
        after = snapshot_hosting_state(home)
        assert diff_hosting_state(before, after) == []

    def test_retargeted_shim_is_detected(self, tmp_path):
        home = _make_home(tmp_path)
        before = snapshot_hosting_state(home)
        shim = home / ".local" / "bin" / "project-guide"
        shim.unlink()
        shim.symlink_to(tmp_path / "somewhere-else")
        problems = diff_hosting_state(before, snapshot_hosting_state(home))
        assert problems and any("project-guide" in p for p in problems)

    def test_deleted_shim_is_detected(self, tmp_path):
        home = _make_home(tmp_path)
        before = snapshot_hosting_state(home)
        (home / ".local" / "bin" / "project-guide").unlink()
        problems = diff_hosting_state(before, snapshot_hosting_state(home))
        assert problems and any("project-guide" in p for p in problems)

    def test_created_shim_is_detected(self, tmp_path):
        home = tmp_path / "empty_home"
        (home / ".local" / "bin").mkdir(parents=True)
        before = snapshot_hosting_state(home)
        (home / ".local" / "bin" / "project-guide").write_text("#!/bin/sh\n")
        problems = diff_hosting_state(before, snapshot_hosting_state(home))
        assert problems and any("project-guide" in p for p in problems)

    def test_file_added_to_toolchain_is_detected(self, tmp_path):
        home = _make_home(tmp_path)
        before = snapshot_hosting_state(home)
        toolchain = home / ".local" / "share" / "pyve" / "toolchain"
        (toolchain / "3.12.13" / "venv" / "bin" / "pip").write_text("#!/bin/sh\n")
        problems = diff_hosting_state(before, snapshot_hosting_state(home))
        assert problems and any("pip" in p for p in problems)

    def test_file_removed_from_toolchain_is_detected(self, tmp_path):
        home = _make_home(tmp_path)
        before = snapshot_hosting_state(home)
        toolchain = home / ".local" / "share" / "pyve" / "toolchain"
        (toolchain / "3.12.13" / "venv" / "bin" / "python").unlink()
        problems = diff_hosting_state(before, snapshot_hosting_state(home))
        assert problems and any("python" in p for p in problems)

    def test_rewritten_toolchain_file_is_detected(self, tmp_path):
        home = _make_home(tmp_path)
        before = snapshot_hosting_state(home)
        toolchain = home / ".local" / "share" / "pyve" / "toolchain"
        target = toolchain / "3.12.13" / "venv" / "bin" / "python"
        target.write_text("#!/bin/sh\n# rewritten with different content\n")
        problems = diff_hosting_state(before, snapshot_hosting_state(home))
        assert problems and any("python" in p for p in problems)

    def test_toolchain_created_from_absent_is_detected(self, tmp_path):
        home = tmp_path / "empty_home"
        home.mkdir()
        before = snapshot_hosting_state(home)
        venv_bin = home / ".local" / "share" / "pyve" / "toolchain" / "3.12.13" / "venv" / "bin"
        venv_bin.mkdir(parents=True)
        (venv_bin / "python").write_text("#!/bin/sh\n")
        problems = diff_hosting_state(before, snapshot_hosting_state(home))
        assert problems

    def test_pycache_churn_is_ignored(self, tmp_path):
        """Bytecode caches are derived state: read-only *executions* of the
        real toolchain python may lazily compile them, which is not a
        hosting-artifact mutation and must not trip the guard."""
        home = _make_home(tmp_path)
        before = snapshot_hosting_state(home)
        pycache = (
            home / ".local" / "share" / "pyve" / "toolchain"
            / "3.12.13" / "venv" / "__pycache__"
        )
        pycache.mkdir()
        (pycache / "site.cpython-312.pyc").write_bytes(b"\x00\x01")
        assert diff_hosting_state(before, snapshot_hosting_state(home)) == []

    def test_xdg_data_home_overrides_toolchain_root(self, tmp_path):
        home = tmp_path / "empty_home"
        home.mkdir()
        xdg = tmp_path / "xdg-data"
        venv_bin = xdg / "pyve" / "toolchain" / "3.12.13" / "venv" / "bin"
        venv_bin.mkdir(parents=True)
        (venv_bin / "python").write_text("#!/bin/sh\n")
        before = snapshot_hosting_state(home, xdg_data_home=str(xdg))
        (venv_bin / "pip").write_text("#!/bin/sh\n")
        problems = diff_hosting_state(
            before, snapshot_hosting_state(home, xdg_data_home=str(xdg))
        )
        assert problems and any("pip" in p for p in problems)
