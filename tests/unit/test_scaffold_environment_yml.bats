#!/usr/bin/env bats
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for `scaffold_starter_environment_yml()` (Story H.f.7).
#
# Library-level behavior of the scaffolding helper:
#   - Writes a valid environment.yml with conda-forge channel,
#     the requested Python pin, and `pip` as a dependency.
#   - Uses the sanitized directory basename as `name` when no
#     explicit env-name is passed.
#   - Honors an explicit env-name override.
#   - Refuses to overwrite an existing environment.yml.
#   - Never scaffolds under --strict.
#   - Short-circuits (refuses) when conda-lock.yml exists (Case 3
#     from validate_lock_file_status — inconsistent-state error).
#

load ../helpers/test_helper

setup() {
    setup_pyve_env
    create_test_dir
}

teardown() {
    cleanup_test_dir
}

#============================================================
# Happy path — fresh dir, --python-version flag, no --env-name
#============================================================

@test "scaffold: creates environment.yml with python pin and conda-forge in empty dir" {
    # rename cwd so the sanitized basename is predictable.
    local dir_basename
    dir_basename="$(basename "$TEST_DIR")"

    run scaffold_starter_environment_yml "3.12.13" "" "false"
    [ "$status" -eq 0 ]
    [ -f environment.yml ]
    grep -q "^channels:" environment.yml
    grep -q "conda-forge" environment.yml
    grep -q "python=3.12.13" environment.yml
    grep -q "^  - pip$" environment.yml
    # Default name is the sanitized basename of cwd.
    local expected_name
    expected_name="$(sanitize_environment_name "$dir_basename")"
    grep -q "^name: ${expected_name}$" environment.yml
}

#============================================================
# --env-name flag overrides the sanitized basename
#============================================================

@test "scaffold: explicit env-name overrides the sanitized basename" {
    run scaffold_starter_environment_yml "3.12.13" "my-custom-env" "false"
    [ "$status" -eq 0 ]
    [ -f environment.yml ]
    grep -q "^name: my-custom-env$" environment.yml
}

#============================================================
# --strict disables scaffolding (returns 1 without writing)
#============================================================

@test "scaffold: --strict (strict_mode=true) does not write environment.yml" {
    run scaffold_starter_environment_yml "3.12.13" "" "true"
    [ "$status" -ne 0 ]
    [ ! -f environment.yml ]
}

#============================================================
# Does not overwrite an existing environment.yml
#============================================================

@test "scaffold: refuses to overwrite an existing environment.yml" {
    printf "name: preserved\nchannels: []\n" > environment.yml

    run scaffold_starter_environment_yml "3.12.13" "" "false"
    [ "$status" -ne 0 ]
    # Pre-existing content is untouched.
    grep -q "^name: preserved$" environment.yml
    # The scaffolded python pin did not leak in.
    ! grep -q "python=3.12.13" environment.yml
}

#============================================================
# Does not scaffold when conda-lock.yml exists without env.yml
# (Case 3 from validate_lock_file_status — inconsistent state)
#============================================================

@test "scaffold: refuses when conda-lock.yml exists without environment.yml" {
    touch conda-lock.yml

    run scaffold_starter_environment_yml "3.12.13" "" "false"
    [ "$status" -ne 0 ]
    [ ! -f environment.yml ]
}

#============================================================
# Generated file is valid YAML structure (basic shape check)
#============================================================

@test "scaffold: generated file has the expected key order (name / channels / dependencies)" {
    run scaffold_starter_environment_yml "3.13.1" "shape-test" "false"
    [ "$status" -eq 0 ]
    # Key order matters for reader sanity and diff review. Extract just
    # the top-level key names in the order they appear.
    local keys_in_order
    keys_in_order="$(grep -Eo "^(name|channels|dependencies):" environment.yml | tr -d ':' | tr '\n' ' ')"
    [[ "$keys_in_order" == "name channels dependencies " ]]
}

#============================================================
# Integration: init --backend micromamba wires scaffolding in
#
# Stubs a no-op micromamba in .pyve/bin/ so init's check passes
# without a network download. We don't care that the downstream
# env-creation step fails — we only assert (a) scaffolding ran
# before the old silent-exit / H.f.6 hard-error path, and
# (b) the scaffolded file has the requested content.
#============================================================

@test "init --backend micromamba in empty dir: scaffolds environment.yml, does not hit H.f.6 error" {
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"

    # No-op micromamba stub so check_micromamba_available returns 0.
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'STUB'
#!/usr/bin/env bash
exit 1   # deliberately fail; we only care that scaffolding ran before this point
STUB
    chmod +x .pyve/bin/micromamba

    run bash -c "NO_COLOR=1 '$PYVE_SCRIPT' init --backend micromamba --python-version 3.12.13 </dev/null"
    # The stub fails env creation downstream, so init exits non-zero —
    # but the scaffold must have happened first.
    [ -f environment.yml ]
    grep -q "python=3.12.13" environment.yml
    # H.f.6's actionable error for Case 4 must NOT appear (scaffolding
    # short-circuited that path).
    [[ "$output" != *"Neither 'environment.yml' nor 'conda-lock.yml' found"* ]]
    # The scaffold notice must appear (unified-UX info line).
    [[ "$output" == *"Scaffolded starter environment.yml"* ]]
}

@test "init --backend micromamba --strict in empty dir: does NOT scaffold (hits H.f.6 error)" {
    export PYVE_SCRIPT="$PYVE_ROOT/pyve.sh"

    # Same stub as above — but --strict should block scaffolding,
    # so init reaches validate_lock_file_status's Case 4 error.
    mkdir -p .pyve/bin
    cat > .pyve/bin/micromamba <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x .pyve/bin/micromamba

    run bash -c "NO_COLOR=1 '$PYVE_SCRIPT' init --backend micromamba --python-version 3.12.13 --strict </dev/null"
    [ ! -f environment.yml ]
    [[ "$output" == *"Neither 'environment.yml' nor 'conda-lock.yml' found"* ]]
}
