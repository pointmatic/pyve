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
| Node | **nvm / fnm / volta** > asdf > system |
| Java / Scala | **SDKMAN** > asdf > system |
| C# / .NET | asdf > system (Microsoft installer) |
| Go | asdf > gvm > system |
| Ruby | **rbenv** > asdf > system |

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

## Related

- [phase-n-framework-plugin-architecture.md](phase-n-framework-plugin-architecture.md) § 4–5 — the schema and contract concept this spike refines.
- [phase-n-plugin-architecture-named-envs-plan.md](phase-n-plugin-architecture-named-envs-plan.md) — Phase N plan; N-2 story breakdown will be updated post-spike approval.
- [stories.md](stories.md) — Phase N section; Subphase N-2 stories will be appended once this spike is approved and the design decisions are locked in.
