#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/canary-registry.sh"

require_root
require_no_arguments "$@"
require_interactive
prompt_registered_canary_name

if systemctl is-active --quiet "$SERVICE_NAME" || systemctl is-enabled --quiet "$SERVICE_NAME"; then
    systemctl disable --now "$SERVICE_NAME"
else
    printf '%s is already inactive and disabled.\n' "$SERVICE_NAME"
fi

printf 'fs-tracker is deactivated. The unit, configuration, binary, target, and log files were retained.\n'

exit 0
