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

log_info() {
    printf "INFO: %s\n" "$1"
}

log_warning() {
    printf "WARNING: %s\n" "$1" >&2
}

log_error() {
    printf "ERROR: %s\n" "$1" >&2
}

log_success() {
    printf "✓ %s\n" "$1"
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
        read -r response
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
    local block
    block="$(cat <<EOF
$PROJECT_GUIDE_COMPLETION_OPEN
command -v project-guide >/dev/null 2>&1 && \\
  eval "\$(_PROJECT_GUIDE_COMPLETE=${shell}_source project-guide)"
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
    if $pip_cmd install --upgrade project-guide; then
        log_success "Installed project-guide"
    else
        log_warning "Failed to install project-guide (skip with --no-project-guide)"
    fi
    return 0
}

# Run `project-guide init` inside the project environment to populate the
# project-guide artifacts (`.project-guide.yml`, `docs/project-guide/`).
#
# Relies on project-guide >= 2.2.3's --no-input flag for unattended runs.
# Older project-guide versions ignore the flag (and prompt-and-fail-on-closed-stdin
# in pyve's subprocess context); failure is non-fatal.
#
# Usage: run_project_guide_init_in_env <backend> <env_path>
# Returns 0 always — failure is non-fatal by design.
run_project_guide_init_in_env() {
    local backend="$1"
    local env_path="$2"

    local pg_cmd=""
    if [[ "$backend" == "venv" ]]; then
        pg_cmd="$env_path/bin/project-guide"
        if [[ ! -x "$pg_cmd" ]]; then
            log_warning "Cannot run 'project-guide init': binary not found at $pg_cmd"
            return 0
        fi
    elif [[ "$backend" == "micromamba" ]]; then
        local micromamba_path
        micromamba_path="$(get_micromamba_path 2>/dev/null || true)"
        if [[ -z "$micromamba_path" ]]; then
            log_warning "Cannot run 'project-guide init': micromamba not found"
            return 0
        fi
        pg_cmd="$micromamba_path run -p $env_path project-guide"
    else
        log_warning "Cannot run 'project-guide init': unknown backend '$backend'"
        return 0
    fi

    log_info "Running 'project-guide init --no-input' in the project environment..."
    if $pg_cmd init --no-input; then
        log_success "project-guide artifacts generated"
    else
        log_warning "'project-guide init' failed (skip with --no-project-guide)"
    fi
    return 0
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
# Usage: run_project_guide_update_in_env <backend> <env_path>
# Returns 0 always — failure is non-fatal by design.
run_project_guide_update_in_env() {
    local backend="$1"
    local env_path="$2"

    local pg_cmd=""
    if [[ "$backend" == "venv" ]]; then
        pg_cmd="$env_path/bin/project-guide"
        if [[ ! -x "$pg_cmd" ]]; then
            log_warning "Cannot run 'project-guide update': binary not found at $pg_cmd"
            return 0
        fi
    elif [[ "$backend" == "micromamba" ]]; then
        local micromamba_path
        micromamba_path="$(get_micromamba_path 2>/dev/null || true)"
        if [[ -z "$micromamba_path" ]]; then
            log_warning "Cannot run 'project-guide update': micromamba not found"
            return 0
        fi
        pg_cmd="$micromamba_path run -p $env_path project-guide"
    else
        log_warning "Cannot run 'project-guide update': unknown backend '$backend'"
        return 0
    fi

    log_info "Running 'project-guide update --no-input' in the project environment..."
    if $pg_cmd update --no-input; then
        log_success "project-guide artifacts refreshed"
    else
        log_warning "'project-guide update' failed (continuing; run 'project-guide update' manually to retry)"
    fi
    return 0
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
project_guide_in_project_deps() {
    # pyproject.toml — any line mentioning project-guide (in quotes or not),
    # ignoring comment lines.
    if [[ -f "pyproject.toml" ]]; then
        # Strip comment lines, then look for project-guide bounded by a
        # quote, comma, whitespace, version specifier, or end-of-line.
        if grep -v '^[[:space:]]*#' pyproject.toml \
           | grep -qE '(^|[[:space:]"'\''[,(])project-guide([[:space:]"'\''<>=!~,)]|$)'; then
            return 0
        fi
    fi

    # requirements.txt — line starts with project-guide (after optional
    # whitespace and ignoring comment lines).
    if [[ -f "requirements.txt" ]]; then
        if grep -v '^[[:space:]]*#' requirements.txt \
           | grep -qE '^[[:space:]]*project-guide([[:space:]<>=!~]|$)'; then
            return 0
        fi
    fi

    # environment.yml — any non-comment line containing project-guide as a word.
    if [[ -f "environment.yml" ]]; then
        if grep -v '^[[:space:]]*#' environment.yml \
           | grep -qE '(^|[[:space:]"'\''=-])project-guide([[:space:]"'\''<>=!~]|$)'; then
            return 0
        fi
    fi

    return 1
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

# Insert a pattern after a section comment in .gitignore if not already present
# Falls back to append if the section comment is not found.
# Usage: insert_pattern_in_gitignore_section "pattern" "section_comment"
#   pattern:         the gitignore entry (e.g. ".venv")
#   section_comment: the full comment line to insert after (e.g. "# Pyve virtual environment")
insert_pattern_in_gitignore_section() {
    local pattern="$1"
    local section="$2"
    local gitignore=".gitignore"
    
    if [[ ! -f "$gitignore" ]]; then
        touch "$gitignore"
    fi
    
    if gitignore_has_pattern "$pattern"; then
        return 0  # Already present
    fi
    
    # Try to insert after the section comment
    if grep -qxF "$section" "$gitignore" 2>/dev/null; then
        # Insert pattern on the line after the section comment
        local tmpfile
        tmpfile="$(mktemp "${gitignore}.tmp.XXXXXX")"
        while IFS= read -r line || [[ -n "$line" ]]; do
            printf '%s\n' "$line" >> "$tmpfile"
            if [[ "$line" == "$section" ]]; then
                printf '%s\n' "$pattern" >> "$tmpfile"
            fi
        done < "$gitignore"
        mv "$tmpfile" "$gitignore"
    else
        # Section not found — fall back to append
        printf "%s\n" "$pattern" >> "$gitignore"
    fi
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

# Write (or rebuild) the .gitignore from the Pyve template.
#
# The Pyve-managed section is written to a temporary file first.  If an
# existing .gitignore is present, every line that is NOT already in the
# template is appended verbatim, preserving the user's formatting, blank
# lines, section headers, and comments.
#
# The result is: Pyve-managed entries at the top, user entries below.
# Running `pyve init` (or --force) is therefore idempotent — the file
# converges to a stable layout without unnecessary git diffs.
#
# Note: .gitignore does not support inline comments.  A `#` is only a
# comment when it is the first non-whitespace character on the line.
#
# Usage: write_gitignore_template
write_gitignore_template() {
    local gitignore=".gitignore"
    local tmpfile
    tmpfile="$(mktemp "${gitignore}.tmp.XXXXXX")"

    # --- 1. Write the Pyve-managed section ---
    # The Pyve virtual environment block below bakes in every pyve-managed
    # ignore pattern that is NOT user-overridable at init time. Before
    # Story H.e.2a only `.pyve/envs` for micromamba and `.venv` for venv
    # were added dynamically per-backend, which meant a venv-init'd project
    # that later had a micromamba env drop into `.pyve/envs/` leaked
    # thousands of files to `git status`. Static patterns eliminate that
    # asymmetry — `pyve update` restores them on any pre-fix project.
    cat > "$tmpfile" << 'GITIGNORE_EOF'
# macOS only
.DS_Store

# Python build and test artifacts
__pycache__
*.pyc
*.pyo
*.pyd
*.egg-info
*.egg
.coverage
coverage.xml
htmlcov/
.pytest_cache/
dist/
build/

# Jupyter notebooks
.ipynb_checkpoints/
*.ipynb_checkpoints

# Pyve virtual environment
.pyve/envs
.pyve/testenv
.envrc
.env
.vscode/settings.json
GITIGNORE_EOF

    # --- 2. Append non-template lines from the existing file ---
    if [[ -f "$gitignore" ]]; then
        # Build set of ALL template lines (including comments) for deduplication
        local -a template_lines=()
        while IFS= read -r tline; do
            [[ -n "$tline" ]] && template_lines+=("$tline")
        done < "$tmpfile"

        # The only pyve-managed pattern still inserted dynamically is the
        # venv directory name — the user can override it via
        # `pyve init <custom_dir>`, so it can't be baked into the template.
        local -a dynamic_patterns=(
            "${DEFAULT_VENV_DIR:-.venv}"
        )
        template_lines+=("${dynamic_patterns[@]}")

        # Pass through every line from the existing file. Blank lines are
        # buffered and only emitted when followed by a non-skipped (user) line
        # — otherwise they'd accumulate at the boundary between the Pyve
        # section and user content across purge/reinit cycles (Story H.a).
        local pending_blank=false
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ -z "$line" ]]; then
                pending_blank=true
                continue
            fi

            # Skip if this exact line is already in the template
            local found=false
            for tl in "${template_lines[@]}"; do
                if [[ "$line" == "$tl" ]]; then
                    found=true
                    break
                fi
            done

            if [[ "$found" == false ]]; then
                if [[ "$pending_blank" == true ]]; then
                    printf '\n' >> "$tmpfile"
                fi
                printf '%s\n' "$line" >> "$tmpfile"
            fi
            pending_blank=false
        done < "$gitignore"
    fi

    # --- 3. Strip trailing blank lines and replace atomically ---
    # When dynamic entries are deduped, their surrounding blank lines may
    # leak through as trailing whitespace.
    local content
    content="$(cat "$tmpfile")"
    printf '%s\n' "$content" > "$tmpfile"

    mv -f "$tmpfile" "$gitignore"
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
    local env_name="$1"
    local vscode_dir=".vscode"
    local settings_file="$vscode_dir/settings.json"
    local interpreter_path=".pyve/envs/${env_name}/bin/python"

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
