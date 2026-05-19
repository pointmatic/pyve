# Phase L — Pyve polish audit (L.a)

**Audience:** Humans and LLMs scheduling L.b+ work.  
**Sources:** [`lib/commands/status.sh`](../../lib/commands/status.sh), [`lib/commands/check.sh`](../../lib/commands/check.sh), [`lib/ui.sh`](../../lib/ui.sh), [`lib/utils.sh`](../../lib/utils.sh) (project-guide), [`features.md`](features.md), archived [`phase-h-check-status-design.md`](.archive/phase-h-check-status-design.md); cross-check **2026-04-29**.

This document fulfills Story **L.a** in [`stories.md`](stories.md): three sections (Diagnostic Surface / Project-Guide Integration / Terminal UX), numbered findings tables, per-finding writeups, **`pyve check --fix`** tagging for Track 1, and an implementation-ordered suggested story slate.

---

## Summary tables

### Track 1 — Diagnostic surface (status / check)

| ID | Symptom | Root cause (short) | Fix size | `--fix` later? |
|----|---------|--------------------|----------|----------------|
| **T1-01** | `pyve status`: **Project ▸ Python:** `not pinned` for micromamba while **Environment ▸ Python:** shows resolved interpreter | `_status_configured_python` ignores `backend`; no `environment.yml` / lock parse | small | Possibly (display-only fix); auto-write **`python.version`** is risky |
| **T1-02** | Users/docs expect **Python version gate** + **distutils shim** diagnostics; **`features.md`** still lists them; **`pyve check --help`** says **`pyve status` is coming** | Deferred H§3.3 checks 6/8 not shipped as **warn** checks; **`show_check_help` stale** | one-liner to small (docs/help) vs refactor if implementing checks | Yes for shim reinstall / mismatch once rules are crisp |
| **T1-03** | **status** shim row present for **venv** only; micromamba skips **Python:** row entirely when **`bin/python`** absent | Separate env builders; asymmetric helpers | optional micro-polish | Shim: maybe; row parity: unclear |

### Track 2 — Project-guide integration

| ID | Symptom | Root cause (short) | Fix locus | Follow-up artifact |
|----|---------|---------------------|-----------|-------------------|
| **T2-01** | `project-guide` subprocess output during `pyve init`/`update` can clutter logs next to pyve banners | No consumer-facing **quiet** mode beyond `--no-input` | upstream | [`project-guide-requests/quiet-non-interactive-embedding.md`](project-guide-requests/quiet-non-interactive-embedding.md) |

### Track 3 — Terminal UX

| ID | Symptom | Root cause (short) | Fix size |
|----|---------|---------------------|----------|
| **T3-01** | Micromamba `pyve init` path interleaves long raw subprocess streams (bootstrap, env create/solve/install) without step framing | `create_micromamba_env` etc. delegate to conda/mamba; no capture/wrap/strides | refactor + `lib/ui/` |
| **T3-02** | `lib/ui.sh` lacks step counters, spinners, selectors, noisy-subprocess wrappers | Planned gap vs npm-style scaffolding | `lib/ui/` growth |
| **T3-03** | Header claims **verbatim gitbetter sync**; Phase L lifts that constraint per plan | Historical comment drift | small (comment + eventual move to `lib/ui/`) |

---

## Track 1 — Diagnostic surface (detailed)

### Code paths walked

**[`lib/commands/status.sh`](../../lib/commands/status.sh)**

| Area | Paths | Backend split |
|------|--------|----------------|
| Non-project | `config_file_exists` false → banner + hint | shared |
| **Project** | path, backend, pyve_version line, **`_status_configured_python`** | **`_status_configured_python` is backend-agnostic** (bug hub for micromamba) |
| **Environment** | Dispatcher on `backend`; `_status_env_venv` vs `_status_env_micromamba` | full split |
| **Integrations** | direnv, `.env`, **`project-guide` binary in env `$env_path/bin`**, testenv | `project-guide` row resolves env root per backend |

**[`lib/commands/check.sh`](../../lib/commands/check.sh)**

| Area | Paths | Backend split |
|------|--------|----------------|
| Early exit | missing config | shared |
| Version drift | recorded `pyve_version` vs `$VERSION` | shared |
| Backend | `_check_venv_backend` vs `_check_micromamba_backend` | full split plus unknown-backend error |
| Common | `.envrc`, `.env`, optional testenv | shared |

Cross-reference with **[`features.md` §FR-5 / FR-5a](features.md)** and archived **H design §3.3 [.archive/phase-h-check-status-design.md](.archive/phase-h-check-status-design.md)** checklist table.

### T1-01 — Micromamba `Python: not pinned` contradiction (seed finding)

- **Symptom:** **[`Future` story § `pyve status` / micromamba pinning](stories.md)** — Project prints **not pinned**; Environment prints **actual** `Python: x.y.z` from `$env_prefix/bin/python --version`; user sees a same-screen contradiction.
- **Root cause:** [`_status_configured_python`](../../lib/commands/status.sh) only consults `.tool-versions` → `.python-version` → `.pyve/config` `python.version`. Micromamba projects pin Python in **`environment.yml`** (`python=…` dependency); **`python.version`** is often unset.
- **Proposed fix size:** **Small** — backend-aware dispatcher mirroring **`_status_section_environment`**; **`environment.yml` line grep / light parse** per Future story sketch; **`venv`** path unchanged.
- **Fix locus:** pyve only.
- **Suggested story:** Promote **`Future` micromamba pinning** → **L.b** `"Status: micromamba Python pin from environment.yml"`.
- **`pyve check --fix`:** **Low value / risky.** Display fix needs no remediation; silently writing **`.pyve/config`** from YAML crosses user ownership. Prefer **manual** or `pyve update` semantics if ever aligning config from files — defer to Future auto-remediation story with explicit gates.

### T1-02 — Documentation vs diagnostics: FR-5 over-claims parity with implementation

- **Symptom:** **[`features.md` FR-5](features.md)** lists **~"Python version agreement"**, **`distutils_shim` status on 3.12+** among ~20 checks. **[`lib/commands/check.sh`](../../lib/commands/check.sh)** runs **informational `_check_pass "Python: $py_version"`** only (see comments referencing deferred full match); **no** distutils shim check. Archived **phase-h-check-status-design §3.3 checks 6 and 8** describe **warn**-level mismatch + shim probes — never fully shipped vs design.
- **Root cause:** Product scope narrowed at implementation without trimming **features.md** list; **`show_check_help`** still says **`pyve status` coming in a later release** (**stale**: status shipped — line ~325 [`check.sh`](../../lib/commands/check.sh)).
- **Proposed fix size:** **One-liner to small:** fix help text (**one-liner**); either **narrow FR-5** wording to match reality (**small**, docs only) **or** implement checks 6/8 (**refactor**) — mutually exclusive bundles.
- **Fix locus:** pyve (**docs ± code**).
- **Suggested story:** **L.c** `"Align check/help/features with shipped diagnostic surface"** (starts as docs/help; spike whether to restore H.e design checks).

### T1-03 — Backend asymmetry polish (severity: low)

| Topic | Observation |
|-------|--------------|
| **distutils shim row** | **status** exposes shim for **`venv`** only (**[`_status_env_venv`](../../lib/commands/status.sh)**); **micromamba** omits analogous row (`init` installs shim via `pyve_install_distutils_shim_for_micromamba_prefix`). |
| **Python row when exe missing** | **venv**: explicit **`Python: not found`**; **micromamba**: skips row if **`bin/python`** not executable (slightly quieter). |

- **Suggested story:** Optional **micro-polish cluster** appended after L.b or folded into Future if negligible user impact.

### T1-04 — Contradictions **within** `pyve status`

- **Confirmed:** Only **material same-fact** contradiction audited is **T1-01** (Project vs Environment Python pinning for micromamba). Other rows use independent facts (counts, file presence).

### Synthetic run note (manual)

 **Synthetic session:** No separate transcript file was archived. **Track-2 friction for T2-01 is inferred from `lib/utils.sh` embeddings** (`log_info` + child **stdout**/stderr interleaving). A live **`pyve init`** / **`update`** log capture remains **recommended dogfood** before **L.d**. Integration risk stays flagged under **T2-01** until **`--quiet`** exists upstream.

---

## Track 2 — Project-guide integration (detailed)

### Inventory (`grep project-guide lib/` plus completion)

| File | Role |
|------|------|
| [`lib/commands/init.sh`](../../lib/commands/init.sh) | Hooks: **`_init_run_project_guide_hooks`**, flags **`--project-guide`/*** , auto-skip if dep declared |
| [`lib/commands/update.sh`](../../lib/commands/update.sh) | **`run_project_guide_update_in_env`** when **`.project-guide.yml`** exists and env resolvable unless **`--no-project-guide`** |
| [`lib/commands/status.sh`](../../lib/commands/status.sh) | Reads **`$env/bin/project-guide --version`** for Integrations row |
| [`lib/commands/self.sh`](../../lib/commands/self.sh) | Uninstall strips **project-guide completion** sentinels from rc files |
| [`lib/utils.sh`](../../lib/utils.sh) | **`run_project_guide_pip_install`**, **`run_project_guide_init_in_env`**, **`run_project_guide_update_in_env`**, **`project_guide_completion_*`**, **`is_project_guide_declared_dependency`** |
| [`lib/completion/pyve.bash`](../../lib/completion/pyve.bash) | **`--project-guide`** completion strings |
| [`lib/completion/_pyve`](../../lib/completion/_pyve) | zsh completions |

### Invocation facts (verbatim from code comments)

| Call site | Invocation | Minimum version commentary in pyve |
|-----------|-------------|-----------------------------------|
| Init / force refresh scaffold | **`project-guide init --no-input`** | Comment: relies on **`≥ 2.2.3`** **`--no-input`** ([`lib/utils.sh`](../../lib/utils.sh) ~568) |
| Update path | **`project-guide update --no-input`** | Same wrapper pattern |
| micromamba backend | **`$micromamba_path run -p $env_path project-guide …`** | correct env targeting |

vs **public upstream surface** summarized at [project-guide docs](https://pointmatic.github.io/project-guide/) — **`init`, `mode`, `override`, `update`, `status`**; **`--no-input`** used by pyve is consistent with unattended hooks.

### T2-01 — Embedded noise / verbosity

- Already summarized; **upstream** change request authored at [**`docs/specs/project-guide-requests/quiet-non-interactive-embedding.md`**](project-guide-requests/quiet-non-interactive-embedding.md).
- **Pyve adoption:** future L.+ story **`Requires project-guide ≥ vX.Y.Z`** once flag exists.

### Contract observations (no upstream spec today)

| Topic | Observation |
|-------|--------------|
| **Version pins** | Pyve **`pip install --upgrade`** default can fight user-declared **`project-guide==`** deps — **`is_project_guide_declared_dependency`** auto-skips to avoid clashes; sane. |
| **Failure handling** | Init/update wrappers **warn and continue** (non-fatal) — aligns with scaffolding-not-blocking-init philosophy. |

---

## Track 3 — Terminal UX (detailed)

### Current [`lib/ui.sh`](../../lib/ui.sh) capabilities

| Capability | Symbols / functions |
|-----------|---------------------|
| **NO_COLOR** | palette + glyphs |
| Messaging | **`banner`, `info`, `success`, `warn`, `fail`** |
| Prompts | **`confirm`**, **`ask_yn`** (`[Y/n]` / `[y/N]`) |
| Layout | **`divider`**, **`header_box`**, **`footer_box`** |
| Subprocess UX | **`run_cmd`** (`$ cmd…` dim echo before exec) |
| Typo UX | **`_edit_distance`** (bash 3.2 safe) |

**Missing vs reference flows** (**`npm create vite@latest`** / **`npm create svelte@latest`**, scoped to plain bash+tput constraints per plan):

- **Step framing** (**`[2/7]`**) across long operations.
- **Spinners / indeterminate progress** for slow downloads/solves — achievable with ANSI **`tput`** + tight loops sparingly (**bash 3.2**).
- **Arrow-key selectors** (`read -sn`) — possible but fiddly vs **numbered menu** (**existing init patterns**) — achievable **subset** is **digits + prompt**, not full **ink** libs.
- **Quiet replay on failure**: capture noisy child stdout/err, print on non-zero (**new helper**, likely **`lib/ui/run.sh`**-class name after split).

Header **lines 17–19** still say **verbatim sync with gitbetter** — **Phase L** explicitly relaxes (**[`phase-l-pyve-polish-plan.md`](phase-l-pyve-polish-plan.md)** §Theme).

### Commands emitting multi-step / noisy flows (walked vs spot-checked)

| Command | Typical noise |
|---------|----------------|
| **`pyve init`** (venv) | `run_cmd` python venv creation, pip chatter if deps install |
| **`pyve init`** (micromamba) | **bootstrap_download**, **`create_micromamba_env`** (conda/mamba solve + install streams), shim, direnv — **worst offender** per plan ([**`lib/commands/init.sh`**](../../lib/commands/init.sh) micromamba branch ~501–631) |
| **`pyve update`** | gitignore/template refresh + optional **project-guide update** subprocess |
| **`pyve lock`** | **conda-lock** stdout |
| **`pyve testenv install`** | **pip** install output |
| **`pyve purge --force`** | delete + confirmations |

### T3-01 … T3-03 — Recap

- **T3-01**: **Micromamba init** lacks unified **macro-step** counter around micro-subprocesses.
- **T3-02**: **`lib/ui/`** subdirectory + **`core.sh`/`progress.sh`** (**names indicative**) — migrate **[`lib/ui.sh`](../../lib/ui.sh)** inside **first Track-3 implementation story** that adds a sibling module (**per plan** explicit sourcing discipline in **`pyve.sh`**).
- **T3-03**: Update **`lib/ui.sh`** header commentary when migrating.

### Verbosity policy recommendation

**Recommendation:** **Defer default noise reduction** to the first **implementation** story bundle that defines **`--verbose` / `PYVE_VERBOSE`** — flipping defaults now risks CI users who scrape full conda traces. **`phase-l-pyve-polish-plan.md`** ties **Quiet by default** to conditional **`project-essentials.md`** entries **only after** UX ships.

**Rationale deferral:** Land **`lib/ui/`** plus a **single-command pilot** (micromamba **init**) before repo-wide verbosity policy.

---

## Suggested story slate (implementation order)

| Order | Working title | Traces | Scope hint |
|:-----:|---------------|-------|-------------|
| **1** | **L.b:** Status — micromamba Python pin from **`environment.yml`** | T1-01 | Promote **`Future`** story; bats branches per Future checklist |
| **2** | **L.c:** Check help + **`features.md` FR-5** alignment with **`check.sh`** | T1-02 | Stale **`coming in later release`** + trim or implement claims |
| **3** | **L.d (+ upstream):** Project-guide **`--quiet`** consume | T2-01 | Land upstream spec **[`quiet-non-interactive-embedding`](project-guide-requests/quiet-non-interactive-embedding.md)** then pyve wrappers |
| **4** | **L.e:** `lib/ui/` split + micromamba **`init`** step framing pilot | T3-01–03 | Migrate **`lib/ui.sh`**, add **`lib/ui/progress.sh`** (name TBD); explicit **`pyve.sh` sources |
| **5** | **Optional cluster:** shim row / missing-python row symmetry | T1-03 | Nano-polish |

**Stories `L.zz`**, **`phase-l-pyve-polish-plan.md`** closure, **unchanged.**

---

## Hand-off

- **`docs/specs/project-guide-requests/quiet-non-interactive-embedding.md`** — upstream **T2-01**.
- Append **L.b+** titles to **`stories.md`** when individual stories get written (post-review).
- **No code or version bump** in **L.a** itself.
