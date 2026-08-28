#!/bin/sh
set -eu

SERVICE_NAME=${SERVICE_NAME:-fs-tracker.service}

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

case "$(id -u)" in
    0) ;;
    *) fail "run this script as root, for example: sudo $0" ;;
esac

[ "$#" -eq 0 ] || fail "this script does not accept arguments"

if systemctl is-active --quiet "$SERVICE_NAME" || systemctl is-enabled --quiet "$SERVICE_NAME"; then
    systemctl disable --now "$SERVICE_NAME"
else
    printf '%s is already inactive and disabled.\n' "$SERVICE_NAME"
fi

printf 'fs-tracker is deactivated. The unit, configuration, binary, target, and log files were retained.\n'
