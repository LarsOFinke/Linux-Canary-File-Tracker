#!/bin/sh

REGISTRY_FILE=${REGISTRY_FILE:-/etc/fs-tracker/canaries}
TAB=$(printf '\t')

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

validate_canary_name() {
    case "$1" in
        ''|*[!A-Za-z0-9_-]*|-) fail "canary name may contain only letters, digits, underscores, and hyphens" ;;
    esac
}

require_root() {
    case "$(id -u)" in
        0) ;;
        *) fail "run this script as root, for example: sudo $0" ;;
    esac
}

require_no_arguments() {
    [ "$#" -eq 0 ] || fail "this script does not accept arguments"
}

require_interactive() {
    [ -t 0 ] || fail "interactive terminal input is required"
}

prompt_new_canary_name() {
    printf 'Canary name [%s]: ' "${CANARY_NAME:-default}"
    IFS= read -r input
    [ -n "$input" ] && CANARY_NAME=$input
    CANARY_NAME=${CANARY_NAME:-default}
    validate_canary_name "$CANARY_NAME"
}

prompt_registered_canary_name() {
    [ -r "$REGISTRY_FILE" ] || fail "no registered canaries found; install one first"

    count=0
    printf 'Registered canaries:\n'
    while IFS="$TAB" read -r name service config target log action project_dir || [ -n "$name" ]; do
        case "$name" in
            ''|'#'*) continue ;;
        esac
        count=$((count + 1))
        printf '  %d) %s (target: %s)\n' "$count" "$name" "$target"
    done < "$REGISTRY_FILE"
    [ "$count" -gt 0 ] || fail "no registered canaries found; install one first"

    printf 'Select canary [1-%d]: ' "$count"
    IFS= read -r selection
    case "$selection" in
        ''|*[!0-9]*) fail "enter the number of a registered canary" ;;
    esac
    [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -le "$count" ] || fail "selection is outside the registered canary list"

    count=0
    while IFS="$TAB" read -r name service config target log action project_dir || [ -n "$name" ]; do
        case "$name" in
            ''|'#'*) continue ;;
        esac
        count=$((count + 1))
        if [ "$count" -eq "$selection" ]; then
            CANARY_NAME=$name
            SERVICE_NAME=$service
            CONFIG_FILE=$config
            TARGET_PATH=$target
            LOG_PATH=$log
            ACTION_PATH=$action
            PROJECT_DIR=${project_dir:-}
            return 0
        fi
    done < "$REGISTRY_FILE"

    fail "could not resolve the selected canary"
}

registry_contains() {
    registry_name=$1
    while IFS="$TAB" read -r name service config target log action project_dir || [ -n "$name" ]; do
        [ "$name" = "$registry_name" ] && return 0
    done < "$REGISTRY_FILE"
    return 1
}

registry_add() {
    install -d -m 0750 "$(dirname -- "$REGISTRY_FILE")"
    umask 022
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$CANARY_NAME" "$SERVICE_NAME" "$CONFIG_FILE" "$TARGET_PATH" "$LOG_PATH" "$ACTION_PATH" "${PROJECT_DIR:-}" >> "$REGISTRY_FILE"
    chmod 0644 "$REGISTRY_FILE"
}

registry_remove() {
    [ -r "$REGISTRY_FILE" ] || return 0
    tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT INT TERM
    while IFS="$TAB" read -r name service config target log action project_dir || [ -n "$name" ]; do
        case "$name" in
            ''|'#'*)
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$service" "$config" "$target" "$log" "$action" "$project_dir" >> "$tmp_file"
                ;;
            *)
                if [ "$name" != "$CANARY_NAME" ]; then
                    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$service" "$config" "$target" "$log" "$action" "$project_dir" >> "$tmp_file"
                fi
                ;;
        esac
    done < "$REGISTRY_FILE"
    mv "$tmp_file" "$REGISTRY_FILE"
    trap - EXIT INT TERM
    chmod 0644 "$REGISTRY_FILE"
}
