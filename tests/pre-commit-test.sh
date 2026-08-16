#!/usr/bin/env bash

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
setup="$repo/scripts/setup-hooks.sh"
hook="$repo/.githooks/pre-commit"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pre-commit.XXXXXX")
fixture="$test_root/repo"
mock_bin="$test_root/bin"
shellcheck_log="$test_root/shellcheck.log"
shfmt_log="$test_root/shfmt.log"
fixture_hook_log="$test_root/fixture-hook.log"
output="$test_root/output"

cleanup() {
    case "$(basename "$test_root")" in
        dotfiles-pre-commit.*) rm -rf -- "$test_root" ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'Pre-commit test failed: %s\n' "$1" >&2
    exit 1
}

mkdir -p "$fixture/scripts" "$fixture/.githooks" "$mock_bin"
cp "$setup" "$fixture/scripts/setup-hooks.sh"
cp "$hook" "$fixture/.githooks/pre-commit"
cat >"$fixture/scripts/lint.sh" <<'EOF'
#!/usr/bin/env bash
printf 'fixture hook\n' >>"$FIXTURE_HOOK_LOG"
EOF
chmod +x "$fixture/.githooks/pre-commit"
git init -q "$fixture"

if bash "$fixture/scripts/setup-hooks.sh" --check >"$output" 2>&1; then
    fail "an inactive clone should fail the hook check"
fi
grep -q 'bash scripts/setup-hooks.sh' "$output" ||
    fail "the inactive check should print the activation command"
if git -C "$fixture" config --local --get core.hooksPath >/dev/null 2>&1; then
    fail "the inactive check should not change Git configuration"
fi

bash "$fixture/scripts/setup-hooks.sh" >"$output"
[ "$(git -C "$fixture" config --local --get core.hooksPath)" = '.githooks' ] ||
    fail "setup should configure only the fixture clone"
bash "$fixture/scripts/setup-hooks.sh" --check >"$output"
FIXTURE_HOOK_LOG="$fixture_hook_log" \
    git -C "$fixture" hook run pre-commit >"$output"
[ "$(<"$fixture_hook_log")" = 'fixture hook' ] ||
    fail "Git should execute the configured versioned hook"

cat >"$mock_bin/shellcheck" <<'EOF'
#!/usr/bin/env bash
printf 'shellcheck\n' >>"$MOCK_SHELLCHECK_LOG"
exit "${MOCK_SHELLCHECK_STATUS:-0}"
EOF

cat >"$mock_bin/shfmt" <<'EOF'
#!/usr/bin/env bash
printf 'shfmt\n' >>"$MOCK_SHFMT_LOG"
exit "${MOCK_SHFMT_STATUS:-0}"
EOF

chmod +x "$mock_bin/shellcheck" "$mock_bin/shfmt"
[ -x "$hook" ] || fail "the versioned hook should be executable"

run_hook() {
    DOTFILES_SHELLCHECK_BIN="$mock_bin/shellcheck" \
        DOTFILES_SHFMT_BIN="$mock_bin/shfmt" \
        MOCK_SHELLCHECK_LOG="$shellcheck_log" \
        MOCK_SHFMT_LOG="$shfmt_log" \
        "$hook"
}

: >"$shellcheck_log"
: >"$shfmt_log"
run_hook >"$output"
[ "$(<"$shellcheck_log")" = shellcheck ] || fail "hook should run ShellCheck"
[ "$(<"$shfmt_log")" = shfmt ] || fail "hook should run shfmt"

: >"$shellcheck_log"
: >"$shfmt_log"
if MOCK_SHELLCHECK_STATUS=1 run_hook >"$output" 2>&1; then
    fail "a ShellCheck failure should block the hook"
fi
[ ! -s "$shfmt_log" ] || fail "shfmt should not run after ShellCheck fails"

: >"$shellcheck_log"
: >"$shfmt_log"
if MOCK_SHFMT_STATUS=1 run_hook >"$output" 2>&1; then
    fail "a shfmt failure should block the hook"
fi

if DOTFILES_SHELLCHECK_BIN="$test_root/missing" \
    DOTFILES_SHFMT_BIN="$mock_bin/shfmt" "$hook" >"$output" 2>&1; then
    fail "a missing lint tool should block the hook"
fi
grep -q 'brew install shellcheck shfmt' "$output" ||
    fail "a missing tool should print installation help"

printf 'Pre-commit hook tests passed.\n'
