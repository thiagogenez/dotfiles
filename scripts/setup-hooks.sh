#!/usr/bin/env bash

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
hooks_path=.githooks
hook="$repo/$hooks_path/pre-commit"

usage() {
    printf 'Usage: %s [--check]\n' "$0" >&2
}

current_hooks_path() {
    git -C "$repo" config --local --get core.hooksPath 2>/dev/null || true
}

check_hooks() {
    local current
    current=$(current_hooks_path)

    if [ "$current" = "$hooks_path" ]; then
        printf 'Git hooks are active: %s\n' "$hooks_path"
        return
    fi

    printf 'Error: Git hooks are not active for this clone.\n' >&2
    printf 'Activate them with: bash scripts/setup-hooks.sh\n' >&2
    return 1
}

git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
    printf 'Error: %s is not a Git checkout.\n' "$repo" >&2
    exit 1
}

[ -x "$hook" ] || {
    printf 'Error: versioned pre-commit hook is not executable: %s\n' "$hook" >&2
    exit 1
}

case "${1:-}" in
    '')
        git -C "$repo" config --local core.hooksPath "$hooks_path"
        check_hooks
        ;;
    --check) check_hooks ;;
    -h | --help) usage ;;
    *)
        usage
        exit 2
        ;;
esac
