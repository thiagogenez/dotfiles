#!/usr/bin/env bash

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
template="$repo/.github/pull_request_template.md"
title_validator="$repo/tests/commit-message.sh"
body_validator="$repo/tests/pr-body.sh"

usage() {
    cat >&2 <<EOF
Usage:
  $0 prepare --issue NUMBER --output PATH
  $0 create --issue NUMBER --title TITLE --body-file PATH [--base BRANCH] [--draft]
EOF
}

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

require_value() {
    if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        fail "$1 requires a value"
    fi
}

validate_issue() {
    case "$1" in
        '' | *[!0-9]* | 0) fail "issue must be a positive number" ;;
    esac
}

prepare_body() {
    local issue='' output='' line
    shift

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --issue)
                require_value "$@"
                issue=$2
                shift 2
                ;;
            --output)
                require_value "$@"
                output=$2
                shift 2
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) fail "unknown prepare option: $1" ;;
        esac
    done

    validate_issue "$issue"
    [ -n "$output" ] || fail "--output is required"
    [ -f "$template" ] || fail "pull request template not found: $template"
    [ ! -e "$output" ] || fail "refusing to overwrite existing file: $output"
    [ -d "$(dirname "$output")" ] || fail "output directory does not exist"

    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = 'Closes #' ]; then
            printf 'Closes #%s\n' "$issue"
        else
            printf '%s\n' "$line"
        fi
    done <"$template" >"$output"

    printf 'Pull request body prepared at %s.\n' "$output"
}

body_closes_issue() {
    local body_file=$1 issue=$2 line

    while IFS= read -r line || [ -n "$line" ]; do
        [ "$line" = "Closes #$issue" ] && return 0
    done <"$body_file"

    return 1
}

create_pull_request() {
    local issue='' title='' body_file='' base='main' draft=0
    local branch local_head remote_head
    local args
    shift

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --issue)
                require_value "$@"
                issue=$2
                shift 2
                ;;
            --title)
                require_value "$@"
                title=$2
                shift 2
                ;;
            --body-file)
                require_value "$@"
                body_file=$2
                shift 2
                ;;
            --base)
                require_value "$@"
                base=$2
                shift 2
                ;;
            --draft)
                draft=1
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) fail "unknown create option: $1" ;;
        esac
    done

    validate_issue "$issue"
    [ -n "$title" ] || fail "--title is required"
    [ -n "$body_file" ] || fail "--body-file is required"
    [ -n "$base" ] || fail "--base must not be empty"
    command -v gh >/dev/null 2>&1 || fail "gh is required"

    bash "$title_validator" --text "$title"
    bash "$body_validator" --file "$body_file"
    body_closes_issue "$body_file" "$issue" ||
        fail "body must contain an exact Closes #$issue line"

    branch=$(git branch --show-current)
    [ -n "$branch" ] || fail "cannot create a pull request from detached HEAD"
    [ "$branch" != "$base" ] || fail "cannot create a pull request from $base"
    case "$branch" in
        main | master) fail "cannot create a pull request from $branch" ;;
    esac

    local_head=$(git rev-parse HEAD)
    if ! remote_head=$(git rev-parse "refs/remotes/origin/$branch" 2>/dev/null); then
        fail "push $branch to origin before creating the pull request"
    fi
    [ "$local_head" = "$remote_head" ] ||
        fail "push the current $branch commit before creating the pull request"

    args=(
        pr create
        --base "$base"
        --head "$branch"
        --title "$title"
        --body-file "$body_file"
    )
    [ "$draft" -eq 0 ] || args+=(--draft)

    gh "${args[@]}"
}

case "${1:-}" in
    prepare) prepare_body "$@" ;;
    create) create_pull_request "$@" ;;
    -h | --help) usage ;;
    '')
        usage
        exit 2
        ;;
    *) fail "unknown command: $1" ;;
esac
