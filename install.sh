#!/usr/bin/env bash

set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/env bash "$repo/lib/dotfiles.sh" install "$repo" "$@"
