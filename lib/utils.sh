#!/usr/bin/env bash
#
# Copyright (c) 2025-2026 Pointmatic, (https://www.pointmatic.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# lib/utils.sh - Utility functions for pyve
# This file is sourced by pyve.sh and should not be executed directly.
#

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf "ERROR: This script should be sourced, not executed directly.\n" >&2
    exit 1
fi

#============================================================
# Logging Functions
#============================================================

# Logging helpers emit the unified UX palette from lib/ui/core.sh
# (▸ / ⚠ / ✘ / ✔ glyphs, two-space indent, stderr vs. stdout
# routing preserved). When lib/ui/core.sh is not sourced — for
# example in tests that load lib/utils.sh standalone — the
# ${VAR:-fallback} pattern uses plain glyphs without ANSI wrappers.

log_info() {
    printf "  %s %s\n" "${ARROW:-▸}" "$1"
}

log_warning() {
    printf "  %s %s\n" "${WARN:-⚠}" "$1" >&2
}

log_error() {
    printf "  %s %s\n" "${CROSS:-✘}" "$1" >&2
}

log_success() {
    printf "  %s %s\n" "${CHECK:-✔}" "$1"
}

#============================================================
# User Prompts
#============================================================

# Prompt user for yes/no confirmation
# Usage: prompt_yes_no "Question?"
# Returns 0 for yes, 1 for no
prompt_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        printf "%s [y/n]: " "$prompt"
        # EOF (closed/empty stdin — e.g. a non-interactive caller) returns
        # non-zero from `read`. Treat it as a decline rather than looping
        # forever on the "invalid answer" arm. Matches the
        # default-negative semantics of ask_yn in lib/ui/core.sh.
        if ! read -r response; then
            return 1
        fi
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                printf "Please answer yes or no.\n"
                ;;
        esac
    done
}

# Prompt to install pip dependencies after environment creation
# Detects pyproject.toml or requirements.txt and prompts user to install
# Respects --auto-install-deps and --no-install-deps flags
# Usage: prompt_install_pip_dependencies [backend] [env_path]
#   backend: "venv" or "micromamba" (optional, defaults to venv)
#   env_path: path to micromamba environment (required if backend is micromamba)
prompt_install_pip_dependencies() {
    local backend="${1:-venv}"
    local env_path="${2:-}"
    
    # Check for --no-install-deps flag
    if [[ "${PYVE_NO_INSTALL_DEPS:-}" == "1" ]]; then
        return 0
    fi
    
    local has_pyproject=false
    local has_requirements=false
    
    if [[ -f "pyproject.toml" ]]; then
        has_pyproject=true
    fi
    
    if [[ -f "requirements.txt" ]]; then
        has_requirements=true
    fi
    
    # Nothing to install
    if [[ "$has_pyproject" == false ]] && [[ "$has_requirements" == false ]]; then
        return 0
    fi
    
    echo ""
    
    # Determine pip command based on backend
    local pip_cmd
    if [[ "$backend" == "micromamba" ]]; then
        if [[ -z "$env_path" ]]; then
            log_warning "Cannot install pip dependencies: micromamba env_path not provided"
            return 1
        fi
        local micromamba_path
        micromamba_path="$(get_micromamba_path)"
        if [[ -z "$micromamba_path" ]]; then
            log_warning "Cannot install pip dependencies: micromamba not found"
            return 1
        fi
        pip_cmd="$micromamba_path run -p $env_path pip"
    else
        # venv backend: use the venv's own pip to avoid the asdf shim
        # (which installs into the base Python and auto-reshims).
        if [[ -z "$env_path" ]]; then
            log_warning "Cannot install pip dependencies: venv env_path not provided"
            return 1
        fi
        pip_cmd="$env_path/bin/pip"
        if [[ ! -x "$pip_cmd" ]]; then
            log_warning "Cannot install pip dependencies: pip not found at $pip_cmd"
            return 1
        fi
    fi
    
    # Auto-install mode (CI or --auto-install-deps flag)
    if [[ -n "${CI:-}" ]] || [[ "${PYVE_AUTO_INSTALL_DEPS:-}" == "1" ]]; then
        if [[ "$has_pyproject" == true ]]; then
            log_info "Auto-installing dependencies from pyproject.toml..."
            $pip_cmd install -e . || log_warning "Failed to install from pyproject.toml"
        fi
        if [[ "$has_requirements" == true ]]; then
            log_info "Auto-installing dependencies from requirements.txt..."
            $pip_cmd install -r requirements.txt || log_warning "Failed to install from requirements.txt"
        fi
        return 0
    fi
    
    # Interactive mode: prompt for each file
    if [[ "$has_pyproject" == true ]]; then
        printf "Install pip dependencies from pyproject.toml? [Y/n]: "
        read -r response
        
        if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
            log_info "Installing dependencies from pyproject.toml..."
            if $pip_cmd install -e .; then
                log_success "Installed dependencies from pyproject.toml"
            else
                log_warning "Failed to install from pyproject.toml"
            fi
        fi
    fi
    
    if [[ "$has_requirements" == true ]]; then
        printf "Install pip dependencies from requirements.txt? [Y/n]: "
        read -r response
        
        if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
            log_info "Installing dependencies from requirements.txt..."
            if $pip_cmd install -r requirements.txt; then
                log_success "Installed dependencies from requirements.txt"
            else
                log_warning "Failed to install from requirements.txt"
            fi
        fi
    fi
}

#============================================================
# project-guide Integration (Story G.c / FR-G2)
#============================================================
#
# pyve init has an opinionated, opt-out hook that installs
# project-guide into the project environment and optionally
# adds a shell-completion eval line to the user's rc file.
#
# Two independent sub-features, each with its own trigger
# logic and a deliberate CI-default asymmetry:
#
#   Install flow (pip install project-guide):
#     CI default: INSTALL (matches interactive default of Y)
#
#   Completion wiring (rc-file edit):
#     CI default: SKIP (editing user rc files in unattended
#     environments is the kind of surprise Pyve avoids)
#
# Both flows are failure-non-fatal: a failed pip install or
# unwritable rc file warns and continues — pyve init still
# exits 0.
#
# Sentinel comments bracket the rc-file block for idempotent
# insertion and removal. Keep these exactly in sync with the
# unit tests (test_project_guide.bats) and with the removal
# logic in uninstall_self() (pyve.sh).
#------------------------------------------------------------

# Sentinel comments used to bracket the project-guide completion
# block in user rc files. These must not change without a
# migration plan — users who installed the block with an older
# sentinel would end up with orphaned blocks on uninstall.
readonly PROJECT_GUIDE_COMPLETION_OPEN="# >>> project-guide completion (added by pyve) >>>"
readonly PROJECT_GUIDE_COMPLETION_CLOSE="# <<< project-guide completion <<<"

# SDKMan's "must be at end of file" load-order marker. Pyve respects
# this marker when inserting any new content into a user rc file:
# instead of appending, the new content is inserted immediately
# above the marker so SDKMan retains its end-of-file position.
readonly SDKMAN_END_MARKER="#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!"

# Insert a multi-line text block into a user rc file. If the SDKMan
# end-of-file marker is present, insert the block immediately before
# it (preserving SDKMan's "must be last" load-order requirement).
# Otherwise, append the block to the end of the file.
#
# Creates the rc file if missing. ALWAYS emits a leading blank line
# before the inserted block (when the file is non-empty in the
# SDKMan-absent case, or unconditionally in the SDKMan-present
# case). The companion remove_project_guide_completion() eats one
# preceding blank line, so this convention guarantees byte-identical
# add → remove round-trips regardless of the original file's
# trailing whitespace.
#
# Usage: insert_text_before_sdkman_marker_or_append <rc_path> <content>
#   content: the text to insert. A trailing newline will be added if
#            absent so the inserted block is well-formed.
insert_text_before_sdkman_marker_or_append() {
    local rc_path="$1"
    local content="$2"

    # Create the rc file if missing.
    if [[ ! -f "$rc_path" ]]; then
        touch "$rc_path" || return 1
    fi

    # Ensure content ends with a newline so the inserted block is
    # well-formed regardless of how the caller built it.
    [[ "$content" == *$'\n' ]] || content+=$'\n'

    if grep -qF "$SDKMAN_END_MARKER" "$rc_path"; then
        # SDKMan present: insert the content immediately above the
        # marker line, bracketed by a blank line before and after for
        # readability and round-trip symmetry (the trailing blank
        # keeps the block visually separated from the SDKMan marker —
        # Story H.a bug 3).
        #
        # Implementation note: BSD awk on macOS rejects embedded
        # newlines in -v variables, so we stage the multi-line block
        # in a temp file and have awk read it line-by-line via
        # getline on the first marker hit.
        local tmpfile blockfile
        tmpfile="$(mktemp "${rc_path}.tmp.XXXXXX")" || return 1
        blockfile="$(mktemp "${rc_path}.blk.XXXXXX")" || { rm -f "$tmpfile"; return 1; }
        printf "%s" "$content" > "$blockfile"
        awk -v marker="$SDKMAN_END_MARKER" -v block_file="$blockfile" '
            BEGIN { inserted = 0 }
            $0 == marker && !inserted {
                print ""
                while ((getline line < block_file) > 0) print line
                close(block_file)
                print ""
                inserted = 1
            }
            { print }
        ' "$rc_path" > "$tmpfile" || { rm -f "$tmpfile" "$blockfile"; return 1; }
        rm -f "$blockfile"
        mv -f "$tmpfile" "$rc_path"
    else
        # SDKMan absent: append. Always emit a leading blank line
        # if the file is non-empty (round-trip symmetry with remove).
        if [[ -s "$rc_path" ]]; then
            printf "\n" >> "$rc_path"
        fi
        printf "%s" "$content" >> "$rc_path"
    fi
}

# Prompt whether to install project-guide into the project env.
#
# Returns 0 to install, 1 to skip.
#
# Priority order (first match wins):
#   PYVE_NO_PROJECT_GUIDE=1 → skip
#   PYVE_PROJECT_GUIDE=1    → install
#   CI=1 or PYVE_FORCE_YES  → install (CI default matches interactive default Y)
#   else (interactive)      → prompt, default Y
prompt_install_project_guide() {
    if [[ "${PYVE_NO_PROJECT_GUIDE:-}" == "1" ]]; then
        return 1
    fi
    if [[ "${PYVE_PROJECT_GUIDE:-}" == "1" ]]; then
        return 0
    fi
    if [[ -n "${CI:-}" ]] || [[ "${PYVE_FORCE_YES:-}" == "1" ]]; then
        return 0
    fi

    local response
    printf "Install project-guide? [Y/n]: "
    read -r response
    if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    fi
    return 1
}

# Prompt whether to add project-guide shell completion to the user rc file.
#
# Returns 0 to add, 1 to skip.
#
# Priority order (first match wins) — DELIBERATE ASYMMETRY WITH install flow:
#   PYVE_NO_PROJECT_GUIDE_COMPLETION=1 → skip
#   PYVE_PROJECT_GUIDE_COMPLETION=1    → add
#   CI=1 or PYVE_FORCE_YES             → SKIP (not add — editing rc files in
#                                        unattended environments is surprising)
#   else (interactive)                 → prompt, default Y
prompt_install_project_guide_completion() {
    if [[ "${PYVE_NO_PROJECT_GUIDE_COMPLETION:-}" == "1" ]]; then
        return 1
    fi
    if [[ "${PYVE_PROJECT_GUIDE_COMPLETION:-}" == "1" ]]; then
        return 0
    fi
    if [[ -n "${CI:-}" ]] || [[ "${PYVE_FORCE_YES:-}" == "1" ]]; then
        return 1
    fi

    local response
    printf "Add project-guide shell completion to your rc file? [Y/n]: "
    read -r response
    if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    fi
    return 1
}

# Detect the user's shell from $SHELL.
# Prints "zsh" | "bash" | "unknown" to stdout.
detect_user_shell() {
    local shell_basename=""
    if [[ -n "${SHELL:-}" ]]; then
        shell_basename="$(basename "$SHELL")"
    fi
    case "$shell_basename" in
        zsh)  printf "zsh\n" ;;
        bash) printf "bash\n" ;;
        *)    printf "unknown\n" ;;
    esac
}

# Map a shell name to its rc file path.
# Prints "$HOME/.zshrc" | "$HOME/.bashrc" | empty string.
get_shell_rc_path() {
    local shell="$1"
    case "$shell" in
        zsh)  printf "%s/.zshrc\n" "$HOME" ;;
        bash) printf "%s/.bashrc\n" "$HOME" ;;
        *)    printf "" ;;
    esac
}

# Check whether the project-guide completion sentinel block is present in a file.
# Returns 0 if present, 1 if absent (including missing file).
is_project_guide_completion_present() {
    local rc_path="$1"
    if [[ ! -f "$rc_path" ]]; then
        return 1
    fi
    grep -qF "$PROJECT_GUIDE_COMPLETION_OPEN" "$rc_path"
}

# Append a project-guide completion block to the user's rc file.
# Idempotent: no-op if the sentinel is already present.
# Creates the rc file if it does not exist.
# SDKMan-aware: if the SDKMan end-of-file marker is present, the
# block is inserted immediately above it via
# insert_text_before_sdkman_marker_or_append() so SDKMan retains its
# "must be last" load-order position.
#
# Usage: add_project_guide_completion <rc_path> <shell>
#   shell: "zsh" or "bash" — determines the completion eval command
add_project_guide_completion() {
    local rc_path="$1"
    local shell="$2"

    # Idempotency: if sentinel already present, no-op success.
    if is_project_guide_completion_present "$rc_path"; then
        return 0
    fi

    # Build the completion block via an unquoted heredoc. The doubled
    # backslash before the embedded newline (\\) is critical: bash
    # heredoc processing turns \\ into a single literal backslash,
    # which is then followed by a real newline, producing a proper
    # shell line-continuation in the output. The escaped \$(...) is
    # likewise critical: it writes a literal $(...) substitution to
    # the rc file so the eval runs at SHELL STARTUP, not at
    # block-construction time.
    #
    # The `2>/dev/null` on the substitution is load-bearing: at shell
    # startup the project env is not yet active (direnv hasn't run), so
    # `project-guide` resolves to an asdf shim. If the asdf-resolved
    # Python has no project-guide installed, the shim errors noisily to
    # stderr ("No version is set for command project-guide"). The
    # `command -v` guard does not catch this — the shim FILE exists —
    # so without stderr suppression the error leaks at every shell
    # startup. Completion is best-effort (FR-16); degrade silently.
    local block
    block="$(cat <<EOF
$PROJECT_GUIDE_COMPLETION_OPEN
command -v project-guide >/dev/null 2>&1 && \\
  eval "\$(_PROJECT_GUIDE_COMPLETE=${shell}_source project-guide 2>/dev/null)"
$PROJECT_GUIDE_COMPLETION_CLOSE
EOF
)"

    insert_text_before_sdkman_marker_or_append "$rc_path" "$block"
}

# Remove the project-guide completion sentinel block from a user rc file.
# Safe no-op if the file is missing or the sentinel is absent.
# Also drops one immediately-preceding blank line AND one immediately-
# following blank line (both added by add_...) so that add→remove
# round-trips cleanly in both the SDKMan-absent (only leading blank) and
# SDKMan-present (leading + trailing blank) cases.
remove_project_guide_completion() {
    local rc_path="$1"

    if [[ ! -f "$rc_path" ]]; then
        return 0  # Nothing to remove
    fi
    if ! is_project_guide_completion_present "$rc_path"; then
        return 0  # Already clean
    fi

    local tmpfile
    tmpfile="$(mktemp "${rc_path}.tmp.XXXXXX")"

    # Note: awk variable names here intentionally avoid `close` (reserved
    # function name in BSD awk on macOS) by using `end_marker` instead.
    awk -v begin_marker="$PROJECT_GUIDE_COMPLETION_OPEN" \
        -v end_marker="$PROJECT_GUIDE_COMPLETION_CLOSE" '
    BEGIN { in_block = 0; pending_blank = 0; eat_trailing_blank = 0 }
    {
        if (in_block) {
            if ($0 == end_marker) {
                in_block = 0
                # Swallow one trailing blank line emitted by add_...
                # when the SDKMan marker was present.
                eat_trailing_blank = 1
            }
            next
        }
        if ($0 == begin_marker) {
            in_block = 1
            # Discard the pending blank line we were holding.
            pending_blank = 0
            next
        }
        # Buffer one blank line at a time so we can discard it
        # if the next line is the sentinel open, or swallow one
        # blank line immediately following the sentinel close.
        if ($0 == "") {
            if (eat_trailing_blank) {
                eat_trailing_blank = 0
                next
            }
            if (pending_blank) {
                print ""
            }
            pending_blank = 1
            next
        }
        eat_trailing_blank = 0
        if (pending_blank) {
            print ""
            pending_blank = 0
        }
        print
    }
    END {
        if (pending_blank) {
            print ""
        }
    }
    ' "$rc_path" > "$tmpfile"

    mv "$tmpfile" "$rc_path"
}

# Detect whether project-guide is importable from the project env's Python.
# Returns 0 if installed, 1 if not (including missing env path / python).
#
# Usage: is_project_guide_installed <backend> <env_path>
#   backend:  "venv" or "micromamba"
#   env_path: for venv, the venv directory; for micromamba, the env prefix
is_project_guide_installed() {
    local backend="$1"
    local env_path="$2"

    if [[ -z "$env_path" ]] || [[ ! -d "$env_path" ]]; then
        return 1
    fi

    local env_python="$env_path/bin/python"
    if [[ ! -x "$env_python" ]]; then
        return 1
    fi

    "$env_python" -c 'import project_guide' >/dev/null 2>&1
}

# Install (or upgrade) project-guide into the project env via pip.
# Always uses --upgrade so fresh init / --force gets the latest project-guide.
# Warn-don't-fail on pip error.
#
# Usage: install_project_guide <backend> <env_path>
# Returns 0 on success (install or already present), 1 if we had no way
# to run pip. A pip install *failure* still returns 0 because the caller
# wants pyve init to continue even if project-guide can't be installed.
install_project_guide() {
    local backend="$1"
    local env_path="$2"

    if [[ -z "$env_path" ]]; then
        log_warning "Cannot install project-guide: env path not provided"
        return 1
    fi

    local pip_cmd=""
    if [[ "$backend" == "venv" ]]; then
        pip_cmd="$env_path/bin/pip"
        if [[ ! -x "$pip_cmd" ]]; then
            log_warning "Cannot install project-guide: pip not found at $pip_cmd"
            return 1
        fi
    elif [[ "$backend" == "micromamba" ]]; then
        local micromamba_path
        micromamba_path="$(get_micromamba_path 2>/dev/null || true)"
        if [[ -z "$micromamba_path" ]]; then
            log_warning "Cannot install project-guide: micromamba not found"
            return 1
        fi
        pip_cmd="$micromamba_path run -p $env_path pip"
    else
        log_warning "Cannot install project-guide: unknown backend '$backend'"
        return 1
    fi

    log_info "Installing/upgrading project-guide into the project environment..."
    # Quiet-by-default subprocess output (Story L.j). Pip's per-package
    # progress is captured to a buffer; on failure the buffer is replayed
    # so the user can see what went wrong. PYVE_VERBOSE=1 (or --verbose)
    # streams output live.
    if run_quiet $pip_cmd install --upgrade project-guide; then
        log_success "Installed project-guide"
    else
        log_warning "Failed to install project-guide (skip with --no-project-guide)"
    fi
    return 0
}

# Run `project-guide init` inside the project environment to populate the
# project-guide artifacts (`.project-guide.yml`, `docs/project-guide/`).
#
# Relies on project-guide >= 2.5.0:
#   - --no-input (>= 2.2.3): unattended runs without prompting.
#   - --quiet    (>= 2.5.0): silent stdout on success; errors stay on
#     stderr. Keeps pyve init's output stream clean of project-guide's
#     per-file progress chatter.
# Older project-guide versions error on the unknown --quiet flag; pip's
# `--upgrade project-guide` install path keeps fresh installs current.
# Failure is non-fatal by design.
#
# project-guide is globally hosted (pyve self install →
# toolchain venv + ~/.local/bin shim), so scaffolding runs the global
# `project-guide` on PATH — not a per-project install. The (backend,
# env_path) args are accepted for call-site compatibility but unused; the
# `_in_env` name is retained pending the N-7 naming cleanup.
#
# Usage: run_project_guide_init_in_env [<backend>] [<env_path>]
# Returns 0 always — failure is non-fatal by design.
# Story N.bh: invoke the pyve-HOSTED project-guide for <subcommand>,
# lazily provisioning hosting on first use (install-method-agnostic — works
# for Homebrew and source installs, not only `self install`). The bare-PATH
# tier from N.bf.22 is no longer *invoked* here: a bare `project-guide`
# under active asdf is the version-gated shim trap, so the callsite only
# runs project-guide when it is genuinely pyve-hosted. If hosting can't be
# provisioned, skip generically (non-fatal) — never leak asdf's internal
# "No version is set" error.
_run_project_guide() {
    local sub="$1" ok_msg="$2" fail_msg="$3"
    pyve_project_guide_ensure || true   # idempotent; no-op when already hosted
    if ! pyve_project_guide_is_hosted; then
        log_warning "project-guide hosting isn't set up — skipping 'project-guide $sub' (run 'pyve self provision' to enable it)"
        return 0
    fi
    local pg
    pg="$(pyve_project_guide)"
    log_info "Running 'project-guide $sub'..."
    if "$pg" "$sub" --no-input --quiet; then
        log_success "$ok_msg"
    else
        log_warning "$fail_msg"
    fi
    return 0
}

run_project_guide_init_in_env() {
    _run_project_guide init \
        "project-guide artifacts generated" \
        "'project-guide init' failed (skip with --no-project-guide)"
}

# Run `project-guide update` inside the project environment to refresh the
# managed artifacts (templates + rendered `go.md`) while preserving user
# state (`.project-guide.yml`'s current_mode, overrides, metadata_overrides,
# test_first, pyve_version). Creates `.bak.<timestamp>` siblings for any
# managed file the user has modified.
#
# Invoked by `pyve init --force` when `.project-guide.yml` is present.
# Failure (including a future SchemaVersionError) is surfaced as a warning
# and is non-fatal — pyve must never auto-run `project-guide init --force`,
# since that is destructive.
#
# Usage: run_project_guide_update_in_env [<backend>] [<env_path>]
# Returns 0 always — failure is non-fatal by design. (See the N.aw note on
# run_project_guide_init_in_env: globally hosted, args accepted-but-unused.)
run_project_guide_update_in_env() {
    _run_project_guide update \
        "project-guide artifacts refreshed" \
        "'project-guide update' failed (continuing; run 'project-guide update' manually to retry)"
}

# Detect whether project-guide is declared as a dependency in the project's
# Python or conda dep files. Used by the auto-skip safety mechanism that
# prevents pyve from upgrading a user-pinned project-guide.
#
# Checks (in order, returns 0 on first match):
#   - pyproject.toml: any line mentioning project-guide as a dep string
#   - requirements.txt: any line starting with project-guide
#   - environment.yml: any non-comment line containing project-guide
#
# Returns 0 if found (auto-skip), 1 if not found.
#
# Edge cases handled:
#   - Word boundary: "project-guide-extras" does NOT match
#   - Comments: "# project-guide==..." does NOT match
#   - Quoted strings in pyproject.toml: both "project-guide" and 'project-guide'
# Story N.bi: report WHICH dependency source declares project-guide, so
# `pyve status` can show the integration mode (pip vs conda). Echoes:
#   pip    — declared in pyproject.toml or requirements.txt
#   conda  — declared in environment.yml
#   (empty)— not declared in any project dep file
# This is the single source of truth for the detection patterns;
# project_guide_in_project_deps is a thin boolean wrapper over it.
project_guide_deps_source() {
    # pyproject.toml — any line mentioning project-guide (in quotes or not),
    # ignoring comment lines. Bounded by a quote, comma, whitespace, version
    # specifier, or end-of-line.
    if [[ -f "pyproject.toml" ]]; then
        if grep -v '^[[:space:]]*#' pyproject.toml \
           | grep -qE '(^|[[:space:]"'\''[,(])project-guide([[:space:]"'\''<>=!~,)]|$)'; then
            printf 'pip'
            return 0
        fi
    fi

    # requirements.txt — line starts with project-guide (after optional
    # whitespace and ignoring comment lines).
    if [[ -f "requirements.txt" ]]; then
        if grep -v '^[[:space:]]*#' requirements.txt \
           | grep -qE '^[[:space:]]*project-guide([[:space:]<>=!~]|$)'; then
            printf 'pip'
            return 0
        fi
    fi

    # environment.yml — any non-comment line containing project-guide as a word.
    if [[ -f "environment.yml" ]]; then
        if grep -v '^[[:space:]]*#' environment.yml \
           | grep -qE '(^|[[:space:]"'\''=-])project-guide([[:space:]"'\''<>=!~]|$)'; then
            printf 'conda'
            return 0
        fi
    fi

    return 0
}

project_guide_in_project_deps() {
    [[ -n "$(project_guide_deps_source)" ]]
}

#============================================================
# Gitignore Management
#============================================================

# Check if a pattern is already present in .gitignore (exact line match)
# Usage: gitignore_has_pattern "pattern"
# Returns 0 if found, 1 if not
gitignore_has_pattern() {
    local pattern="$1"
    local gitignore=".gitignore"
    grep -qxF "$pattern" "$gitignore" 2>/dev/null
}

# Add a pattern to .gitignore if not already present
# Usage: append_pattern_to_gitignore "pattern"
append_pattern_to_gitignore() {
    local pattern="$1"
    local gitignore=".gitignore"
    
    # Create .gitignore if it doesn't exist
    if [[ ! -f "$gitignore" ]]; then
        touch "$gitignore"
    fi
    
    if gitignore_has_pattern "$pattern"; then
        return 0  # Already present
    fi
    
    # Append pattern
    printf "%s\n" "$pattern" >> "$gitignore"
}

# Remove a pattern from .gitignore (exact line match)
# Usage: remove_pattern_from_gitignore "pattern"
remove_pattern_from_gitignore() {
    local pattern="$1"
    local gitignore=".gitignore"
    
    if [[ ! -f "$gitignore" ]]; then
        return 0  # Nothing to remove
    fi
    
    # Use sed to remove exact line match
    # macOS sed requires '' after -i, Linux doesn't
    local escaped
    escaped="$(printf '%s' "$pattern" | sed 's/[.[\*^$()+?{|]/\\&/g')"
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "/^${escaped}$/d" "$gitignore"
    else
        sed -i "/^${escaped}$/d" "$gitignore"
    fi
}

#============================================================
# YAML Configuration Parser
#============================================================

# Read a simple YAML value from .pyve/config
# Usage: read_config_value "backend" or read_config_value "micromamba.env_name"
# Returns the value or empty string if not found
read_config_value() {
    local key="$1"
    local config_file=".pyve/config"
    
    # Return empty if config file doesn't exist
    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 0
    fi
    
    # Handle nested keys (e.g., "micromamba.env_name")
    if [[ "$key" == *.* ]]; then
        local section="${key%%.*}"
        local subkey="${key#*.}"
        
        # Extract value from nested section using awk
        # This handles simple YAML: section:\n  subkey: value
        awk -v section="$section" -v subkey="$subkey" '
            /^[a-z_]+:/ { current_section = $1; gsub(/:/, "", current_section) }
            current_section == section && $1 == subkey ":" {
                # Remove leading/trailing whitespace and quotes
                value = $2
                gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", value)
                print value
                exit
            }
        ' "$config_file"
    else
        # Handle top-level keys
        awk -v key="$key" '
            /^[a-z_]+:/ && $1 == key ":" {
                # Remove leading/trailing whitespace and quotes
                value = $2
                gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "", value)
                print value
                exit
            }
        ' "$config_file"
    fi
}

# Check if .pyve/config file exists
# Returns 0 if exists, 1 if not
config_file_exists() {
    [[ -f ".pyve/config" ]]
}

#============================================================
# Validation Functions
#============================================================

# Validate venv directory name
# Returns 0 if valid, 1 if invalid
# Usage: validate_venv_dir_name "dirname"
validate_venv_dir_name() {
    local dir_name="$1"
    
    # Check for empty
    if [[ -z "$dir_name" ]]; then
        log_error "Virtual environment directory name cannot be empty."
        return 1
    fi
    
    # Check for valid characters (alphanumeric, dots, underscores, hyphens)
    if [[ ! "$dir_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid directory name '$dir_name'. Use only alphanumeric characters, dots, underscores, and hyphens."
        return 1
    fi
    
    # Check for reserved names
    local reserved_names=(".env" ".git" ".gitignore" ".tool-versions" ".python-version" ".envrc")
    local reserved
    for reserved in "${reserved_names[@]}"; do
        if [[ "$dir_name" == "$reserved" ]]; then
            log_error "Directory name '$dir_name' is reserved and cannot be used."
            return 1
        fi
    done
    
    return 0
}

# Validate Python version format
# Returns 0 if valid, 1 if invalid
# Usage: validate_python_version "3.13.7"
validate_python_version() {
    local version="$1"
    
    # Check for empty
    if [[ -z "$version" ]]; then
        log_error "Python version cannot be empty."
        return 1
    fi
    
    # Check format: major.minor.patch (e.g., 3.13.7)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid Python version format '$version'. Expected format: #.#.# (e.g., 3.13.7)"
        return 1
    fi
    
    return 0
}

#============================================================
# Doctor: Environment Integrity Checks
#============================================================

# Scan site-packages for packages that have more than one .dist-info directory.
# This indicates cloud sync corruption or overlapping installs.
# Usage: doctor_check_duplicate_dist_info <env_path>
doctor_check_duplicate_dist_info() {
    local env_path="$1"

    local site_packages
    site_packages=$(find "$env_path/lib" -maxdepth 2 -type d -name "site-packages" 2>/dev/null | head -1)

    if [[ -z "$site_packages" ]]; then
        printf "✓ No duplicate dist-info directories\n"
        return 0
    fi

    # Collect all .dist-info dir basenames
    local -a all_dirs=()
    while IFS= read -r d; do
        all_dirs+=("$(basename "$d")")
    done < <(find "$site_packages" -maxdepth 1 -type d -name "*.dist-info" 2>/dev/null | sort)

    if [[ ${#all_dirs[@]} -eq 0 ]]; then
        printf "✓ No duplicate dist-info directories\n"
        return 0
    fi

    # Extract normalized package names (strip -<version>.dist-info)
    local -a pkg_names=()
    for d in "${all_dirs[@]}"; do
        local pkg_name
        pkg_name=$(printf '%s' "${d%.dist-info}" | sed 's/-[0-9].*//')
        pkg_names+=("$pkg_name")
    done

    # Find which package names appear more than once
    local dup_pkgs
    dup_pkgs=$(printf '%s\n' "${pkg_names[@]}" | sort | uniq -d)

    if [[ -z "$dup_pkgs" ]]; then
        printf "✓ No duplicate dist-info directories\n"
        return 0
    fi

    # Report each duplicated package with its conflicting dirs and mtimes
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        printf "✗ Duplicate dist-info detected: %s\n" "$pkg"
        for d in "${all_dirs[@]}"; do
            local dpkg
            dpkg=$(printf '%s' "${d%.dist-info}" | sed 's/-[0-9].*//')
            if [[ "$dpkg" == "$pkg" ]]; then
                local full_path="$site_packages/$d"
                local mtime
                if [[ "$(uname)" == "Darwin" ]]; then
                    mtime=$(stat -f "%Sm" -t "%b %d %H:%M" "$full_path" 2>/dev/null || echo "?")
                else
                    mtime=$(stat -c "%y" "$full_path" 2>/dev/null | cut -d'.' -f1 || echo "?")
                fi
                printf "    %s (%s)\n" "$d" "$mtime"
            fi
        done
    done <<< "$dup_pkgs"
    printf "  Run 'pyve init --force' to rebuild the environment cleanly.\n"
}

# Scan the environment tree for files/directories with a " 2" suffix — the
# collision naming used by iCloud Drive when two processes create the same
# path simultaneously.
# Usage: doctor_check_collision_artifacts <env_path>
doctor_check_collision_artifacts() {
    local env_path="$1"

    if [[ ! -d "$env_path" ]]; then
        return 0
    fi

    local -a artifacts=()
    while IFS= read -r artifact; do
        artifacts+=("$artifact")
    done < <(find "$env_path" -name "* 2" 2>/dev/null | sort | head -20)

    if [[ ${#artifacts[@]} -eq 0 ]]; then
        printf "✓ No cloud sync collision artifacts\n"
        return 0
    fi

    printf "✗ Cloud sync collision artifacts detected (%d found):\n" "${#artifacts[@]}"
    local shown=0
    for artifact in "${artifacts[@]}"; do
        if [[ $shown -lt 5 ]]; then
            printf "    %s\n" "$artifact"
        fi
        (( shown++ )) || true
    done
    if [[ ${#artifacts[@]} -gt 5 ]]; then
        printf "    ... and %d more\n" "$(( ${#artifacts[@]} - 5 ))"
    fi
    printf "  Caused by cloud sync running concurrently with environment extraction.\n"
    printf "  Rebuild outside a cloud-synced directory: pyve init --force\n"
}

# Check for known conflicts between pip-bundled native libraries and
# conda-linked ones. When pip packages (torch, tensorflow) bundle their own
# OpenMP and conda packages (numpy, scipy) link against the system OpenMP in
# the environment's lib/ directory, a missing libomp/libgomp produces
# intermittent dlopen failures at import time.
#
# Only runs when both a pip bundler AND a conda linker are detected.
# Usage: doctor_check_native_lib_conflicts <env_path>
doctor_check_native_lib_conflicts() {
    local env_path="$1"

    if [[ ! -d "$env_path" ]]; then
        return 0
    fi

    local site_packages
    site_packages=$(find "$env_path/lib" -maxdepth 2 -type d -name "site-packages" 2>/dev/null | head -1)

    # Known pip packages that bundle their own OpenMP runtime
    local -a pip_bundlers=("torch" "tensorflow" "tensorflow_macos" "tensorflow-macos"
                           "tensorflow_metal" "jax" "jaxlib")

    # Known conda packages that link against the shared OpenMP in env/lib/
    local -a conda_linkers=("numpy" "scipy" "scikit-learn" "pandas" "openblas" "blas" "mkl")

    # Detect pip bundlers present in site-packages
    local -a found_pip=()
    if [[ -n "$site_packages" ]]; then
        for pkg in "${pip_bundlers[@]}"; do
            local matches=("$site_packages/${pkg}-"*.dist-info)
            [[ -e "${matches[0]}" ]] && found_pip+=("$pkg")
        done
    fi

    # Detect conda linkers present in conda-meta
    local -a found_conda=()
    if [[ -d "$env_path/conda-meta" ]]; then
        for pkg in "${conda_linkers[@]}"; do
            local matches=("$env_path/conda-meta/${pkg}-"*.json)
            [[ -e "${matches[0]}" ]] && found_conda+=("$pkg")
        done
    fi

    # Only check for a missing shared lib when both sides are present
    if [[ ${#found_pip[@]} -eq 0 ]] || [[ ${#found_conda[@]} -eq 0 ]]; then
        printf "✓ No conda/pip native library conflicts detected\n"
        return 0
    fi

    # Platform-specific shared library name and conda fix package
    local missing_lib="" fix_pkg=""
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ ! -f "$env_path/lib/libomp.dylib" ]]; then
            missing_lib="libomp.dylib"
            fix_pkg="llvm-openmp"
        fi
    else
        local gomp_matches=("$env_path/lib/libgomp.so"*)
        if [[ ! -e "${gomp_matches[0]}" ]]; then
            missing_lib="libgomp.so"
            fix_pkg="libgomp"
        fi
    fi

    if [[ -z "$missing_lib" ]]; then
        printf "✓ No conda/pip native library conflicts detected\n"
        return 0
    fi

    local pip_list conda_list
    pip_list=$(IFS=', '; echo "${found_pip[*]}")
    conda_list=$(IFS=', '; echo "${found_conda[*]}")

    printf "⚠ Potential native library conflict detected:\n"
    printf "    pip-installed:   %s (bundles its own OpenMP)\n" "$pip_list"
    printf "    conda-installed: %s (requires %s)\n" "$conda_list" "$missing_lib"
    printf "    %s not found in %s/lib/\n\n" "$missing_lib" "$env_path"
    printf "  Fix: add '%s' to environment.yml conda dependencies:\n" "$fix_pkg"
    printf "    dependencies:\n"
    printf "      - %s\n" "$fix_pkg"
    printf "  Then regenerate: conda-lock -f environment.yml -p %s\n" "$(uname -m)"
}

# Detect venv path mismatch (relocated project).
#
# When a project directory is moved after venv creation, pyvenv.cfg and the
# activate script retain hardcoded paths to the original location. Direnv
# will prepend the wrong bin/ to PATH, so `which python` resolves to a
# system shim instead of the venv's Python.
#
# Extracts the venv path from pyvenv.cfg's `command` line (Python 3.11+)
# or falls back to parsing VIRTUAL_ENV from bin/activate (all versions).
# Prints a warning if the recorded path differs from the actual location.
# Usage: doctor_check_venv_path <env_path>
doctor_check_venv_path() {
    local env_path="$1"

    # Strategy 1: pyvenv.cfg command line (Python 3.11+)
    local cfg_venv_path=""
    local pyvenv_cfg="$env_path/pyvenv.cfg"
    if [[ -f "$pyvenv_cfg" ]]; then
        cfg_venv_path="$(grep "^command" "$pyvenv_cfg" 2>/dev/null | sed 's/.*-m venv //' || true)"
    fi

    # Strategy 2: VIRTUAL_ENV from activate script (all Python versions)
    # The export line is indented inside a case block, e.g.:
    #     export VIRTUAL_ENV=/path/to/.venv
    if [[ -z "$cfg_venv_path" ]]; then
        local activate_script="$env_path/bin/activate"
        if [[ -f "$activate_script" ]]; then
            cfg_venv_path="$(grep 'export VIRTUAL_ENV=' "$activate_script" 2>/dev/null | grep -v 'cygpath' | head -1 | sed 's/.*export VIRTUAL_ENV=//' | tr -d '"'"'" || true)"
        fi
    fi

    if [[ -z "$cfg_venv_path" ]]; then
        return 0
    fi

    local expected_venv_path
    expected_venv_path="$(cd "$env_path" && pwd -P)"
    local canonical_cfg_path
    # Resolve the config path if it exists, otherwise use as-is
    if [[ -d "$cfg_venv_path" ]]; then
        canonical_cfg_path="$(cd "$cfg_venv_path" && pwd -P)"
    else
        canonical_cfg_path="$cfg_venv_path"
    fi

    if [[ "$canonical_cfg_path" != "$expected_venv_path" ]]; then
        printf "⚠ Environment: venv path mismatch (project may have been relocated)\n"
        printf "  Created at: %s\n" "$cfg_venv_path"
        printf "  Expected:   %s\n" "$expected_venv_path"
        printf "  Run 'pyve init --force' to recreate the environment.\n"
        return 0
    fi

    return 0
}

#============================================================
# VS Code Settings
#============================================================

# Generate .vscode/settings.json for micromamba environments.
#
# Points the IDE at the correct interpreter and prevents it from attempting
# to manage the environment independently (which conflicts with direnv/Pyve).
#
# Skips if the file already exists, unless PYVE_REINIT_MODE=force.
# Usage: write_vscode_settings <env_name>
write_vscode_settings() {
    # shellcheck disable=SC2034 # $1 accepted for caller compat; main env lives at the v3 root slot, not the configured name
    local env_name="$1"
    local vscode_dir=".vscode"
    local settings_file="$vscode_dir/settings.json"
    # The main micromamba env lives at the v3 root slot (Story N.bf.14),
    # not the flat configured-name path. `$1` accepted for caller compat.
    local interpreter_path
    interpreter_path="$(micromamba_root_prefix)/bin/python"

    if [[ -f "$settings_file" ]] && [[ "${PYVE_REINIT_MODE:-}" != "force" ]]; then
        log_info "Skipping .vscode/settings.json (already exists; use --force to overwrite)"
        return 0
    fi

    mkdir -p "$vscode_dir"
    cat > "$settings_file" << EOF
{
  "python.defaultInterpreterPath": "${interpreter_path}",
  "python.terminal.activateEnvironment": false,
  "python.condaPath": ""
}
EOF
    log_success "Created .vscode/settings.json (interpreter: ${interpreter_path})"
}

#============================================================
# Content hashing
#============================================================

# Story N.bf.15: portable SHA-256 of a file's contents. Probes the two
# tools that cover the OSes pyve supports — `sha256sum` (Linux/coreutils)
# then `shasum -a 256` (macOS, where `sha256sum` is absent) — and prints
# the 64-hex digest to stdout.
#
# Deliberately NO `cksum`/CRC fallback: this is a *true* SHA-256 so the
# same helper is safe to reuse for N.bh's bootstrap-download verification
# (comparing against a published SHA-256 checksum — a CRC would never
# match and would defeat the security check). When neither tool exists,
# returns non-zero with no output, so callers degrade safely:
#   - drift detection (N.bf.15): treat as "can't tell" → no nudge.
#   - download verification (N.bh): treat as "can't verify" → hard error.
# Also returns non-zero if <file> is missing/unreadable.
pyve_file_sha256() {
    local file="$1"
    [[ -r "$file" ]] || return 1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        return 1
    fi
}

#============================================================
# Cloud Sync Detection
#============================================================

# Hard fail if the current directory is inside a known cloud-synced path.
#
# Cloud sync daemons (iCloud Drive, Dropbox, Google Drive, OneDrive) write
# concurrently to synced directories, which corrupts micromamba environments
# during extraction. This causes non-deterministic import failures and can
# damage the Python standard library itself.
#
# Set PYVE_ALLOW_SYNCED_DIR=1 (or pass --allow-synced-dir) to bypass.
# Usage: check_cloud_sync_path
check_cloud_sync_path() {
    if [[ "${PYVE_ALLOW_SYNCED_DIR:-}" == "1" ]]; then
        return 0
    fi

    local current_dir="$PWD"
    local sync_root=""
    local sync_provider=""

    # Primary check: known synced path prefixes
    local -a known_synced=(
        "$HOME/Documents"
        "$HOME/Desktop"
        "$HOME/Library/Mobile Documents"
        "$HOME/Dropbox"
        "$HOME/Google Drive"
        "$HOME/OneDrive"
    )

    local path
    for path in "${known_synced[@]}"; do
        if [[ "$current_dir" == "$path" ]] || [[ "$current_dir" == "$path/"* ]]; then
            sync_root="$path"
            case "$path" in
                */Documents)                  sync_provider="iCloud Drive" ;;
                */Desktop)                    sync_provider="iCloud Drive (Desktop)" ;;
                */"Library/Mobile Documents") sync_provider="iCloud Drive" ;;
                */Dropbox)                    sync_provider="Dropbox" ;;
                */"Google Drive")             sync_provider="Google Drive" ;;
                */OneDrive)                   sync_provider="OneDrive" ;;
            esac
            break
        fi
    done

    # Secondary check: extended attributes (macOS only)
    if [[ -z "$sync_root" ]] && [[ "$(uname)" == "Darwin" ]] && command -v xattr >/dev/null 2>&1; then
        if xattr -l "$current_dir" 2>/dev/null | grep -qi "com.apple.cloud\|com.dropbox\|com.google.drive\|com.microsoft.onedrive"; then
            sync_root="$current_dir"
            sync_provider="cloud sync (detected via extended attributes)"
        fi
    fi

    if [[ -z "$sync_root" ]]; then
        return 0
    fi

    printf "ERROR: Project is inside a cloud-synced directory.\n\n" >&2
    printf "  Path:      %s\n" "$current_dir" >&2
    printf "  Sync root: %s (%s)\n\n" "$sync_root" "$sync_provider" >&2
    printf "  Cloud sync daemons write concurrently to synced directories, which\n" >&2
    printf "  corrupts micromamba environments during extraction. This causes\n" >&2
    printf "  non-deterministic import failures and can damage the Python standard\n" >&2
    printf "  library itself.\n\n" >&2
    printf "  Recommended fix: move your project outside the synced directory.\n" >&2
    printf "    mv \"%s\" ~/Developer/%s\n\n" "$current_dir" "$(basename "$current_dir")" >&2
    printf "  If you have disabled sync for this directory and understand the risk:\n" >&2
    printf "    pyve init --allow-synced-dir\n" >&2
    exit 1
}

#============================================================
# Install Source Detection
#============================================================

# Detect how pyve was installed.
# Prints one of: homebrew, installed, source
# Requires SCRIPT_DIR and TARGET_BIN_DIR to be set.
detect_install_source() {
    if command -v brew >/dev/null 2>&1; then
        local brew_prefix
        brew_prefix="$(brew --prefix 2>/dev/null)"
        if [[ "$SCRIPT_DIR" == "$brew_prefix"/* ]]; then
            echo "homebrew"
            return 0
        fi
    fi
    if [[ "$SCRIPT_DIR" == "$TARGET_BIN_DIR" ]]; then
        echo "installed"
    else
        echo "source"
    fi
}

#============================================================
# File Utilities
#============================================================

# Usage: is_file_empty "filename"
is_file_empty() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0  # Doesn't exist, treat as empty
    fi

    if [[ ! -s "$file" ]]; then
        return 0  # Exists but empty
    fi

    return 1  # Has content
}

#============================================================
# Testenv (dev/test runner environment) Utilities
#
# Three cross-command helpers — each shared by 2+ of `init`,
# `testenv`, `purge`, `test`. Moved out of `pyve.sh` by Story K.g per
# audit F-7 (`purge_env_dir` shared with `purge`) and F-8
# (`env_paths` + `ensure_env_exists` shared with `init` and
# `test`).
#
# Post-M.h.3 / N.f: derive both paths from `resolve_env_path testenv`
# in lib/envs.sh — the single source of truth for the v3
# `.pyve/envs/<name>/{venv,conda}/` layout. The `TESTENV_DIR_NAME`
# global in pyve.sh is retained as a back-compat constant for any
# external scripts referencing it, but no internal code reads it.
#============================================================

# Emit two lines: testenv_root, then testenv_venv. Single source of
# truth for both paths so callers do not hard-code `.pyve/envs/...`.
# `resolve_env_path testenv` may trigger opportunistic migration
# (M.h.3); we tolerate that side effect because every caller of
# `env_paths` is about to act on the testenv anyway.
env_paths() {
    local testenv_venv
    testenv_venv="$(resolve_env_path testenv)"
    local testenv_root="${testenv_venv%/venv}"
    printf "%s\n" "$testenv_root" "$testenv_venv"
}

# Create the testenv if it doesn't exist; rebuild it if its Python
# version has drifted from the current project Python (mismatched
# `pyvenv.cfg` version field).
#
# Story M.i.1: accepts an optional `<name>` argument. No-arg defaults
# to the reserved `testenv` (today's behavior). With-arg: load config
# (idempotent if caller already ran read_env_config), validate name
# via `assert_env_name_actionable`, resolve path via
# `resolve_env_path`.
#
# Story M.k: dispatches on the resolved backend — venv envs go through
# `python -m venv`; conda envs (`backend = "micromamba"` or `inherit`
# resolving to micromamba) go through `_env_init_conda` in
# `lib/commands/env.sh`, which calls `micromamba create -p <path>
# -f <manifest> -y` from the env's declared `manifest`.
ensure_env_exists() {
    local name="${1:-testenv}"

    # Always load config so we can validate names + dispatch on backend.
    # Idempotent if the caller already populated the V3 arrays.
    if [[ -z "${PYVE_TESTENVS_NAMES+x}" ]]; then
        read_env_config
    fi
    assert_env_name_actionable "$name" || return 1

    local backend
    backend="$(_env_resolve_backend "$name")" || backend="venv"

    local testenv_env_path testenv_root
    testenv_env_path="$(resolve_env_path "$name")"
    # Strip either the /venv or /conda suffix to get the env root.
    testenv_root="${testenv_env_path%/venv}"
    testenv_root="${testenv_root%/conda}"

    # Story N.bf.17: do NOT mkdir the env root here. Materialize only
    # AFTER the relevant resolvability gate passes, so a failed gate (e.g.
    # the asdf-shim trap on an uninitialized / non-activated project)
    # leaves no `.pyve/envs/<name>` stray for a later `pyve purge` to
    # "find" and remove. Each branch below mkdir's once it commits to
    # creating the env.

    if [[ "$backend" == "micromamba" ]]; then
        mkdir -p "$testenv_root"
        local manifest
        manifest="$(_env_manifest_of "$name")" || manifest=""
        _env_init_conda "$name" "$testenv_env_path" "$manifest" || return $?
        # Story M.m: write initial `.state` for the conda env (parallel
        # to the venv branch below). Idempotent: skipped when .state
        # already exists.
        if [[ ! -f "$(state_path "$name")" ]]; then
            state_write "$name" "micromamba" manifest="$manifest"
        fi
        return 0
    fi

    # Venv backend: today's behavior.
    # If the testenv exists but was built with a different Python version (e.g.
    # the project Python was changed after the initial pyve init, then pyve init
    # --force preserved the old testenv via --keep-testenv), rebuild it.
    if [[ -d "$testenv_env_path" ]] && [[ -f "$testenv_env_path/pyvenv.cfg" ]]; then
        # pre-flight before invoking `python -c` for the
        # drift check. Previously this silently no-op'd when python
        # errored — `current_ver` came back empty, the comparison
        # short-circuited, and the stale testenv stayed in place with
        # no signal to the user. Now we surface the same actionable
        # asdf-shim error here. `|| true` removed from `current_ver`
        # since python is pre-flighted; a failure now means something
        # unexpected, not the routine asdf-trap.
        assert_python_resolvable || return 1
        local testenv_ver current_ver
        testenv_ver="$(awk -F' *= *' '/^version/{print $2; exit}' "$testenv_env_path/pyvenv.cfg" 2>/dev/null || true)"
        current_ver="$(python -c 'import sys; print(".".join(str(x) for x in sys.version_info[:3]))' 2>/dev/null)"
        if [[ -n "$testenv_ver" && -n "$current_ver" && "$testenv_ver" != "$current_ver" ]]; then
            warn "Testenv Python ($testenv_ver) differs from project Python ($current_ver) — rebuilding testenv..."
            rm -rf "$testenv_env_path"
        fi
    fi

    if [[ ! -d "$testenv_env_path" ]]; then
        info "Creating dev/test runner environment in '$testenv_env_path'..."
        # pre-flight check for the asdf/pyenv shim trap. Gate BEFORE the
        # mkdir below (Story N.bf.17) so a failed resolution materializes
        # nothing.
        # The next call invokes `python` directly. In a non-activated
        # shell with no resolvable version pin, the shim errors with
        # asdf's confusing "No version is set for command python" — a
        # leak that reads as a pyve bug. Catch it here and emit a
        # pyve-owned error pointing at `direnv allow` / `pyve run`.
        # Placed AFTER the banner so the user sees the intent first,
        # and the existing testenv-grammar tests still observe the
        # banner before the eventual error.
        assert_python_resolvable || return 1
        mkdir -p "$testenv_root"
        run_cmd python -m venv "$testenv_env_path"
        success "Created dev/test runner environment"
    fi

    # Story M.m: write an initial `.state` for the freshly-created env
    # so M.m's `last_used_at` touch (in `test_tests`) and M.p's
    # `pyve testenv list` / `prune` have something to read. Idempotent:
    # skipped when `.state` already exists (preserves `provisioned_at`
    # from the legacy migration or a prior `state_write` invocation).
    if [[ ! -f "$(state_path "$name")" ]]; then
        state_write "$name" "venv"
    fi
}

# Remove the testenv directory (no-op message if absent).
#
# Story M.i.4: accepts an optional `<name>` argument (default `testenv`).
# Removes the env root (`.pyve/envs/<name>/` in v3, was `.pyve/testenvs/<name>/`
# pre-N.f), not just the inner `venv/` — covers `.state` and any future
# siblings. Backend-agnostic (rm -rf doesn't care whether the env is
# venv or conda underneath).
purge_env_dir() {
    local name="${1:-testenv}"
    local testenv_venv testenv_root
    testenv_venv="$(resolve_env_path "$name")"
    # `dirname` handles both layout shapes — .pyve/envs/<name>/venv
    # (venv-backed) and .pyve/envs/<name>/conda (conda-backed) —
    # without hard-coding the suffix.
    testenv_root="$(dirname "$testenv_venv")"
    if [[ -d "$testenv_root" ]]; then
        rm -rf "$testenv_root"
        success "Removed $testenv_root"
    else
        info "No dev/test runner environment found at '$testenv_root'"
    fi
}
