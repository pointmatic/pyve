# Phase N-7 Audit — story-named tests, story-refs in code, load-bearing exceptions

**Story:** N.bb (audit + classification). **Drives:** N.bc (test renames, executes §1), N.bd (production code-ref sweep, executes §2), and N.bd.1 (test-body ref sweep, executes §2-T). **Status:** **approved at the N.bb gate (2026-06-06)** — §1 merge proposals A–E accepted as default; §3 load-bearing classification confirmed; the §2-T scope seam resolved into Story N.bd.1.

This is a **reviewable classification artifact**, not an execution log. Nothing is renamed or deleted by N.bb — the dispositions below are proposals for the developer to confirm/adjust before N.bc/N.bd run. The split exists because silently stripping a load-bearing marker disarms a downstream sweep with **no test failure to catch it** (e.g. the N-10 read-compat cleanup), so the narrative-vs-contract call deserves explicit review first.

**This doc is itself a kept historical record** (per the N-7 preamble: spike + audit docs are not scaffolding) — N.be does not clean it up.

---

## §1 — Test file rename catalog

59 story-IDed test files → capability-named targets. Convention: group by **capability/surface**, mirroring the existing capability-named files (`test_check`, `test_status`, `test_purge_ui`, `test_manifest`, `test_project_guide`, `test_python_plugin_command_layout`). Where multiple story files cover one capability, the proposed target **merges** them (N.bc reconciles duplicate `@test` descriptions — Bats requires uniqueness per file — and preserves every assertion).

Legend — **Disposition**: `rename` = 1:1 `git mv`; `merge→X` = combine into target `X` (existing or new); `LB` = load-bearing assertion subject (filename renamable, in-test marker must survive — see §3).

### Python plugin cluster

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_n_python_plugin.bats` | `test_python_plugin.bats` | rename |
| `test_n_o_python_plugin_lifecycle.bats` | `test_python_plugin_lifecycle.bats` | rename |
| `test_n_p_python_plugin_runtime.bats` | `test_python_plugin_runtime.bats` | rename |
| `test_n_q_python_plugin_activate.bats` | `test_python_plugin_activate.bats` | rename |
| `test_n_r_python_plugin_gitignore_purge.bats` | `test_python_plugin_gitignore_purge.bats` | rename |
| `test_n_aj_python_active_gate.bats` | `test_python_plugin_active_gate.bats` | rename |

### Node plugin cluster

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_t_node_plugin.bats` | `test_node_plugin.bats` | rename |
| `test_n_u_node_backend_providers.bats` | `test_node_backend_providers.bats` | rename |
| `test_n_v_node_runtime_detect.bats` | `test_node_runtime_detect.bats` | rename |
| `test_n_w_node_plugin_lifecycle.bats` | `test_node_plugin_lifecycle.bats` | rename |
| `test_n_x_node_plugin_runtime.bats` | `test_node_plugin_runtime.bats` | rename |
| `test_n_y_node_plugin_activate.bats` | `test_node_plugin_activate.bats` | rename |
| `test_n_z_node_plugin_gitignore_purge.bats` | `test_node_plugin_gitignore_purge.bats` | rename |
| `test_n_aa_node_sveltekit.bats` | `test_node_sveltekit.bats` | rename |

### Plugin / backend infrastructure

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_k_plugin_registry.bats` | `test_plugin_registry.bats` | rename |
| `test_n_k_plugin_schema.bats` | `test_plugin_schema.bats` | rename |
| `test_n_l_backend_registry.bats` | `test_backend_registry.bats` | rename (distinct from existing `test_backend_detect.bats`) |

### Composition builders (`.envrc` / `.gitignore` / check / status / purge)

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_m_envrc_safety.bats` | `test_envrc_safety.bats` | rename |
| `test_n_ae_2_python_activate_emitter.bats` | `test_envrc_composer.bats` | merge → ⚠️ see note A |
| `test_n_ae_3_envrc_composer.bats` | `test_envrc_composer.bats` | merge |
| `test_n_ae_4_compose_envrc_write.bats` | `test_envrc_composer.bats` | merge |
| `test_n_ae_5_compose_project_wiring.bats` | `test_envrc_composer.bats` | merge |
| `test_n_ae_6_prompt_eof.bats` | `test_envrc_composer.bats` | merge → ⚠️ see note A |
| `test_n_af_gitignore_composer.bats` | `test_gitignore_composer.bats` | rename |
| `test_n_ag_compose_check.bats` | `test_check.bats` | merge → ⚠️ see note B |
| `test_n_ah_compose_status.bats` | `test_status.bats` | merge → ⚠️ see note B |
| `test_n_ai_compose_purge.bats` | `test_purge_ui.bats` | merge → ⚠️ see note B |

### Composed `pyve init` (orchestrator + e2e + polyglot)

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_av_1_init_composer.bats` | `test_composed_init.bats` | merge |
| `test_n_av_2_init_tail.bats` | `test_composed_init.bats` | merge |
| `test_n_av_3_node_only_init.bats` | `test_composed_init.bats` | merge |
| `test_n_av_4_polyglot_init.bats` | `test_composed_init.bats` | merge |
| `test_n_av_5_composed_matrix.bats` | `test_composed_init.bats` | merge |
| `test_n_ab_1_node_root_e2e.bats` | `test_composed_init.bats` | merge → ⚠️ see note C |
| `test_n_ab_2_polyglot_e2e.bats` | `test_composed_init.bats` | merge → ⚠️ see note C |
| `test_n_ab_3_composed_envrc.bats` | `test_composed_init.bats` | merge → ⚠️ see note C |
| `test_n_ad_polyglot_scaffold.bats` | `test_polyglot_scaffold.bats` | rename |
| `test_n_am_polyglot_matrix.bats` | `test_composed_init.bats` | merge → ⚠️ see note C |

### Toolchain Python (resolver + lifecycle + provisioning)

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_at_1_toolchain_python.bats` | `test_toolchain_python.bats` | rename |
| `test_n_at_2_resolver_rewire.bats` | `test_toolchain_python.bats` | merge |
| `test_n_at_3_toolchain_lifecycle.bats` | `test_toolchain_python.bats` | merge |
| `test_n_az_1_provisioning.bats` | `test_toolchain_python.bats` | merge → ⚠️ see note D (PyYAML provisioning into toolchain venv) |

### project-guide hosting / orchestration

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_au_project_guide_locus.bats` | `test_project_guide.bats` | merge (into existing) |
| `test_n_aw_toolchain_hosting.bats` | `test_project_guide.bats` | merge |
| `test_n_aw_2_orchestration.bats` | `test_project_guide.bats` | merge |
| `test_n_ay_marker_contract.bats` | `test_project_guide_marker_contract.bats` | rename — **LB** (`.project-guide.yml` literal, §3) |

### Packaging lifecycle

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_aq_packaging_registry.bats` | `test_packaging_registry.bats` | rename |
| `test_n_ar_package.bats` | `test_package.bats` | rename |

### Env spec / `pyve env sync`

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_az_1_env_spec_helper.bats` | `test_env_spec_helper.bats` | rename |
| `test_n_az_2_env_sync.bats` | `test_env_sync.bats` | rename |
| `test_n_az_2_env_sync_helper.bats` | `test_env_sync.bats` | merge |
| `test_n_az_2_check_drift.bats` | `test_env_sync.bats` | merge → ⚠️ see note E (or `test_check.bats`) |

### Closed-vocabulary / enforcement / advisory (F6)

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_ba_1_vocabulary.bats` | `test_env_vocabulary.bats` | rename |
| `test_n_ba_2_enforcement.bats` | `test_env_vocabulary.bats` | merge |
| `test_n_ba_3_advisory.bats` | `test_env_vocabulary.bats` | merge |

### Core v3 infrastructure

| Current | Proposed target | Disposition |
|---|---|---|
| `test_n_f_state_layout.bats` | `test_state_layout.bats` | rename — **LB** (`.pyve/testenvs/` forbidden-literal sentinel, §3) |
| `test_n_h_v2_banner.bats` | `test_v2_banner.bats` | rename |
| `test_n_i_read_compat.bats` | `test_read_compat.bats` | rename — **LB** (`v3.0-only: remove in N-10` grep, §3) |
| `test_n_j_1_run_backend_detection.bats` | `test_run_backend_detection.bats` | rename |
| `test_n_al_retired_writers.bats` | `test_retired_writers.bats` | rename — **LB** (retired writer-name sentinel, §3) |

### §1 open decisions for the gate — RESOLVED (approved 2026-06-06)

All five notes below were **accepted as their proposed defaults** at the N.bb gate. N.bc executes the catalog as written above; the alternatives are recorded for traceability only.

- **Note A — N.ae split.** `ae_2` (python activate *emitter*) and `ae_6` (prompt-EOF "invalid answer" arm in `lib/utils.sh`) are only loosely "envrc composition." Alternatives: `ae_2` → `test_python_plugin_activate.bats`; `ae_6` → `test_utils.bats`. Proposed default folds both into `test_envrc_composer.bats` since they exist to feed the composer. **Developer call.**
- **Note B — composed check/status/purge.** Proposed merge into the *existing* `test_check.bats` / `test_status.bats` / `test_purge_ui.bats` (the most capability-honest target, matching the preamble's cited examples). Alternative: standalone `test_check_composer.bats` / `test_status_composer.bats` / `test_purge_composer.bats` if the existing files are large enough that merging hurts readability. **Developer call.**
- **Note C — composed-init blast radius.** Ten files collapse to `test_composed_init.bats`. That is a large merge; if it produces an unwieldy file, the natural seam is `test_composed_init.bats` (orchestrator + unit, the `av_*` set) vs `test_composed_init_e2e.bats` (the `ab_*` + `am` end-to-end matrix). **Developer call.**
- **Note D — toolchain provisioning.** `az_1_provisioning` is PyYAML-into-the-toolchain-venv; it sits between "toolchain python" and "env spec." Proposed `test_toolchain_python.bats` (it provisions the toolchain). Alternative: `test_env_spec_helper.bats`. **Developer call.**
- **Note E — drift check locus.** `az_2_check_drift` is the `pyve check` env-spec drift addendum. Proposed `test_env_sync.bats` (same feature family). Alternative: `test_check.bats` (same command surface). **Developer call.**

---

## §2 — Story-ref classification (production code)

**203** story-ID-bearing lines across **27** files in `lib/` + `pyve.sh` (full count below). Rather than 203 individual rows, refs are classified by **form**, because the overwhelming majority are uniform and the disposition follows from the form. The few non-uniform cases (load-bearing, stale-forward) are enumerated individually. The complete `file:line` list is mechanically reproducible — see the appendix grep — so N.bd has no ambiguity at execution time.

### The "where does the context survive?" gate

Per the developer-directed refinement at the N.bb design discussion: **no narrative ref is deleted without recording where its context survives.** Three outcomes:

1. **Derivable from the code** → delete the ref clean; nothing to preserve.
2. **Survives in a prose doc** (the `stories.md` entry, `project-essentials.md`, a spike doc) → delete the inline pointer; narrative is safe in the durable record.
3. **Lives nowhere but this comment** → do **not** delete-as-narrative. Relocate the *why* into a self-contained comment (no story ID), **or**, if it is project-level wisdom, lift it into `project-essentials.md`. Only then drop the ID.

### Form taxonomy

| Form | Shape | Count (approx) | Disposition | Context survives via |
|---|---|---|---|---|
| **A — file-header banner** | `# lib/foo.sh — <self-contained description> (Story N.x)` | ~28 (one per file head) | Strip the `(Story N.x)` parenthetical; keep the description verbatim. | Self-contained (outcome 1) |
| **B — inline narration** | `# Story N.x: <self-contained explanation>` or `<explanation> (Story N.x)` | majority (~150) | Drop the `Story N.x:` prefix / `(Story N.x)` tag; keep the explanation. | Self-contained (outcome 1) |
| **C — pure pointer** | `# Story N.x` / `(Story N.x)` with no surrounding why; `see Story N.x` | a few | Remove entirely. | `stories.md` entry (outcome 2) |
| **D — stale forward-ref** | "lands in Story N.i", "that is F6 (Story N.ba)", "is F6 in Subphase N-6" — names work that is now **[Done]** | 8 (enumerated below) | Rephrase to present-tense current state; drop the ID. | Self-contained after rephrase (outcome 1/3) |
| **E — LOAD-BEARING marker** | `v3.0-only: remove in N-10` | 6 lines (enumerated in §3) | **KEEP verbatim.** | n/a — the ref *is* the contract |

**Net rule for N.bd:** Forms A/B keep their prose, lose only the story-ID token (the barnacle). Form C is removed. Form D is rephrased. Form E is untouched. No production *behavior* changes — this is comment hygiene; the green suite is the proof.

### Form D — stale forward-refs to now-completed work (individual review)

These name work that has since shipped `[Done]`, so the forward-looking phrasing is now misleading, not informative. Rephrase to describe current behavior; the underlying *why* (this reader/writer is intentionally lenient; validation lives elsewhere) is worth keeping — relocate it without the ID.

| file:line | current text | rephrase to |
|---|---|---|
| `lib/pyve_env_spec_helper.py:15` | "…values; that is F6 (Story N.ba)." | "…values; closed-set validation is enforced separately (see `pyve_toml_helper.py` `VALID_*`)." |
| `lib/pyve_env_sync_helper.py:16` | "does not closed-set-validate values; that is F6 (Story N.ba)." | same shape as above |
| `lib/pyve_toml_helper.py:262` | "reads it leniently — closed-set validation is F6 in N-6." | "reads it leniently — closed-set validation is enforced by `VALID_*` at manifest-validate time." |
| `lib/commands/package.sh:19` | "…is F6 in Subphase N-6, not here — this verb reads leniently." | "this verb reads leniently; unknown-value rejection is enforced at manifest-validate time." |
| `lib/plugins/packaging_registry.sh:26` | "…is F6 in Subphase N-6, not here — N-5 reads leniently." | same shape as above |
| `lib/plugins/python/plugin.sh:1767` | "the YAML removal lands in Story N.i with the read-compat" | "the legacy `.pyve/config` YAML is no longer written; the v3 manifest is canonical." |
| `lib/plugins/python/plugin.sh:1866` | "the YAML removal lands in Story N.i with the" | same shape as above |
| `lib/plugins/python/plugin.sh:3650` | "…blocks lands in Story N.i; until" | "legacy `[tool.pyve.testenvs.<name>]` blocks are no longer read; pyve.toml is canonical." |

> Note: `lib/manifest.sh`'s `v3.0-only: remove in N-10` lines also *read* as forward-refs but are **Form E (load-bearing)** — they are the contract that drives the N-10 sweep, not stale narration. Do not fold them into Form D.

### Per-file ref counts (for N.bd coverage tracking)

```
 59  lib/plugins/python/plugin.sh
 28  pyve.sh
 16  lib/manifest.sh        (incl. 6 Form-E load-bearing — see §3)
 13  lib/commands/self.sh
 12  lib/plugins/node/plugin.sh
  8  lib/pyve_toml_helper.py
  8  lib/commands/env.sh
  6  lib/envrc_composer.sh
  6  lib/check_composer.sh
  5  lib/project_guide.sh
  5  lib/init_composer.sh
  5  lib/envs.sh
  4  lib/utils.sh
  3  lib/toolchain_python.sh
  3  lib/status_composer.sh
  3  lib/plugins/packaging_registry.sh
  2  lib/pyve_env_sync_helper.py
  2  lib/pyve_env_spec_helper.py
  2  lib/envrc_safety.sh
  2  lib/env_detect.sh
  2  lib/commands/package.sh
  1   each: lib/purge_composer.sh, lib/plugins/registry.sh,
         lib/plugins/node/runtime_detect.sh, lib/plugins/contract.sh,
         lib/plugins/backend_registry.sh, lib/gitignore_composer.sh,
         lib/backend_detect.sh
```

> One special case in `lib/env_detect.sh:331`: `# BOUNDARY (Story N.at.2): this guards the *project* python…`. The **`BOUNDARY` marker is semantically load-bearing prose** (it marks the carved project-vs-toolchain python boundary documented in `project-essentials.md`). Form B disposition: drop `(Story N.at.2)`, **keep `BOUNDARY` and the explanation**.

### §2-T — Story-refs inside test bodies (separate from the §1 filename catalog)

Task 3 also sweeps `tests/`. **115** story-ID lines live *inside* test file bodies (comments/strings), across both story-named and capability-named files. Classification:

- **Load-bearing: exactly one.** `tests/unit/test_n_i_read_compat.bats:243` — `grep -qE 'v3\.0-only: remove in N-10'`. This is **LB-1's enforcer** (see §3); the literal is the assertion subject and stays. All other test-body refs are **narrative** (`# Story N.x — what this test covers` headers).
- **Disposition for the narrative 114:** Form-B — strip the `Story N.x` token, keep any self-contained "what this covers" prose. Lower-stakes than production code (tests are inherently more disposable narrative), but they are barnacles all the same.

> **Scope-ownership gap — RESOLVED (developer-directed, 2026-06-06).** N.bc renames test *files*; N.bd sweeps *production* code (`lib/` + `pyve.sh`). Neither owned the narrative story-refs *inside* test bodies. Resolution: a dedicated **Story N.bd.1** ("Sweep narrative story-refs from test bodies per the audit") now owns this work — N.bd's test-body counterpart, single story (no bundle), run *after* N.bc so it operates on final filenames. Its scope walks **all of `tests/`** (both story-named and capability-named files: refs exist in `test_check.bats`, `test_manifest.bats`, `tests/helpers/test_helper.bash`, etc.). The one load-bearing §2-T entry (LB-1's grep enforcer in `test_n_i_read_compat.bats:243`) is preserved by N.bd.1, adjusting only the `load`/path if N.bc renamed the file.

---

## §3 — Load-bearing contract notes

Each entry documents what the ref protects so a future maintainer cannot strip it on a follow-up pass without understanding the cost. These survive N.bd untouched; their **filenames** (where they are tests) may still be renamed by N.bc, but the **in-test marker/literal they assert on** is the contract.

### LB-1 — `v3.0-only: remove in N-10` markers (production code)

- **Where:** `lib/manifest.sh` lines 50, 60, 65, 128, 143, 246 (the literal `v3.0-only: remove in N-10`; line 60 is the explanatory prose that also names the literal).
- **What depends on it:** `test_n_i_read_compat.bats:243` runs `grep -qE 'v3\.0-only: remove in N-10' "$PYVE_ROOT/lib/manifest.sh"` and fails the build if zero hits. The marker also *drives* the N-10 read-compat cleanup sweep (grep the marker → delete the matching helpers). Documented in `project-essentials.md` § "`v3.0-only: remove in N-10` marker is the contract".
- **Disposition:** **KEEP verbatim.** Each line marks a distinct read-compat code path the N-10 sweep removes; all should survive (not just one). This is the canonical example of why N.bb precedes N.bc/N.bd — stripping these has **no test-visible failure** other than the dedicated sentinel.

### LB-2 — `.pyve/testenvs/` forbidden-literal sentinel (test)

- **Where:** `tests/unit/test_n_f_state_layout.bats` → proposed `test_state_layout.bats`.
- **What depends on it:** the test greps `lib/commands/*.sh` + `pyve.sh` for the forbidden `.pyve/testenvs/` literal and fails on regression (migrator surfaces `lib/envs.sh` / `lib/commands/self.sh` are location-exempt). Documented in `project-essentials.md` § "v3 state directory is `.pyve/envs/<name>/<backend>/`".
- **Disposition:** rename the file (N.bc); the in-test `.pyve/testenvs/` literal it greps for is the **assertion subject** and stays. Also references sibling `test_testenvs_activate.bats` § "no legacy literals survive" — that sibling name is itself capability-named (not story-IDed), so no cross-update needed.

### LB-3 — retired writer-name sentinel (test)

- **Where:** `tests/unit/test_n_al_retired_writers.bats` → proposed `test_retired_writers.bats`.
- **What depends on it:** the test greps `lib/` + `pyve.sh` for non-comment references to the retired writers `write_envrc_template` / `write_gitignore_template` and fails if any executable callsite reappears. **Comment** mentions of the retired names (the "retired in N.al" notes) are explicitly allowed.
- **Disposition:** rename the file (N.bc); the retired function-name list inside the test is the **assertion subject** and stays. *Cross-note for N.bd:* the `# … retired in Story N.al` comments in `lib/plugins/python/plugin.sh:17,414` are Form-B narrative (strip the ID, keep the "retired" note) — and stripping the ID is safe precisely because the sentinel keys on the *function name*, not the story ID.

### LB-4 — `.project-guide.yml` marker contract (test)

- **Where:** `tests/unit/test_n_ay_marker_contract.bats` → proposed `test_project_guide_marker_contract.bats`.
- **What depends on it:** guards the cross-repo `.project-guide.yml` install-marker contract (F5). Documented in `project-essentials.md` § "`.project-guide.yml` is the canonical project-guide install marker" — pyve keys real behavior off this exact filename, so it is a coordinated breaking change upstream.
- **Disposition:** rename the file (N.bc); the `.project-guide.yml` literal it asserts on is the **assertion subject** and stays.

### LB-5 — `lib/ui/` boundary invariant (test, already capability-named)

- **Where:** `tests/unit/test_ui_run.bats` — **not story-IDed**, no rename needed. Listed for completeness because the preamble names it.
- **What depends on it:** greps `lib/ui/run.sh` for forbidden pyve-specific tokens (`pyve.sh`, `.pyve`, `DEFAULT_VENV_DIR`, `TESTENV_DIR_NAME`) and asserts `PYVE_VERBOSE` is the only `PYVE_`-prefixed identifier — enforces the extractable-UX-library boundary. Documented in `project-essentials.md` § "`lib/ui/` is the extractable UX boundary".
- **Disposition:** no action in N.bc/N.bd. Any *new* `lib/ui/` module must extend this test (project-essentials rule), but that is outside N-7.

### LB-6 — `BOUNDARY` marker (production code, prose-not-story)

- **Where:** `lib/env_detect.sh:331` (`assert_python_resolvable`).
- **What depends on it:** marks the carved project-python-vs-toolchain-python boundary. Documented in `project-essentials.md` § "Pyve's toolchain Python is the hidden venv" (the "one exception" callout).
- **Disposition:** Form-B in N.bd — drop `(Story N.at.2)`, **keep the `BOUNDARY` keyword and the explanation.** The `BOUNDARY` token is load-bearing prose even though no test greps it; it is the human-facing signal that this callsite intentionally stays on `${PYVE_PYTHON:-python}`.

---

## Appendix — reproduction commands

```sh
# §1 surface — every story-named test file:
find tests -name 'test_n_*.bats' | sort

# §2 surface — every story-ID ref in production code:
grep -rnE 'Story N\.|Stories N\.|v3\.0-only|remove in N-|Subphase N-' lib/ pyve.sh

# §3 LB-1 grep-visibility check (must stay nonzero through N-10):
grep -c 'v3.0-only: remove in N-10' lib/manifest.sh
```
