# phase-n-2-spike-env-model-worked-examples.md — Architectural spike for Pyve v3.0 env/backend/plugin model

**Status:** Architectural spike artifact for Subphase N-2 (drafted 2026-06-02 during a `plan_production_phase` re-invocation). **Not** an implementation spec. The deliverable of this spike is the documented set of design decisions in § *Synthesis* that emerge from contact with realistic project shapes.

**Why a spike here:** the v3.0 plugin/backend-provider contract design surfaced several non-obvious design questions during N-2 planning — what "owns" the project root, whether `role` is explicit or inferred, how cardinality should work, whether `backend` is a singleton or a stack, and whether Pyve's model extends gracefully to ecosystems Pyve doesn't actually virtualize (mobile dev). Trying to settle these in the abstract drove vocabulary collisions and forced framings. The spike works backward from concrete project shapes.

**Trigger:** the developer's challenge during N-2 planning — *"Are we conflating 'runnable' and 'the main thing'? Let's pause and nail down what 'named environment' and 'backend' mean, then produce worked examples and see what shape emerges."*

**Input:**
- [phase-n-framework-plugin-architecture.md](phase-n-framework-plugin-architecture.md) — concept doc; charter, requirements R1–R11, 7 open questions.
- [phase-n-plugin-architecture-named-envs-plan.md](phase-n-plugin-architecture-named-envs-plan.md) — Phase N plan, including the N-2 description and the 5 production concerns.
- N-1's shipped vocabulary (`[env.<name>]`, `purpose`, `backend`, `manifest`/`requirements`/`extra`, the legacy/sugar layer).

---

## Open questions this spike must answer

The synthesis section at the end commits to a position on each. Each example below is annotated with which question(s) it surfaces.

- **Q1 — Plugin role term.** "Host" carries server/client baggage; "root" collides with the existing `[env.root]`. Is there a better term, or does the *role concept itself* need rethinking?
- **Q2 — Role declaration.** Explicit `role` field in `[plugins.*]`, inferred from `path`, both, or neither?
- **Q3 — Host cardinality.** Zero-or-one host, exactly one (with synthetic fallback), or zero-or-many?
- **Q4 — Is backend a singleton or a stack?** Micromamba composes conda → pip materialization stages. Is "backend" one mechanism per env, or a layered list?
- **Q5 — `env` granularity.** Does every `purpose: run` surface need its own `[env.<name>]`, or can one env support multiple invocations? What *is* an env, fundamentally?
- **Q6 — Non-virtualizable ecosystems.** Mobile dev requires system-installed toolchains (Xcode, Android SDK). Does Pyve's `backend` abstraction extend to "verify presence" without "materialize"? Is mobile in scope at all?
- **Q7 — Human-required steps.** Some workflows have steps that *must* be human-driven (Xcode signing UI, KMP iOS targets requiring Xcode for runs). Does Pyve need an advisory `manual_steps` surface, or do those ecosystems sit outside Pyve's contract?
- **Q8 — Deploy as env vs hook.** Concept doc §7 says deploy is a *lifecycle hook*, not a `purpose:`. But the deploy artifact has its own backend (docker) and manifest (Dockerfile). Where does that declaration live?
- **Q9 — Runtime version managers (asdf et al.).** asdf is already integrated at the implementation layer (`is_asdf_active()` in [lib/env_detect.sh](../../lib/env_detect.sh)) but doesn't appear in `pyve.toml`. Where does runtime-version resolution fit in the v3.0 architecture, and does asdf's universality survive ecosystems that have their own canonical version manager (rustup, nvm, SDKMAN, rbenv)?
- **Q10 — Language flavors.** TypeScript runs on Node, Kotlin on JVM, mypy as Python type-checker, mixed C/C++ in CMake. These aren't backends and aren't plugins — they're *kinds of code* within an env. Where do they belong in the schema, if anywhere?

---

## Example 1: Pure Python library

**Surfaces:** baseline shape; whether `[plugins.*]` needs to exist at all for single-plugin cases.

A pip-installable library like `requests` or `click` (or Pyve itself qua Python development of bash scripts). Has tests and dev tooling, no runtime app.

**Project shape:**

```
my-lib/
├── pyproject.toml
├── src/my_lib/
├── tests/
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[project]
name = "my-lib"

[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true
```

**What works:** trivially. Almost no schema needed. No `[plugins.*]` section — Python is implicit (the only ecosystem Pyve ships with by default, and the only `backend` values cited are `venv`/`micromamba` which the Python plugin provides).

**What feels forced:** nothing.

**Question surfaced:**
- **Q1/Q2/Q3:** if `[plugins.*]` is absent, what is the implicit role / cardinality model? Possible answer: *implicit single-plugin*, where the only declared backend values determine the only active plugin. This works as a default for the overwhelming majority of pyve projects today and means most users never write a `[plugins.*]` block.

---

## Example 2: Python web app, single backend (venv)

**Surfaces:** Q5 sharply — does a `purpose: run` need its own env, or is it just an invocation of an existing env?

A Flask / FastAPI / Django app. Code in `src/`, runs via `python -m app` or `uvicorn app:asgi`.

**Project shape:**

```
my-app/
├── pyproject.toml
├── src/my_app/__main__.py
├── tests/
└── pyve.toml
```

**Proposed `pyve.toml` (Option A — `purpose: run` as its own env):**

```toml
[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[env.app]
purpose = "run"
backend = "venv"
```

**Proposed `pyve.toml` (Option B — no separate run env; running is an invocation of root):**

```toml
[env.root]
purpose = "utility"   # or "run"? — see below
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true
```

In Option B, the user runs `pyve run python -m my_app` from the root env. There is no `[env.app]` — "running the app" is an invocation, not a materialization.

**What works:** Option B is much simpler and matches today's Pyve behavior (you `pyve run …` from the activated env). Option A treats every run surface as a materialization, which buys nothing for the single-backend case: `[env.root]` and `[env.app]` would be byte-identical environments with the same `.venv/` materialized identically.

**What feels forced:** Option A. Same materialization, two env names, no behavioral difference. The only reason to prefer Option A would be if `purpose: run` carried semantic weight that `purpose: utility` doesn't — e.g., if `pyve deploy` only operates on `purpose: run` envs.

**Question surfaced:**
- **Q5:** an `env` is a **materialization**, not a **run surface**. One materialization may serve multiple invocations. The number of `[env.<name>]` blocks in `pyve.toml` should be the number of *distinct dependency closures*, not the number of "things you can do." For this example: one closure (the app deps), so one env. The "running the app" is just `pyve run`.
- **Sub-question:** if Option B's `[env.root]` actually hosts the run target, should its `purpose` be `run` or `utility`? Probably `utility` still — `purpose` describes the env's *primary* role; running an app from a utility env is a normal invocation.

---

## Example 3: Python web app with micromamba (layered: conda → pip)

**Surfaces:** Q4 — is `backend` a singleton or a stack?

A Django app with scientific deps (numpy, GDAL, CUDA libraries) where conda packages are the right install mechanism for the C-extension layer, and pip handles the rest on top.

**Project shape:**

```
ml-app/
├── pyproject.toml
├── environment.yml      # conda manifest
├── requirements.txt     # pip manifest, sits on top of conda
├── src/ml_app/
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[env.root]
purpose = "utility"
backend = "micromamba"
manifest = "environment.yml"           # conda layer
requirements = ["requirements.txt"]    # pip layer on top

[env.testenv]
purpose = "test"
backend = "micromamba"
inherit = "root"
```

**What works:** N-1's existing shape already handles this. `manifest` is the conda layer; `requirements` is the pip layer. The `micromamba` backend-provider materializes in two stages internally: `micromamba env create -f environment.yml`, then `pip install -r requirements.txt` inside the activated micromamba env.

**What feels forced:** nothing — *if* the layered behavior stays internal to the `micromamba` backend-provider.

**Question surfaced:**
- **Q4:** **`backend` is a singleton from `pyve.toml`'s POV.** Layering is internal to the provider's `init` hook implementation. The two-stage conda → pip composition for micromamba is not a Pyve-schema concept; it's a `micromamba` provider implementation detail. A future backend that genuinely needs to declare multiple ordered backends (theoretically: `[backend = "micromamba+poetry"]`) would be the moment to revisit, but no such case is concrete today.
- **Corollary:** the existing `manifest` / `requirements` / `extra` fields are *provider-specific configuration*, not generic schema. The Python plugin's `micromamba` provider knows how to interpret them; the Python plugin's `venv` provider interprets `requirements` and `extra` but not `manifest`; a hypothetical Node provider's `pnpm` interpretation would use different field names entirely (e.g., `package.json`, `lockfile`).
- **Schema implication:** the per-env `[env.<name>]` block has a core required set (`purpose`, `backend`) and a provider-private extension space (everything else). Core never interprets provider-private keys (matches concept doc § 5 hook 1: "Manifest namespace — Core does not interpret plugin-private keys").

---

## Example 4: Python API + SvelteKit frontend (monorepo)

**Surfaces:** Q1, Q2, Q3 sharply — the canonical multi-plugin case.

A SaaS app: Python FastAPI backend in `src/`, SvelteKit frontend in `src/frontend/`. Two ecosystems, two `purpose: run` envs, two `path` roots.

**Project shape:**

```
my-saas/
├── pyproject.toml
├── src/my_saas/
│   ├── __main__.py        # API entrypoint
│   └── frontend/          # SvelteKit lives here
│       ├── package.json
│       ├── pnpm-lock.yaml
│       └── src/
├── tests/
└── pyve.toml
```

**Proposed `pyve.toml` (Option A — explicit `host` role for python):**

```toml
[plugins.python]
role = "host"

[plugins.node]
role = "visitor"
path = "src/frontend"

[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[env.web]
purpose = "run"
backend = "pnpm"
path = "src/frontend"
```

**Proposed `pyve.toml` (Option B — no host concept; both plugins are peers, distinguished only by `path`):**

```toml
[plugins.python]
# path = "." implicit

[plugins.node]
path = "src/frontend"

[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[env.web]
purpose = "run"
backend = "pnpm"
path = "src/frontend"
```

In Option B, "owning the root" falls out of `path = "."` (explicit or default). The plugin with no explicit `path` (or `path = "."`) is implicitly the one whose `.envrc` content goes at the top of the composed root `.envrc`. There is no separate `role` field; spatial owner is derived from `path`.

**What works:** Option B. Reading Option A, the `role = "host"` line carries no information not already implied by `path = "."` (or its absence). The composition order question ("whose `.envrc` snippet comes first?") has a clean answer: the one whose `path` is `.`. The other(s) come in declared order or `path` lexicographic order, doesn't matter much because their snippets target different sub-paths and don't compete.

**What feels forced:** Option A's `role` field. Once you have `path`, `role` is derivative. The terminology debate ("host vs root vs anchor") evaporates if there's no explicit role field — the *concept* becomes "the plugin at `path = .`" which is self-describing.

**Question surfaced:**
- **Q1 + Q2:** **Drop the `role` field; infer from `path`.** This eliminates the terminology problem entirely. The "plugin at the project root" is just whichever has `path = "."` (default); others have explicit sub-paths. No need to name the concept — it doesn't appear in the manifest.
- **Q3:** with `role` gone, "host cardinality" reframes as "how many plugins can have `path = .`?" Answer: zero or one. Zero is fine (the docs-site case — example 5); two would mean two plugins want the same root, which is a `pyve init` conflict to flag explicitly.

---

## Example 5: Pure docs site (mkdocs)

**Surfaces:** Q3 — the zero-host case.

A documentation repository that uses `mkdocs` (Python tooling) to build a static site. The "site" is the deliverable but it's a build artifact, not a runtime; there's no Python app being served.

**Project shape:**

```
my-docs/
├── mkdocs.yml
├── docs/
├── requirements.txt    # mkdocs, mkdocs-material, etc.
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[env.root]
purpose = "utility"
backend = "venv"
```

No `[plugins.*]` (single-plugin case → implicit Python). No `purpose: run` env (mkdocs is a build tool, not a runtime). User invokes `pyve run mkdocs build` or `pyve run mkdocs serve` (which is a dev server, but ephemeral — not a managed env).

**What works:** trivially. The "zero-host" question is moot once Option B from Example 4 is adopted (no `role`/`host` concept; spatial owner is just whoever has `path = "."`). In this case `[plugins.python]` is implicit with implicit `path = "."`.

**What feels forced:** nothing.

**Question surfaced:**
- **Q3 confirmed:** zero hosts (in the renamed sense: zero plugins with explicit `path = "."`) is fine because *implicit Python at `path = "."`* covers it. The "single-plugin implicit Python" rule from Example 1 generalizes here too.

---

## Example 6: Python service deployed via Docker

**Surfaces:** Q8 — where does the deploy backend's declaration live?

A backend service: Python venv for dev, Docker image for production.

**Project shape:**

```
my-svc/
├── pyproject.toml
├── src/my_svc/
├── Dockerfile
├── tests/
└── pyve.toml
```

**Proposed `pyve.toml` (Option A — deploy as a hook on an existing env):**

```toml
[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[env.app]
purpose = "run"
backend = "venv"

[deploy.app]
provider = "docker"
dockerfile = "Dockerfile"
```

A new top-level table `[deploy.<env-name>]` keyed by the env it deploys, with its own provider configuration. `pyve deploy app` builds the Docker image from `Dockerfile` against the materialized state of `[env.app]`.

**Proposed `pyve.toml` (Option B — deploy as backend-of-an-env with `purpose: deploy`):**

```toml
[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[env.app]
purpose = "run"
backend = "venv"

[env.app_image]
purpose = "deploy"
backend = "docker"
source_env = "app"
```

A deploy is "just another env" with its own backend (docker) and a `source_env` cross-reference.

**Proposed `pyve.toml` (Option C — no deploy in pyve.toml; declared in pyproject.toml or similar):**

Deploy stays out of `pyve.toml` entirely; Docker config lives in `Dockerfile` + `.dockerignore` + whatever orchestration tool the team uses. `pyve deploy` reads `Dockerfile` directly and is a thin lifecycle hook with no schema in `pyve.toml`.

**What works:** Option A. It puts the deploy declaration in `pyve.toml` (so it's discoverable, lockable, versionable) without overloading the `[env.*]` table or introducing a `purpose: deploy` that breaks the (run/test/utility/temp) vocabulary. The `[deploy.<env-name>]` keying makes the relationship explicit: this is how *that env* gets deployed.

**What feels forced:** Option B's `purpose: deploy`. A deploy artifact (a Docker image) is not the same kind of thing as a dev environment — it's the output of a build, not an interactive workspace. Calling it an `env` muddles the model.

**Question surfaced:**
- **Q8:** **Deploy goes in `[deploy.<env-name>]`, not in `[env.*]`.** This keeps the (run/test/utility/temp) purpose vocabulary intact and makes the deploy → env relationship explicit. Whether `pyve deploy` ships a provider in v3.0 vs reserves the verb (concept doc Q6) is still open and remains an N-5 decision; this spike only settles where the *declaration* lives.

---

## Example 7: Android-only mobile app

**Surfaces:** Q6 — does Pyve's `backend` concept extend to non-virtualizable ecosystems?

An Android app: Kotlin source, built via Gradle, depends on the Android SDK + JDK being installed on the dev machine. There is no "create a virtual environment" step — the toolchain is system-installed.

**Project shape:**

```
my-android-app/
├── settings.gradle.kts
├── app/build.gradle.kts
├── app/src/main/kotlin/
└── pyve.toml
```

**Proposed `pyve.toml` (Option A — Pyve doesn't support mobile; spike concludes "out of scope"):**

```
(no pyve.toml at all — Pyve isn't the right tool for mobile)
```

**Proposed `pyve.toml` (Option B — Pyve supports mobile as "check-only" backends):**

```toml
[plugins.android]
# path = "." implicit

[env.root]
purpose = "utility"
backend = "android-sdk"
require_min_version = { "android-sdk" = "34", "jdk" = "17" }
```

A check-only backend declares dependencies on system-installed toolchains; `pyve check` verifies presence and version; there is no `pyve init` materialization step for the env (no `.venv/` equivalent — just a verification pass). `pyve run gradle …` works because gradle is on PATH.

**Proposed `pyve.toml` (Option C — Pyve treats it as a passthrough; no backend semantics):**

```toml
# No [env.*] for the Android dev workflow.
# pyve still manages .gitignore and .envrc for the project root.
# All Android operations happen via direct gradle/adb invocations, not pyve.
```

**What works:** Option B (with caveats) or Option A (clean cut).

- Option B extends Pyve's "every env declares a backend" rule by introducing a *check-only backend* category — backends that verify presence rather than materialize. This is a useful expansion: it gives Pyve a way to surface "this project requires Xcode 15+" via `pyve check` without claiming to install it. Cost: a new backend category (check-only vs materializing) to define and document.
- Option A keeps Pyve focused on virtualizable ecosystems and is honest about the boundary. Cost: the developer's stated future interest in iOS framework tooling (and the KMP case in example 8) loses an integration path.

**What feels forced:** Option C — having Pyve in the project for `.gitignore` management only is awkward; users will wonder why they're using Pyve at all.

**Question surfaced:**
- **Q6:** Tentative answer: **adopt Option B and define a "check-only backend" category.** Concrete schema implication: `backend` values come in two flavors — *materializing* (`venv`, `micromamba`, `pnpm` — Pyve creates and manages state under `.pyve/envs/<name>/`) and *check-only* (`android-sdk`, `xcode`, `homebrew`, `docker` — Pyve verifies presence and surfaces missing-toolchain errors but creates no state). The Python plugin provides materializing backends only; a new mobile plugin (post-v3.0 roadmap) would provide check-only backends.
- **Caveat:** this expansion broadens Pyve's identity from "virtual environment manager" to "environment-and-toolchain manager." The brand-descriptions doc revision in N-6 will need to reflect this.

---

## Example 8: Kotlin Multiplatform (Android + iOS + JVM, dev primarily in IDE)

**Surfaces:** Q6 + Q7 — non-virtualizable ecosystems AND human-required steps.

A KMP project: shared Kotlin code targeting Android, iOS, and JVM. Development happens primarily in an IDE (IntelliJ / Android Studio / Fleet) for Android + JVM + shared code; iOS targets require Xcode for builds, signing, and device runs. The developer's stated future interest: building a *declarative iOS framework / Swift code generator* with some steps requiring Xcode action — the KMP shape generalizes that.

**Project shape:**

```
my-kmp-app/
├── settings.gradle.kts
├── shared/             # shared Kotlin code
├── androidApp/         # Android target
├── iosApp/             # iOS target (Xcode project)
├── jvmApp/             # JVM target
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[plugins.kotlin-multiplatform]
# path = "." implicit
# (Hypothetical plugin name; out-of-tree per concept doc R6 for v3.0; included for design exploration.)

[env.android]
purpose = "run"
backend = "android-sdk"        # check-only
require_min_version = { "android-sdk" = "34", "jdk" = "17" }

[env.ios]
purpose = "run"
backend = "xcode"              # check-only
require_min_version = { "xcode" = "15.0" }
manual_steps = [
  "Open iosApp/iosApp.xcworkspace in Xcode",
  "Select target device or simulator",
  "Cmd+R to run"
]

[env.jvm]
purpose = "run"
backend = "jvm"                # check-only
require_min_version = { "jdk" = "17" }
```

**What works:** the schema accommodates the multi-target case by giving each target its own env (different `backend` values, different toolchain requirements). The `manual_steps` field is a new advisory pattern.

**What feels forced:** without `manual_steps` (or equivalent), Pyve has no way to communicate "Xcode steps are unavoidable here." `pyve check` could report "Xcode 15+ installed: yes" but not "you'll need to drive Xcode interactively for these steps." Without that, the model lies — claiming `pyve run` works for iOS when in fact it doesn't.

**Question surfaced:**
- **Q7:** **Add a `manual_steps` advisory field as optional metadata on `[env.<name>]`.** It's not a contract hook (Pyve can't run them). It's a string-list field that `pyve check`, `pyve status`, and `pyve env list` surface to the user. Future tooling could turn it into an interactive checklist (`pyve env manual-steps <env>` walks the user through), but v3.0 just renders it.
- **Q6 expanded:** check-only backends + `manual_steps` together make the non-virtualizable-ecosystem story coherent. Pyve becomes useful even for ecosystems it can't fully automate, by being honest about the boundary and surfacing the manual seams.

---

## Example 9: API + CLI + Electron desktop (heterogeneous multi-surface)

**Surfaces:** Q5 again (now with multiple run surfaces sharing one backend) and Q4 (Electron's runtime is itself layered: Node + Chromium).

A product with three deliverables: HTTP API (Python), CLI binary (Python, same codebase), Electron desktop app (Node + JS frontend + Chromium runtime bundled). Examples in the wild: `gh` (CLI + future web UI), `sentry` (API + multiple frontends), `gitlab` (API + Ruby + admin tools).

**Project shape:**

```
my-product/
├── pyproject.toml         # API + CLI live here
├── src/my_product/
│   ├── api.py
│   └── cli.py
├── desktop/               # Electron app
│   ├── package.json
│   ├── pnpm-lock.yaml
│   └── src/
├── tests/
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[plugins.python]
# path = "." implicit

[plugins.node]
path = "desktop"

[env.root]
purpose = "utility"
backend = "venv"

[env.testenv]
purpose = "test"
backend = "venv"
default = true

[env.desktop]
purpose = "run"
backend = "pnpm"
path = "desktop"

# Note: NO separate [env.api] or [env.cli] — both run from [env.root].
```

The API and CLI share one Python materialization (`venv` at the root); user runs `pyve run python -m my_product.api` or `pyve run my-cli`. No need for two `[env.*]` blocks just because there are two run surfaces — they have the same dependency closure.

The Electron desktop is a separate ecosystem (Node), separate `path`, separate materialization (`pnpm` at `desktop/`).

**What works:** this falls out of Example 2's Option B conclusion ("env = materialization, not run surface") and Example 4's Option B conclusion ("no host concept; spatial owner falls out of `path`"). The schema accommodates this case without any new fields.

**What feels forced:** nothing.

**Question surfaced:**
- **Q5 reinforced:** env count is determined by *distinct dependency closures*, not by *number of run targets*. Two run targets sharing a venv = one env, two invocation patterns.
- **Q4 secondary:** Electron's Node + Chromium layering is opaque to Pyve. `pnpm install` materializes the dependency tree; Electron handles its own Chromium bundle internally. Same conclusion as Example 3's micromamba layering: composition inside the backend-provider is invisible to `pyve.toml`.

---

## Example 10: Rust web service (cache-backed backend, rustup precedence)

**Surfaces:** Q6 + Q9 — the "cache-backed" backend category that doesn't fit cleanly under "materializing vs check-only," plus the per-plugin version-manager precedence chain.

A Rust HTTP service: standard cargo project, dependencies declared in `Cargo.toml`, locked in `Cargo.lock`, build output in `target/`. Dependencies themselves live in the shared user-level cache `~/.cargo/registry/`, not under the project. Rust version pinning via `rust-toolchain.toml` (rustup convention).

**Project shape:**

```
my-rust-service/
├── Cargo.toml
├── Cargo.lock
├── rust-toolchain.toml    # rustup pinning
├── src/main.rs
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[plugins.rust]
# path = "." implicit; out-of-tree per concept doc R6 for v3.0; included for design exploration.

[env.root]
purpose = "utility"
backend = "cargo"

[env.testenv]
purpose = "test"
backend = "cargo"
default = true
```

**What works:** lifecycle hooks map cleanly — `init` = `cargo fetch`, `check` = `cargo check`, `test` = `cargo test`, `run` = `cargo run`, `purge` = `cargo clean` (project-local `target/`). No PATH activation needed (cargo is on system PATH via rustup). No separate `[env.app]` for running the binary — `pyve run cargo run` works from root (S1 applies — env = materialization, not run surface).

**What feels forced:** S6 as originally written ("two backend categories: materializing vs check-only"). Cargo doesn't fit either — it doesn't create per-project state under `.pyve/envs/<name>/` (deps live in shared `~/.cargo/registry/`), but it's also not check-only (it actively fetches and builds). There's a missing middle category: **cache-backed**.

**Question surfaced:**
- **Q6 (revised):** **three backend categories, not two** — see S6 (revised). Project-virtualized (venv, pnpm, …), cache-backed (cargo, go, gradle, …), check-only (xcode, android-sdk, …).
- **Q9:** **per-plugin version-manager precedence chain.** Rust's canonical version manager is **rustup**, not asdf. The Python plugin uses asdf > pyenv > system; the Rust plugin uses rustup > asdf > system. asdf is a common second-tier fallback because asdf-plugins exist for most ecosystems, but it isn't framework-privileged. See S10.

---

## Example 11: Go HTTP service (cache-backed, minimal-project-state baseline)

**Surfaces:** Q6 (further confirmation of cache-backed category) — Go has even less project-local state than Rust.

A Go service: dependencies declared in `go.mod`, locked in `go.sum`, deps cached in shared `~/go/pkg/mod/`. No project-local build directory by default (the binary is produced at the project root or wherever `-o` points).

**Project shape:**

```
my-go-service/
├── go.mod
├── go.sum
├── main.go
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[plugins.go]
# path = "." implicit; out-of-tree per concept doc R6 for v3.0; included for design exploration.

[env.root]
purpose = "utility"
backend = "go"

[env.testenv]
purpose = "test"
backend = "go"
default = true
```

**What works:** lifecycle hooks — `init` = `go mod download` (populates shared cache, writes nothing project-local beyond the lockfile), `test` = `go test ./...`, `run` = `go run .`, `purge` = effectively no-op (Go has nothing to clean per-project that's safe to touch). No PATH activation needed.

**What feels forced:** the contract's `purge` hook semantics need to clearly state that cache-backed backends do NOT touch the shared cache during normal `pyve purge` — the cache is co-owned with other projects. An optional `pyve purge --deep` could prompt to invoke the language tool's own cache-clean (`cargo clean`, `go clean -modcache`) with explicit confirmation.

**Question surfaced:**
- **Q6 reinforced:** cache-backed is a real category; some cache-backed backends (Go) have *no* project-local materialized state at all beyond the lockfile. The contract's `init`/`purge` hooks must be expressive enough that providers can decide whether they create per-project state or not.

---

## Example 12: Swift iOS mobile app (un-installable toolchain, narrow manual seam)

**Surfaces (post-S15 validation, drafted 2026-06-04):** confirms the expanded env-spec vocabulary (S12–S15 + O4) against an Xcode-driven stack, and *triggers the S6 re-revision* (S16) — the case that exposed "check-only" as conflating "Pyve can't *install* the toolchain" with "Pyve can't *build*."

A SwiftUI iOS app: Swift sources, an `.xcodeproj`, XCTest suites, a SwiftLint/SwiftFormat gate. Built with `xcodebuild`; deps (if any) via SwiftPM; distributed as a signed `.app`/`.ipa`.

**Project shape:**

```
my-ios-app/
├── MyApp.xcodeproj/          # project.pbxproj — text (NeXTSTEP plist), not binary
├── MyApp/{MyApp.swift, ContentView.swift, Assets.xcassets/}
├── MyAppTests/               # XCTest
├── Package.swift             # optional SwiftPM deps
└── pyve.toml
```

**Proposed `pyve.toml`:**

```toml
[plugins.swift]               # out-of-tree per concept doc R6; design exploration

[env.root]                    # project-guide host (N.ao) — Pyve's "good work on any project" floor
purpose = "utility"
backend = "venv"

[env.app]
purpose  = "run"
backend  = "xcode"            # CLI-buildable via xcodebuild; project scaffoldable (XcodeGen / swift package init)
languages = ["swift", "objective_c"]
frameworks = ["swiftui", "xctest"]
app_type = "mobile"
packaging = "mobile_app"
require_min_version = { xcode = "15.0", swift = "5.9" }   # the un-installable-toolchain check
manual_steps = [
  "One-time: enroll the Apple ID in the Apple Developer Program; accept agreements (web portal)",
  "In Xcode → Signing & Capabilities, select your Development Team (enables automatic signing)",
  "Physical-device runs only: trust the developer cert on the device",
]

[env.testenv]
purpose  = "test"
backend  = "xcode"
languages = ["swift"]
frameworks = ["xctest", "swiftlint", "swiftformat"]       # one list, mixed kinds (S14)
default  = true
```

**What works:** the whole project is **text and generatable** — `.swift`, `Package.swift`, `Info.plist` (XML), and even `project.pbxproj` (verbose NeXTSTEP-style plist, painful to hand-merge but not binary). So a future Swift plugin's `init` hook can scaffold a template app (the "adapter" pattern — XcodeGen / Tuist / `swift package init`). Build, test, and simulator runs are **CLI-drivable**: `xcodebuild -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15' build test`, `swift test`, `xcrun simctl`. None of those are manual.

**What feels forced (and the fix):** classifying `xcode` as a *check-only* backend (S6 as written, which named `xcode`/`android-sdk` as its flagship examples) implied "Pyve does nothing here — the workflow is manual." That's false: Pyve can scaffold and can drive `xcodebuild`/`swift test`/`simctl`. The only thing Pyve genuinely cannot do is **install Xcode** (a multi-GB Mac App Store download + license acceptance), and the only irreducibly-human seam is **signing/enrollment** (Apple-issued certs `.p12` and provisioning profiles `.mobileprovision` — CMS-signed blobs, not hand-editable). KMP (Example 8) shows the same shape: Gradle generates and builds the iOS framework; only signing + the final device run need Xcode the app.

**Question surfaced:**
- **S6 re-revision (→ S16):** "check-only" is an **install-posture** ("Pyve verifies the toolchain but can't install it"), *orthogonal* to scaffolding (text files, automatable) and to building/testing (CLI tools). The un-installable fact rides the advisory `require_min_version` field; the backend itself is **cache-backed** (`xcodebuild` produces a DerivedData cache; SwiftPM caches deps). `manual_steps` carries only the human seam (signing/enrollment). `swiftpm` is plainly cache-backed (cargo's twin).

### Worked §4 env specs — the three "carry Pyve anywhere" stacks (O4 validation)

The locked O4 vocabulary expressing each named cross-ecosystem case end-to-end. (The vocabulary *data* is Pyve-owned in [env-dependencies-template.md](project-guide-requests/env-dependencies-template.md) §2 / [wizard-env-contract.md](project-guide-requests/wizard-env-contract.md) §B; these are validation *instances*.)

**Rust service:**
```yaml
spec_version: "3.0"
project: my-rust-service
description: Axum HTTP service; cargo build/test, clippy+rustfmt gate, container artifact.
envs:
  root:    { purpose: utility, backend: venv,  default: false, path: ".", languages: [python], frameworks: [none], app_type: none }   # project-guide host
  app:     { purpose: run,     backend: cargo, default: false, path: ".", languages: [rust], frameworks: [none], app_type: service, packaging: container }
  testenv: { purpose: test,    backend: cargo, default: true,  path: ".", languages: [rust], frameworks: [clippy, rustfmt], app_type: service, packaging: none }
```

**Ruby / Rails app:**
```yaml
spec_version: "3.0"
project: my-rails-app
description: Rails web app; bundler-managed, RSpec suite, RuboCop gate, container artifact.
envs:
  root:    { purpose: utility, backend: venv,    default: false, path: ".", languages: [python], frameworks: [none], app_type: none }
  app:     { purpose: run,     backend: bundler, default: false, path: ".", languages: [ruby], frameworks: [rails], app_type: web, packaging: container }
  testenv: { purpose: test,    backend: bundler, default: true,  path: ".", languages: [ruby], frameworks: [rspec, rubocop], app_type: web, packaging: none }
```

**Swift iOS app:**
```yaml
spec_version: "3.0"
project: my-ios-app
description: SwiftUI iOS app; xcodebuild build/test, SwiftLint/SwiftFormat gate, signed mobile_app.
envs:
  root:
    purpose: utility
    backend: venv               # project-guide host
    default: false
    path: "."
    languages: [python]
    frameworks: [none]
    app_type: none
  app:
    purpose: run
    backend: xcode              # cache-backed (S16); xcodebuild + DerivedData cache
    default: false
    path: "."
    languages: [swift, objective_c]
    frameworks: [swiftui, xctest]
    app_type: mobile
    packaging: mobile_app
    require_min_version: { xcode: "15.0", swift: "5.9" }
    manual_steps:
      - "Enroll the Apple ID in the Apple Developer Program; accept agreements (web portal)"
      - "Select a Development Team in Signing & Capabilities (enables automatic signing)"
      - "Trust the developer cert on the device for physical-device runs"
  testenv:
    purpose: test
    backend: xcode
    default: true
    path: "."
    languages: [swift]
    frameworks: [xctest, swiftlint, swiftformat]
    app_type: mobile
    packaging: none
```

A line worth recording: **`axum` is `frameworks: [none]` but `rails`/`flask` are frameworks** — the membership test is "does knowing it let Pyve supply a command?" (`rails server` / `flask run` yes; `axum` is just `cargo run`). That keeps the app-framework roster principled rather than "every web library."

---

## Synthesis — design decisions emerging from the examples

### S1. `env` is a **materialization**, not a run surface (Q5)

The number of `[env.<name>]` blocks in `pyve.toml` is the number of *distinct dependency closures*, not the number of "things you can do."

- Examples 2, 9: multiple run targets sharing one closure → one env.
- Example 4: two ecosystems with separate dep closures → two envs (`root` + `web`).
- Example 3: one closure, two materialization stages (conda → pip) → still one env.

**Implication for the contract:** `purpose: run` is appropriate for an env whose primary identity is the runtime of a deployed/executed artifact (Example 4's `web`, Example 8's `android`). For a project where running the code is a normal invocation of the dev env, `purpose: utility` is the right answer and there is no separate `[env.app]`. Pyve docs (N-6) need to make this explicit; otherwise users will reflexively create one env per "thing they can run."

### S2. `backend` is a singleton per env (Q4)

Layering (micromamba's conda → pip, Electron's Node → Chromium) is internal to the backend-provider implementation. From `pyve.toml`'s POV: one `backend = "<name>"` per env.

**Implication for the contract:** the backend-provider hook surface needs to be expressive enough that providers can compose internal stages. Concretely, `init` and `update` hooks may run multiple subprocesses; the contract just requires they leave the env coherent at the end.

### S3. Drop the `role` field; infer spatial owner from `path` (Q1 + Q2)

There is no `role = "host" | "visitor"` in `pyve.toml`. The plugin with `path = "."` (explicit or default) owns the project root for composition purposes. Other plugins have explicit sub-paths. The terminology debate (host vs root vs anchor) is eliminated by removing the explicit declaration.

**Implication for the contract:** the registry loads plugins in declared order from `pyve.toml`; the activation-hook composer puts plugin contributions in their `path` order (whoever's at `.` goes first; others append). No `role` enum.

### S4. Host cardinality = zero-or-one (Q3)

Zero or one plugin may have `path = "."`. Two would be a conflict (`pyve init` flags it). Zero is fine (Examples 5: docs site; the single-plugin implicit-Python rule covers most cases).

**Implication:** `pyve init` validates the manifest: at most one plugin without an explicit `path` (or with `path = "."`); error if violated.

### S5. Single-plugin implicit Python (Q1 corollary)

When `[plugins.*]` is absent from `pyve.toml`, the Python plugin is implicitly active at `path = "."`. This covers Examples 1, 2, 3, 5, 6, and 9 (for projects that omit `[plugins.node]` because there's no Node surface). Most pyve projects today never need to write a `[plugins.*]` block.

**Implication:** the migration command (`pyve self migrate`) does NOT emit a `[plugins.*]` block for projects that have only Python surfaces. The implicit-Python rule means migrated pyve.toml files stay minimal.

### S6 (revised). Three backend categories: project-virtualized, cache-backed, check-only (Q6)

The original "materializing vs check-only" dichotomy is too coarse — most modern languages (Rust, Go, Java, Scala, C#, Ruby, …) cache dependencies in a shared user-level location rather than per-project. Three categories cover the design space, surfaced by Examples 7–11:

- **Project-virtualized**: per-project state under `.pyve/envs/<name>/` (or `.venv/`, `node_modules/`); PATH activation required for invocations to resolve project-pinned binaries. Examples: `venv`, `micromamba`, `pnpm`, `npm`, `yarn`. The traditional Pyve case.
- **Cache-backed (lockfile-driven)**: shared user-level dependency cache (`~/.cargo/registry/`, `~/go/pkg/mod/`, `~/.m2/`, `~/.gradle/caches/`, `~/.nuget/packages/`, `~/.gem/`, …) + project-local lockfile (`Cargo.lock`, `go.sum`, etc.). No PATH activation needed — the language build tool resolves deps from the cache via the lockfile. Examples: `cargo`, `go`, `dotnet`, `maven`, `gradle`, `sbt`, `bundler`, `conan`.
- **Check-only**: Pyve verifies presence and version; no install action by Pyve. Examples: `xcode`, `android-sdk`, system `gcc`, `make`, `cmake`, `homebrew`, `apt`, `docker`.

The contract's hook semantics differ meaningfully across categories:

- **`init`**: project-virtualized creates the env dir; cache-backed runs `cargo fetch` / `go mod download` / `dotnet restore` (populates shared cache + writes/updates lockfile); check-only verifies presence and version, errors loudly if missing.
- **`purge`**: project-virtualized removes `.pyve/envs/<name>/` entirely; cache-backed removes only project-local build dirs (`target/`, `build/`, `obj/`) — **never** the shared cache (co-owned with other projects); check-only is a no-op. An optional `pyve purge --deep` could prompt to invoke the language tool's own cache-clean (`cargo clean`, `go clean -modcache`) with explicit confirmation.
- **`activation` (`.envrc`)**: project-virtualized adds `bin/` to PATH; cache-backed adds nothing (or just the project's `target/release/` if a binary is built and the user wants it on PATH); check-only contributes nothing.

**Implication for v3.0 scope:** v3.0 ships only project-virtualized backends (Python's `venv` + `micromamba`, Node's `pnpm`/`npm`/`yarn`) per concept doc R6 (in-tree plugins only). The cache-backed and check-only categories are **designed in but unexercised** — schema accommodates them, no in-tree plugins ship them in v3.0. First cache-backed backend lands in a post-v3.0 phase (Rust or Go are natural candidates given community pull); first check-only backend lands when mobile / Docker / Homebrew plugins arrive.

**Caveat:** this expansion broadens Pyve's identity from "virtual environment manager" to "environment-and-toolchain orchestration across virtualized, cache-backed, and check-only ecosystems." The brand-descriptions doc revision in N-6 will need to reflect this — see N.s in the story-breakdown adjustments table below.

### S7. `manual_steps` is an optional advisory field on `[env.<name>]` (Q7)

A string-list on the env that surfaces in `pyve check`, `pyve status`, and `pyve env list`. Not a contract hook (Pyve can't run them). Use case: KMP iOS targets, future iOS-framework tooling, any env where Xcode UI / mobile device interaction is unavoidable.

**Implication:** optional schema field; default behavior is empty. v3.0 ships the schema field and the surfacing in `check` / `status`; no contract changes.

### S8. Deploy declarations live in `[deploy.<env-name>]`, not in `[env.*]` (Q8)

A new top-level `[deploy.<env-name>]` table cross-references the env it deploys, with its own provider configuration. The `purpose:` vocabulary stays as (run/test/utility/temp) — no `purpose: deploy`.

**Implication for N-5:** the `pyve deploy` lifecycle hook reads `[deploy.<env-name>]` for the named env. Whether a provider ships in v3.0 or the verb is reserved (concept doc Q6) remains an N-5 decision; this spike only settles the schema location.

### S9. `[env.*]` has a core required surface + provider-private extension space

Core fields: `purpose`, `backend`. Provider-private fields (everything else: `manifest`, `requirements`, `extra`, `inherit`, `path`, `default`, `require_min_version`, `manual_steps`, …) are interpreted only by the relevant backend-provider. Core never reads provider-private keys.

**Implication for the contract:** hook 1 ("Manifest namespace — Core does not interpret plugin-private keys") is load-bearing. The contract's `init` hook receives the entire `[env.<name>]` block and decides what to do with provider-private fields.

### S10. Runtime version resolution is plugin-internal; each plugin owns its own precedence chain (Q9)

Pyve does not impose a single runtime-version-manager precedence at the framework level. Each plugin's `init` hook handles "make the right runtime version available" using *that ecosystem's canonical precedence chain*:

| Plugin | Canonical precedence chain |
|---|---|
| Python | asdf > pyenv > system |
| Rust | **rustup** > asdf > system |
| Node | **nvm** > **fnm** > **volta** > asdf > Homebrew / system PATH |
| Java / Scala | **SDKMAN** > asdf > system |
| C# / .NET | asdf > system (Microsoft installer) |
| Go | asdf > gvm > system |
| Ruby | **rbenv** > asdf > system |

The **Node row is the one chain v3.0 actually ships** — implemented as `node_runtime_manager()` in [lib/plugins/node/runtime_detect.sh](../../lib/plugins/node/runtime_detect.sh) (Story N.v): `nvm > fnm > volta > asdf > Homebrew / system PATH`, where the final tier is the bare-`command -v node` fallback (any active manager shims `node` onto PATH; absent all of them, a Homebrew/system install resolves the same way). Each manager tier honors its own `PYVE_NO_{NVM,FNM,VOLTA}_COMPAT` opt-out, and the asdf tier uses a Node-specific `_is_asdf_node_active()` rather than the Python-context `is_asdf_active()`. The Python row ships via `lib/env_detect.sh`; every other row in the table is illustrative of a future plugin, not yet implemented.

asdf is one widely-applicable manager (asdf-plugins exist for most ecosystems) and is a common second-tier fallback because of that universality — but it isn't privileged at the framework level. The canonical tool per ecosystem (rustup, SDKMAN, nvm, rbenv) is what the plugin tries first.

Project-level runtime pinning uses each ecosystem's native convention: `.tool-versions` (asdf-style; what Pyve writes today for Python via `pyve python set`), `rust-toolchain.toml` (rustup), `.nvmrc` / `.node-version` (Node), `.ruby-version` (rbenv), etc. The Python plugin writes `.tool-versions` because asdf is Python's effective canonical pinning today in Pyve's audience; a future Rust plugin would write `rust-toolchain.toml`; a future Node plugin would write `.nvmrc`. Per-env overrides (rare; e.g., a testenv pinning Python 3.13 while main uses 3.12) use a provider-private field on `[env.<name>]` like `python_version = "3.13"`.

`pyve.toml` schema does **not** grow version-manager-specific fields. The precedence chain is implementation detail of each plugin's `init` hook. `is_asdf_active()` remains the single gate for asdf-aware behavior (existing Pyve invariant per [project-essentials.md](project-essentials.md)); the Python plugin owns its callsites, and a future Rust plugin would have its own `is_rustup_active()` etc.

**Implication for the contract:** no version-resolution hook. Runtime resolution is internal to each plugin's `init`. The current `lib/env_detect.sh` continues to expose Python-ecosystem detection (asdf/pyenv/system); other plugins implement their own equivalent helpers as needed.

### S11. Language flavors live in the `languages` structured attribute, orthogonal to backend (Q10)

A "language flavor" is a programming language used within an env that is not itself the basis for the backend choice. Examples: TypeScript on a Node backend; Kotlin on a Java/Gradle backend; mypy/strict typing on a Python venv; mixed C and C++ in a CMake project. These don't change the backend (the materialization mechanism) — they change the *kind of code* in the env.

The concept doc § 4.1 already lists `languages` as a structured attribute per `[env.<name>]`. This spike confirms the axis is real and correctly placed: language flavors are metadata for `pyve check` / `pyve status` / docs (e.g., "this env uses TypeScript — ensure `tsc` is in your deps"); they are not backends or plugins.

```toml
[env.web]
purpose = "run"
backend = "pnpm"
languages = ["typescript"]    # the flavor — not a backend
frameworks = ["sveltekit"]
```

**Confirmed-to-fit variations** (no new examples needed in the body — listed here so future contributors don't relitigate):

- **TypeScript on Node**: `languages = ["typescript"]`, backend stays `pnpm` / `npm` / `yarn`. **Deno** and **Bun**, when added, would be separate *backend-providers* within the Node plugin (similar to `venv` vs `micromamba` within the Python plugin) — they're alternative JS runtimes with their own dep models, not language flavors.
- **Kotlin on JVM**: `languages = ["java", "kotlin"]`, backend stays `gradle` / `maven`.
- **Scala on JVM**: `languages = ["scala"]`, backend stays `sbt`.
- **mypy on Python**: `languages = ["python"]`, backend stays `venv`. mypy is a dev-tool dependency, not a language.
- **Mixed C/C++ in CMake**: `languages = ["c", "c++"]`, backend stays the build system (`cmake`-driven, with the underlying compiler invoked indirectly).
- **Ruby**: same Python/asdf shape — cache-backed `bundler` backend, `languages = ["ruby"]`, version-manager precedence `rbenv > asdf > system` per S10.

**Implication for the contract:** no change. `languages` is a core schema attribute interpreted only as advisory metadata; plugins may read it to inform diagnostics (e.g., the Node plugin's `check` hook can warn if `languages` includes `typescript` but `tsc` isn't in `package.json`).

---

## Known partial fits and out-of-scope ecosystems

Stress-testing the design against ecosystems beyond the original 9 examples surfaced one ecosystem class that fits **partially** — the architecture covers most of it, but one specific gap in the `purpose:` vocabulary remains. Documenting it here so future contributors don't relitigate.

### Embedded / hardware-deployment ecosystems (Arduino, PlatformIO, ESP-IDF, Mbed)

**What fits:**

- **Multi-target builds** (one sketch → ESP32 + RP2040 + AVR): one env per target, identical to KMP (Example 8).
- **PlatformIO as a project-virtualized backend**: `backend = "platformio"` materializes `.pio/` per project with downloaded toolchains, libraries, and build cache. Project-virtualized per S6 (revised).
- **Cross-compilation toolchain provision** (xtensa-esp32-elf-gcc, ARM gcc, AVR gcc): handled internally by the build tool's board-core packages. Transparent to Pyve — same posture as micromamba's bundled Python.
- **Hardware interaction quirks** (DTR/RTS auto-reset, BOOT button holds, USB enumeration races): covered by `manual_steps` (S7).
- **Multiple build tools per ecosystem** (Arduino CLI vs PlatformIO vs ESP-IDF vs Mbed): separate backend-providers within an embedded plugin, per S9 — same shape as Java's Maven/Gradle.
- **Version management of board cores and framework versions**: handled inside `platformio.ini` / Arduino Boards Manager, internal to the plugin's `init` hook per S10.

**The gap.** The `purpose:` vocabulary (run/test/utility/temp) has no slot for "build an artifact that will be deployed to physical hardware." Three options were considered:

- **`purpose: run`** is misleading — the env doesn't run on the dev machine; it produces firmware that gets flashed to hardware.
- **`purpose: deploy`** conflicts with S8 (deploy lives in `[deploy.<env-name>]`, not as a `purpose:` value).
- **`purpose: utility`** is honest but loses semantic clarity — the env exists specifically to build firmware, not as general dev tooling.

**Future-phase candidate**: add **`purpose: embedded`** to the vocabulary when an embedded plugin actually ships. ("Embedded" is the purpose — the *kind of env*; "firmware" is the *kind of artifact* — keep the vocabulary about the env, not the output.) This is **not a v3.0 schema change** — defer until an embedded plugin is actually being planned.

**Out of scope for v3.0**: embedded plugins remain out of scope per concept doc R6 (in-tree plugins only; Python + Node/SvelteKit ship in v3.0). The gap is documented here so a future embedded-plugin author has the design context without re-deriving it.

**Out of Pyve's model entirely**: physical hardware device state (`/dev/ttyUSB0` must be present, specific board must be connected, USB hub power adequate). `manual_steps` (S7) advises; the user owns the USB / device-tree reality. Same posture as not abstracting "the developer has a display attached."

### Raspberry Pi (dual-nature)

The Pi exposes two distinct usage patterns; the architecture handles them asymmetrically:

- **Pi as a general-purpose Linux computer** (the common case): fits existing categories trivially. The Pi runs Python / Node / Docker / etc. directly; `backend = "venv"` (or `"pnpm"`, …) works the same as on Ubuntu / macOS. No special handling; not actually an "embedded" case from Pyve's POV.
- **Pi as a deployment target** (cross-compile or build on dev machine, deploy via SSH/scp): mirrors the embedded `purpose:` vocabulary gap above. Either reuse the future `purpose: embedded`, or leave it to `pyve deploy` (N-5) once that surface matures. v3.0 doesn't address this case directly; users continue to use SSH-based deployment workflows outside Pyve.

The Pi case mostly demonstrates that **"embedded vs general-purpose" is a usage choice, not an ecosystem property** — the same hardware can be either depending on how it's used.

---

## Recommended N-2 story breakdown adjustments

The spike's conclusions update the N-2 plan from what was sketched before this session:

| Prior story | Adjustment from spike |
|---|---|
| **N.k** Plugin contract + registry skeleton | Update — registry reads `[plugins.*]` from pyve.toml with the implicit-single-plugin-Python default (S5); validates `path = "."` cardinality (S4); no `role` field (S3) |
| **N.k.1** `[plugins.*]` schema | Update — schema has just `path` (no `role`); add `pyve.toml` validation per S4 |
| **N.l** Backend-provider registry + abstraction | Update — provider category (project-virtualized / cache-backed / check-only) is an attribute of the provider, per revised S6; v3.0 ships only project-virtualized providers; `init` / `purge` / `activation` hook semantics differ by category and the contract must accommodate all three |
| **N.m** PC-1 input safety validator | Unchanged — still resolves PC-1 |
| **N.n** Python plugin module + scaffold-time detection | Unchanged in shape — detection is scaffold-time only. Internal note: Python plugin's runtime resolution follows the asdf > pyenv > system precedence per S10; `is_asdf_active()` stays the single gate |
| **N.o** Python plugin — init/purge/update hooks | Add task: implement env-block validation per S9 (core vs provider-private separation); add task: read `languages` advisory attribute per S11 (informational only — no behavior change in v3.0 for Python) |
| **N.p** Python plugin — check/status/run/test hooks | Add task: surface `manual_steps` (S7) in `pyve check` / `pyve status` output |
| **N.q** Python plugin — activation hook | Unchanged |
| **N.r** Python plugin — `.gitignore` + smart-purge hooks | Unchanged |
| **N.s** End-to-end regression sweep + doc updates | Expand: doc updates per the new env-as-materialization framing (S1), backend-singleton rule (S2), implicit-Python rule (S5), revised three-category backend taxonomy (S6 revised), per-plugin version-manager precedence (S10), `languages` axis (S11), and the brand identity shift ("Pyve orchestrates environments AND toolchains across virtualized, cache-backed, and check-only ecosystems"). N-6 will revisit holistically; N.s captures the immediate updates |
| **N.t** Append project-essentials entries for N-2 | Expand: capture S1–S11 as Phase N invariants; include the embedded-`purpose:` gap and the `purpose: embedded` future-phase candidate (from the *Known partial fits* section) so a future embedded-plugin author finds the design context |

**New stories not in the prior breakdown** (proposed additions):

- None required. The spike's conclusions slot into existing N-2 stories. `manual_steps` (S7), the deploy table (S8), the `languages` attribute (S11), and the cache-backed / check-only backend categories (S6 revised) are *schema or design additions* that the manifest helper and contract already accommodate; no new stories needed for them in N-2 because v3.0 only exercises the project-virtualized Python providers (`venv` + `micromamba`).
- The `[deploy.<env-name>]` table per S8 belongs to **N-5** (`pyve deploy` lifecycle hook); v3.0 just reserves the schema slot.
- First cache-backed plugin (Rust or Go candidates) and first check-only plugin (mobile / Docker / Homebrew) land in **post-v3.0 phases**, not Phase N. Phase N's scope is the architectural contract that accommodates them, not the implementation of them.

---

## N-3 evidence: contract-holes synthesis (Story N.ab.4)

Subphase N-3 stood up the Node/SvelteKit plugin as the second reference plugin — the proof obligation that the N-2 contract generalizes beyond Python. This section synthesizes the contract-design holes surfaced across the whole subphase (N.t–N.ab.3) so the record is in one place. The load-bearing finding: **exactly one hole surfaced, it was caught at the first story (N.t) and deferred to N-4 by design; every subsequent N-3 story composed cleanly with no new holes.**

**Hole 1 — root-collision: a root-level `package.json` beside a Python project is not expressible as a valid polyglot manifest (N.t).** Surfaced in [stories.md](stories.md) Story N.t's decision note. Two N.k registry rules collide when `pyve init` tries to auto-write `[plugins.node]` from root-level detection:

- **S5 (implicit-Python):** the registry implicit-loads Python only when *zero* `[plugins.*]` are declared. The moment init writes `[plugins.node]`, Python must *also* be declared explicitly or it stops loading on every later command.
- **S4 (host cardinality = zero-or-one):** Python and Node both at `path = "."` is a hard cardinality error — `plugin_load_all_from_manifest` errors on every command. The polyglot model assumes distinct paths (Node at `src/frontend`, …), which root-only detection can't discover.

**Resolution:** N.t made `pyve init`'s Node consult *advisory-only* (detect + advise, never mutate `pyve.toml`). The composed multi-plugin scaffold — prompt for / infer a distinct Node sub-path, emit explicit `[plugins.python]` + `[plugins.node]` — is **Subphase N-4** (composed activation) work. This is a deliberate scope boundary, not an unresolved defect: N-3's job was to *surface* it, which it did at the earliest possible story.

**No further holes — the lifecycle and composition proofs came back clean.** Every other N-3 story drove its hook surface against realistic fixtures with **zero production-code changes**:

- **N.u–N.aa** (backend-providers, runtime resolution, init/purge/update, check/status/run/test, activation, `.gitignore`/smart-purge, SvelteKit detection) — each hook implemented against the N.k contract signatures with the same shape as the Python plugin; reviewers can diff the two side-by-side.
- **N.ab.1** (Node-at-root lifecycle drive) — the full Node hook surface composed end-to-end against a SvelteKit fixture; no contract hole.
- **N.ab.2** (polyglot Python+Node, distinct paths) — both plugins loaded with no S4 error and fired their hooks independently against their own paths; no contract hole.
- **N.ab.3** (composed `.envrc` non-interference + visitor-path activation) — the Python root snippet and the Node `src/frontend` section concatenate into one `.envrc` body, each passing PC-1 individually and composed, with distinct non-interfering `PATH_add`s; no contract hole.

A clean result across N.u–N.ab.3 is the intended positive finding: the N-2 contract (hook signatures, backend-provider registry, PC-1 activation gate, path-awareness) generalizes to a non-Python ecosystem without amendment. The single hole (root-collision auto-write) is a *composition* concern, which is precisely what N-4 owns.

**Scope note.** N-3 proved the *hook surface* generalizes; it did not (and structurally could not) exercise the `pyve init` *materialization* flow. A second, different-axis composition gap — init is still Python-first, so a Node-only project gets an unwanted Python env — was surfaced later by the [N.ao spike](spike-n-ao-project-guide-provisioning.md) and is owned by the still-open [Subphase N-6](stories.md). "Contract generalizes without amendment" ≠ "composed init is shipped."

---

## Addendum (2026-06-04): env-spec vocabulary model — S12–S15

**Provenance.** Drafted during the N.ao-era design conversation on the `project-guide` ↔ pyve handoff ([wizard-env-contract.md](project-guide-requests/wizard-env-contract.md)). These extend the S-series with the *attribute-vocabulary* decisions (`purpose`/`backend`/`packaging`/`frameworks`/`languages`/`app_type`) that S1–S11 left under-specified, and **revise Example 8 / S6** on one point (KMP). S1–S11 above are the N-2 point-in-time record and are unchanged; this is the later refinement.

The concrete closed enumeration is **not duplicated here** — it is Pyve-owned in [env-dependencies-template.md](project-guide-requests/env-dependencies-template.md) §2 (runtime mirror: `VALID_*` in `lib/pyve_toml_helper.py`, follow-up F6), reproduced for the cross-repo audience in [wizard-env-contract.md](project-guide-requests/wizard-env-contract.md) §B. This section records the *rationale and shape*, not the data.

### Settled

**S12. Pyve owns the env-spec vocabulary; closed, versioned, forward-looking; the trichotomy.** Pyve is the sole owner of the schema, `spec_version`, and the closed set of legal values for every axis. `project-guide` consumes; it never invents. The vocabulary is *forward-looking* — it enumerates values Pyve recognizes but does not yet implement, as no-ops. Every value resolves to exactly one of: **known + implemented** → activated normally; **known + no-op** → recorded + advisory, never blocks; **unknown** → spec violation = bug → hard error + abort. No fourth "guess" branch. Current enforcement: only `purpose` is closed-set-validated today (`VALID_PURPOSES`); extending the trichotomy to the other axes is follow-up **F6**.

**S13. Vocabulary membership = mechanical activation.** A value earns a place iff knowing it lets Pyve *do* something — pick/validate a backend or packaging, supply a build/serve/test/lint command, or cross-check languages — now, or as a declared no-op on the roadmap. Pure libraries with no env-management activation of their own (`jinja2`) are excluded (they belong in a dependency manifest). **Distance from Python/Node is irrelevant; activation profile is everything.**
- **Revises Example 8 / S6:** `kotlin_multiplatform` (and `spring`, `j2ee`) **stay** as framework no-ops. KMP has a rich profile (a `gradle` backend, JDK/Xcode/Android-SDK toolchain, `mobile_app`/`binary`/`library` packaging, `./gradlew build`, kotlin/swift/java). Its inclusion is the spec *doing its job* — surfacing the need for a future `gradle`/`maven` backend (the way gitbetter's `homebrew`/`apt` surfaced §8). Example 8's "mobile is out-of-scope / check-only" lean is narrowed: mobile *toolchains* stay unimplemented (no-op), but the framework is recognized, not dropped.

**S14. `frameworks` is one list attribute of registry entries — not three attributes.** Each canonical framework is defined once in Pyve's closed registry with `kind` (app | test | lint — a coarse display grouping; `lint` = the read-only code-quality gate covering linters + format-check + type-check, per O3), `status` (implemented | no-op), and the metadata the verb hooks consult: declarative attributes (`backend`, `packaging`, `languages`) plus the command it contributes per verb (`serve`/`test`/`lint`/`format`/`package`; `build` is **not** a verb — subsumed by `package`, per O3). The `kind` is *intrinsic* — looked up, never a filing decision pushed onto the author. So `frameworks = ["sveltekit", "vitest", "ruff", "mypy"]` mixes kinds in one list; the env's **plugin hook** dispatches by reading them — a framework is never invoked directly (see O3 for the full `backend × language × framework` composition). `none` is the explicit "no framework activation" (framework-less envs are first-class); an unrecognized value still hard-errors (S12). Tooling renders the flat list grouped-by-kind for readability.

**S15. `packaging` is a structured attribute = the artifact kind Pyve materializes.** *(axis CONFIRMED)* `packaging ∈ {container, static, server, serverless, package, binary, mobile_app, lock_bundle, none}` — the *form* a materialize step produces for an env. Distinct from two things Pyve deliberately does **not** store: **`build_target`** (the build-time platform/runtime you build *for* — `linux/amd64`, a SvelteKit adapter, a Rust target triple; usually a defaulted sub-detail) and **`deploy_target`** (the *destination* you ship to — GHCR, Vercel, PyPI, k8s; out of scope — Pyve materializes, external CD ships). Absorbs the former `ios_app`/`android_app` framework entries → `packaging: mobile_app`.

**S16. "Check-only" is an install-posture, not a build-verdict — `xcode`/`swiftpm`/`android_sdk` are cache-backed (revises S6).** *(Triggered by Example 12, 2026-06-04.)* S6 (revised) named `xcode`/`android-sdk` as flagship *check-only* backends, conflating two independent facts: **(a)** Pyve cannot **install** the toolchain (a multi-GB Xcode download; an Android SDK licence), and **(b)** whether Pyve can **build** with it. (b) is false as stated — `xcodebuild` / `swift test` / `xcrun simctl` / `gradle` are all CLI-drivable, and the project files are text (scaffoldable via an adapter: XcodeGen / Tuist / `swift package init`). So: **`xcode`, `swiftpm`, and `android_sdk` are cache-backed** (CLI build tools, dep/DerivedData caches, optional project-local build dirs). The un-installable-toolchain fact rides the advisory **`require_min_version`** field + a `pyve check` verification, *not* a backend category. **`manual_steps`** carries only the irreducibly-human seam — for iOS, signing/enrollment (Apple-issued `.p12` certs + `.mobileprovision` profiles, not hand-editable). This narrows **check-only** to the thin "presence-verified, Pyve runs no build" set (a bare `gcc`/`make`/`homebrew`/`apt` prerequisite). KMP (Example 8) is the same shape: Gradle builds; only signing + device-run need Xcode the app. **Refines S7:** `manual_steps` is for human-only seams, never for steps Pyve can CLI-drive.

**Example 8 completeness note — KMP web target.** *(2026-06-04.)* KMP also targets **Kotlin/JS** (browser + Node) and **Kotlin/Wasm** (`wasmJs` — what Compose Multiplatform for Web compiles to), beyond the Android / iOS / JVM targets Example 8 listed; Compose Multiplatform now spans iOS + Android + Desktop(JVM) + Web. **No model change** — the web target is just another env: `[env.web] backend = "gradle", app_type = "web", packaging = "static", languages = ["kotlin"], frameworks = ["kotlin_multiplatform"]`. It reinforces **S1** (one env per target/closure — each KMP target gets its own env, each producing its own `packaging`: `mobile_app` / `static` / `binary` / a JVM jar) and **S2** (the Gradle provider's internal Node/Yarn toolchain for Kotlin/JS — `kotlin-js-store/yarn.lock`, Gradle-managed `node_modules` — is opaque to `pyve.toml`, same shape as micromamba's conda→pip). It also gives `packaging: static` its first KMP exercise. Optional future design conversations (deferred, non-blocking, per S13): a `compose` / `compose_multiplatform` framework value distinct from the `kotlin_multiplatform` umbrella; a distinct `wasm` packaging value if `static` ever feels too coarse.

### Open (to be settled in follow-up design conversations)

- **O1 — `pyve deploy` → `pyve package` rename. [SETTLED 2026-06-04 — developer-ratified.]** The command *materializes* the `packaging`; it does not ship — so it is `pyve package`, with `deploy` reserved for a future ship step. Propagation is docs-only (no code exists yet) but **not a pure find-replace** (see O8). It touches: stories.md (phase theme line + the `## Subphase N-5` heading/body), the plan doc (the N-5 subphase/gap/technical rows, BC-6, out-of-scope #6), and the concept doc (§6 CLI DX, §7, the gap table, open-question Q6). Because re-theming the N-5 subphase + reconciling the plan doc is `plan_production_phase`'s job — **and the plan doc is still on the pre-N-6-insertion numbering** (the debt flagged in story N.ap) — this should ride a *single* `plan_production_phase` pass, not piecemeal edits in an implementation mode.
- **O8 — `[deploy.<env-name>]` (S8) vs `packaging` on `[env.*]` (S15). [SETTLED 2026-06-05 — developer-ratified.]** `packaging` + packaging-provider-private fields (e.g. `dockerfile`) on `[env.<name>]` **subsume** the table; S8's top-level `[deploy.*]`/`[package.*]` is **retired**. Rationale: S9 already established the core-vs-provider-private extension space on `[env.*]` (the backend reads `manifest`/`requirements` the same way), and O7's "one packaging per env" makes the env itself the key, so a parallel keyed table earns nothing. `pyve package [--env <name>]` reads the env block directly. Paired decision (concept Q6 / v3.0-window): v3.0 **reserves the verb + scaffolds the packaging-provider contract**, materializing **no** provider (mirrors the `pyve lint` verb being post-v3.0, O3). Drafted as Subphase N-5 stories **N.aq–N.as** in [stories.md](stories.md).
- **O2 — `app_type` roster. [SETTLED 2026-06-04.]** Added `service` (long-running non-web backend) and `library` (importable package, no app). Roster: `api, cli, service, library, desktop, mobile, embedded, script, web, none`. Reflected in template §2 + contract §B; runtime `VALID_APP_TYPES` lands with F6.
- **O3 — verb dispatch model (backend × language × framework) + the `lint` surface. [SETTLED 2026-06-04.]** **Verbs dispatch to the plugin/backend hook, not the framework** (the existing concept §5 contract) — but **execution composes both**: the **backend** always supplies the env/execution context (and owns dispatch + the lifecycle verbs), while for **code-exercising** verbs the **framework** supplies the command. Two verb classes:
  - **Env-lifecycle** (`init`/`purge`/`update`/`check`/`status`/`run`) → **backend-only**; frameworks contribute nothing.
  - **Code-exercising** (`test`/`lint`/`format`/`package`/`serve`) → **backend × framework**: the plugin's hook runs the framework-contributed command(s) in the backend's env. (`test` may ride a backend ecosystem-entrypoint default — `pnpm test`/`pytest`, framework behind it; `lint`/`format` have no universal entrypoint, so the framework supplies the command — the clearest "both".)

  A framework is **never invoked directly** — it is declarative env metadata (kind + the command it contributes per verb + implied `languages`/`packaging`/`backend`) that the hook *consults*. `packaging` is the *output noun*; the verb that produces it is `package` (O1). **`build` is not a verb** — one ecosystem command goes source → artifact (`cargo build` → binary, `python -m build` → wheel, `docker build` → container, `pnpm build` → static), subsumed by `package`; iterative builds are `pyve run <cmd>`. Lint is **multi-tool** (unlike `pyve test`'s single entrypoint): `pyve lint --env X` → X's plugin `lint` hook → runs every lint-contributing framework in X's `frameworks` (`ruff` → `ruff check`, `mypy`), aggregating pass/fail. A tool may contribute to multiple verbs (`ruff` → `lint` = `ruff check` **and** `format` = `ruff format`); `kind` is the coarse display grouping (primary verb) — this refines S14's "single-kind" framing: kind = display, contribution is per-verb. **`pyve lint` (code analysis) is distinct from `pyve check` (env health).** **Language is a third axis for `lint`/`format`:** one backend hosts several languages (the JVM runs Kotlin + Scala + Java under one `gradle` backend), each with its *own* linter/formatter (`ktlint`/`detekt` for Kotlin, `scalafmt`/`scalafix` for Scala, `google-java-format` for Java). So `lint`/`format` compose **(backend = context) × (language = partition) × (tool = command)**: `pyve lint` fans across the env's `languages`, running each language's declared tool in the backend's context. This **refines S11** — `languages` is not purely advisory for these verbs; it is the *coverage axis* (a declared language with no matching lint/format tool → warn). `test` usually rides one backend entrypoint (`gradle test` / `pnpm test` / `pytest`) that itself dispatches each language's test task, so it is less per-language at the pyve layer; `package`/`serve` stay backend/app-level and language-agnostic (`gradle build` → one jar regardless of how many JVM languages compile in). v3.0: lint-kind tools are recognized no-ops surfaced in check/status; the `pyve lint` verb is post-v3.0. **Resolved (a)+(b): no separate `format` or `typecheck` verb.** `pyve lint` is the single aggregated **read-only** code-quality gate — it fans per-language and runs each language's linter + format-**check** + type-check (`ruff check` + `ruff format --check` + `mypy` for Python; `ktlint` + `scalafmt --check` for Kotlin/Scala), CI-safe. The **mutating** side (auto-fix + format rewrite) is a flag — **`pyve lint --fix`** (runs the fixable subset: `ruff check --fix` + `ruff format` + `ktlint -F`) — never a silent side effect of plain `pyve lint`. The read-only/mutating split is the load-bearing distinction; "format" collapses into `lint` (check) + `--fix` (rewrite), and "typecheck" collapses into `lint` (read-only gate). **Net pyve verb set: `test`, `lint` (+`--fix`), `package`, `run`** (`serve` likely just a `pyve run` passthrough — TBD). Naming note: `pyve lint` covers more than style (format-check + types) because `pyve check` is already env-health; docs must say so.
- **O4 — Per-axis roster confirmation. [SETTLED 2026-06-04.]** The closed vocabulary is locked across all axes (data Pyve-owned in [env-dependencies-template.md](project-guide-requests/env-dependencies-template.md) §2, mirrored in [wizard-env-contract.md](project-guide-requests/wizard-env-contract.md) §B; not duplicated here). Decisions:
  - **Two classes, not a roadmap tier** — *implemented* (a real Pyve-surface integration today) vs *advisory* (recorded + surfaced in `check`/`status`, never materialized, never an error). *Advisory* is the single home for every not-yet-implemented value, regardless of roadmap status (the trichotomy's "known + no-op" class).
  - **Membership test = "meaningfully Pyve-able"** — a value is in the closed list iff Pyve can initialize / manage / invoke it, or faithfully record it as part of the technical spec. Pure libraries with no env-management activation (`jinja2`) are **out** → unknown → hard error. Mainstream-inclusive on purpose: Pyve does good work on any project (direnv, `project-guide`, an honest env spec) even when every backend in the spec is advisory.
  - **`backend`** completed to the full S6 taxonomy so any mainstream ecosystem is expressible — *project-virtualized* (`venv`/`micromamba`/`pnpm`/`npm`/`yarn` implemented; `uv`/`poetry`/`conda`/`bun`/`deno` advisory), *cache-backed* (`cargo`/`go`/`bundler`/`swiftpm`/`xcode`/`android_sdk`/`gradle`/`maven`/`sbt`/`dotnet`/`conan`/`cmake` advisory — incl. the S16 recategorization), *check-only* (`homebrew`/`apt`/`docker`/`podman`), plus `none`.
  - **`languages`** dropped `lua`/`sql`, added `go`/`scala`, machine-safe snake_case throughout (`cpp`, `c_sharp`, `objective_c`).
  - **`frameworks`** carry an intrinsic `kind` (app/test/lint) with broad rosters across Python/Node/Ruby/Swift/JVM/Rust/Go/C; pruned `jinja2`; moved `ios_app`/`android_app` → `packaging: mobile_app`; added `django`/`rails`/`sinatra`/`swiftui`/`uikit` (app), `rspec`/`minitest`/`xctest`/`junit`/`vitest`/`jest`/`mocha`/`playwright`/`cypress` (test), and the full lint set.
  - **`packaging`** axis added (S15); **`app_type`** per O2.
  - **Two advisory §4 fields added — `manual_steps` (S7) and `require_min_version`** — so signing seams + un-installable-toolchain pins ride the machine surface.
  - Validated by **Example 12** + the three worked §4 specs above. Runtime enforcement of the trichotomy across all axes remains follow-up **F6**.
- **O5 — `build_target` / `deploy_target` as future no-op axes.** Deferred until Pyve grows platform-aware builds / CD awareness; not added now (would be recorded-but-unactable).
- **O6 — `lock_bundle` vs `pyve lock` overlap.** Whether "the deployable *is* the pinned lock set" is a distinct `packaging` value or just what `pyve lock` already emits — unresolved.
- **O7 — Cardinality rules.** e.g. "≤ 1 `kind: app` framework per env," "exactly one `packaging` per env" — to be defined with F6.

---

## Related

- [wizard-env-contract.md](project-guide-requests/wizard-env-contract.md) — the project-guide ↔ pyve handoff contract; reproduces the closed vocabulary (§B) and the drift-reconciliation model.
- [spike-n-ao-project-guide-provisioning.md](spike-n-ao-project-guide-provisioning.md) — provisioning spike + F-list (incl. F6, closed-vocabulary + no-op trichotomy enforcement).
- [phase-n-framework-plugin-architecture.md](phase-n-framework-plugin-architecture.md) § 4–5 — the schema and contract concept this spike refines.
- [phase-n-plugin-architecture-named-envs-plan.md](phase-n-plugin-architecture-named-envs-plan.md) — Phase N plan; N-2 story breakdown will be updated post-spike approval.
- [stories.md](stories.md) — Phase N section; Subphase N-2 stories will be appended once this spike is approved and the design decisions are locked in.
