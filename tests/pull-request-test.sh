#!/usr/bin/env bash

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$repo/scripts/pull-request.sh"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pull-request.XXXXXX")
mock_bin="$test_root/bin"
body_file="$test_root/body.md"
prepared_file="$test_root/prepared.md"
gh_log="$test_root/gh.log"

cleanup() {
    case "$(basename "$test_root")" in
        dotfiles-pull-request.*) rm -rf -- "$test_root" ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'Pull request helper test failed: %s\n' "$1" >&2
    exit 1
}

expect_reject() {
    local name=$1
    shift

    : >"$gh_log"
    if "$@" >"$test_root/output" 2>&1; then
        fail "$name should fail"
    fi
    [ ! -s "$gh_log" ] || fail "$name should not invoke gh"
}

mkdir -p "$mock_bin"

cat >"$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "branch --show-current") printf '%s\n' "${MOCK_BRANCH:-fix/pr-helper}" ;;
    "rev-parse HEAD") printf '%s\n' "${MOCK_LOCAL_HEAD:-abc123}" ;;
    "rev-parse refs/remotes/origin/"*)
        [ "${MOCK_REMOTE_EXISTS:-1}" -eq 1 ] || exit 1
        printf '%s\n' "${MOCK_REMOTE_HEAD:-abc123}"
        ;;
    *) exit 2 ;;
esac
EOF

cat >"$mock_bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$GH_LOG"
printf 'https://github.com/example/dotfiles/pull/1\n'
EOF

chmod +x "$mock_bin/git" "$mock_bin/gh"

valid_body=$(printf '%s\n' \
    'Closes #42' \
    '' \
    '## Problem' \
    '' \
    'A generic publisher can ignore the local template.' \
    '' \
    '## Before' \
    '' \
    'The publishing command accepts the wrong headings.' \
    '' \
    '```text' \
    'wrong headings accepted' \
    '```' \
    '' \
    '## After' \
    '' \
    'The same command rejects the wrong headings.' \
    '' \
    '```text' \
    'Error: Expected ## Problem before ## Validation' \
    '```' \
    '' \
    '## Implementation' \
    '' \
    'The helper validates metadata before invoking gh.' \
    '' \
    '## Validation' \
    '' \
    'The focused helper regression passes.' \
    '' \
    '## Not covered' \
    '' \
    'The helper does not write application prose.')
printf '%s\n' "$valid_body" >"$body_file"

bash "$helper" prepare --issue 42 --output "$prepared_file" >/dev/null
first_line=$(sed -n '1p' "$prepared_file")
[ "$first_line" = '<!-- markdownlint-disable-file MD041 -->' ] ||
    fail "prepare should preserve the template"
grep -qx 'Closes #42' "$prepared_file" ||
    fail "prepare should insert the issue reference"
expect_reject "existing prepare output" \
    bash "$helper" prepare --issue 42 --output "$prepared_file"

PATH="$mock_bin:$PATH" GH_LOG="$gh_log" \
    bash "$helper" create \
    --issue 42 \
    --title 'fix: guard pull request creation' \
    --body-file "$body_file" >"$test_root/output"

expected_args=$(printf '%s\n' \
    'pr' \
    'create' \
    '--base' \
    'main' \
    '--head' \
    'fix/pr-helper' \
    '--title' \
    'fix: guard pull request creation' \
    '--body-file' \
    "$body_file")
[ "$(<"$gh_log")" = "$expected_args" ] || fail "create passed unexpected gh arguments"

expect_reject "invalid title" \
    env PATH="$mock_bin:$PATH" GH_LOG="$gh_log" \
    bash "$helper" create --issue 42 --title 'Wrong title' \
    --body-file "$body_file"

invalid_body=$(printf '%s\n' "$valid_body" | sed 's/^## Before$/## Context/')
printf '%s\n' "$invalid_body" >"$body_file"
expect_reject "invalid body" \
    env PATH="$mock_bin:$PATH" GH_LOG="$gh_log" \
    bash "$helper" create --issue 42 \
    --title 'fix: guard pull request creation' --body-file "$body_file"

printf '%s\n' "$valid_body" >"$body_file"
expect_reject "wrong issue reference" \
    env PATH="$mock_bin:$PATH" GH_LOG="$gh_log" \
    bash "$helper" create --issue 41 \
    --title 'fix: guard pull request creation' --body-file "$body_file"

expect_reject "base branch" \
    env PATH="$mock_bin:$PATH" GH_LOG="$gh_log" MOCK_BRANCH=main \
    bash "$helper" create --issue 42 \
    --title 'fix: guard pull request creation' --body-file "$body_file"

expect_reject "unpushed commit" \
    env PATH="$mock_bin:$PATH" GH_LOG="$gh_log" MOCK_REMOTE_HEAD=def456 \
    bash "$helper" create --issue 42 \
    --title 'fix: guard pull request creation' --body-file "$body_file"

printf 'Pull request helper tests passed.\n'
