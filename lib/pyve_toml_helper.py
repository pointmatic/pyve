# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Reads pyve.toml (the v3.0 canonical declarative manifest) and emits
# bash-array-literal declarations. Consumed by lib/manifest.sh via
# `eval "$(... helper.py)"`.
#
# Mirrors lib/pyve_testenvs_helper.py's shape (V3 wire format from
# spike M.f) but reads pyve.toml's [project] + [env.<name>] blocks
# instead of pyproject.toml's [tool.pyve.testenvs] block.
#
# Output shape (parallel indexed arrays keyed by position in
# PYVE_ENV_NAMES). Plain assignment syntax (no `declare`) so eval inside
# a bash function lands in global scope under bash 3.2:
#
#   PYVE_SCHEMA_VERSION="3.0"
#   PYVE_PROJECT_NAME="demo"
#   PYVE_ENV_NAMES=("root" "testenv")
#   PYVE_ENV_PURPOSE=("utility" "test")
#   PYVE_ENV_BACKEND=("venv" "venv")
#   PYVE_ENV_PATH=("." ".")
#   PYVE_ENV_DEFAULT=("0" "1")
#   PYVE_ENV_LAZY=("0" "0")
#   PYVE_ENV_EXTRA=("" "")
#   PYVE_ENV_MANIFEST=("" "")
#   PYVE_ENV_APP_TYPE=("" "")
#   PYVE_ENV_REQUIREMENTS_Q=("" "")
#   PYVE_ENV_FRAMEWORKS_Q=("" "")
#   PYVE_ENV_LANGUAGES_Q=("" "")
#
# Validation errors are batched, printed to stderr with the prefix
# `error: pyve.<key>: <message>`, and the process exits with status 2
# (distinct from operation-failed exit 1).
import shlex
import sys
import tomllib
from pathlib import Path

SCHEMA_VERSION = "3.0"
VALID_PURPOSES = ("run", "test", "utility", "temp")


def _normalize_env(name, decl):
    return {
        "name": name,
        "purpose": decl.get("purpose") or "",
        "backend": decl.get("backend") or "",
        "path": decl.get("path") or ".",
        "default": "1" if bool(decl.get("default", False)) else "0",
        "lazy": "1" if bool(decl.get("lazy", False)) else "0",
        "extra": decl.get("extra") or "",
        "manifest": decl.get("manifest") or "",
        "app_type": decl.get("app_type") or "",
        "requirements": list(decl.get("requirements", [])),
        "frameworks": list(decl.get("frameworks", [])),
        "languages": list(decl.get("languages", [])),
    }


def _empty_cfg():
    return {
        "schema_version": SCHEMA_VERSION,
        "project_name": "",
        "envs": {},
    }


def load(manifest_path):
    if not manifest_path.exists():
        return _empty_cfg()
    with manifest_path.open("rb") as f:
        data = tomllib.load(f)
    schema = data.get("pyve_schema", SCHEMA_VERSION)
    project_name = data.get("project", {}).get("name", "")
    envs = {}
    for name, decl in data.get("env", {}).items():
        if isinstance(decl, dict):
            envs[name] = _normalize_env(name, decl)
    return {
        "schema_version": schema,
        "project_name": project_name,
        "envs": envs,
    }


def validate(cfg):
    errors = []
    if cfg["schema_version"] != SCHEMA_VERSION:
        errors.append(
            f"pyve.pyve_schema: unknown schema version "
            f"'{cfg['schema_version']}' (expected '{SCHEMA_VERSION}')"
        )
    default_envs = []
    for name, env in cfg["envs"].items():
        if env["purpose"] and env["purpose"] not in VALID_PURPOSES:
            errors.append(
                f"pyve.env.{name}.purpose: unknown purpose "
                f"'{env['purpose']}' (expected one of: {list(VALID_PURPOSES)})"
            )
        sources = sum(
            [
                bool(env["requirements"]),
                bool(env["extra"]),
                bool(env["manifest"]),
            ]
        )
        if sources > 1:
            errors.append(
                f"pyve.env.{name}: only one of "
                f"'requirements'/'extra'/'manifest' may be declared"
            )
        if env["default"] == "1":
            default_envs.append(name)
    if len(default_envs) > 1:
        errors.append(
            f"pyve.env: only one env may declare 'default = true' "
            f"(found: {default_envs})"
        )
    return errors


def _quote_array(items):
    if not items:
        return ""
    return " ".join(shlex.quote(str(s)) for s in items)


def emit(cfg, out):
    names = list(cfg["envs"].keys())
    print(f"PYVE_SCHEMA_VERSION={shlex.quote(cfg['schema_version'])}", file=out)
    print(f"PYVE_PROJECT_NAME={shlex.quote(cfg['project_name'])}", file=out)
    print(f"PYVE_ENV_NAMES=({_quote_array(names)})", file=out)
    scalar_fields = [
        ("PYVE_ENV_PURPOSE", "purpose"),
        ("PYVE_ENV_BACKEND", "backend"),
        ("PYVE_ENV_PATH", "path"),
        ("PYVE_ENV_DEFAULT", "default"),
        ("PYVE_ENV_LAZY", "lazy"),
        ("PYVE_ENV_EXTRA", "extra"),
        ("PYVE_ENV_MANIFEST", "manifest"),
        ("PYVE_ENV_APP_TYPE", "app_type"),
    ]
    for var, key in scalar_fields:
        vals = [cfg["envs"][n][key] for n in names]
        print(f"{var}=({_quote_array(vals)})", file=out)
    list_fields = [
        ("PYVE_ENV_REQUIREMENTS_Q", "requirements"),
        ("PYVE_ENV_FRAMEWORKS_Q", "frameworks"),
        ("PYVE_ENV_LANGUAGES_Q", "languages"),
    ]
    for var, key in list_fields:
        vals_q = [_quote_array(cfg["envs"][n][key]) for n in names]
        print(f"{var}=({_quote_array(vals_q)})", file=out)


def main():
    manifest = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("pyve.toml")
    cfg = load(manifest)
    errors = validate(cfg)
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        sys.exit(2)
    emit(cfg, sys.stdout)


if __name__ == "__main__":
    main()
