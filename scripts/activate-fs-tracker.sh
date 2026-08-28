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

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

printf 'fs-tracker is active.\n'
printf 'Status: systemctl status %s\n' "$SERVICE_NAME"
printf 'Events: journalctl -u %s -f\n' "$SERVICE_NAME"