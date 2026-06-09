<!--
Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
SPDX-License-Identifier: Apache-2.0
-->

# Pyve CLI Output Contract — design proposal

**Status:** ACCEPTED (2026-06-08). Feeds **Subphase N-10 "UX visual refinement"** — this is now the contract that `plan_production_phase` breaks into N-10 stories. No code changes are implied by this document itself; the retrofit lands as N-10 stories.

**Open decisions O-1…O-5 resolved as recommended** (see §5 for rationale): O-1 lighter report frame, no box for `check`/`status`; O-2 standardize on the heavy `✔`/`✘` set, retire `✓`/`✗`; O-3 header-only for `exec`/streaming commands (documented exception, no footer after `exec`); O-4 full `✘` chrome on stderr, no lowercase `error:` token; O-5 the output contract is its own N-10 slice, orthogonal to the migration gate.

**Author context:** drafted 2026-06-08 after a smoke pass on an empty `pyve-v3-smoke` directory exposed five distinct, mutually-inconsistent output styles across pyve commands.

---

## 1. Problem — five dialects, two glyph families

Every command below was run on the *same* empty (`.git`-only) directory. Each renders in a different visual language:

| Command(s) | Dialect | Frame | Body glyphs | Source |
|---|---|---|---|---|
| `init`, `purge`, `env init/install`, `self` | **Box** | rounded box header + box footer (`✔ All done.`) | `▸ ✔ ✘ ⚠` | `lib/ui/core.sh` |
| `test`, `env run` | **No-box glyph** | none | `▸ ✘` | `lib/ui/core.sh` primitives, no box |
| `check` | **ASCII report** | `Pyve Environment Check` + `======` rules, `Overall:` verdict | `✓ ✗ ⚠` | `lib/check_composer.sh` (hand-rolled `printf`) |
| `status` | **Underline report** | `Pyve project status` + dim `───` underline | plain text | `lib/status_composer.sh` (hand-rolled `printf`) |
| `env init foo` (and other `assert_*`) | **Bare error** | none | none — lowercase `error: …` | `lib/envs.sh` `printf "error: …" >&2` |

Two independent problems compound the dialect sprawl:

1. **The footer lies on failure.** `footer_box` ([lib/ui/core.sh:141](../../lib/ui/core.sh#L141)) is hardcoded to `✔ All done.` with no status parameter; dispatchers call it unconditionally before returning the real code, so a failed `pyve env init` prints its `✘` errors *and* a green success box. (Tracked separately as Story **N.bf.23**; folded into this contract as retrofit step 1.)
2. **Two glyph families.** `lib/ui/core.sh` uses the *heavy* set `✔` (U+2714) / `✘` (U+2718); `check`/the python plugin use the *light* set `✓` (U+2713) / `✗` (U+2717). Same meaning, different code points — visible drift even within a single command's neighborhood.

The `lib/ui/` layer already exists and is the sanctioned extractable UX seam — but `check` and `status` bypass it entirely, and the action commands use it inconsistently (some boxed, some not).

---

## 2. Design principles

1. **One visual language, two archetypes.** A user should recognize pyve output at a glance regardless of command. The only legitimate variation is *action* vs *report* (below) — never per-command accident.
2. **Everything routes through `lib/ui/`.** No command or composer hand-rolls rules, glyphs, or colors. The `lib/ui/` boundary invariant (pyve-agnostic) is preserved; `check`/`status` adopt shared primitives.
3. **The chrome must never contradict the outcome.** Success chrome only on success; failure chrome on failure.
4. **One glyph set, semantic colors.** Retire the light `✓`/`✗`. Color carries meaning (green=ok, red=error, yellow=warn, cyan=step) and degrades cleanly under `NO_COLOR`.
5. **Backward-compatible primitives.** Extend `lib/ui/` signatures with optional args so existing callsites keep working as the retrofit lands incrementally.

---

## 3. The contract

### 3.1 Command archetypes → chrome

**Action commands** — they *do* something / mutate state: `init`, `purge`, `update`, `lock`, `self`, `env init/install/purge/sync`, `test`, `env run`, `run`.

- **Header:** `header_box "pyve <cmd>"` at entry (always).
- **Body:** indented primitive lines — `▸` step (`info`), `✔` success, `✘` error, `⚠` warn, `$ …` dimmed command echo (`run_cmd`).
- **Footer:** **status-aware** `footer_box <rc>` at exit — success variant (`✔ All done.`, green) on `rc == 0`; failure variant (`✘ Failed.` / equivalent, red) on `rc != 0`.
- This unifies `test` and `env run` (currently boxless) with the rest. *(Open decision O-3 covers the `exec`-style streaming case.)*

**Report commands** — read-only diagnostics that *describe* state: `check`, `status`.

- **NOT** the action box — a report is not "All done." Instead a shared **report frame**: a `report_header "<Title>"` primitive (one consistent rule character, replacing both `======` and `───`), per-section `[<plugin>]` labels, per-finding lines using the *same* glyph set (`✔/✘/⚠`), and for `check` a shared `report_verdict "<Overall>"` footer.
- Both composers stop hand-rolling `printf` and call these primitives.

**Hard errors / pre-dispatch validation** — `assert_*` helpers and arg validators that abort before any frame is drawn.

- A single `die "<msg>"` / `error_line "<msg>"` primitive (stderr-safe, consistent `✘` prefix + red + indent + exit). Replaces bare lowercase `error: …`. *(Open decision O-4: keep a short machine-readable `error:` prefix for scriptability, or go full chrome.)*

### 3.2 Glyph + color set (canonical)

| Role | Glyph | Color | Primitive |
|---|---|---|---|
| step / progress | `▸` | cyan | `info` |
| success | `✔` (U+2714) | green | `success` |
| error | `✘` (U+2718) | red | `fail` / `error_line` |
| warning | `⚠` | yellow | `warn` |

Retire `✓` (U+2713) and `✗` (U+2717) everywhere (`check`, python plugin). A `lib/ui/` boundary test greps for the light glyphs and fails the build to prevent regression.

### 3.3 `footer_box` signature

```
footer_box [exit_code]   # 0 / absent → "✔ All done." (green, unchanged)
                         # non-zero    → "✘ Failed."   (red)
```

Dispatchers that compute a result thread it through (`footer_box "$leaf_rc"`); no-arg callsites keep today's success default.

---

## 4. Retrofit plan → proposed N-10 stories

The contract lands incrementally; each step is independently shippable and test-guarded. Suggested order (cheap correctness first, design-led unification last):

1. **`footer_box` status-aware** (= existing **N.bf.23**). Thread real rc through all ~11 dispatcher/composer callsites.
2. **Glyph unification.** Single heavy set; retire `✓`/`✗` in `check` + python plugin; add the boundary grep test.
3. **Error primitive.** Introduce `die`/`error_line`; convert `assert_*` and pre-dispatch validators off bare `error:`.
4. **Boxless action commands.** `test` and `env run` adopt `header_box` + status-aware `footer_box` (respecting O-3 for `exec` paths).
5. **`check` → report frame.** `check_composer` adopts `report_header` + `report_verdict`; drop hand-rolled `======`.
6. **`status` → report frame.** `status_composer` adopts `report_header`; drop hand-rolled `───`.
7. **Consistency sweep + snapshot tests.** Golden-output tests per command (success + failure) so the contract can't silently drift again.

---

## 5. Open decisions (need the developer)

- **O-1 — Report chrome.** Do `check`/`status` get *any* box, or only the lighter `report_header` frame? *(Recommendation: lighter frame, no box — a report isn't an action.)*
- **O-2 — Glyph family.** Standardize on the heavy set `✔/✘`? *(Recommendation: yes — it's already the action-command default.)*
- **O-3 — `exec`/streaming commands.** `env run` (and `pyve run`) `exec` into a subprocess that owns the rest of the terminal — a trailing footer is impossible after `exec`. Header-only for these? Or wrap (no `exec`) so a footer can render? *(Recommendation: header only; document the exception.)*
- **O-4 — Error prefix.** Keep a terse machine-readable `error:` token for scripting/grep, or fully chrome the hard-error path? *(Recommendation: `✘ ` chrome on stderr, no lowercase `error:` token — pyve errors aren't a stable machine API.)*
- **O-5 — Scope boundary with N-10's other goals.** N-10 also bundles the hard migration gate; is the output contract its own subphase slice, or interleaved? *(Recommendation: its own slice — orthogonal concern.)*

---

## 6. Relationship to existing work

- **Subsumes N.bf.23** (footer-lies bug) as retrofit step 1.
- **Honors** the `lib/ui/` boundary invariant (project-essentials "`lib/ui/` is the extractable UX boundary").
- **Does not** change any command's exit codes or error *semantics* — purely how output is *rendered*.
