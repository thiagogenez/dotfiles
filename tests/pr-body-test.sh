#!/usr/bin/env bash

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
validator="$repo/tests/pr-body.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pr-body.XXXXXX")
marker="$test_root/evaluated"

cleanup() {
    case "$(basename "$test_root")" in
        dotfiles-pr-body.*) rm -rf -- "$test_root" ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'PR body test failed: %s\n' "$1" >&2
    exit 1
}

expect_accept() {
    local name=$1 body=$2 output

    if ! output=$(bash "$validator" --text "$body" 2>&1); then
        fail "$name should pass: $output"
    fi
}

expect_reject() {
    local name=$1 body=$2 output

    if output=$(bash "$validator" --text "$body" 2>&1); then
        fail "$name should fail"
    fi

    case "$output" in
        *"Error:"*) ;;
        *) fail "$name should return a useful error: $output" ;;
    esac
}

valid_body=$(printf '%s\n' \
    'Closes #42' \
    '' \
    '## Problem' \
    '' \
    'A publishing tool can omit the local headings.' \
    '' \
    '## Before' \
    '' \
    'The same command had no report.' \
    '' \
    '```text' \
    'before evidence' \
    '```' \
    '' \
    '## After' \
    '' \
    'The same command now has a report.' \
    '' \
    '```text' \
    'after evidence' \
    '```' \
    '' \
    '## Implementation' \
    '' \
    "The validator treats \$(touch \"$marker\") as text." \
    '' \
    '## Validation' \
    '' \
    'The focused regression passes.' \
    '' \
    '## Not covered' \
    '' \
    'No coverage threshold is added.')

generic_body=$(printf '%s\n' \
    'Closes #42' \
    '' \
    '## What changed' \
    '' \
    'A validator was added.' \
    '' \
    '## Why' \
    '' \
    'The template should be enforced.' \
    '' \
    '## Validation' \
    '' \
    'Tests pass.')

missing_body=${valid_body/Before/Context}
reordered_body=${valid_body/Before/Temporary}
reordered_body=${reordered_body/After/Before}
reordered_body=${reordered_body/Temporary/After}
duplicate_body=${valid_body/After/$'Before\n\nDuplicate evidence.\n\n## After'}
empty_problem=${valid_body/A publishing tool can omit the local headings./}
empty_before=${valid_body/before evidence/}
empty_after=${valid_body/after evidence/}

# GitHub hands the workflow a body with CRLF line endings.
crlf_body=$(printf '%s' "$valid_body" | sed 's/$/\r/')

expect_accept "complete template" "$valid_body"
expect_accept "body stored with CRLF" "$crlf_body"
[ ! -e "$marker" ] || fail "body content was evaluated as shell code"
expect_reject "former #41 headings" "$generic_body"
expect_reject "missing section" "$missing_body"
expect_reject "reordered sections" "$reordered_body"
expect_reject "duplicate section" "$duplicate_body"
expect_reject "empty required section" "$empty_problem"
expect_reject "empty Before evidence" "$empty_before"
expect_reject "empty After evidence" "$empty_after"

printf 'Pull request body tests passed.\n'
