# Spike M.f — `[tool.pyve.testenvs]` config schema & reader pattern

**Type:** Architectural spike (no production code).
**Story:** [M.f](stories.md#story-mf-testenv-dx-architectural-spike) in the Phase M testenv-DX bundle.
**Sketches:** [tmp/spike-testenvs/](../../tmp/spike-testenvs/) (throwaway).
**Drafted:** 2026-05-30.
**Reader audience:** M.g implementer (will lift these decisions into `lib/testenvs.sh` + tests).

The plan doc [phase-m-testenv-dx-plan.md](phase-m-testenv-dx-plan.md) names `[tool.pyve.testenvs]` in `pyproject.toml` as the canonical config surface and pins a Python tomllib helper as the read mechanism. This spike resolves the **five concrete open questions** that affect every downstream M.g+ story:

1. Schema shape — confirmed against UC1–UC6.
2. TOML reader invocation pattern.
3. Output format from the helper (JSON+jq / shell `key=value` / bash-array-literal).
4. Validation locus + error-message shape.
5. Missing-config implicit-default behavior.

---

## TL;DR — decisions

| # | Decision | Why |
|---|---|---|
| 1 | Schema as below; reserved names `root` and `testenv`; `testenv` redeclarable, `root` not. | Covers UC1–UC6 with a flat `[tool.pyve.testenvs.<name>]` table; `root` is global-not-a-testenv (FR-M.5), `testenv` is the well-known default. |
| 2 | **Python tomllib helper** invoked once per `pyve` command via `python -c`-style `lib/testenvs/read_config.py`. No caching. | Cold-start measured ~60 ms; pyve's Python-startup floor is ~44 ms; the 30 ms threshold from the story body is **below pyve's existing baseline**. One-time cost is invisible against any pyve command's ambient cost. |
| 3 | **V3 — bash-array-literal `eval`'d output.** Parallel indexed arrays keyed by position in `PYVE_TESTENVS_NAMES`. Bash-3.2-safe. | V1 (JSON+jq) adds a `jq` dependency pyve has not previously required and multiplies subprocess count per field. V2 (`key=value`) requires hyphen-to-underscore slot-name sanitization in two places (helper + every consumer) — a real footgun. V3 has the same parse cost, no extra dependency, no name sanitization, native bash idioms for the consumer. |
| 4 | Validate in the Python helper. Errors prefixed `error: pyve.testenvs.<env>[.<key>]: <message>`. Helper batches all errors per invocation, exits **2**. Tests assert on prefix + substring, not full strings. | Multi-rule cross-checks (manifest⊕requirements, manifest-requires-conda) are awkward in bash and cleanly expressible in Python. Exit 2 distinguishes "config invalid" from "operation failed" (1). |
| 5 | Missing `pyproject.toml` **or** missing `[tool.pyve.testenvs]` block → implicit `{default: "testenv", envs: {testenv: {backend: "venv"}}}`. Resolver returns this synthesized config; downstream code never special-cases "missing". | FR-M.4: light default preserved; pure-Python projects pay zero ceremony. Synthesized config makes the no-config path use the same code paths as the explicit-config path. |

The rest of this doc walks each decision with the spike evidence behind it.

---

## Decision 1 — Schema shape

```toml
[tool.pyve.testenvs]
default = "testenv"        # optional; the env used by `pyve test` with no --env. Defaults to "testenv".

[tool.pyve.testenvs.<name>]
backend = "venv"           # optional; "venv" (default), "micromamba", or "inherit"
requirements = ["a.txt", "b.txt"]   # optional; venv-backed only
extra = "dev"              # optional; venv-backed only; pyproject [project.optional-dependencies].dev
manifest = "environment.yml"        # optional; conda-backed only
lazy = false               # optional; default false. lazy envs skipped by bulk install.
```

**Reserved names:**

- `root` — the project's main `.venv/` (or conda env). **Cannot be redeclared.** Selection only: `pyve test --env root` routes to the main env (the M.e form). It is *not* a testenv and has no `[tool.pyve.testenvs.root]` table.
- `testenv` — the well-known default testenv at `.pyve/testenvs/testenv/venv/` (or conda equivalent). **May be redeclared** — declaring `[tool.pyve.testenvs.testenv]` overrides its defaults (e.g. to add `requirements`, switch backend). If undeclared, exists implicitly with `backend = "venv"` and no manifest source.

**Validated against UC1–UC6** (fixtures under [tmp/spike-testenvs/fixtures/](../../tmp/spike-testenvs/fixtures/)):

| UC | Fixture | Schema fit |
|---|---|---|
| UC1 (heavy hardware + light) | `uc1-nbfoundry.toml` | `testenv` (light) + `hardware` (`backend=micromamba`, `manifest=…`, `lazy=true`). |
| UC2 (conda parity) | `uc2-conda-parity.toml` | `testenv` (`backend=inherit`, `manifest=…`). |
| UC3 (conda-only native deps) | `uc3-conda-native.toml` | `testenv` (venv) + `geospatial` (micromamba). |
| UC4 (anti-drift bundled manifest) | `uc4-bundled-manifest.toml` | `smoke` env points at the shipped `environment.yml` — same-file (FR-M.7). |
| UC5 (polyglot) | — | Out of scope per the plan doc; schema does not preclude (open `backend` value). |
| UC6 (matrix) | `uc6-matrix-extras.toml` | Three envs with three different `extra =` extras; matrix executor (M.r) iterates them. |

**Non-schema constraints** (validated in helper, not by TOML schema):

- `requirements` / `extra` / `manifest` are **mutually exclusive** per env. `error: pyve.testenvs.<env>: only one of 'requirements'/'extra'/'manifest' may be declared`.
- `manifest` requires `backend ∈ {micromamba, inherit}` — venv cannot consume `environment.yml`. `error: pyve.testenvs.<env>: 'manifest' requires backend=micromamba or inherit`.
- `backend` value must be in `{venv, micromamba, inherit}`. `error: pyve.testenvs.<env>.backend: unknown backend 'X' (expected one of: ['inherit', 'micromamba', 'venv'])`.
- Reserved-name violation: `[tool.pyve.testenvs.root]` is an error. `error: pyve.testenvs.root: reserved name cannot be redeclared`.

**Out of schema by design:**

- No `python_version` per env. Backend chooses Python; the M.g `inherit` resolver pulls main-env Python for `backend=inherit`.
- No `tests = [...]` glob block. The FR-M.8 silent-skip advisory uses M.c's "does the env have pytest importable" probe, not declared globs (which would be a separate design choice).
- No conda-channel pinning per env. Channels live in the `environment.yml` (the canonical conda mechanism). `pyve lock --env <name>` (M.q) handles lockfile generation.

---

## Decision 2 — TOML reader invocation pattern

**Mechanism.** Python helper at `lib/testenvs/read_config.py` invoked via subprocess from `lib/testenvs.sh`. Pyve already requires Python (≥3.11 — pyve's venv-creation path uses `python -m venv`, and `tomllib` is stdlib from 3.11). The helper imports `tomllib`, normalizes the schema, validates, and emits the chosen output format (Decision 3) to stdout.

**Invocation.** One subprocess per `pyve` command: `lib/testenvs.sh` `read_testenv_config` calls the helper at most once and caches the result in shell variables for the lifetime of the command. Downstream consumers (`testenv_init`, `test_tests`, `lock_environment`) read those variables — no second subprocess.

**Caching policy: skip.**

The story body proposed a 30 ms threshold for "skip caching." Measured cold-start (20 iterations, [tmp/spike-testenvs/bench.sh](../../tmp/spike-testenvs/bench.sh)):

```
V1 JSON+jq           mean   65 ms
V2 key=value         mean   64 ms
V3 array-literal     mean   60 ms
V1 helper only       mean   64 ms
python -c noop       mean   44 ms     <-- pyve's existing Python-startup floor
```

The 30 ms threshold is **below pyve's Python-startup floor** of ~44 ms. Any pyve command that touches Python — `pyve init`, `pyve check`, etc. — already pays this cost. The helper's marginal cost is ~16 ms (60 - 44), invisible against the ambient cost of a typical pyve command (filesystem I/O, possibly pip/conda calls measured in seconds).

Caching would add:

- Cache file location (`.pyve/.testenvs-cache`).
- Invalidation logic (mtime of `pyproject.toml` vs. cache mtime).
- Concurrency races during write.
- "What if cache is stale" support code.
- A new code path for the M.g+ implementer to debug.

For 16 ms of marginal savings, this is not a good trade. **Decision: no caching.** If a future profiling pass surfaces a hot path that re-reads the config many times per command, revisit — but until then, the single-subprocess-per-command pattern is sufficient and the simplest possible mechanism.

---

## Decision 3 — Output format

Three sketches under [tmp/spike-testenvs/](../../tmp/spike-testenvs/): V1 `v1-json/`, V2 `v2-keyval/`, V3 `v3-array/`. Each helper consumes the same fixtures and emits the same logical content in a different wire format.

### V1 — JSON to stdout, parsed in bash via `jq`

```bash
JSON="$(python read_config.py pyproject.toml)"
backend="$(jq -r '.envs.testenv.backend' <<<"$JSON")"
mapfile -t reqs < <(jq -r '.envs.testenv.requirements[]' <<<"$JSON")
```

**Pros:** structured data with a real schema; future-proof (nested structures land naturally); jq is ubiquitous on macOS/Linux.

**Cons:** **`jq` is not currently a pyve dependency.** Adding a hard-dep on jq for every `pyve test` / `pyve testenv` invocation expands pyve's bootstrap surface meaningfully (bootstrap docs, install docs, CI matrix). Each field-read spawns a `jq` subprocess (~10–30 ms each); reading five fields per env across many envs accumulates. The convenience is real, but the dependency cost is structural.

### V2 — Shell `key=value` lines (sourced)

```bash
KV="$(python read_config.py pyproject.toml)"
eval "$KV"
backend="$PYVE_TESTENV__testenv__backend"
eval "reqs=( $PYVE_TESTENV__testenv__requirements_q )"
```

**Pros:** zero new dependencies; sourced once; direct variable lookup.

**Cons:** **hyphenated env names need slot-name sanitization** (`name="my-env"` → variable `PYVE_TESTENV__my_env__backend`). The mapping logic has to live in *every* consumer (or in a helper that wraps every lookup), and the moment a consumer forgets, the field-read silently returns the wrong env's value or an unbound variable. The spike's V2 consumer demonstrates this is non-trivial — and the schema does allow hyphens in env names (no reason to forbid them). This is a real footgun.

### V3 — Bash-array-literal declarations (eval'd)

```bash
eval "$(python read_config.py pyproject.toml)"
# After eval: PYVE_TESTENVS_NAMES, PYVE_TESTENV_BACKEND, PYVE_TESTENV_LAZY, etc.
i=0
name="${PYVE_TESTENVS_NAMES[$i]}"
backend="${PYVE_TESTENV_BACKEND[$i]}"
eval "reqs=( ${PYVE_TESTENV_REQUIREMENTS_Q[$i]} )"
```

Parallel indexed arrays keyed by position in `PYVE_TESTENVS_NAMES`. Bash 3.2 supports `declare -a` (it does **not** support associative arrays `declare -A`, which only arrived in 4.0 — hence parallel indexed arrays rather than a single `declare -A PYVE_TESTENV_BACKEND_BY_NAME`).

**Pros:**

- No new dependencies (no jq).
- No name-to-slot sanitization (env names live in `PYVE_TESTENVS_NAMES` and are read directly — no transformation).
- Native bash idioms for the consumer; no indirect `${!var_name}` lookup.
- Cold-start measured fastest of the three (60 ms vs 64–65 ms).
- Lookup by name is `i = index_of(name)` + `${array[$i]}` — explicit, predictable, debug-friendly.

**Cons:**

- Index-of-name lookup needs a small helper function (`_testenvs_name_to_index`). Trivial: linear scan over `PYVE_TESTENVS_NAMES`, returns 0-based index.
- Adding a new field requires emitting a new parallel array. M.g+ stories that grow the schema land 2-line changes in the helper + a new field accessor in `lib/testenvs.sh`.

### Pick: V3 with one paragraph of rationale

V3 wins on dependencies (no jq), on name-handling robustness (no slot sanitization), on cold-start cost (fastest), and on consumer ergonomics (native arrays, no indirect lookup). V1 would win if pyve grew complex nested schemas, but the testenv config is intentionally flat per env — five scalar fields plus one list field — and the index-of-name pattern handles that flatness cleanly. V2 is rejected on the hyphen footgun alone. **V3 is the canonical pattern. M.g implements `lib/testenvs.sh` against the V3 wire format documented above.**

---

## Decision 4 — Validation & error UX

**Locus: validate in the Python helper.** Two reasons:

1. The cross-rule checks (`manifest ⊕ requirements ⊕ extra`, `manifest requires conda backend`) are pleasant in Python and ugly in bash. Re-implementing them in shell would multiply the surface for "validation in helper vs. in shell drifts apart" bugs.
2. Pyve always invokes the helper anyway to *read* the config. Adding "validate after read" in bash duplicates work and adds a second locus to keep correct.

**What the helper does not validate:** filesystem state. The helper checks that the *schema* is valid — `requirements = ["requirements-dev.txt"]` is a well-formed declaration — but does **not** check that `requirements-dev.txt` exists on disk. That's the concern of `pyve testenv install <name>`, which already has the cleanest place to surface "manifest not found" errors with context (it's the consumer that needs to read the file). Validating filesystem in the read path means every `pyve test` / `pyve testenv list` invocation pays disk I/O for paths it doesn't need to touch.

**Error-message shape.** The helper batches every error per invocation, prints each on its own line to **stderr**, and exits with status **2** (distinct from operation-failed exit 1). Each line uses a stable prefix:

```
error: pyve.testenvs.<env>[.<key>]: <message>
```

Examples (verified in the spike):

```
error: pyve.testenvs.broken-env: only one of 'requirements'/'extra'/'manifest' may be declared
error: pyve.testenvs.broken-env: 'manifest' requires backend=micromamba or inherit
error: pyve.testenvs.root: reserved name cannot be redeclared
error: pyve.testenvs.broken-env.backend: unknown backend 'uv' (expected one of: ['inherit', 'micromamba', 'venv'])
```

The TOML-path prefix maps directly to the user's edit location — they can grep for `pyve.testenvs.broken-env` in `pyproject.toml` and find the offending table.

**Pinned-message contract: no.** Tests assert on the **prefix** (`error: pyve.testenvs.<env>`) plus a **substring** capturing the rule violated (`"unknown backend"`, `"reserved name"`, `"only one of"`, `"requires backend"`). The exact wording stays editable across releases without breaking the test suite — important because the M.k–M.m stories will likely refine these messages as new rules land.

**Multiple errors per invocation: yes.** The helper does not stop at the first error; it collects all and prints all. Users get a single fix cycle to resolve every validation problem in the file rather than fixing one, re-running, fixing the next, re-running. M.g should preserve this batching.

---

## Decision 5 — Missing-config implicit-default behavior

**Confirmed: synthesize the default config, do not branch.** When `pyproject.toml` is absent **or** the `[tool.pyve.testenvs]` block is absent, the helper returns:

```python
{
  "default": "testenv",
  "envs": {
    "testenv": {
      "name": "testenv",
      "backend": "venv",
      "lazy": False,
      "requirements": [],
      "extra": None,
      "manifest": None,
    }
  }
}
```

Downstream code never special-cases "no config." `pyve test` looks up `default → testenv`, resolves to `.pyve/testenvs/testenv/venv/`, and runs. `pyve testenv install` (no name) installs the one env, fetching from `requirements-dev.txt` if it exists (the existing FR-M.4 light-default behavior).

**`testenv` is always present in the synthesized envs.** Even if a user declares `[tool.pyve.testenvs.foo]` and `[tool.pyve.testenvs.bar]` but no explicit `[tool.pyve.testenvs.testenv]`, the helper injects a default `testenv` entry so `pyve test` (no `--env`) keeps working. If the user *does* declare `[tool.pyve.testenvs.testenv]`, their declaration overrides the default.

**The reserved `root` selector** is handled in [lib/commands/test.sh](../../lib/commands/test.sh)'s arg parser, not by the helper — `--env root` short-circuits to "delegate to `run_command python -m pytest`" before any `[tool.pyve.testenvs]` lookup. It is not a member of the synthesized envs dict.

---

## What M.g inherits from this spike

After M.g lands `lib/testenvs.sh`:

- `lib/testenvs/read_config.py` — the V1-derived Python helper, but emitting V3's wire format.
- `lib/testenvs.sh` — `read_testenv_config`, `resolve_testenv_path <name>`, `is_testenv_declared <name>`, `is_testenv_reserved <name>`, `is_testenv_lazy <name>`, `list_testenv_names`, `_testenvs_name_to_index <name>`. Per the [`lib/commands/<name>.sh` is for command implementations only](../project-guide/templates/artifacts/pyve-essentials.md) rule, the V3 array shape lives in `lib/testenvs.sh` and is read by `testenv`, `test`, and `lock` consumers via accessor functions — not by reaching directly into the arrays from consumer code.
- Validation messages: stable-prefix, substring-asserted, batched per invocation.
- No caching, no concurrency story for the read path.

What M.g does **not** inherit:

- The throwaway code under [tmp/spike-testenvs/](../../tmp/spike-testenvs/) is **discarded**. The shapes are illustrative; M.g re-writes against pyve's coding standards (license headers per [project-essentials.md](../project-guide/templates/artifacts/pyve-essentials.md), `lib/utils.sh` integration, proper bats unit tests). The spike's value is the decisions in this doc, not the literal files.

---

## Spike housekeeping

- [tmp/spike-testenvs/](../../tmp/spike-testenvs/) is throwaway, not committed for production. It may be retained alongside this doc through the rest of the M.g–M.t bundle as reference; the M.t bundle release story should delete it.
- Time-box met: ~1 session.
- No production code introduced. Zero version impact.
