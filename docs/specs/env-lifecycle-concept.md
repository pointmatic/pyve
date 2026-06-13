# Concept seed — environment durability & the `purpose` lifecycle

**Status:** design seed (2026-06-12). Input for a `refactor_document` pass that
folds this framing into the driving documents, then a `plan_phase` pass that
derives stories. **Not yet propagated.** Retire this file once `concept.md` /
`project-essentials.md` / `tech-spec.md` carry the framing (see "Where this
lands" below).

This note exists to answer one question before any lifecycle behavior is built:
**what precious resource are we preserving when we decline to purge an
environment?** The current `purpose` vocabulary (`run` / `test` / `utility` /
`temp`) carries an *implied* durability ranking, but nothing behavioral keys off
`run` vs `utility` today, and the only live gate is `pyve test --env` requiring
`purpose = test`. The distinctions are decorative until grounded.

## Core principle

In a declarative system an environment is a pure function of its declaration:
`env = materialize(declaration)`. Purging is therefore only *lossy* to the
degree that rebuild is **costly** or **unfaithful**. It follows that:

> **No environment is precious because it is irreplaceable. We preserve an env
> only to save reconstruction *cost* or to hold a *validated snapshot* —
> never because we cannot rebuild it. An env you are afraid to rebuild is a
> bug, not an asset: irreproducibility is the defect.**

## What is actually precious (the only candidate resources)

Rebuild loses nothing *except* what it cannot cheaply or faithfully recreate:

1. **Reconstruction cost** — compute + network (a conda solve pulling
   torch/CUDA/opencv; a large pip tree). Rebuild yields the *same* env, slower.
   This is a **cache** value, not a correctness one.
2. **Insulation from upstream churn** — rebuild assumes sources still fetch and
   resolve identically; a yanked version / moved git dep / index outage makes
   rebuild *fail or drift*. A preserved env is a frozen known-good snapshot.
   Lockfiles shrink this but don't eliminate it.
3. **Undeclared / out-of-band state** — anything the declaration does not
   capture (editable install of uncommitted source, a manual `pip install`,
   generated artifacts, caches, data). Rebuild *loses* it. The fix is to make
   the declaration complete (the declarative-env-setup megastory), not to
   preserve the env.
4. **Validated identity** — "the artifact I tested is the artifact I ship."
   Even with a lockfile a rebuild is a *new* env, equivalent but not provably
   identical to the one that was validated.

## Per-purpose mapping (what each protects)

| purpose | precious resource | consequence |
|---|---|---|
| `utility` | ~nothing (ad hoc tooling: ruff/mypy/scratch) | freely purgeable; rebuild is the model |
| `temp` | nothing by definition (one-shot) | system auto-prune |
| `test` | mostly **cost** (#1) + fast iteration | cacheable; reproducible; low drift stakes |
| `run` | **upstream-insulation (#2) + validated identity (#4)** | reproducibility *mandate*; deployable/production intent |

## The twist: preservation has its own cost — rot

The longer an env is preserved, the more it drifts from both its declaration
and the filesystem — dead-shebang console scripts after a relocation, an
interpreter symlink to a deleted Python, drift from a since-edited pin. So the
*most-preserved* env (`run`) is paradoxically the *most rot-prone*. Therefore
the right durability mechanism for `run` is **not** "never purge this mutable
directory" (the weakest, rot-prone form) but **lock + promote to an immutable
artifact** (lockfile + built wheelhouse/image) so the precious thing lives
*outside* the fragile env directory.

## Design conclusion — two independent levers, not a "survives-purge" ranking

Stop modeling `purpose` durability as "which envs survive `pyve purge`." Model
it as:

- **Recovery fidelity** — make rebuild *always faithful* (the declarative
  setup megastory). As fidelity → 100%, resources #2/#3/#4 evaporate and purge
  becomes safe for everything.
- **Recovery cost** — preserve as a **cache with declaration-hash
  invalidation**, not a "don't touch" flag. `run`/`test` get higher cache
  priority (expensive); `utility`/`temp` get little or none.

`purpose` then means:

- **`run`** — reproducibility mandate + **artifact-promotion** target (the
  deployable/production runtime, or its faithful local mirror). Long-lived
  *intent*, realized via lock + artifact, not via directory permanence.
- **`test`** — cacheable, reproducible test-execution env.
- **`utility`** — disposable ad hoc dev tooling; no long-running/production
  intent.
- **`temp`** — ephemeral; auto-pruned.

## Where this lands (for the `refactor_document` pass)

- **`concept.md`** — add the "irreproducibility is the bug; we preserve for
  cost + validated snapshot, never because an env is irreplaceable" principle
  to the vision.
- **`project-essentials.md`** — rewrite the `purpose:` vocabulary entry: the
  durability spectrum above grounded in *which precious resource each purpose
  protects*. **Note:** the current entry's hint that "utility envs survive
  `pyve purge`" **inverts** this framing (utility is now the disposable one) and
  must be corrected.
- **`tech-spec.md`** — the lifecycle model (cache-with-invalidation; artifact
  promotion for `run`) where env materialization/state is described.

## Open questions (for `plan_phase`)

- **`utility` vs `temp` boundary** — proposed line: `temp` is *system
  auto-pruned*; `utility` is *manually managed* (never auto-deleted, but safe to
  nuke and rebuild). Confirm or redraw.
- **`run` at root?** — is the deployable runtime `[env.root] purpose = "run"`
  (vs today's `root → utility` default), or a named `run` env? Should `pyve init`
  for an app project default root to `run`? (`run` is never a name-based default
  today.)
- **Reproducibility-mandate enforcement** — does `run` *require* a lockfile /
  strict mode, and what does `pyve check` say when a `run` env isn't provably
  reproducible?
- **Artifact promotion** — is there a future `pyve package`/deploy verb that
  consumes a `run` env's lock to emit the immutable artifact?
