# Bug: asdf shim hash poisoning after `pip install` in Pyve-managed venvs

## Summary

When a user runs `pip install <new-cli>` inside a Pyve-activated virtualenv on a system that also uses asdf (with asdf's shell integration loaded), the newly installed CLI can resolve to an asdf shim instead of the venv's binary on the very next invocation — even though `PATH` is correctly ordered with `.venv/bin` first.

Pyve should mitigate this by exporting `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` in the user's shell rc file at install time.

## Symptoms

Immediately after `pip install <new-cli>` in a Pyve venv:

```
$ which <new-cli>
/path/to/project/.venv/bin/<new-cli>          # correct

$ type -a <new-cli>
<new-cli> is /path/to/project/.venv/bin/<new-cli>     # PATH order correct
<new-cli> is /Users/<user>/.asdf/shims/<new-cli>

$ hash | grep <new-cli>
<new-cli>=/Users/<user>/.asdf/shims/<new-cli>         # hash poisoned

$ <new-cli> --version
# fails, or dispatches through asdf instead of the venv
```

`hash -r && <new-cli> --version` works, confirming the zsh command hash is the culprit rather than `PATH`.

## Root Cause

Two independent asdf behaviors combine to defeat the normal `PATH`-order resolution that `.venv/bin/activate` (and therefore Pyve's direnv integration) relies on:

1. **asdf's Python plugin runs a reshim hook after every `pip install`.** This drops a new shim file into `~/.asdf/shims/<new-cli>` even though the CLI was installed into a venv, not into the asdf-managed Python's global site-packages.

2. **asdf's zsh integration installs a `precmd` hook that populates the zsh command hash directly from the shim directory, bypassing the normal `PATH` walk.** When the precmd hook fires after the reshim, it writes `<new-cli>=~/.asdf/shims/<new-cli>` into the hash — overriding whatever a `PATH`-ordered lookup would have produced.

The result: `PATH` is correct, `type -a` does a fresh `PATH` walk and reports the venv binary first, but zsh consults the hash before re-scanning `PATH`, so every invocation hits the asdf shim.

The standard venv activator's trailing `hash -r` does not help here, because the precmd hook re-poisons the hash on the next prompt.

## Why This Isn't Always Visible

The race only produces a visible error when all of these are true:

- The CLI name is newly installed (no prior shim existed).
- The install happens in a Pyve/direnv-activated venv.
- The CLI is then invoked from a directory whose `.tool-versions` chain does not include a Python that has the package — so asdf's shim dispatch fails loudly instead of silently routing through a second layer of indirection.

When `.tool-versions` happens to resolve, the shim dispatches successfully and the user just unknowingly runs their venv CLI through asdf. That means this bug likely explains some "random" slowness or behavior users have attributed to other causes.

## Proposed Fix

During Pyve install, append the following line to the user's shell rc (`~/.zshrc`, `~/.bashrc`, etc.), guarded so it isn't duplicated on repeat installs:

```sh
export ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1
```

### Why this works

- `pip install` still drops the binary into `.venv/bin/` as normal.
- asdf's Python plugin post-install hook becomes a no-op — no new shim is created in `~/.asdf/shims/`.
- asdf's precmd hook still runs, but finds no shim for the new CLI and therefore injects no hash entry.
- On first invocation, zsh does a normal `PATH` walk, finds `.venv/bin/<new-cli>` first, and caches that correctly.

The shim file was both the symptom and the cause; removing it removes what the precmd hook latches onto.

## Trade-offs

With reshim disabled for the Python plugin:

- **Venv-based workflows (Pyve's use case):** strict win. No behavior change except the bug going away.
- **Global `pip install` without a venv:** asdf will not auto-create shims for globally installed Python CLIs. Users who rely on this pattern will need to run `asdf reshim python` manually after global installs.

Since Pyve's entire purpose is managing per-project venvs, the global-install case is outside its intended workflow, and the trade-off is acceptable.

## Implementation Notes for Pyve

- Detect the user's login shell (or the presence of `~/.zshrc` / `~/.bashrc` / `~/.config/fish/config.fish`) and append to the appropriate rc file.
- Wrap the export in a sentinel comment block (e.g. `# >>> pyve asdf compat >>>` / `# <<< pyve asdf compat <<<`) so the installer can detect prior installs and the uninstaller can remove it cleanly.
- Only write the export if asdf is actually detected on the system (`command -v asdf` or `[ -d "$HOME/.asdf" ]`) to avoid polluting rc files on systems that don't need it.
- Consider printing a one-line notice at install time: "Added `ASDF_PYTHON_PLUGIN_DISABLE_RESHIM=1` to ~/.zshrc to prevent asdf shim conflicts with venv binaries. Restart your shell to apply."

## Reproduction Recipe

On macOS with asdf + zsh + direnv + Pyve:

```sh
# 1. In a Pyve-managed project directory with an activated venv
cd ~/some-pyve-project
# (direnv has sourced .venv/bin/activate)

# 2. Install a CLI whose name has never been installed before
pip install <brand-new-package-name>

# 3. Immediately run it — from a directory without a matching .tool-versions,
#    or with a .tool-versions pointing at a Python that doesn't have the package
<brand-new-cli>

# Expected: runs from .venv/bin/
# Actual:   dispatches through ~/.asdf/shims/, often failing
```

## References

- asdf Python plugin reshim behavior: `asdf-python` post-install hook
- asdf zsh integration: `precmd` hook in `asdf.sh` / `asdf.zsh`
- zsh command hashing: `man zshbuiltins`, `hash` and `hash -r`
