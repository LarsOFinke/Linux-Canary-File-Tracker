#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/canary-registry.sh"

require_root
require_no_arguments "$@"
require_interactive
prompt_registered_canary_name

if systemctl is-active --quiet "$SERVICE_NAME" || systemctl is-enabled --quiet "$SERVICE_NAME"; then
    systemctl disable --now "$SERVICE_NAME" || true
fi

if [ -n "$CONFIG_FILE" ] && [ -e "$CONFIG_FILE" ]; then
    rm -f "$CONFIG_FILE"
fi

if [ -n "$SERVICE_NAME" ] && [ -e "/etc/systemd/system/$SERVICE_NAME" ]; then
    rm -f "/etc/systemd/system/$SERVICE_NAME"
fi

if [ -n "$ACTION_PATH" ] && [ -x "$ACTION_PATH" ] && [ "$ACTION_PATH" != "/usr/local/bin/fs-tracker" ]; then
    rm -f "$ACTION_PATH"
fi

if [ -n "$TARGET_PATH" ] && [ -e "$TARGET_PATH" ] && [ ! -d "$TARGET_PATH" ]; then
    rm -f "$TARGET_PATH"
fi

if [ -n "$LOG_PATH" ] && [ -e "$LOG_PATH" ]; then
    rm -f "$LOG_PATH"
fi

if [ -n "$CONFIG_FILE" ]; then
    registry_remove
fi

systemctl daemon-reload
printf 'fs-tracker is uninstalled. The binary, config, service, logs, and registry entry were removed for %s.\n' "$CANARY_NAME"
