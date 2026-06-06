# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# pyve_env_spec_helper.py — read §4.0 of the env-dependencies doc (the
# `plan_envs`-authored machine surface) and project each environment to the
# pyve.toml-projectable shape, emitting JSON on stdout for the Bash side.
#
# Story N.az.1 (F4 foundation). Per wizard-env-contract.md §B: §4.0
# "Environment Surface Enumeration" is a single machine-readable YAML block
# (the only machine surface — §4.1's table and §5–§9 prose are human-only).
#
# This helper runs under Pyve's TOOLCHAIN interpreter (resolved by the Bash
# seam via pyve_toolchain_python), which carries PyYAML (provisioned by
# `pyve self install`). It is PERMISSIVE — it does not closed-set-validate
# values; that is F6 (Story N.ba). Missing optional fields are default-filled
# so the projected shape is uniform.
#
# Usage:  python pyve_env_spec_helper.py <env-dependencies-doc-path>
# Output: JSON {"spec_version", "project", "envs": {<name>: {<projected>}}}
# Exit codes:
#   0  success
#   2  doc file not found
#   3  PyYAML not importable (run `pyve self install`)
#   4  no §4.0 YAML block found in the doc
#   5  YAML parse error

import json
import re
import sys

# Exit codes (kept in lockstep with the Bash seam's contract).
EXIT_OK = 0
EXIT_NO_FILE = 2
EXIT_NO_YAML_LIB = 3
EXIT_NO_BLOCK = 4
EXIT_PARSE_ERROR = 5

# The pyve.toml-projectable subset (wizard-env-contract.md §B). app_type,
# require_min_version, manual_steps are advisory and NOT projected here.
_HEADING_4 = re.compile(r"^##\s+4\.")
_HEADING_5 = re.compile(r"^##\s+5\.")
_FENCE_YAML = re.compile(r"^```ya?ml\s*$")
_FENCE_END = re.compile(r"^```\s*$")


def _extract_section4_yaml(text):
    """Return the §4.0 fenced YAML block body, or None if absent.

    Anchored on the `## 4.` section heading so a stray ```yaml fence in an
    earlier section can never be mistaken for the machine surface.
    """
    lines = text.split("\n")
    start = end = None
    for i, line in enumerate(lines):
        if _HEADING_4.match(line):
            start = i
        elif start is not None and _HEADING_5.match(line):
            end = i
            break
    if start is None:
        return None
    region = lines[start:end] if end is not None else lines[start:]

    in_block = False
    buf = []
    for line in region:
        if not in_block:
            if _FENCE_YAML.match(line):
                in_block = True
            continue
        if _FENCE_END.match(line):
            return "\n".join(buf)
        buf.append(line)
    return None


def _project_env(env):
    """Project one env mapping to the uniform pyve.toml-projectable shape.

    Permissive: purpose/backend pass through as-is (None when absent — F6
    validates). The remaining optionals are default-filled.
    """
    if not isinstance(env, dict):
        env = {}
    return {
        "purpose": env.get("purpose"),
        "backend": env.get("backend"),
        "default": bool(env.get("default", False)),
        "path": env.get("path", "."),
        "languages": list(env.get("languages") or []),
        "frameworks": list(env.get("frameworks") or []),
        "packaging": env.get("packaging", "none"),
    }


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: pyve_env_spec_helper.py <doc-path>\n")
        return EXIT_PARSE_ERROR
    path = argv[1]

    try:
        # Deferred import: its absence maps to EXIT_NO_YAML_LIB so the Bash
        # seam can surface a precise "run pyve self install" instead of a
        # raw traceback.
        import yaml
    except ImportError:
        sys.stderr.write(
            "PyYAML is not available in Pyve's toolchain — run 'pyve self install'.\n"
        )
        return EXIT_NO_YAML_LIB

    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except FileNotFoundError:
        sys.stderr.write("env spec not found: {}\n".format(path))
        return EXIT_NO_FILE

    block = _extract_section4_yaml(text)
    if block is None:
        sys.stderr.write(
            "no §4.0 machine-readable YAML block found in {}\n".format(path)
        )
        return EXIT_NO_BLOCK

    try:
        data = yaml.safe_load(block) or {}
    except yaml.YAMLError as exc:
        sys.stderr.write("failed to parse §4.0 YAML: {}\n".format(exc))
        return EXIT_PARSE_ERROR
    if not isinstance(data, dict):
        sys.stderr.write("§4.0 YAML is not a mapping\n")
        return EXIT_PARSE_ERROR

    envs = data.get("envs") or {}
    result = {
        "spec_version": data.get("spec_version"),
        "project": data.get("project"),
        "envs": {name: _project_env(env) for name, env in envs.items()},
    }
    sys.stdout.write(json.dumps(result))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv))
