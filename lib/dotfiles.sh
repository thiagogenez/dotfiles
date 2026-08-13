#!/usr/bin/env bash

# Shared install/uninstall engine and terminal UI.
# Keep this compatible with the Bash 3.2 shipped by macOS.

set -euo pipefail
umask 077

DOTFILES_COMPONENT_IDS=(git ssh gnupg)
DOTFILES_SELECTED=()
DOTFILES_SELECTED_COUNT=0

dotfiles_component_name() {
    case "$1" in
        git)   printf '%s' "Git" ;;
        ssh)   printf '%s' "SSH" ;;
        gnupg) printf '%s' "GnuPG" ;;
    esac
}

dotfiles_component_description() {
    case "$1" in
        git)   printf '%s' "global configuration and ignore rules" ;;
        ssh)   printf '%s' "SSH configuration with a private overlay" ;;
        gnupg) printf '%s' "agent configuration from the private overlay" ;;
    esac
}

# Where a component is authored. The source checkout is never linked into $HOME,
# so it may live in a directory that macOS gates behind a privacy prompt.
dotfiles_component_origin() {
    case "$1" in
        git)   printf '%s' "$DOTFILES_REPO/config/git" ;;
        ssh)   printf '%s' "$DOTFILES_REPO/config/ssh/config" ;;
        gnupg) printf '%s' "$DOTFILES_PRIVATE_REPO/config/gnupg/gpg-agent.conf" ;;
    esac
}

# Where a component is installed. Links in $HOME resolve here and nowhere else.
dotfiles_component_source() {
    case "$1" in
        git)   printf '%s' "$DOTFILES_PREFIX/git" ;;
        ssh)   printf '%s' "$DOTFILES_PREFIX/ssh/config" ;;
        gnupg) printf '%s' "$DOTFILES_PRIVATE_PREFIX/gnupg/gpg-agent.conf" ;;
    esac
}

dotfiles_component_target() {
    case "$1" in
        git)   printf '%s' ".config/git" ;;
        ssh)   printf '%s' ".ssh/config" ;;
        gnupg) printf '%s' ".gnupg/gpg-agent.conf" ;;
    esac
}

dotfiles_component_known() {
    case "$1" in
        git | ssh | gnupg) return 0 ;;
        *) return 1 ;;
    esac
}

dotfiles_component_available() {
    local origin
    origin="$(dotfiles_component_origin "$1")"
    [ -e "$origin" ] || [ -L "$origin" ]
}

dotfiles_component_owned() {
    local source target
    source="$(dotfiles_component_source "$1")"
    target="$HOME/$(dotfiles_component_target "$1")"
    [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]
}

dotfiles_component_has_backup() {
    local target
    target="$(dotfiles_component_target "$1")"
    [ -e "$DOTFILES_BACKUP_ROOT/$target" ] || [ -L "$DOTFILES_BACKUP_ROOT/$target" ]
}

dotfiles_component_selectable() {
    local action="$1" id="$2"

    if [ "$action" = "install" ]; then
        dotfiles_component_available "$id"
    else
        dotfiles_component_owned "$id" || dotfiles_component_has_backup "$id"
    fi
}

dotfiles_add_selected() {
    local candidate="$1" existing index=0

    while [ "$index" -lt "$DOTFILES_SELECTED_COUNT" ]; do
        existing="${DOTFILES_SELECTED[$index]}"
        [ "$existing" = "$candidate" ] && return
        index=$((index + 1))
    done
    DOTFILES_SELECTED[DOTFILES_SELECTED_COUNT]="$candidate"
    DOTFILES_SELECTED_COUNT=$((DOTFILES_SELECTED_COUNT + 1))
}

dotfiles_select_all() {
    local action="$1" id
    DOTFILES_SELECTED=()
    DOTFILES_SELECTED_COUNT=0
    for id in "${DOTFILES_COMPONENT_IDS[@]}"; do
        if dotfiles_component_selectable "$action" "$id"; then
            dotfiles_add_selected "$id"
        fi
    done
}

dotfiles_select_defaults() {
    local action="$1" id
    DOTFILES_SELECTED=()
    DOTFILES_SELECTED_COUNT=0

    if [ "$action" = "install" ]; then
        for id in git ssh; do
            dotfiles_component_available "$id" && dotfiles_add_selected "$id"
        done
    else
        dotfiles_select_all "$action"
    fi
}

dotfiles_parse_selection() {
    local action="$1"
    shift

    DOTFILES_SELECTED=()
    DOTFILES_SELECTED_COUNT=0
    if [ "$#" -eq 1 ] && [ "$1" = "--all" ]; then
        dotfiles_select_all "$action"
        return
    fi

    while [ "$#" -gt 0 ]; do
        if ! dotfiles_component_known "$1"; then
            echo "Unknown component: $1" >&2
            echo "Available components: ${DOTFILES_COMPONENT_IDS[*]}" >&2
            return 2
        fi
        if ! dotfiles_component_selectable "$action" "$1"; then
            if [ "$action" = "install" ]; then
                echo "Cannot install $(dotfiles_component_name "$1"): missing $(dotfiles_component_source "$1")" >&2
            else
                echo "Cannot uninstall $(dotfiles_component_name "$1"): it is not installed by this clone" >&2
            fi
            return 1
        fi
        dotfiles_add_selected "$1"
        shift
    done
}

dotfiles_menu_status() {
    local action="$1" id="$2"

    if ! dotfiles_component_selectable "$action" "$id"; then
        if [ "$action" = "install" ] && [ "$id" = "gnupg" ]; then
            printf '%s' "private config missing"
        else
            printf '%s' "not installed"
        fi
    elif dotfiles_component_owned "$id"; then
        printf '%s' "installed"
    fi
}

dotfiles_render_menu() {
    local action="$1" cursor="$2" redraw="$3"
    shift 3
    local selected=("$@")
    local count="${#DOTFILES_COMPONENT_IDS[@]}" index id marker pointer status suffix

    if [ "$redraw" -eq 1 ]; then
        printf '\033[%dA' "$((count + 3))" >&4
    fi

    printf '\r\033[2K\033[1;36m?\033[0m Select components to %s\n' "$action" >&4
    index=0
    while [ "$index" -lt "$count" ]; do
        id="${DOTFILES_COMPONENT_IDS[$index]}"
        pointer=" "
        [ "$index" -eq "$cursor" ] && pointer="›"

        if ! dotfiles_component_selectable "$action" "$id"; then
            marker="-"
        elif [ "${selected[$index]}" -eq 1 ]; then
            marker="x"
        else
            marker=" "
        fi

        status="$(dotfiles_menu_status "$action" "$id")"
        suffix=""
        [ -n "$status" ] && suffix=" — $status"

        printf '\r\033[2K  %s [%s] \033[1m%s\033[0m — %s\033[2m%s\033[0m\n' \
            "$pointer" "$marker" "$(dotfiles_component_name "$id")" \
            "$(dotfiles_component_description "$id")" "$suffix" >&4
        index=$((index + 1))
    done
    printf '\r\033[2K\n\r\033[2K  \033[2m↑/↓ move • space toggle • a all • enter confirm • q cancel\033[0m\n' >&4
}

dotfiles_open_terminal() {
    if [ -t 0 ] && [ -t 1 ]; then
        exec 3<&0 4>&1
        return
    fi

    if { exec 3<>/dev/tty; } 2>/dev/null; then
        exec 4>&3
        return
    fi

    return 1
}

dotfiles_interactive_selection() {
    local action="$1" count="${#DOTFILES_COMPONENT_IDS[@]}" cursor=0 redraw=0
    local selected=() index id key rest any

    if ! dotfiles_open_terminal; then
        dotfiles_select_defaults "$action"
        return
    fi

    index=0
    while [ "$index" -lt "$count" ]; do
        id="${DOTFILES_COMPONENT_IDS[$index]}"
        selected[index]=0
        if dotfiles_component_selectable "$action" "$id"; then
            if [ "$action" = "uninstall" ] || dotfiles_component_owned "$id" || [ "$id" = "git" ] || [ "$id" = "ssh" ]; then
                selected[index]=1
            fi
        fi
        index=$((index + 1))
    done

    while :; do
        dotfiles_render_menu "$action" "$cursor" "$redraw" "${selected[@]}"
        redraw=1
        IFS= read -r -s -n 1 key <&3 || key="q"

        case "$key" in
            $'\033')
                IFS= read -r -s -n 2 rest <&3 || rest=""
                case "$rest" in
                    '[A') cursor=$(((cursor + count - 1) % count)) ;;
                    '[B') cursor=$(((cursor + 1) % count)) ;;
                esac
                ;;
            k) cursor=$(((cursor + count - 1) % count)) ;;
            j) cursor=$(((cursor + 1) % count)) ;;
            ' ')
                id="${DOTFILES_COMPONENT_IDS[$cursor]}"
                if dotfiles_component_selectable "$action" "$id"; then
                    if [ "${selected[$cursor]}" -eq 1 ]; then
                        selected[cursor]=0
                    else
                        selected[cursor]=1
                    fi
                fi
                ;;
            a)
                any=0
                index=0
                while [ "$index" -lt "$count" ]; do
                    id="${DOTFILES_COMPONENT_IDS[$index]}"
                    if dotfiles_component_selectable "$action" "$id" && [ "${selected[$index]}" -eq 0 ]; then
                        any=1
                    fi
                    index=$((index + 1))
                done
                index=0
                while [ "$index" -lt "$count" ]; do
                    id="${DOTFILES_COMPONENT_IDS[$index]}"
                    if dotfiles_component_selectable "$action" "$id"; then
                        selected[index]="$any"
                    fi
                    index=$((index + 1))
                done
                ;;
            '') break ;;
            q | Q)
                printf '\n%s cancelled.\n' "$action" >&4
                exec 3>&- 4>&-
                return 130
                ;;
        esac
    done

    DOTFILES_SELECTED=()
    DOTFILES_SELECTED_COUNT=0
    index=0
    while [ "$index" -lt "$count" ]; do
        if [ "${selected[$index]}" -eq 1 ]; then
            dotfiles_add_selected "${DOTFILES_COMPONENT_IDS[$index]}"
        fi
        index=$((index + 1))
    done
    printf '\n' >&4
    exec 3>&- 4>&-
}

dotfiles_choose_components() {
    local action="$1"
    shift

    if [ "$#" -gt 0 ]; then
        dotfiles_parse_selection "$action" "$@"
    else
        dotfiles_interactive_selection "$action"
    fi
}

dotfiles_print_selection() {
    local action="$1" id index=0

    if [ "$DOTFILES_SELECTED_COUNT" -eq 0 ]; then
        echo "No components selected."
        return
    fi

    echo "Components to $action:"
    while [ "$index" -lt "$DOTFILES_SELECTED_COUNT" ]; do
        id="${DOTFILES_SELECTED[$index]}"
        echo "  • $(dotfiles_component_name "$id")"
        index=$((index + 1))
    done
    echo
}

dotfiles_reload_agent() {
    command -v gpgconf >/dev/null 2>&1 || return 0
    gpgconf --kill gpg-agent
}

dotfiles_usage() {
    local action="$1"

    if [ "$action" = "install" ]; then
        cat <<'EOF'
Usage: ./install.sh [--all | COMPONENT...]

Publishes the source checkout to ~/.local/share and links $HOME at that copy.
With no arguments, opens an interactive component selector.

Components:
  git    Global Git configuration and ignore rules
  ssh    SSH configuration with a private overlay
  gnupg  GnuPG agent configuration from the private overlay
EOF
    elif [ "$action" = "doctor" ]; then
        cat <<'EOF'
Usage: ./doctor.sh

Checks this machine's installation and reports what it finds. Read-only: it
never repairs anything. Exits non-zero when something is wrong, so it can gate
a shell prompt or a scheduled job.

Run ./update.sh to repair links and republish the checkout.
EOF
    elif [ "$action" = "update" ]; then
        cat <<'EOF'
Usage: ./update.sh [--check]

Republishes the source checkout to the installed copy under ~/.local/share and
repairs any link that has drifted. Only installed components are considered.

  --check  Report what would change and exit non-zero if anything is stale.
EOF
    else
        cat <<'EOF'
Usage: ./uninstall.sh [--all | COMPONENT...]

With no arguments, opens an interactive selector for installed components.

Components: git, ssh, gnupg
EOF
    fi
}

# Mirror one payload directory from the source checkout into the install prefix.
# Reports every file it would touch and leaves matching files alone, so a repeat
# run is silent. With DOTFILES_DRY_RUN=1 nothing is written.
# Digest of a published file, recorded so a later run can tell which side of a
# difference moved. Without it the installer sees only "these differ" and always
# assumes the checkout is the one that changed.
dotfiles_digest() {
    [ -f "$1" ] || return 0
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        sha256sum "$1" | cut -d' ' -f1
    fi
}

dotfiles_manifest_path() {
    printf '%s' "$DOTFILES_MANIFEST_ROOT/$(printf '%s' "$1" | tr '/' '%')"
}

dotfiles_manifest_read() {
    local record
    record="$(dotfiles_manifest_path "$1")"
    [ -f "$record" ] && cat "$record"
}

dotfiles_manifest_write() {
    local record
    record="$(dotfiles_manifest_path "$1")"
    mkdir -p "$DOTFILES_MANIFEST_ROOT"
    dotfiles_digest "$1" >"$record"
}

# Move a file the installer is about to overwrite into the backup store, keeping
# the path it had under the prefix so it can be found again.
dotfiles_preserve_local_edit() {
    local target="$1" relative backup

    relative="${target#"$DOTFILES_DATA_HOME"/}"
    backup="$DOTFILES_BACKUP_ROOT/local/$relative"

    mkdir -p "$(dirname "$backup")"
    cp "$target" "$backup"
    echo "  preserved a local edit to $target at $backup"
}

dotfiles_sync_tree() {
    local source="$1" dest="$2" relative file target listing published

    [ -d "$source" ] || return 0

    if [ "$DOTFILES_DRY_RUN" -eq 0 ]; then
        mkdir -p "$dest"
    fi

    listing="$(find "$source" -type f ! -name '.DS_Store' 2>/dev/null)"
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        relative="${file#"$source"/}"
        target="$dest/$relative"

        if [ -f "$target" ] && cmp -s "$file" "$target"; then
            continue
        fi

        # The installed copy differs from the checkout. Compare both against what
        # was published last to find out which one moved.
        if [ -f "$target" ]; then
            published="$(dotfiles_manifest_read "$target")"
            if [ -n "$published" ] && [ "$published" != "$(dotfiles_digest "$target")" ]; then
                DOTFILES_LOCAL_EDITS=1
                if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
                    echo "  would overwrite a local edit to $target"
                else
                    dotfiles_preserve_local_edit "$target"
                fi
            fi
        fi

        DOTFILES_SYNC_CHANGED=1
        if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
            echo "  would update $target"
            continue
        fi

        mkdir -p "$(dirname "$target")"
        cp "$file" "$target"
        dotfiles_manifest_write "$target"
        echo "  updated $target"
    done <<EOF
$listing
EOF

    # Files dropped from the source checkout must not survive in the prefix.
    listing="$(find "$dest" -type f 2>/dev/null)"
    while IFS= read -r target; do
        [ -n "$target" ] || continue
        relative="${target#"$dest"/}"
        [ -f "$source/$relative" ] && continue

        DOTFILES_SYNC_CHANGED=1
        if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
            echo "  would remove $target"
            continue
        fi

        rm -f "$target" "$(dotfiles_manifest_path "$target")"
        echo "  removed $target"
    done <<EOF
$listing
EOF
}

# Publish every directory under a checkout's config/ into the matching prefix.
# Iterating means a new component needs no edit here, and it keeps the boundary
# honest: config/ is payload, everything else in the checkout is not.
dotfiles_sync_config() {
    local source="$1" dest="$2" entry

    [ -d "$source" ] || return 0

    for entry in "$source"/*; do
        [ -d "$entry" ] || continue
        dotfiles_sync_tree "$entry" "$dest/$(basename "$entry")"
    done
}

# A checkout that exists but has no config/ publishes nothing. Silence there
# reads as "up to date" when it means "this overlay is being ignored", so the
# absent case and the empty case are reported differently.
dotfiles_check_config_dir() {
    local checkout="$1" label="$2"

    [ -d "$checkout" ] || return 0

    if [ ! -d "$checkout/config" ]; then
        echo "Warning: $label at $checkout has no config/ directory." >&2
        echo "         Nothing from it will be published. Payload belongs in" >&2
        echo "         $checkout/config/{git,ssh,gnupg}." >&2
        return 0
    fi

    case "$(echo "$checkout"/config/*/)" in
        *'/config/*/') echo "Warning: $checkout/config is empty, so nothing will be published." >&2 ;;
    esac
}

# Publish both checkouts into their prefixes. The private overlay is optional;
# the Git and SSH includes that reference it degrade to no-ops when it is absent.
dotfiles_sync_payload() {
    DOTFILES_SYNC_CHANGED=0
    DOTFILES_LOCAL_EDITS=0

    dotfiles_check_config_dir "$DOTFILES_REPO" "the checkout"
    dotfiles_check_config_dir "$DOTFILES_PRIVATE_REPO" "the private overlay"

    dotfiles_sync_config "$DOTFILES_REPO/config" "$DOTFILES_PREFIX"
    dotfiles_sync_config "$DOTFILES_PRIVATE_REPO/config" "$DOTFILES_PRIVATE_PREFIX"

    if [ "$DOTFILES_SYNC_CHANGED" -eq 0 ]; then
        echo "  installed copy already matches the source checkout"
    fi

    if [ "$DOTFILES_LOCAL_EDITS" -eq 1 ]; then
        echo
        echo "The installed copy carried edits that were not made in the checkout," >&2
        echo "so they have been copied into $DOTFILES_BACKUP_ROOT/local before" >&2
        echo "being replaced. This happens when a tool writes through a link, as" >&2
        echo "'git config --global' does. Move anything worth keeping into the" >&2
        echo "checkout, where it is version-controlled." >&2
    fi
}

# The configuration files hard-code ~/.local/share because neither Git's
# include.path nor SSH's Include expands environment variables.
dotfiles_check_prefix() {
    local expected="$HOME/.local/share"

    [ "$DOTFILES_DATA_HOME" = "$expected" ] && return 0

    echo "Warning: XDG_DATA_HOME points at $DOTFILES_DATA_HOME," >&2
    echo "         but the Git and SSH includes hard-code $expected." >&2
    echo "         The private overlay will not be picked up." >&2
}

dotfiles_install_link() {
    local source="$1" target="$HOME/$2" backup="$DOTFILES_BACKUP_ROOT/$2" origin="${3:-}"
    DOTFILES_LINK_CHANGED=0

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        echo "already linked $target -> $source"
        return
    fi

    # A link into the source checkout is one we made before installs went through
    # a prefix. It is ours to replace, not a user file worth preserving.
    if [ -n "$origin" ] && [ -L "$target" ] && [ "$(readlink "$target")" = "$origin" ]; then
        unlink "$target"
        echo "replaced link into the source checkout at $target"
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -e "$backup" ] || [ -L "$backup" ]; then
            echo "Cannot preserve $target: backup already exists at $backup" >&2
            return 1
        fi

        mkdir -p "$(dirname "$backup")"
        mv "$target" "$backup"
        echo "preserved $target at $backup"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    DOTFILES_LINK_CHANGED=1
    echo "linked $target -> $source"
}

dotfiles_uninstall_link() {
    local source="$1" target="$HOME/$2" backup="$DOTFILES_BACKUP_ROOT/$2"
    DOTFILES_LINK_CHANGED=0

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        unlink "$target"
        DOTFILES_LINK_CHANGED=1
        echo "removed $target"
    elif [ -e "$target" ] || [ -L "$target" ]; then
        echo "skipped $target (not owned by this clone)" >&2
        return 1
    fi

    if [ -e "$backup" ] || [ -L "$backup" ]; then
        mkdir -p "$(dirname "$target")"
        mv "$backup" "$target"
        DOTFILES_LINK_CHANGED=1
        echo "restored $target"
    fi
}

# Drop the published copy once no component links to it. Guarded on the computed
# prefix so a caller cannot turn this into an rm -rf of something else.
dotfiles_remove_prefix() {
    local prefix="$1"

    case "$prefix" in
        "$DOTFILES_DATA_HOME"/dotfiles | "$DOTFILES_DATA_HOME"/dotfiles-private) ;;
        *) return 0 ;;
    esac

    [ -d "$prefix" ] || return 0
    rm -rf -- "$prefix"
    echo "removed $prefix"
}

dotfiles_cleanup_state() {
    local id remaining=0

    for id in "${DOTFILES_COMPONENT_IDS[@]}"; do
        [ -e "$DOTFILES_COMPONENTS_ROOT/$id" ] && remaining=1
    done

    if [ "$remaining" -eq 0 ]; then
        dotfiles_remove_prefix "$DOTFILES_PREFIX"
        dotfiles_remove_prefix "$DOTFILES_PRIVATE_PREFIX"
    fi

    # The manifest only describes files that were published; once the prefix is
    # gone it describes nothing. Preserved local edits are not touched.
    if [ "$remaining" -eq 0 ] && [ -d "$DOTFILES_MANIFEST_ROOT" ]; then
        rm -rf -- "$DOTFILES_MANIFEST_ROOT"
    fi

    rmdir "$DOTFILES_BACKUP_ROOT/.config" 2>/dev/null || true
    rmdir "$DOTFILES_BACKUP_ROOT/.ssh" 2>/dev/null || true
    rmdir "$DOTFILES_BACKUP_ROOT/.gnupg" 2>/dev/null || true
    rmdir "$DOTFILES_BACKUP_ROOT" 2>/dev/null || true
    rmdir "$DOTFILES_COMPONENTS_ROOT" 2>/dev/null || true

    if rmdir "$DOTFILES_STATE_ROOT" 2>/dev/null; then
        return
    fi
    if [ -d "$DOTFILES_COMPONENTS_ROOT" ]; then
        return
    fi
    if [ -e "$DOTFILES_STATE_ROOT/installed" ]; then
        unlink "$DOTFILES_STATE_ROOT/installed"
        rmdir "$DOTFILES_STATE_ROOT" 2>/dev/null || true
    fi
}

dotfiles_process_components() {
    local action="$1" index=0 component source origin target failed=0 reload_gpg=0

    if [ "$action" = "install" ]; then
        mkdir -p "$DOTFILES_STATE_ROOT" "$DOTFILES_COMPONENTS_ROOT"
        dotfiles_check_prefix
        echo "Publishing the source checkout to $DOTFILES_PREFIX:"
        dotfiles_sync_payload
        echo
    fi

    while [ "$index" -lt "$DOTFILES_SELECTED_COUNT" ]; do
        component="${DOTFILES_SELECTED[$index]}"
        source="$(dotfiles_component_source "$component")"
        origin="$(dotfiles_component_origin "$component")"
        target="$(dotfiles_component_target "$component")"

        if [ "$action" = "install" ]; then
            dotfiles_install_link "$source" "$target" "$origin"
            touch "$DOTFILES_COMPONENTS_ROOT/$component"
        elif dotfiles_uninstall_link "$source" "$target"; then
            if [ -e "$DOTFILES_COMPONENTS_ROOT/$component" ]; then
                unlink "$DOTFILES_COMPONENTS_ROOT/$component"
            fi
        else
            failed=1
        fi

        if [ "$component" = "gnupg" ] && [ "$DOTFILES_LINK_CHANGED" -eq 1 ]; then
            reload_gpg=1
        fi
        index=$((index + 1))
    done

    if [ "$failed" -ne 0 ]; then
        echo >&2
        echo "Uninstall incomplete; preserved backups remain in $DOTFILES_BACKUP_ROOT" >&2
        return 1
    fi

    if [ "$action" = "install" ]; then
        touch "$DOTFILES_STATE_ROOT/installed"
    else
        dotfiles_cleanup_state
    fi

    if [ "$reload_gpg" -eq 1 ]; then
        dotfiles_reload_agent
    fi
}

dotfiles_select_installed() {
    local id
    DOTFILES_SELECTED=()
    DOTFILES_SELECTED_COUNT=0

    for id in "${DOTFILES_COMPONENT_IDS[@]}"; do
        if [ -e "$DOTFILES_COMPONENTS_ROOT/$id" ]; then
            dotfiles_add_selected "$id"
        fi
    done
}

# Refresh the installed copy from the source checkout. Links are only touched
# when they are missing or point somewhere unexpected.
dotfiles_update() {
    local index=0 component source origin target relinked=0

    dotfiles_select_installed
    if [ "$DOTFILES_SELECTED_COUNT" -eq 0 ]; then
        echo "Nothing is installed. Run ./install.sh first."
        return
    fi

    dotfiles_check_prefix
    dotfiles_print_selection "refresh"

    if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
        echo "Comparing $DOTFILES_PREFIX with the source checkout:"
    else
        echo "Publishing the source checkout to $DOTFILES_PREFIX:"
    fi
    dotfiles_sync_payload

    while [ "$index" -lt "$DOTFILES_SELECTED_COUNT" ]; do
        component="${DOTFILES_SELECTED[$index]}"
        source="$(dotfiles_component_source "$component")"
        origin="$(dotfiles_component_origin "$component")"
        target="$(dotfiles_component_target "$component")"
        index=$((index + 1))

        dotfiles_component_owned "$component" && continue

        if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
            echo "  would relink $HOME/$target -> $source"
            relinked=1
            continue
        fi

        echo
        dotfiles_install_link "$source" "$target" "$origin"
        relinked=1
    done

    echo
    if [ "$DOTFILES_DRY_RUN" -eq 1 ]; then
        if [ "$DOTFILES_SYNC_CHANGED" -eq 0 ] && [ "$relinked" -eq 0 ]; then
            echo "Up to date."
        else
            echo "Run ./update.sh to apply these changes."
            return 1
        fi
        return
    fi

    if [ "$DOTFILES_SYNC_CHANGED" -eq 1 ] && [ -e "$DOTFILES_COMPONENTS_ROOT/gnupg" ]; then
        dotfiles_reload_agent
    fi
    echo "Done. The installed copy matches the source checkout."
}

DOTFILES_DOCTOR_FAILED=0

dotfiles_report() {
    local status="$1" message="$2"
    case "$status" in
        ok) printf '  ok    %s\n' "$message" ;;
        warn) printf '  warn  %s\n' "$message" ;;
        bad)
            printf '  FAIL  %s\n' "$message"
            DOTFILES_DOCTOR_FAILED=1
            ;;
    esac
}

# Does every installed component still point where it should?
dotfiles_doctor_links() {
    local id source target link

    for id in "${DOTFILES_COMPONENT_IDS[@]}"; do
        [ -e "$DOTFILES_COMPONENTS_ROOT/$id" ] || continue

        source="$(dotfiles_component_source "$id")"
        target="$HOME/$(dotfiles_component_target "$id")"

        if [ ! -L "$target" ]; then
            if [ -e "$target" ]; then
                dotfiles_report bad "$target is not a link. Something replaced it."
            else
                dotfiles_report bad "$target is missing. Run ./update.sh to restore it."
            fi
            continue
        fi

        link="$(readlink "$target")"
        if [ "$link" = "$source" ]; then
            dotfiles_report ok "$target"
        else
            dotfiles_report bad "$target points at $link, expected $source"
        fi
    done
}

# The rule the design rests on: nothing in $HOME may resolve into a checkout.
dotfiles_doctor_boundary() {
    local link target found=0 listing

    # A missing directory makes find exit non-zero, which under set -e would
    # abort the whole check rather than skip one path.
    listing="$(find "$HOME/.config" "$HOME/.ssh" "$HOME/.gnupg" "$DOTFILES_DATA_HOME" \
        -type l 2>/dev/null || true)"
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        target="$(readlink "$link")"
        case "$target" in
            "$DOTFILES_REPO" | "$DOTFILES_REPO"/* | "$DOTFILES_PRIVATE_REPO" | "$DOTFILES_PRIVATE_REPO"/*)
                found=1
                dotfiles_report bad "$link resolves into a checkout at $target"
                ;;
        esac
    done <<EOF
$listing
EOF

    if [ "$found" -eq 0 ]; then
        dotfiles_report ok "nothing under \$HOME resolves into a checkout"
    fi
}

# Edits written straight into the prefix, which the next update would replace.
dotfiles_doctor_local_edits() {
    local record path digest found=0

    if [ ! -d "$DOTFILES_MANIFEST_ROOT" ]; then
        dotfiles_report warn "no record of what was published; run ./update.sh"
        return
    fi

    for record in "$DOTFILES_MANIFEST_ROOT"/*; do
        [ -f "$record" ] || continue
        path="$(basename "$record" | tr '%' '/')"
        [ -f "$path" ] || continue

        digest="$(dotfiles_digest "$path")"
        if [ "$digest" != "$(cat "$record")" ]; then
            found=1
            dotfiles_report warn "$path was edited in place; ./update.sh will replace it"
        fi
    done

    if [ "$found" -eq 0 ]; then
        dotfiles_report ok "no edits made directly to the installed copy"
    fi
}

dotfiles_doctor_payload() {
    local checkout label

    for checkout in "$DOTFILES_REPO:the checkout" "$DOTFILES_PRIVATE_REPO:the private overlay"; do
        label="${checkout#*:}"
        checkout="${checkout%%:*}"

        if [ ! -d "$checkout" ]; then
            if [ "$label" = "the checkout" ]; then
                dotfiles_report bad "$label is missing at $checkout"
            fi
            continue
        fi

        if [ ! -d "$checkout/config" ]; then
            dotfiles_report bad "$label has no config/, so nothing from it is published"
            continue
        fi

        dotfiles_report ok "$label publishes from $checkout/config"
    done
}

# Ask Git and SSH what they resolve to, rather than trusting the files to parse.
dotfiles_doctor_resolution() {
    if command -v git >/dev/null 2>&1; then
        if git config --get user.name >/dev/null 2>&1; then
            dotfiles_report ok "git resolves a user identity"
        else
            dotfiles_report warn "git resolves no user.name; the overlay may not be published"
        fi
    fi

    if command -v ssh >/dev/null 2>&1; then
        if ssh -G github.com >/dev/null 2>&1; then
            dotfiles_report ok "ssh parses its configuration"
        else
            dotfiles_report bad "ssh cannot parse its configuration"
        fi
    fi
}

# Read-only by design. Diagnosing and repairing in one command is a command
# nobody trusts to run when something already looks wrong.
dotfiles_doctor() {
    local installed=0 id

    for id in "${DOTFILES_COMPONENT_IDS[@]}"; do
        [ -e "$DOTFILES_COMPONENTS_ROOT/$id" ] && installed=1
    done

    if [ "$installed" -eq 0 ]; then
        echo "Nothing is installed. Run ./install.sh first."
        return
    fi

    echo "Checkout:  $DOTFILES_REPO"
    echo "Installed: $DOTFILES_PREFIX"
    echo

    echo "Payload"
    dotfiles_doctor_payload
    echo
    echo "Links"
    dotfiles_doctor_links
    echo
    echo "Boundary"
    dotfiles_doctor_boundary
    echo
    echo "Local edits"
    dotfiles_doctor_local_edits
    echo
    echo "Resolution"
    dotfiles_doctor_resolution
    echo

    if [ "$DOTFILES_DOCTOR_FAILED" -eq 1 ]; then
        echo "Something is wrong above. ./update.sh repairs links and republishes;"
        echo "anything it does not fix needs a look by hand."
        return 1
    fi

    echo "This installation looks healthy."
}

dotfiles_main() {
    local action="${1:-}" repo="${2:-}"
    shift 2 || true

    case "$action" in
        install | uninstall | update | doctor) ;;
        *)
            echo "Internal error: unknown action" >&2
            return 2
            ;;
    esac

    if [ -z "$repo" ]; then
        echo "Internal error: repository path is missing" >&2
        return 2
    fi

    DOTFILES_REPO="$repo"
    DOTFILES_PRIVATE_REPO="${DOTFILES_PRIVATE_ROOT:-$(dirname "$repo")/dotfiles-private}"
    DOTFILES_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    DOTFILES_PREFIX="$DOTFILES_DATA_HOME/dotfiles"
    DOTFILES_PRIVATE_PREFIX="$DOTFILES_DATA_HOME/dotfiles-private"
    DOTFILES_STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-installer"
    DOTFILES_BACKUP_ROOT="$DOTFILES_STATE_ROOT/backups"
    DOTFILES_COMPONENTS_ROOT="$DOTFILES_STATE_ROOT/components"
    DOTFILES_MANIFEST_ROOT="$DOTFILES_STATE_ROOT/published"
    DOTFILES_DRY_RUN=0
    DOTFILES_SYNC_CHANGED=0
    DOTFILES_LOCAL_EDITS=0
    export DOTFILES_REPO DOTFILES_PRIVATE_REPO DOTFILES_DATA_HOME DOTFILES_PREFIX \
        DOTFILES_PRIVATE_PREFIX DOTFILES_STATE_ROOT DOTFILES_BACKUP_ROOT \
        DOTFILES_COMPONENTS_ROOT DOTFILES_MANIFEST_ROOT

    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        dotfiles_usage "$action"
        return
    fi

    if [ "$action" = "update" ]; then
        case "${1:-}" in
            --check) DOTFILES_DRY_RUN=1 ;;
            "") ;;
            *)
                echo "Unknown option: $1" >&2
                dotfiles_usage "$action" >&2
                return 2
                ;;
        esac
        dotfiles_update
        return
    fi

    if [ "$action" = "doctor" ]; then
        dotfiles_doctor
        return
    fi

    dotfiles_choose_components "$action" "$@"
    dotfiles_print_selection "$action"
    if [ "$DOTFILES_SELECTED_COUNT" -eq 0 ]; then
        return
    fi

    dotfiles_process_components "$action"

    echo
    if [ "$action" = "install" ]; then
        echo "Done. Inspect the active Git configuration with:"
        echo "  git config --global --list --show-origin"
    else
        echo "Done. The pre-install configuration has been restored."
        if [ -d "$DOTFILES_BACKUP_ROOT/local" ]; then
            echo
            echo "Edits made to the installed copy were preserved earlier and are"
            echo "still at $DOTFILES_BACKUP_ROOT/local. They are yours to keep or"
            echo "delete; uninstall does not remove them."
        fi
    fi
}

dotfiles_main "$@"
