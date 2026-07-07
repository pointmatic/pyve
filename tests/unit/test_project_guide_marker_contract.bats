#!/usr/bin/env bats
# bats file_tags=self
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
#============================================================
# F5: `.project-guide.yml` contract guard + `env_spec_path`
# discovery.
#
# Two concerns:
#   (1) Contract guard — `.project-guide.yml` is pyve's load-bearing
#       cross-repo install marker. These sentinels trip a RED build if an
#       upstream rename/reshape drifts the filename out of pyve's
#       consumers. SCOPE NOTE: we deliberately guard only the STABLE
#       surface — the filename, its root-level location, and its role as
#       the install marker + `env_spec_path` pointer. We do NOT pin the
#       "presence ⇒ Python plugin active" inference (N.aj): that semantic
#       is slated to change under the N.aw global-tool re-approach, so
#       guarding it here would just churn.
#   (2) `env_spec_path` discovery — read the tool-state pointer from
#       `.project-guide.yml`, defaulting to docs/specs/env-dependencies.md.
#============================================================

setup() {
    export PYVE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    load '../helpers/test_helper'
    source "$PYVE_ROOT/lib/ui/core.sh"
    source "$PYVE_ROOT/lib/utils.sh"
    source "$PYVE_ROOT/lib/project_guide.sh"
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

#------------------------------------------------------------
# (1) Contract guard — stable marker surface
#------------------------------------------------------------

@test "marker contract: '.project-guide.yml' is the literal used by canonical consumers" {
    # An upstream rename/reshape must trip these — each is a real consumer
    # that keys behavior off the exact filename. (Post-N.s, the init/update
    # commands live inside the Python plugin, not lib/commands/.)
    grep -q '\.project-guide\.yml' "$PYVE_ROOT/lib/utils.sh"
    grep -q '\.project-guide\.yml' "$PYVE_ROOT/lib/project_guide.sh"
    grep -q '\.project-guide\.yml' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
}

@test "marker contract: the install-marker predicate keys off the exact filename" {
    # `_init_detect_project_guide_present` is the canonical "is project-guide
    # installed in this project?" predicate; it must test the literal marker.
    run grep -nE '_init_detect_project_guide_present\(\)' "$PYVE_ROOT/lib/plugins/python/plugin.sh"
    assert_status_equals 0
    # Its body asserts the marker file presence.
    grep -A2 '_init_detect_project_guide_present()' "$PYVE_ROOT/lib/plugins/python/plugin.sh" \
        | grep -q '\[\[ -f \.project-guide\.yml \]\]'
}

#------------------------------------------------------------
# (2) env_spec_path discovery
#------------------------------------------------------------

@test "env_spec_path: helper is defined in lib/project_guide.sh" {
    run declare -F project_guide_env_spec_path
    assert_status_equals 0
}

@test "env_spec_path: defaults to docs/specs/env-dependencies.md when no marker file" {
    run project_guide_env_spec_path
    assert_status_equals 0
    assert_output_equals "docs/specs/env-dependencies.md"
}

@test "env_spec_path: defaults when marker present but key absent" {
    printf 'installed_version: 2.13.0\ntarget_dir: docs/project-guide\n' > .project-guide.yml
    run project_guide_env_spec_path
    assert_status_equals 0
    assert_output_equals "docs/specs/env-dependencies.md"
}

@test "env_spec_path: reads the pointer value when present" {
    printf 'installed_version: 2.13.0\nenv_spec_path: docs/specs/my-envs.md\n' > .project-guide.yml
    run project_guide_env_spec_path
    assert_status_equals 0
    assert_output_equals "docs/specs/my-envs.md"
}

@test "env_spec_path: trims surrounding whitespace and quotes" {
    printf 'env_spec_path:   "docs/specs/quoted-envs.md"  \n' > .project-guide.yml
    run project_guide_env_spec_path
    assert_status_equals 0
    assert_output_equals "docs/specs/quoted-envs.md"
}

@test "env_spec_path: falls back to default when value is empty" {
    printf 'env_spec_path:\n' > .project-guide.yml
    run project_guide_env_spec_path
    assert_status_equals 0
    assert_output_equals "docs/specs/env-dependencies.md"
}

@test "env_spec_path: single-quoted value is unwrapped" {
    printf "env_spec_path: 'docs/specs/sq-envs.md'\n" > .project-guide.yml
    run project_guide_env_spec_path
    assert_status_equals 0
    assert_output_equals "docs/specs/sq-envs.md"
}
