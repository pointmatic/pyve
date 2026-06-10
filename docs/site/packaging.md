# Packaging

`pyve package` is the verb for **materializing an artifact** from an environment — building a wheel, a tarball, a container image, and so on. In v3.0 the verb is **reserved and scaffolded**: the CLI surface, the manifest field, and the registry that future providers plug into all exist, but **no packaging provider ships yet**. This page documents the contract so you know what's coming and so a future provider drops in transparently.

!!! warning "Reserved in v3.0"
    `pyve package` does not build anything in v3.0. It validates your declaration and prints a clean advisory. Concrete packaging providers land after v3.0. Don't wire `pyve package` into a release pipeline expecting an artifact yet.

## The `packaging` attribute

An environment opts into packaging by declaring a `packaging` value on its `[env.<name>]` block:

```toml
[env.dist]
purpose = "utility"
backend = "venv"
packaging = "wheel"
```

The value names the kind of artifact the environment should produce. The closed vocabulary of packaging values grows as providers ship; in v3.0 the value is recorded and surfaced but not acted on.

## v3.0 behavior

Running `pyve package` consults the packaging registry. Because no provider is registered, it prints an advisory and exits `0` — the verb is reserved and scaffolded, so this is the intended "nothing to do yet" path:

```text
$ pyve package
env 'dist' declares packaging 'wheel'; no packaging provider is registered yet —
reserved for a future release.
```

Exit `0` is deliberate: a reserved verb shouldn't fail a script that calls it speculatively, and a future provider should drop in without changing the call site.

## `package` vs. `deploy`

Pyve separates two future concerns:

- **`package`** — materialize the artifact (build it). Scaffolded in v3.0.
- **`deploy`** — ship the artifact somewhere. Reserved separately, for a later step.

Keeping them distinct means "build" and "ship" can ship (and be gated) independently.

## Roadmap

The following are **planned, not shipped** — described here as roadmap:

- Concrete packaging providers (wheels/sdists for Python, tarballs/images for Node, container builds, …).
- The full `packaging` value vocabulary each provider recognizes.
- A separate `deploy` step.

## See also

- [`pyve.toml` Reference](pyve-toml.md) — where the `packaging` attribute lives.
- [Plugins](plugins.md) — how providers register behind the contract.
