#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/canary-registry.sh"

require_root
require_no_arguments "$@"
require_interactive
prompt_registered_canary_name

if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    printf 'Start generated canary project in %s? [y/N]: ' "$PROJECT_DIR"
    IFS= read -r answer
    case "$answer" in
        y|Y|yes|YES)
            if command -v docker >/dev/null 2>&1; then
                (cd "$PROJECT_DIR" && docker compose up -d)
            else
                printf 'docker is not installed; skipping project startup.\n' >&2
            fi
            ;;
    esac
fi

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

printf 'fs-tracker is active.\n'
printf 'Service: %s\n' "$SERVICE_NAME"
if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
    printf 'Project: %s\n' "$PROJECT_DIR"
fi
printf 'Status: systemctl status %s\n' "$SERVICE_NAME"
printf 'Events: journalctl -u %s -f\n' "$SERVICE_NAME"
