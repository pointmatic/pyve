# Spike P.e — Parameter decision-graph → wizard/flags/help generation in Bash

**Type:** architectural spike (throwaway). **Subphase:** P-1 (v3.1.0). **Date:** 2026-06-26.
**Evidence:** [`scripts/spike_decision_graph.sh`](../../scripts/spike_decision_graph.sh) — quarantined, never sourced by `pyve.sh`, delete (or leave parked) once P.f/P.g/P.h land.

## Question answered

Can a single decision-graph node definition drive the `pyve init` wizard, the
flag/CLI parser, `--help`, and defaults — with plugin-contributed subtrees and
applicability pruning — in Bash that runs on macOS system bash **3.2**?

**Answer: yes.** The proof script does exactly this for a 6-node graph
(2 framework + 3 Python-plugin + 1 Node-plugin) and runs clean under
`/bin/bash 3.2.57` with `set -euo pipefail`.

## Decision 1 — representation: indexed array of pipe-delimited rows

The spike was framed as "associative-array tables **vs.** a generated dispatch."
**The first option is ruled out by construction, not by taste:**

- Associative arrays (`declare -A`) require Bash 4.0+. macOS ships bash **3.2.57**,
  which pyve must support (it is the daily-driver shell on every Mac).
- Pyve's own suite **forbids them**: [`tests/unit/test_bash32_compat.bats`](../../tests/unit/test_bash32_compat.bats)
  greps for `declare -A` / `local -A` and fails the build; `test_ui*.bats` do the
  same for the `lib/ui/` boundary. A registry built on `declare -A` could not land.

So the representation is the idiom pyve already uses elsewhere (e.g.
[`lib/commands/env.sh`](../../lib/commands/env.sh)'s colon-delimited dedup):
a flat, **indexed** array `NODES=()`, one **pipe-delimited row** per node, parsed
field-by-field at walk time. Indexed arrays *are* 3.2-safe. Pipe (`|`) beats colon
as the delimiter because flag names, paths, and version strings never contain it.

A "generated dispatch" (codegen of one big `case`) was the other candidate; it is
strictly worse here — it duplicates the data into emitted code, can't be introspected
at runtime for `--help`/drift, and complicates the plugin-contribution seam. The
table-walked-at-runtime model keeps **one** artifact that all sinks read live.

## Decision 2 — the node schema needs a 9th field: `label`

The story's schema is 8 fields `{name, applicability, choices, default, flag, env,
owner, required}`. The spike finds that is **insufficient**: you cannot generate a
wizard prompt or a `--help` line without human text. The proven schema adds `label`:

```
name | owner | applicability | choices | default | flag | env | required | label
```

- **applicability** — `*` (always) · `key=val` (prior answer match) · `@fn` (computed predicate).
- **choices** — `a,b,c` (literal set) · `@fn` (computed from prior answers) · `-` (free value, e.g. a version/path).
- **default** — literal · `@fn` (computed) · `-` (none).
- **owner** — `framework` or a plugin name; drives the contribution seam and `--help` grouping.

The `@fn` indirection is how *computed* fields work without baking dependencies into
the table: the row names a function; the function reads accumulated `ANSWERS`. This is
what lets "Backend's choices/default are a function of Language + an `environment.yml`
heuristic" be **data**, not a special-cased branch. Proven: `@py_backend_default`
returns `micromamba` iff `environment.yml` exists, else `venv`.

## Decision 3 — answers accumulator is a membership string, not a map

Prior answers accumulate in a single space-bracketed string `ANSWERS=" "` scanned by
glob membership — the same 3.2-safe idiom `_env_list_all_names` uses. No map needed.

## Decision 4 — `--help` is a DIFFERENT traversal from wizard/flags

A mid-spike bug became a load-bearing finding. The wizard and flag sinks **prune** by
applicability (skip nodes whose condition fails against prior answers). The first
`--help` implementation reused that walk — and with no prior answers, every
plugin/conditional node (`backend`, `python-version`, …) failed its `language=python`
gate and was hidden. **`--help` is static**: it must enumerate *every* node, annotated
with its gating condition (`[when language=python]`), never run the answer-pruning walk.
P.g must implement help as its own enumeration pass over the table, not a walk.

## What the proof demonstrates (maps to P.e's four tasks)

| Task | Proven by |
|---|---|
| Node schema `{…}` + a walk that prunes on prior answers | `NODES` table + `walk()`; `provider` pruned for a Python project, `version-manager` pruned when backend≠venv |
| Same node generates an interactive prompt **and** non-interactive flag resolution | `walk wizard` and `walk flags` both traverse the *same* table; flag precedence flag → `--no-x` negation → env var → default, with choice-set validation |
| A plugin contributes a subtree | `register_python_subtree` / `register_node_subtree` append rows; framework code never names `venv`/`asdf`/`3.14`/`pnpm` — that knowledge lives only in the plugin's contribution |
| Write-up + risks feeding P.f/P.g/P.h | this document |

Two **bonus** sinks fell out for free, confirming the "one artifact, six outputs"
thesis: explicit-`pyve.toml` emission and (by reading defaults vs. answers) the basis
for drift detection both read the same table.

## Risks & open issues handed to P.f/P.g/P.h

1. **Single-condition applicability.** The spike's `key=val` form is one condition; real
   nodes need AND/OR (`language=python AND backend=venv`). Proven workaround: a `@fn`
   predicate (`@py_needs_vmgr`) expresses arbitrary logic today. **P.f decision:** keep
   `@fn` as the escape hatch and decide whether to also support a small `a=b,c=d` (AND)
   literal form for readability. *(Feeds P.f — core model.)*
2. **Negation/boolean flags.** `--no-project-guide` is matched by a `--no-<name>`
   convention in the spike. P.g must formalize boolean nodes (paired `--x`/`--no-x`,
   mutual-exclusion errors — the current wizard hand-codes these) as a node *kind*. *(Feeds P.g.)*
3. **Field delimiter collision.** Pipe is safe for the current fields; `label` text must
   not contain `|`. P.f should add a one-line guard/test rather than trust it. *(Feeds P.f.)*
4. **`cut`-per-field cost.** The proof calls `cut` per field per node — fine at ~6 nodes,
   wasteful at scale. P.f should parse a row once into positional locals (read with `IFS='|'`)
   instead of N `cut` calls. Not a correctness issue; a known cleanup. *(Feeds P.f.)*
5. **Contribution-hook shape.** The spike registers subtrees via plain function calls
   (`register_python_subtree`). P.h must wire this into the real plugin contract
   ([`lib/plugins/contract.sh`](../../lib/plugins/contract.sh), today 14 hooks, none for
   wizard/flags) as a default-no-op hook, matching the subset-of-hooks design. The node
   **order** within a subtree is the prompt order — order is data, confirmed. *(Feeds P.h.)*
6. **Validation & required-resolution** live in the `flags` sink in the spike; P.f should
   make choice-set validation and required-but-unresolved errors a shared step both the
   wizard and flag sinks call, so the two surfaces can never diverge.

## Verdict

Implementation pattern is **viable and low-risk**; the binding constraint (bash 3.2)
*forces* the cleaner of the two candidate designs. Proceed to P.f (core model & walk
engine) on the indexed-array/pipe-row representation with the 9-field schema above,
carrying risks 1–6 forward. Throwaway proof to be deleted when P.g retires the four
scattered sites.
