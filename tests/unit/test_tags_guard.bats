#!/usr/bin/env bats
# bats file_tags=core
#
# Copyright (c) 2026 Pointmatic, (https://www.pointmatic.com)
# SPDX-License-Identifier: Apache-2.0
#
# Drift guard for the unit-suite subsystem tags.
#
# Every tests/unit/*.bats file carries a `# bats file_tags=<tag>[,<tag>]`
# line so targeted runs (`make test-tag TAG=<t>`, `bats --filter-tags`)
# can select by subsystem. The vocabulary is CLOSED — this file is its
# single source of truth in code (docs/specs/testing-spec.md documents
# it for humans). A new test file must pick the closest subsystem tag;
# a genuinely new subsystem extends the list HERE, in testing-spec.md,
# and (if high-traffic) as a Makefile shorthand, in the same change.

# The closed vocabulary. Keep sorted; keep in sync with testing-spec.md.
PYVE_TEST_TAG_VOCABULARY="check cli core env init manifest micromamba plugin purge self ui"

_unit_dir() {
    cd "$(dirname "$BATS_TEST_FILENAME")" && pwd
}

@test "tags guard: every unit test file declares file_tags" {
    local dir untagged=""
    dir="$(_unit_dir)"
    local f
    for f in "$dir"/*.bats; do
        if ! grep -q "^# bats file_tags=" "$f"; then
            untagged+="${f##*/} "
        fi
    done
    if [[ -n "$untagged" ]]; then
        echo "untagged files: $untagged"
        false
    fi
}

@test "tags guard: every used tag is in the closed vocabulary" {
    local dir bad=""
    dir="$(_unit_dir)"
    local f line tags tag
    for f in "$dir"/*.bats; do
        line="$(grep -m1 "^# bats file_tags=" "$f" || true)"
        [[ -z "$line" ]] && continue  # the other test reports untagged files
        tags="${line#\# bats file_tags=}"
        for tag in ${tags//,/ }; do
            if [[ " $PYVE_TEST_TAG_VOCABULARY " != *" $tag "* ]]; then
                bad+="${f##*/}:$tag "
            fi
        done
    done
    if [[ -n "$bad" ]]; then
        echo "tags outside the closed vocabulary: $bad"
        echo "vocabulary: $PYVE_TEST_TAG_VOCABULARY"
        false
    fi
}
