# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Reads [tool.pyve.testenvs] from a pyproject.toml and emits
# bash-array-literal declarations (V3 wire format from spike M.f).
# Consumed by lib/testenvs.sh via `eval "$(... helper.py)"`.
#
# Spike doc: docs/specs/spike-m-f-testenvs-config.md
#
# Output shape (parallel indexed arrays keyed by position in NAMES).
# Plain assignment syntax (no `declare`) so eval inside a bash function
# lands in global scope under bash 3.2 — which lacks `declare -g`:
#   PYVE_TESTENVS_DEFAULT="testenv"
#   PYVE_TESTENVS_NAMES=("testenv" "hardware")
#   PYVE_TESTENV_BACKEND=("venv" "micromamba")
#   PYVE_TESTENV_LAZY=("0" "1")
#   PYVE_TESTENV_EXTRA=("" "")
#   PYVE_TESTENV_MANIFEST=("" "src/templates/environment.yml")
#   PYVE_TESTENV_REQUIREMENTS_Q=("requirements-dev.txt" "")
#
# Validation errors are batched, printed to stderr with the prefix
# `error: pyve.testenvs.<env>[.<key>]: <message>`, and the process exits
# with status 2 (distinct from operation-failed exit 1).
import shlex
import sys
import tomllib
from pathlib import Path

VALID_BACKENDS = ("venv", "micromamba", "inherit")
RESERVED_NAMES = ("root", "testenv")


def _normalize(name, decl):
    return {
        "name": name,
        "backend": decl.get("backend", "venv"),
        "lazy": "1" if bool(decl.get("lazy", False)) else "0",
        "requirements": list(decl.get("requirements", [])),
        "extra": decl.get("extra") or "",
        "manifest": decl.get("manifest") or "",
    }


def _default_cfg():
    return {
        "default": "testenv",
        "envs": {"testenv": _normalize("testenv", {})},
    }


def load(pyproject):
    if not pyproject.exists():
        return _default_cfg()
    with pyproject.open("rb") as f:
        data = tomllib.load(f)
    block = data.get("tool", {}).get("pyve", {}).get("testenvs", {})
    if not block:
        return _default_cfg()
    default = block.get("default", "testenv")
    envs = {}
    for name, decl in block.items():
        if name == "default" or not isinstance(decl, dict):
            continue
        envs[name] = _normalize(name, decl)
    if "testenv" not in envs:
        envs["testenv"] = _normalize("testenv", {})
    return {"default": default, "envs": envs}


def validate(cfg):
    errors = []
    for name, env in cfg["envs"].items():
        if name == "root":
            errors.append(
                f"pyve.testenvs.{name}: reserved name cannot be redeclared"
            )
        if env["backend"] not in VALID_BACKENDS:
            errors.append(
                f"pyve.testenvs.{name}.backend: unknown backend "
                f"'{env['backend']}' (expected one of: {list(VALID_BACKENDS)})"
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
                f"pyve.testenvs.{name}: only one of "
                f"'requirements'/'extra'/'manifest' may be declared"
            )
        if env["manifest"] and env["backend"] == "venv":
            errors.append(
                f"pyve.testenvs.{name}: 'manifest' requires backend=micromamba or inherit"
            )
    return errors


def _quote_array(items):
    if not items:
        return ""
    return " ".join(shlex.quote(s) for s in items)


def emit(cfg, out):
    names = list(cfg["envs"].keys())
    print(f"PYVE_TESTENVS_DEFAULT={shlex.quote(cfg['default'])}", file=out)
    print(f"PYVE_TESTENVS_NAMES=({_quote_array(names)})", file=out)
    backends = [cfg["envs"][n]["backend"] for n in names]
    lazies = [cfg["envs"][n]["lazy"] for n in names]
    extras = [cfg["envs"][n]["extra"] for n in names]
    manifests = [cfg["envs"][n]["manifest"] for n in names]
    reqs_q = [_quote_array(cfg["envs"][n]["requirements"]) for n in names]
    print(f"PYVE_TESTENV_BACKEND=({_quote_array(backends)})", file=out)
    print(f"PYVE_TESTENV_LAZY=({_quote_array(lazies)})", file=out)
    print(f"PYVE_TESTENV_EXTRA=({_quote_array(extras)})", file=out)
    print(f"PYVE_TESTENV_MANIFEST=({_quote_array(manifests)})", file=out)
    print(
        f"PYVE_TESTENV_REQUIREMENTS_Q=({_quote_array(reqs_q)})",
        file=out,
    )


def main():
    pyproject = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("pyproject.toml")
    cfg = load(pyproject)
    errors = validate(cfg)
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        sys.exit(2)
    emit(cfg, sys.stdout)


if __name__ == "__main__":
    main()
