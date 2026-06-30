# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve_manifest_write.py — structure-preserving in-place edits to pyve.toml.
#
# The companion writer to lib/pyve_toml_helper.py (which is read-only: it parses
# pyve.toml via tomllib and emits bash-variable assignments). This file owns the
# few cases where `pyve` must mutate an *existing* manifest while keeping the
# rest of the document — comments, key order, provider-private keys, other env
# blocks — byte-for-byte intact. That is what tomlkit gives us and tomllib does
# not; the same dependency the env-sync writer (lib/pyve_env_sync_helper.py)
# already relies on.
#
# Subcommand:
#   set-env-attr <manifest> <env> <key> <value>
#       Set [env.<env>].<key> = "<value>" in <manifest>, creating the table
#       when absent. Idempotent (a no-op rewrite when the value already matches,
#       so the file's mtime/content is left untouched). Scalar string values
#       only — the one caller today writes the root env's backend.
#
# Exit codes:
#   0  — written (or already correct: no change needed)
#   2  — usage / argument error
#   3  — tomlkit unavailable (the caller degrades gracefully: the value still
#        rides `.pyve/config` during the v3.0 read-compat window)
#   4  — manifest does not exist (callers that require it treat this as fatal;
#        the init wrapper pre-checks existence, so it should not hit this)

import sys
from pathlib import Path

EXIT_OK = 0
EXIT_USAGE = 2
EXIT_NO_TOMLKIT = 3
EXIT_NO_MANIFEST = 4


def _set_env_attr(manifest, env, key, value):
    try:
        import tomlkit
    except ImportError:
        sys.stderr.write("pyve_manifest_write: tomlkit unavailable\n")
        return EXIT_NO_TOMLKIT

    path = Path(manifest)
    if not path.exists():
        sys.stderr.write(f"pyve_manifest_write: {manifest} does not exist\n")
        return EXIT_NO_MANIFEST

    doc = tomlkit.parse(path.read_text(encoding="utf-8"))

    env_tbl = doc.get("env")
    if env_tbl is None:
        # A super-table so sub-envs render as `[env.<name>]` headers rather than
        # an inline `env = {…}` table (the shape the env-sync writer also uses).
        env_tbl = tomlkit.table(is_super_table=True)
        doc["env"] = env_tbl

    block = env_tbl.get(env)
    if block is None:
        block = tomlkit.table()
        env_tbl[env] = block

    if block.get(key) == value:
        return EXIT_OK  # already correct — leave the file untouched

    block[key] = value
    path.write_text(tomlkit.dumps(doc), encoding="utf-8")
    return EXIT_OK


def main(argv):
    if len(argv) >= 1 and argv[0] == "set-env-attr":
        if len(argv) != 5:
            sys.stderr.write(
                "usage: pyve_manifest_write.py set-env-attr "
                "<manifest> <env> <key> <value>\n"
            )
            return EXIT_USAGE
        return _set_env_attr(argv[1], argv[2], argv[3], argv[4])
    sys.stderr.write("pyve_manifest_write: unknown subcommand\n")
    return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
