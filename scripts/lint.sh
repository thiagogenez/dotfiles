#!/usr/bin/env bash

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
shellcheck_bin=${DOTFILES_SHELLCHECK_BIN:-shellcheck}
shfmt_bin=${DOTFILES_SHFMT_BIN:-shfmt}

cd "$repo"
shell_files=(
    ./*.sh
    lib/*.sh
    scripts/*.sh
    tests/*.sh
    .githooks/pre-commit
)

require_tool() {
    local tool=$1 name=$2

    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Error: %s is required for shell lint.\n' "$name" >&2
        printf 'Install the contributor tools with: brew install shellcheck shfmt\n' >&2
        exit 1
    fi
}

require_tool "$shellcheck_bin" shellcheck
require_tool "$shfmt_bin" shfmt

"$shellcheck_bin" -x "${shell_files[@]}"
"$shfmt_bin" -d -i 4 -ci -kp "${shell_files[@]}"

printf 'Shell lint passed.\n'
