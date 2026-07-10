# phase-p-subphase-2-runnability-heal-plan.md — Pyve v3.2.0 Harden & Heal (Act 2)

Plan for **Subphase P-2: Runnability probes & environment healing**, drafted in the subphase's own `plan_production_phase` session (2026-07-08) per the deferred-breakdown marker in [stories.md](stories.md). The strategic frame — Act 2 of Phase P's two-act arc — lives in the Phase P preamble ([stories.md](stories.md) § "Act 2 context") and in the P-1 plan's roadmap (§8 of [phase-p-subphase-1-ux-overhaul.md](.archive/phase-p-subphase-1-ux-overhaul.md), now archived). This document frames the subphase; the detailed candidate designs remain in `stories.md` § Future and are cited, not duplicated.

---

## 1. The problem this subphase solves

The 2026-06-09 triggering incident (Phase P preamble) took a long manual trace across four independent layers — PATH shadowing, venv↔pin interpreter drift, dead Pyve-managed artifacts, and an unplaceable interpreter version — none of which any Pyve command could see or explain. Three systemic gaps made it possible:

1. **Existence ≠ runnability.** Health code stats artifacts (`-x` / `-f` / `-d`) or probes through paths that bypass the breakable artifact (`python -c 'import pytest'` bypasses dead console-script wrappers). A broken env reports green.
2. **No resolution reasoning.** Nothing narrates *where* a managed command resolves from and *why* — the developer hand-traces PATH slots, shims, and symlinks.
3. **No heal path.** Every detected (or undetected) fault ends in hand-repair of Pyve-managed state.

A fourth gap *manufactured* the incident: the integration suite's `_isolate_home` symlinks the developer's **real** `~/.asdf` and `~/.local` into the test's fake `$HOME`, so provisioning tests write hosting artifacts into real developer state that dangle when the tmpdir is reaped.

**Act-1 dependency (why this comes second):** `pyve heal` restores toward the intent the manifest fully captures (P-1's explicit declaration + `[env.<name>]` setup recipes) and the operational reality it recorded (P-1's state record). Resolution reasoning diagnoses drift against *declared* pins. The substrate shipped in v3.1.0; this subphase stands on it.

---

## 2. Gap analysis — what exists vs. what's needed

| Area | Exists today (v3.1.0) | Needed (v3.2.0) |
|---|---|---|
| Hosting health | Runnability probes done: `pyve_toolchain_runnable` / `pyve_project_guide_runnable` execute artifacts; shared by `pyve check` and `pyve self provision --status` | — (the discipline to generalize) |
| Project-env health | `check`'s testenv probe runs `python -c 'import pytest'` (bypasses dead wrappers); root probe is existence-only | Plugin-owned **canary** hook executing a console-script wrapper per declared+materialized env |
| Failure classification | None — pass/fail at best | Classified verdicts: `runnable` / `dead-shebang` / `dangling symlink` / `missing interpreter` / `not materialized` / `orphaned` (manifest↔disk contradiction) |
| Resolution reasoning | None — manual PATH trace | `check` narrates per managed command: resolving PATH slot, shadow relationships, pin vs. actual, venv↔pin drift |
| Healing | None (role-correct rebuild *hints* at best) | `pyve heal` / `pyve check --fix`: classified failure → safe, idempotent, confirm-before-destroy repair |
| Test isolation | `_isolate_home` symlinks real `~/.asdf`, `~/.local` into fake `$HOME` | Fully self-contained fake `$HOME`; the suite can never mutate real developer state |
| Silent-skip advisory | `root` probe broken (first-dir glob → unconditional "no pytest"); suppression is a per-shell env var only | Fix the `root` branch (canonical resolver); declarative `pyve.toml` opt-out |
| project-guide status | Two contradictory readouts (v2 `[python]` Integrations row vs. v3 `[project-guide]` section); no version shown | One readout naming *how* it's present (toolchain / local pip / neither) + resolved version, in `status` and `self provision` |
| Staleness | `check` is local-only; nothing says "a newer version exists" | Optional, info-only, offline-graceful update surfacing with install-source-correct remediation hints |

---

## 3. Feature requirements (the four pillars + riders)

**Pillar 1 — Runnability probes.** An optional plugin-contract hook (working name `env_probe` / canary): each plugin defines per backend a minimal runnable command + expected response, executed against every declared *and materialized* env. Executes a **console-script wrapper** (carries the baked shebang — the artifact that actually breaks), never `python -m …`. Advisory/not-materialized envs are skipped via `_env_backend_is_advisory`. Includes the manifest↔disk **orphan/contradiction** reconciliation. Full design: the "Per-env runnability probe" candidate in stories.md.

**Pillar 2 — Resolution reasoning in `pyve check`.** Turn the manual trace into automated narrative: for each managed command, report where it resolves and why — PATH-slot ordering, venv-shadows-pin, reachability under the active pin, interpreter drift — in plain language ("`python` resolves from `.venv` (3.14.4), shadowing the asdf pin (3.12.13); …").

**Pillar 3 — Healing mechanism.** `pyve heal` (or `pyve check --fix`): for every failure class the probes detect, a safe, idempotent, **confirm-before-destroy** repair — rebuild a dead-interpreter toolchain venv, re-link a dangling shim, rebuild a drifted or dead-wrapper env (destructive → explicit confirmation), remove an orphaned tree, install a missing managed command into the *selected* interpreter. Heal rides P-1's machinery: the state record + `[env.<name>]` recipe make "rebuild" a replay, not a guess. Flag semantics per the established rule: `--yes` assents to prompts, `--force` escalates — never synonyms.

**Pillar 4 — Close the test-isolation leak.** Re-scope `_isolate_home` so provisioning/self-install tests run against a fully self-contained fake `$HOME` (or stub provisioning entirely). The `PYVE_PROJECT_GUIDE_BIN` / `PYVE_PYTHON` seams close part of the surface; the version-manager (`~/.asdf`) and self-install paths remain open today.

**Riders (same theme, smaller):**
- Silent-skip advisory `root` pytest-probe fix (false negative in exactly the guard's reason for being).
- Declarative `pyve.toml` opt-out for the silent-skip advisory (project-scoped, reviewable; the env var stays as a one-off/CI override).
- project-guide status unify + version (drop the v2 `[python]` Integrations row; `[project-guide]` section becomes the sole readout, naming presence mode + version; `self provision` prints the installed version).
- `pyve check` surfaces available updates (info-only staleness detection for hosted project-guide + pyve itself, with install-source-correct remediation hints).

---

## 4. Technical changes (mini tech-spec)

- **Plugin contract** ([lib/plugins/contract.sh](../../lib/plugins/contract.sh)): new optional `env_probe` hook, no-op default; documented verdict vocabulary.
- **Python plugin** ([lib/plugins/python/plugin.sh](../../lib/plugins/python/plugin.sh)): canary implementation — venv: execute `bin/pip --version` directly; micromamba: `micromamba run -p <env> pip --version`. Replace the existence-only / `python -m`-style testenv + root probes in `check_environment`. Fix `_test_env_has_pytest`'s `root` branch (canonical backend-aware resolution; delete the first-dir glob).
- **Check composers** ([lib/check_composer.sh](../../lib/check_composer.sh) + a resolution-reasoning surface): per-managed-command resolution narrative; canary verdicts rendered with role-correct heal hints (broken root → `pyve init --force`; broken named env → `pyve env init <name> --force`; never the rejected `pyve env purge root`).
- **Heal command**: new surface (name resolved in story breakdown) consuming classified verdicts; repairs routed through existing machinery (`self provision`, `pyve init --force`, `pyve env init <name> --force`, shim re-link); plan-then-confirm output; idempotent and re-runnable.
- **Manifest schema** ([lib/pyve_toml_helper.py](../../lib/pyve_toml_helper.py) + [lib/manifest.sh](../../lib/manifest.sh)): the silent-skip opt-out field — `pyve.toml`'s first "project preference" key; section shape (`[pyve]` / `[test]` / per-env `isolated`) decided at story breakdown; line-attributed validation; routed through the single TOML reader.
- **Status composer** ([lib/status_composer.sh](../../lib/status_composer.sh)): `_compose_status_project_guide` becomes the sole project-guide readout — presence mode + runnability-probed version; remove the `[python]` Integrations row; `self_provision` prints the installed version.
- **Staleness probe**: best-effort latest-version lookups (PyPI JSON for project-guide; Homebrew tap / GitHub releases for pyve) with short timeout, TTL cache, `--offline` / `PYVE_NO_NETWORK` opt-out; degrades silently offline; info-level only.
- **Test harness** ([tests/integration/test_project_guide_integration.py](../../tests/integration/test_project_guide_integration.py)): `_isolate_home` re-scoped to a self-contained fake `$HOME`; provisioning tests stub or fully sandbox version-manager and `~/.local` paths.

---

## 5. Production concerns

1. **Heal is destructive-capable.** Confirm-before-destroy everywhere; `--yes` = assent, `--force` = escalate (never prompt-skip synonyms); idempotent and re-runnable; always prints what it will do before doing it; never silently mutates.
2. **`check` stays CI-safe.** Probes *execute* artifacts, so every probe needs a bounded runtime (no hangs on a wedged interpreter); the 0/1/2 exit-code contract is preserved. The staleness probe adds a network dimension to a currently-offline command: info-only, short timeout, cached, opt-out, and a network failure can **never** change the exit code.
3. **Probe cost.** One cheap console-script execution per declared+materialized env per `check`; keep the canary minimal (`pip --version`).
4. **The test-isolation leak is a reliability hazard, not polish.** It has already corrupted a real developer home (dangling shim + dead-interpreter toolchain venv); closing it is in-scope, mandatory work.
5. **Trusted-publisher note (checklist carry-forward).** `update-homebrew.yml` (`dawidd6/action-homebrew-bump-formula`) relies on a PAT; recorded as a **Subphase P-5** hardening candidate (token scoping / trusted-publishing equivalent), not P-2 scope.

---

## 6. Anticipated breaking changes & version target

Negotiated per the `plan_production_phase` breaking-change pass (2026-07-08):

- **`pyve check` gets honest.** Envs reporting a false green today (existence-only probes; `python -m` bypassing dead wrappers) will start reporting broken, and CI consuming the 0/1/2 exit codes may flip red on previously-masked breakage. **Judged technically-but-trivially breaking**: "broken env → non-zero" was always the documented contract; the diagnostic stops lying. No semver-relevant behavior contract changes.
- **Human-readable output reshapes.** The project-guide unify drops the `[python]` Integrations row; resolution reasoning adds lines to `check`. **Judged trivially breaking**: affects output scrapers only; the machine contract (exit codes, `self provision --status` JSON) is untouched.
- **Additive surfaces** — `pyve heal` (or `check --fix`), the `pyve.toml` opt-out key, staleness info lines: not breaking.

**Version bump target: v3.2.0 (minor)**, per Phase P's documented multi-release exception (one minor per subphase). No item rose to substantively-breaking; no major bump.

---

## 7. Scope — v3.2.0 (in) vs. deferred (out)

**In scope (Subphase P-2):** the four pillars (§3) + the four riders.

**Out of scope:**

- **`purpose`-lifecycle policy** (durability ranking, cost-cache preservation, what survives purge) — gated on the conceptual pass seeded in [env-lifecycle-concept.md](env-lifecycle-concept.md) (`refactor_document` → planning). Session decision (2026-07-08): P-2's heal repairs *broken materialized state toward the declared manifest* and does not decide lifecycle policy, so it proceeds without that pass.
- **Auto-applying upgrades of healthy-but-stale tools.** Staleness detection ships hints; whether heal ever *applies* an upgrade is an open question (§8) leaning "no" — heal repairs broken state.
- **P-3 / P-4 / P-5 candidates** stay parked (kcov coverage upload, integration flakes, per-leaf help, calm-UX rollout, TypeScript depth, bootstrap SHA256 + version pinning).
- **The silent-skip advisory's heuristic itself** — only the opt-out and the `root` probe fix land here.
- **Move-time shebang repair** — shipped in v3.0.5; the canary + heal cover the already-broken residue.
- **`lib/ui/` extraction** — the boundary invariant holds; no extraction work here.

---

## 8. Open questions (resolve during story breakdown)

1. **Command surface:** ~~`pyve heal`~~ vs. `pyve check --fix` (or both, one delegating). Naming decides where confirm-flow and reporting live.
2. **Opt-out shape:** project-wide key (`[pyve]` / `[test]` section — the first project-preference key seeds the settings-section shape) vs. per-env `isolated` flag, or both. **Resolved (Story P.x, 2026-07-09): per-env `isolated = true` on `[env.<name>]`.** Rationale: it is surgical — the deliberate smoke/typecheck envs go quiet while the advisory keeps firing for the catch-all `testenv` (all-or-nothing is still expressible by marking every env); it slots into the existing `KNOWN_ENV_KEYS` closed vocabulary and accessor machinery; and it avoids seeding a `[pyve]`/`[test]` settings section for a single key — that shape decision keeps until a second project-preference key actually exists. Semantics: target-side only (a marked env still appears as a candidate when another env is targeted); precedence: env var **or** manifest flag suppresses, either alone sufficient. Strictly boolean, validated with a line-attributed error (`pyve.toml:<n>: …`) — the manifest's first line-attributed validation.
3. **Staleness network model:** opt-in vs. opt-out, timeout, cache TTL + location, flag/env-var names.
4. **Resolution-reasoning coverage:** which commands count as "managed" (python, pip, project-guide; the Node plugin's node/npm?) and how deep the narrative goes in the default vs. verbose view. **Resolved (Story P.aa, 2026-07-09): the managed set is `python` + `pip` (on Python-shaped projects) and `project-guide` (any-stack) — the incident trio; no plugin-extension hook yet (the tracer/vocabulary are plugin-agnostic by design, but Node's node/npm waits for P-4's deeper plugin work rather than growing a second contract hook here). Depth: concise by default — one winner line per command (`<cmd> → <path> (<slot class>[, <version>])`) plus a finding line only when something is wrong; the full slot-by-slot PATH trace renders under verbose (`is_verbose`). Finding classes: `ok` / `venv-pin-drift` / `no-version-set` / `broken-winner` / `not-found` (machine class in brackets on each finding line — the heal map's input). Severity: findings contribute WARN on the composed ladder (process exit unchanged; only plugin-check errors drive exit 2), honoring the "reasoning lines are diagnostic narrative" constraint.**
5. **Heal vs. upgrade boundary:** does heal ever apply a version upgrade, or strictly repair broken state and defer upgrades to the staleness hints?
6. **Orphan detection placement:** per-env probe vs. a separate manifest↔disk reconcile pass inside `check`.
