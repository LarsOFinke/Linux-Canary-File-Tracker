#!/bin/sh
set -eu

REGISTRY_FILE=${REGISTRY_FILE:-/etc/fs-tracker/canaries}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/canary-registry.sh"

require_root
require_no_arguments "$@"

if [ ! -r "$REGISTRY_FILE" ]; then
    printf 'No registered canaries found at %s\n' "$REGISTRY_FILE"
    exit 0
fi

printf 'Checking canary services...\n\n'
count=0
while IFS=$(printf '\t') read -r name service config target log action || [ -n "$name" ]; do
    case "$name" in
        ''|'#'*) continue ;;
    esac

    count=$((count + 1))

    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        enabled='enabled'
    else
        enabled='disabled'
    fi

    if systemctl is-active --quiet "$service" 2>/dev/null; then
        active='active'
    else
        active='inactive'
    fi

    if [ -f "$config" ]; then
        config_state='config-ok'
    else
        config_state='config-missing'
    fi

    if [ -e "$target" ]; then
        target_state='target-ok'
    else
        target_state='target-missing'
    fi

    if [ -e "$log" ]; then
        log_state='log-ok'
    else
        log_state='log-missing'
    fi

    printf '%s\n' "Canary: $name"
    printf '  service: %s\n' "$service"
    printf '  enabled: %s\n' "$enabled"
    printf '  active:  %s\n' "$active"
    printf '  config:  %s (%s)\n' "$config" "$config_state"
    printf '  target:  %s (%s)\n' "$target" "$target_state"
    printf '  log:     %s (%s)\n' "$log" "$log_state"
    printf '  action:  %s\n' "${action:-none}"
    printf '\n'

done < "$REGISTRY_FILE"

if [ "$count" -eq 0 ]; then
    printf 'No canaries are registered.\n'
    exit 0
fi

printf 'Summary: %d canary(s) checked.\n' "$count"
