#!/usr/bin/env bash

set -euo pipefail

usage() {
    printf 'Usage: %s (--text "BODY" | --file PATH)\n' "$0" >&2
}

body_error() {
    printf 'Error: %s\n' "$1" >&2
}

is_blank() {
    case "$1" in
        *[![:space:]]*) return 1 ;;
        *) return 0 ;;
    esac
}

heading_index() {
    case "$1" in
        "## Problem") HEADING_INDEX=0 ;;
        "## Before") HEADING_INDEX=1 ;;
        "## After") HEADING_INDEX=2 ;;
        "## Implementation") HEADING_INDEX=3 ;;
        "## Validation") HEADING_INDEX=4 ;;
        "## Not covered") HEADING_INDEX=5 ;;
        *) return 1 ;;
    esac
}

validate_body() {
    local body=$1 line index i
    local current=-1 next=0 in_fence=0 fence_section=-1
    local fence_has_content=0 in_comment=0
    local required=(
        "Problem"
        "Before"
        "After"
        "Implementation"
        "Validation"
        "Not covered"
    )
    local seen=(0 0 0 0 0 0)
    local content=(0 0 0 0 0 0)
    local evidence=(0 0 0 0 0 0)

    while IFS= read -r line || [ -n "$line" ]; do
        # GitHub stores a pull request body with CRLF line endings, so every
        # heading and fence arrives with a trailing carriage return.
        line=${line%$'\r'}

        if [ "$in_fence" -eq 1 ]; then
            if [ "$line" = '```' ]; then
                if [ "$fence_section" -ge 0 ] &&
                    [ "$fence_has_content" -eq 1 ]; then
                    content[fence_section]=1
                    if [ "$fence_section" -eq 1 ] ||
                        [ "$fence_section" -eq 2 ]; then
                        evidence[fence_section]=1
                    fi
                fi
                in_fence=0
                fence_section=-1
                fence_has_content=0
            elif ! is_blank "$line"; then
                fence_has_content=1
            fi
            continue
        fi

        if [ "$in_comment" -eq 1 ]; then
            case "$line" in
                *'-->'*) in_comment=0 ;;
            esac
            continue
        fi

        case "$line" in
            *'<!--'*)
                case "$line" in
                    *'-->'*) ;;
                    *) in_comment=1 ;;
                esac
                continue
                ;;
        esac

        if heading_index "$line"; then
            index=$HEADING_INDEX

            if [ "${seen[$index]}" -eq 1 ]; then
                body_error "Pull request body repeats required section: ## ${required[$index]}"
                return 1
            fi

            if [ "$index" -ne "$next" ]; then
                body_error "Expected ## ${required[$next]} before ## ${required[$index]}"
                return 1
            fi

            seen[index]=1
            current=$index
            next=$((next + 1))
            continue
        fi

        case "$line" in
            '## '*)
                current=-1
                continue
                ;;
            '```'*)
                in_fence=1
                fence_section=$current
                fence_has_content=0
                continue
                ;;
        esac

        if [ "$current" -ge 0 ] && ! is_blank "$line"; then
            content[current]=1
        fi
    done <<<"$body"

    if [ "$next" -lt "${#required[@]}" ]; then
        body_error "Pull request body is missing required section: ## ${required[$next]}"
        return 1
    fi

    i=0
    while [ "$i" -lt "${#required[@]}" ]; do
        if [ "${content[$i]}" -eq 0 ]; then
            body_error "Required section is empty: ## ${required[$i]}"
            return 1
        fi
        i=$((i + 1))
    done

    for i in 1 2; do
        if [ "${evidence[$i]}" -eq 0 ]; then
            body_error "## ${required[$i]} needs a non-empty fenced evidence block"
            return 1
        fi
    done
}

if [ "$#" -ne 2 ]; then
    usage
    exit 2
fi

case "$1" in
    --text) body=$2 ;;
    --file)
        if [ ! -f "$2" ]; then
            body_error "Pull request body file does not exist: $2"
            exit 2
        fi
        body=$(<"$2")
        ;;
    *)
        usage
        exit 2
        ;;
esac

validate_body "$body"
printf 'Pull request body is valid.\n'
