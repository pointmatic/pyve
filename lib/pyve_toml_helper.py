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

#============================================================
# F6 (Story N.ba.1): the Pyve-owned closed vocabulary.
#
# Machine mirror of the enumeration published in
# docs/specs/project-guide-requests/env-dependencies-template.md §2 and
# reproduced in wizard-env-contract.md §B. Each axis is a CLOSED set
# partitioned into two classes:
#   implemented — pyve has a real integration that acts on it today.
#   advisory    — recognized + surfaced in check/status, never materialized,
#                 never an error (the trichotomy's "known + no-op" class).
# A value outside both → unknown → hard error (enforced in N.ba.2).
#
# `none` is the not-applicable value; it lives in the ADVISORY column of
# every none-bearing axis (per the contract table), exactly as the docs list
# it — surfacing policy (N.ba.3) decides not to print it, but classification
# stays faithful to the vocabulary.
#
# LOCKSTEP: tests/unit/test_n_ba_1_vocabulary.bats parses the contract §B
# table and fails the build if these sets drift from the docs. Edit one and
# the other together — never independently.
#============================================================

# backend — the environment-management mechanism (S6 categories below).
BACKENDS_IMPLEMENTED = ("venv", "micromamba", "pnpm", "npm", "yarn")
BACKENDS_ADVISORY = (
    # project-virtualized (advisory)
    "uv", "poetry", "conda", "bun", "deno",
    # cache-backed (all advisory; xcode/swiftpm/android_sdk are cache-backed
    # per S16 — the un-installable-toolchain fact rides require_min_version)
    "cargo", "go", "bundler", "swiftpm", "xcode", "android_sdk",
    "gradle", "maven", "sbt", "dotnet", "conan", "cmake",
    # check-only / special (all advisory)
    "homebrew", "apt", "docker", "podman", "none",
)

LANGUAGES_IMPLEMENTED = ("python", "javascript", "typescript")
LANGUAGES_ADVISORY = (
    "bash", "c", "cpp", "c_sharp", "java", "kotlin", "scala", "go",
    "swift", "objective_c", "rust", "ruby",
)

# frameworks — intrinsic kind (app/test/lint) in FRAMEWORK_KIND below.
FRAMEWORKS_IMPLEMENTED = ("sveltekit",)
FRAMEWORKS_ADVISORY = (
    # app
    "flask", "fastapi", "django", "react", "vue", "jupyter", "marimo",
    "spring", "j2ee", "kotlin_multiplatform", "rails", "sinatra",
    "swiftui", "uikit",
    # test
    "pytest", "vitest", "jest", "mocha", "playwright", "cypress", "bats",
    "rspec", "minitest", "xctest", "junit",
    # lint
    "ruff", "mypy", "black", "isort", "flake8", "pylint", "eslint",
    "prettier", "shellcheck", "shfmt", "ktlint", "detekt", "scalafmt",
    "scalafix", "google_java_format", "rustfmt", "clippy", "gofmt",
    "golangci_lint", "rubocop", "swiftlint", "swiftformat",
    "clang_format", "clang_tidy",
    # special
    "none",
)

PACKAGING_IMPLEMENTED = ()
PACKAGING_ADVISORY = (
    "container", "static", "server", "serverless", "package", "binary",
    "mobile_app", "lock_bundle", "none",
)

APP_TYPES_IMPLEMENTED = ()
APP_TYPES_ADVISORY = (
    "api", "cli", "service", "library", "desktop", "mobile",
    "embedded", "script", "web", "none",
)

# Derived unions — the closed set per axis (implemented ∪ advisory).
VALID_BACKENDS = BACKENDS_IMPLEMENTED + BACKENDS_ADVISORY
VALID_LANGUAGES = LANGUAGES_IMPLEMENTED + LANGUAGES_ADVISORY
VALID_FRAMEWORKS = FRAMEWORKS_IMPLEMENTED + FRAMEWORKS_ADVISORY
VALID_PACKAGING = PACKAGING_IMPLEMENTED + PACKAGING_ADVISORY
VALID_APP_TYPES = APP_TYPES_IMPLEMENTED + APP_TYPES_ADVISORY

# Per-axis (implemented, advisory) partition — the single source the
# classifier and the lockstep test read.
_AXES = {
    "purpose": (VALID_PURPOSES, ()),
    "backend": (BACKENDS_IMPLEMENTED, BACKENDS_ADVISORY),
    "languages": (LANGUAGES_IMPLEMENTED, LANGUAGES_ADVISORY),
    "frameworks": (FRAMEWORKS_IMPLEMENTED, FRAMEWORKS_ADVISORY),
    "packaging": (PACKAGING_IMPLEMENTED, PACKAGING_ADVISORY),
    "app_type": (APP_TYPES_IMPLEMENTED, APP_TYPES_ADVISORY),
}

# Framework → intrinsic kind (app / test / lint), looked up, never an
# authoring choice (S14). `none` = no framework activation.
FRAMEWORK_KIND = {}
for _fw in ("sveltekit", "flask", "fastapi", "django", "react", "vue",
            "jupyter", "marimo", "spring", "j2ee", "kotlin_multiplatform",
            "rails", "sinatra", "swiftui", "uikit"):
    FRAMEWORK_KIND[_fw] = "app"
for _fw in ("pytest", "vitest", "jest", "mocha", "playwright", "cypress",
            "bats", "rspec", "minitest", "xctest", "junit"):
    FRAMEWORK_KIND[_fw] = "test"
for _fw in ("ruff", "mypy", "black", "isort", "flake8", "pylint", "eslint",
            "prettier", "shellcheck", "shfmt", "ktlint", "detekt", "scalafmt",
            "scalafix", "google_java_format", "rustfmt", "clippy", "gofmt",
            "golangci_lint", "rubocop", "swiftlint", "swiftformat",
            "clang_format", "clang_tidy"):
    FRAMEWORK_KIND[_fw] = "lint"
FRAMEWORK_KIND["none"] = "none"

# Backend → S6 category, for advisory messaging (N.ba.3).
BACKEND_CATEGORY = {}
for _b in ("venv", "micromamba", "pnpm", "npm", "yarn", "uv", "poetry",
           "conda", "bun", "deno"):
    BACKEND_CATEGORY[_b] = "project-virtualized"
for _b in ("cargo", "go", "bundler", "swiftpm", "xcode", "android_sdk",
           "gradle", "maven", "sbt", "dotnet", "conan", "cmake"):
    BACKEND_CATEGORY[_b] = "cache-backed"
for _b in ("homebrew", "apt", "docker", "podman"):
    BACKEND_CATEGORY[_b] = "check-only"
BACKEND_CATEGORY["none"] = "special"


def classify_value(axis, value):
    """Return 'implemented' | 'advisory' | 'unknown' for a value on an axis.

    The single classifier the F6 enforcement (N.ba.2) and advisory surfacing
    (N.ba.3) both consult. An unrecognized axis classifies everything as
    'unknown'.
    """
    implemented, advisory = _AXES.get(axis, ((), ()))
    if value in implemented:
        return "implemented"
    if value in advisory:
        return "advisory"
    return "unknown"

# Core `[env.<name>]` keys interpreted by pyve. Every other key is
# packaging-/backend-provider-private (spike S9): core stores it but
# never interprets it, and it round-trips through the manifest unchanged
# into the per-env attr space. `packaging` (S15) is core — it has a
# dedicated accessor read by `pyve package`; provider-private fields like
# `dockerfile` are NOT core.
KNOWN_ENV_KEYS = frozenset(
    {
        "purpose",
        "backend",
        "path",
        "default",
        "lazy",
        "extra",
        "manifest",
        "app_type",
        "packaging",
        "requirements",
        "frameworks",
        "languages",
        "manual_steps",
    }
)


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
        # S15: `packaging` is a core scalar read by `pyve package`. v3.0
        # reads it leniently — closed-set validation is F6 in N-6.
        "packaging": decl.get("packaging") or "",
        "requirements": list(decl.get("requirements", [])),
        "frameworks": list(decl.get("frameworks", [])),
        "languages": list(decl.get("languages", [])),
        # S7: manual_steps is an advisory list. v3.0 surfaces it in
        # `pyve check` / `pyve status`; no automated execution.
        "manual_steps": list(decl.get("manual_steps", [])),
        # S9: packaging-/backend-provider-private keys (e.g. `dockerfile`)
        # are preserved as-is. Core never interprets them; they exist so a
        # provider's `package` hook can read its own config from
        # `[env.<name>]`.
        "attrs": {k: v for k, v in decl.items() if k not in KNOWN_ENV_KEYS},
    }


def _empty_cfg():
    return {
        "schema_version": SCHEMA_VERSION,
        "project_name": "",
        "envs": {},
        "plugins": {},
    }


def _normalize_plugin(name, decl):
    # Per spike S3: the only core schema key is `path` (default ".").
    # Per S9: every other key is provider-private and preserved as-is.
    # The `role` field was explicitly rejected by the spike and must
    # not be added here.
    path = decl.get("path") or "."
    attrs = {k: v for k, v in decl.items() if k != "path"}
    return {"name": name, "path": path, "attrs": attrs}


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
    plugins = {}
    for name, decl in data.get("plugins", {}).items():
        if isinstance(decl, dict):
            plugins[name] = _normalize_plugin(name, decl)
    return {
        "schema_version": schema,
        "project_name": project_name,
        "envs": envs,
        "plugins": plugins,
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
        # Story N.aq (S15): packaging artifact kind, read by `pyve package`.
        ("PYVE_ENV_PACKAGING", "packaging"),
    ]
    for var, key in scalar_fields:
        vals = [cfg["envs"][n][key] for n in names]
        print(f"{var}=({_quote_array(vals)})", file=out)
    list_fields = [
        ("PYVE_ENV_REQUIREMENTS_Q", "requirements"),
        ("PYVE_ENV_FRAMEWORKS_Q", "frameworks"),
        ("PYVE_ENV_LANGUAGES_Q", "languages"),
        # S7 (Story N.p): manual_steps advisory list.
        ("PYVE_ENV_MANUAL_STEPS_Q", "manual_steps"),
    ]
    for var, key in list_fields:
        vals_q = [_quote_array(cfg["envs"][n][key]) for n in names]
        print(f"{var}=({_quote_array(vals_q)})", file=out)
    # Story N.aq (S9): per-env packaging-/backend-provider-private attrs.
    # Same per-index-array shape as the plugin attrs below: each attr is a
    # single "key=value" entry so manifest_get_env_attr can iterate without
    # bash-4 associative arrays. Core stores these but never interprets them.
    for idx, name in enumerate(names):
        attrs = cfg["envs"][name].get("attrs", {})
        pairs = [f"{k}={v}" for k, v in attrs.items()]
        print(f"PYVE_ENV_{idx}_ATTRS=({_quote_array(pairs)})", file=out)
    # Plugins (Story N.k): per-plugin attrs are exposed as per-index
    # arrays so manifest_get_plugin_attr can iterate without resorting
    # to bash-4 associative arrays.
    plugin_names = list(cfg.get("plugins", {}).keys())
    print(f"PYVE_PLUGIN_NAMES=({_quote_array(plugin_names)})", file=out)
    plugin_paths = [cfg["plugins"][n]["path"] for n in plugin_names]
    print(f"PYVE_PLUGIN_PATHS=({_quote_array(plugin_paths)})", file=out)
    for idx, name in enumerate(plugin_names):
        attrs = cfg["plugins"][name].get("attrs", {})
        # Encode each attr as a single "key=value" entry. TOML keys are
        # ASCII identifier-safe; values are stringified.
        pairs = [f"{k}={v}" for k, v in attrs.items()]
        print(f"PYVE_PLUGIN_{idx}_ATTRS=({_quote_array(pairs)})", file=out)


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
