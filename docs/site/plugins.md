# Plugins

Pyve's environment logic lives in **language plugins** behind a single contract. Each plugin knows how to detect its ecosystem, materialize its environments through one or more backends, activate them via direnv, contribute `.gitignore` patterns, and report health. The Pyve core knows none of that ecosystem detail — it just fans each command across the active plugins and composes the results.

This is what makes Pyve polyglot: the same `pyve init` / `check` / `status` / `purge` you run on a Python project runs on a Node project, or on a repository that has both.

## How a plugin becomes active

A plugin is active in one of two ways:

- **Explicitly** — a `[plugins.<name>]` block in [`pyve.toml`](pyve-toml.md) names the plugin and the sub-tree it owns (`path`, default `"."`).
- **Implicitly (Python)** — a project with **no** `[plugins.*]` blocks at all gets the Python plugin at `path = "."`. This is the shape every v2-era project migrates into, so existing Python projects need no plugin declaration.

At most one plugin may own the project root (`path = "."`). In a multi-stack repo, the secondary stack takes a sub-path — see [Polyglot Projects](polyglot.md).

## What a plugin does

For each `pyve` command, the active plugins each contribute their part and Pyve composes one coherent result:

| Command | Composed result |
|---|---|
| `pyve init` | Each plugin materializes its environments; `.envrc` and `.gitignore` are composed from every plugin's contribution. |
| `pyve check` | Per-plugin health sections, rolled up to a single worst-case exit code (CI-safe `0`/`1`/`2`). |
| `pyve status` | Per-plugin read-only sections (always exits `0`). |
| `pyve purge` | A composed inventory of created vs. authored paths; only Pyve-created paths are removed, and a path any plugin marks *authored* is never touched. |
| activation | Each plugin emits a validated `.envrc` snippet; they concatenate into one managed section. |

All plugin-emitted content destined for `.envrc` or `.gitignore` passes through Pyve's input-safety validators before it is written, so a plugin can only contribute the narrow, safe shapes those files expect.

## Reference plugins (v3.0)

### Python

The Python plugin owns the Python ecosystem and ships two backends:

- **`venv`** — the standard library virtual environment, for pure-Python projects.
- **`micromamba`** — a conda-compatible backend, for scientific/ML stacks with binary dependencies.

It pins versions through your version manager (**asdf** or **pyenv**), auto-detects the backend from project files (`pyproject.toml` / `requirements*.txt` / `setup.py` ⇒ `venv`; `environment.yml` / `conda-lock.yml` ⇒ `micromamba`; both ⇒ a prompt), and manages the `.venv` / conda prefix, `.envrc`, and `.gitignore`.

### Node / SvelteKit

The Node plugin owns the JavaScript/TypeScript ecosystem and ships three backends:

- **`pnpm`**, **`npm`**, **`yarn`** — selected by an explicit `backend = …`, else inferred from the lockfile present, else defaulting to `pnpm`.

It resolves the Node runtime through the active version manager (precedence: **nvm → fnm → volta → asdf → Homebrew/system**), runs the package manager's install, activates `node_modules/.bin` on PATH via direnv, and recognizes **SvelteKit** as a framework (surfaced advisory-only in `check` / `status`). TypeScript is read from an env's `languages` and surfaced as an advisory; deeper TypeScript integration is on the roadmap, not shipped.

## The backend categories

Every backend a plugin registers declares one of three categories, which determines its `init` / `purge` / `activate` behavior:

| Category | Behavior | v3.0 status |
|---|---|---|
| `virtualized` | Per-project environment directory; activation adds its `bin/` to PATH. | **Shipped** — `venv`, `micromamba`, `pnpm`, `npm`, `yarn`. |
| `cache-backed` | Shared user-level cache + project lockfile; activation contributes nothing to PATH. | Designed-in; no providers yet. |
| `check-only` | Pyve verifies presence/version, installs nothing. | Designed-in; no providers yet. |

See [Backends](backends.md) for the full treatment.

## Roadmap

The plugin contract is designed to generalize. The following are **under consideration via the contract, not shipped in v3.0** — they are described here as roadmap, not as available features:

- Additional language plugins (e.g. Ruby, Rust, Go).
- `cache-backed` providers (the natural first fits are Rust and Go).
- `check-only` providers (Docker / Podman, Homebrew, apt, mobile toolchains).
- Deeper TypeScript integration for the Node plugin.

## See also

- [Polyglot Projects](polyglot.md) — running two plugins in one repo.
- [Backends](backends.md) — backend names, categories, and the canonical-vs-advisory distinction.
- [`pyve.toml` Reference](pyve-toml.md) — declaring plugins and their `path`.
