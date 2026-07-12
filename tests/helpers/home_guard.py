# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0

"""
Real-home mutation guard for the integration suite.

The integration harness once symlinked the developer's real ~/.local and
~/.asdf into its fake $HOME, so provisioning tests wrote Pyve hosting
artifacts into REAL developer state — a dangling ~/.local/bin/project-guide
shim and a dead-interpreter toolchain venv were the result. The suite-level
guard (tests/integration/conftest.py) snapshots those artifacts before the
run and fails teardown if the suite touched them.

This module holds the pure snapshot/diff functions so the guard's detection
behavior is unit-testable (tests/integration/test_home_guard.py) without
mutating anything real.

Guarded artifacts under <home>:
  - the project-guide shim:  <home>/.local/bin/project-guide
  - the toolchain tree:      ${XDG_DATA_HOME:-<home>/.local/share}/pyve/toolchain

Bytecode caches (__pycache__ dirs, *.pyc files) are excluded: read-only
*executions* of a real toolchain python may lazily compile them, which is
derived state, not a hosting-artifact mutation.
"""

import os
import stat
from pathlib import Path

_MAX_REPORTED_PATHS = 20


def _signature(path):
    """lstat-based signature of one filesystem entry; never follows symlinks."""
    try:
        st = os.lstat(path)
    except OSError:
        return ("absent",)
    if stat.S_ISLNK(st.st_mode):
        return ("symlink", os.readlink(path))
    if stat.S_ISDIR(st.st_mode):
        return ("dir",)
    return ("file", st.st_size, st.st_mtime_ns)


def _tree_signature(root: Path):
    """Signatures of every entry under <root>, keyed by relative path."""
    if _signature(root) == ("absent",):
        return ("absent",)
    entries = {}
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = [d for d in dirnames if d != "__pycache__"]
        for name in dirnames + filenames:
            if name.endswith(".pyc"):
                continue
            full = Path(dirpath) / name
            rel = str(full.relative_to(root))
            entries[rel] = _signature(full)
    return ("tree", entries)


def snapshot_hosting_state(home, xdg_data_home=None):
    """Point-in-time signature of the Pyve hosting artifacts under <home>."""
    home = Path(home)
    data_root = Path(xdg_data_home) if xdg_data_home else home / ".local" / "share"
    return {
        "shim": _signature(home / ".local" / "bin" / "project-guide"),
        "toolchain": _tree_signature(data_root / "pyve" / "toolchain"),
    }


def _diff_trees(before, after):
    """Human-readable added/removed/changed lines for two _tree_signature values."""
    if before == after:
        return []
    if before == ("absent",):
        return ["toolchain tree was CREATED"]
    if after == ("absent",):
        return ["toolchain tree was DELETED"]
    before_entries, after_entries = before[1], after[1]
    problems = []
    for rel in sorted(set(after_entries) - set(before_entries)):
        problems.append(f"toolchain: added {rel}")
    for rel in sorted(set(before_entries) - set(after_entries)):
        problems.append(f"toolchain: removed {rel}")
    for rel in sorted(set(before_entries) & set(after_entries)):
        if before_entries[rel] != after_entries[rel]:
            problems.append(
                f"toolchain: changed {rel} "
                f"({before_entries[rel]} -> {after_entries[rel]})"
            )
    if len(problems) > _MAX_REPORTED_PATHS:
        extra = len(problems) - _MAX_REPORTED_PATHS
        problems = problems[:_MAX_REPORTED_PATHS]
        problems.append(f"... and {extra} more")
    return problems


def diff_hosting_state(before, after):
    """List of human-readable mutations between two snapshots; [] when clean."""
    problems = []
    if before["shim"] != after["shim"]:
        problems.append(
            f"~/.local/bin/project-guide shim changed: "
            f"{before['shim']} -> {after['shim']}"
        )
    problems.extend(_diff_trees(before["toolchain"], after["toolchain"]))
    return problems
