#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/canary-registry.sh"

require_root
require_no_arguments "$@"
require_interactive
prompt_registered_canary_name

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

printf 'fs-tracker is active.\n'
printf 'Service: %s\n' "$SERVICE_NAME"
printf 'Status: systemctl status %s\n' "$SERVICE_NAME"
printf 'Events: journalctl -u %s -f\n' "$SERVICE_NAME"
