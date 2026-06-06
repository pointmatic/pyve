# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve_env_sync_helper.py — the engine behind `pyve env sync` (Story N.az.2,
# F4). Computes a STATELESS diff between §4.0 of the env-dependencies doc
# (the `plan_envs`-authored machine surface) and the current `pyve.toml`,
# and applies the reconcile via tomlkit (round-trip-preserving).
#
# `pyve.toml` *is* the baseline — there is no separate state file. The diff
# normalizes BOTH sides through pyve_env_spec_helper's `_project_env`, so
# default-fill never manufactures a spurious diff.
#
# Like its sibling, this runs under Pyve's TOOLCHAIN interpreter (resolved
# by the Bash seam via pyve_toolchain_python), which carries PyYAML AND
# tomlkit (both provisioned by `pyve self install`). It is PERMISSIVE — it
# does not closed-set-validate values; that is F6 (Story N.ba).
#
# Usage:
#   pyve_env_sync_helper.py diff [--human] <spec-doc> <pyve.toml>
#   pyve_env_sync_helper.py apply          <spec-doc> <pyve.toml>
#
# `diff`           — emits JSON {added, changed, dropped, destructive, clean}.
# `diff --human`   — emits a human summary; the EXIT CODE is the verdict the
#                    Bash seam branches on (no JSON parsing in Bash):
#                      0  clean (no changes)
#                     10  non-destructive changes present
#                     11  destructive changes present (drop / backend flip)
# `apply`          — reconciles `pyve.toml` in place (writes config only;
#                    never materializes an env).
#
# Exit codes (shared with the verdict codes above for `diff --human`):
#   0   success / clean
#   2   spec doc not found
#   3   PyYAML or tomlkit not importable (run `pyve self install`)
#   4   no §4.0 YAML block found in the doc
#   5   YAML parse error / usage error
#   6   §4 has an unknown axis value or unrecognized field (F6/N.ba.2)
#  10   diff --human: non-destructive changes
#  11   diff --human: destructive changes

import json
import sys
from pathlib import Path

# Reuse the §4.0 extraction + per-env projection from the spec helper so the
# two surfaces normalize identically (the contract that keeps default-fill
# from inventing diffs). Same directory → plain import resolves when invoked
# as a script (sys.path[0] is lib/).
import pyve_env_spec_helper as spec
import pyve_toml_helper as toml_helper

# Exit / verdict codes (kept in lockstep with pyve_env_spec_helper).
EXIT_OK = 0
EXIT_NO_FILE = 2
EXIT_NO_LIB = 3
EXIT_NO_BLOCK = 4
EXIT_PARSE_ERROR = 5
EXIT_SPEC_INVALID = 6  # F6/N.ba.2: §4 has an unknown value / unrecognized field

VERDICT_CHANGES = 10
VERDICT_DESTRUCTIVE = 11

# Core env keys we (re)write in apply, ordered for stable rendering. Each is
# emitted only when it differs from the natural default — so a round-trip
# back through _project_env reproduces the projected shape exactly.
_DEFAULTS = {
    "purpose": None,
    "backend": None,
    "default": False,
    "path": ".",
    "languages": [],
    "frameworks": [],
    "packaging": "none",
}
_WRITE_ORDER = ("purpose", "backend", "default", "path", "languages", "frameworks", "packaging")


def _load_spec_envs(doc_path):
    """Return ({name: projected}, EXIT_OK) or (None, <error-code>)."""
    import yaml

    try:
        with open(doc_path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except FileNotFoundError:
        sys.stderr.write("env spec not found: {}\n".format(doc_path))
        return None, EXIT_NO_FILE

    block = spec._extract_section4_yaml(text)
    if block is None:
        sys.stderr.write(
            "no §4.0 machine-readable YAML block found in {}\n".format(doc_path)
        )
        return None, EXIT_NO_BLOCK

    try:
        data = yaml.safe_load(block) or {}
    except yaml.YAMLError as exc:
        sys.stderr.write("failed to parse §4.0 YAML: {}\n".format(exc))
        return None, EXIT_PARSE_ERROR
    if not isinstance(data, dict):
        sys.stderr.write("§4.0 YAML is not a mapping\n")
        return None, EXIT_PARSE_ERROR

    envs = data.get("envs") or {}
    # F6/N.ba.2: closed-vocabulary + recognized-field enforcement on the RAW
    # §4 envs (before projection, so app_type and unrecognized fields are in
    # scope). An invalid spec aborts here — diff/apply both propagate the rc,
    # so no pyve.toml write happens on an invalid spec.
    errors = _validate_spec_envs(envs)
    if errors:
        for err in errors:
            sys.stderr.write("error: {}\n".format(err))
        return None, EXIT_SPEC_INVALID
    return {name: spec._project_env(env) for name, env in envs.items()}, EXIT_OK


def _load_toml(toml_path):
    """Return (tomlkit_doc_or_None, {name: projected}).

    An absent pyve.toml is the empty baseline: (None, {}). The doc is kept so
    `apply` can reconcile in place while preserving comments / formatting.
    """
    import tomlkit

    p = Path(toml_path)
    if not p.exists():
        return None, {}
    doc = tomlkit.parse(p.read_text(encoding="utf-8"))
    env_tbl = doc.get("env", {}) or {}
    projected = {}
    for name, decl in env_tbl.items():
        # tomlkit tables behave like dicts; _project_env only .get()s.
        projected[name] = spec._project_env(dict(decl))
    return doc, projected


def _validate_spec_envs(raw_envs):
    """F6/N.ba.2: closed-vocabulary + recognized-field enforcement for §4.

    Replaces the N.az.2 permissive accept-all stub. Operates on the RAW §4
    env mappings (keys are the authored field names). Returns the list of
    error strings; an empty list means "accepted". An unrecognized field or
    an unknown axis value is an error — the caller aborts with
    EXIT_SPEC_INVALID and writes nothing. Shares the value gate with
    pyve.toml validation via pyve_toml_helper.env_value_errors so the
    vocabulary has exactly one enforcement point.
    """
    errors = []
    if not isinstance(raw_envs, dict):
        return errors
    for name, env in raw_envs.items():
        if not isinstance(env, dict):
            continue
        # Unrecognized field → error (spec-side only; pyve.toml keeps its S9
        # provider-private key tolerance).
        for field in env:
            if field not in toml_helper.SPEC_RECOGNIZED_FIELDS:
                errors.append(
                    "env '{}': unrecognized field '{}'".format(name, field)
                )
        errors.extend(toml_helper.env_value_errors(name, env))
    return errors


def _compute_diff(spec_envs, toml_envs):
    """Stateless diff between the (already-projected) spec and toml env sets."""
    added = {n: spec_envs[n] for n in spec_envs if n not in toml_envs}
    dropped = {n: toml_envs[n] for n in toml_envs if n not in spec_envs}

    changed = {}
    for n in spec_envs:
        if n not in toml_envs:
            continue
        s, t = spec_envs[n], toml_envs[n]
        if s == t:
            continue
        changed[n] = {k: [t.get(k), s[k]] for k in s if s[k] != t.get(k)}

    # A backend FLIP (concrete → different concrete) implies an on-disk
    # rebuild; adding a backend where none was declared does not.
    backend_flip = any(
        "backend" in f and f["backend"][0] and f["backend"][1]
        and f["backend"][0] != f["backend"][1]
        for f in changed.values()
    )
    destructive = bool(dropped) or backend_flip

    return {
        "added": added,
        "changed": changed,
        "dropped": dropped,
        "destructive": destructive,
        "clean": not (added or changed or dropped),
    }


def _render_human(d, out):
    if d["clean"]:
        out.write("Environments are in sync with the spec — nothing to apply.\n")
        return
    out.write("Environment changes vs the spec:\n")
    for name, env in d["added"].items():
        out.write(
            "  + {}  (add: purpose={}, backend={})\n".format(
                name, env["purpose"], env["backend"]
            )
        )
    for name, fields in d["changed"].items():
        parts = ", ".join(
            "{}: {!r} -> {!r}".format(k, old, new) for k, (old, new) in fields.items()
        )
        out.write("  ~ {}  ({})\n".format(name, parts))
    for name in d["dropped"]:
        out.write("  - {}  (drop)\n".format(name))
    if d["destructive"]:
        out.write(
            "\n  ! destructive: drops an env and/or flips a backend "
            "(an on-disk rebuild is implied)\n"
        )


def _set_or_clear(table, key, value):
    """Set table[key]=value, or delete the key when value is its default."""
    if value == _DEFAULTS[key]:
        if key in table:
            del table[key]
        return
    table[key] = value


def _write_env_table(env_tbl, name, projected):
    import tomlkit

    existing = env_tbl.get(name)
    if existing is None:
        existing = tomlkit.table()
        env_tbl[name] = existing
    for key in _WRITE_ORDER:
        _set_or_clear(existing, key, projected[key])


def _apply(spec_envs, doc, toml_path):
    import tomlkit

    if doc is None:
        doc = tomlkit.document()
    if "env" not in doc:
        # A super-table so sub-envs render as `[env.<name>]` headers rather
        # than an inline `env = {…}` (verified empirically — N.az.2).
        doc["env"] = tomlkit.table(is_super_table=True)
    env_tbl = doc["env"]

    for name, projected in spec_envs.items():
        _write_env_table(env_tbl, name, projected)
    # Drop envs absent from the spec.
    for name in list(env_tbl.keys()):
        if name not in spec_envs:
            del env_tbl[name]

    Path(toml_path).write_text(tomlkit.dumps(doc), encoding="utf-8")


def _cmd_diff(spec_path, toml_path, human):
    # _load_spec_envs runs the F6 closed-vocabulary gate before projecting;
    # an invalid spec returns EXIT_SPEC_INVALID and we abort here.
    spec_envs, rc = _load_spec_envs(spec_path)
    if rc != EXIT_OK:
        return rc
    _, toml_envs = _load_toml(toml_path)
    d = _compute_diff(spec_envs, toml_envs)

    if human:
        _render_human(d, sys.stdout)
        if d["clean"]:
            return EXIT_OK
        return VERDICT_DESTRUCTIVE if d["destructive"] else VERDICT_CHANGES

    sys.stdout.write(json.dumps(d))
    return EXIT_OK


def _cmd_apply(spec_path, toml_path):
    # _load_spec_envs runs the F6 closed-vocabulary gate before projecting;
    # an invalid spec returns EXIT_SPEC_INVALID → no write happens.
    spec_envs, rc = _load_spec_envs(spec_path)
    if rc != EXIT_OK:
        return rc
    doc, _ = _load_toml(toml_path)
    _apply(spec_envs, doc, toml_path)
    return EXIT_OK


def _usage():
    sys.stderr.write(
        "usage: pyve_env_sync_helper.py diff [--human] <spec-doc> <pyve.toml>\n"
        "       pyve_env_sync_helper.py apply <spec-doc> <pyve.toml>\n"
    )
    return EXIT_PARSE_ERROR


def main(argv):
    if len(argv) < 2:
        return _usage()

    # Deferred imports: a missing PyYAML/tomlkit maps to EXIT_NO_LIB so the
    # Bash seam surfaces a precise "run pyve self install" — not a traceback.
    try:
        import yaml  # noqa: F401
        import tomlkit  # noqa: F401
    except ImportError:
        sys.stderr.write(
            "PyYAML and tomlkit are required in Pyve's toolchain — "
            "run 'pyve self install'.\n"
        )
        return EXIT_NO_LIB

    cmd = argv[1]
    if cmd == "diff":
        args = argv[2:]
        human = False
        if args and args[0] == "--human":
            human = True
            args = args[1:]
        if len(args) != 2:
            return _usage()
        return _cmd_diff(args[0], args[1], human)
    if cmd == "apply":
        if len(argv) != 4:
            return _usage()
        return _cmd_apply(argv[2], argv[3])
    return _usage()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
