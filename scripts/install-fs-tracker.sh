#!/bin/sh
set -eu

PREFIX=${PREFIX:-/usr/local}
CONFIG_DIR=${CONFIG_DIR:-/etc/fs-tracker}
SERVICE_DIR=${SERVICE_DIR:-/etc/systemd/system}
REGISTRY_FILE=${REGISTRY_FILE:-$CONFIG_DIR/canaries}
CANARY_NAME=${CANARY_NAME:-default}
TARGET_PATH=/srv/honey/.ssh/id_ed25519
LOG_PATH=/var/log/fs-tracker/events.jsonl
ACTION_PATH=

write_fake_ssh_private_key() {
    mkdir -p "$(dirname -- "$TARGET_PATH")"
    cat > "$TARGET_PATH" <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEIC7uP5hP4T1Gf0fLzsV0qJxk3p7Vx6JtL5u64W0NQ8
PnD4Vj2Q2um8iVY9iJDAR7NOp2R6u0X2Wc6zNzE5wT0mH7jTn0QJdDzi2gJH8gH0h
LJ2K9wA8Sos0YisjPo4b+9VQnSmvPbcLMn9vwbRr9iK0vPq7N0lqP0bDx8w==
-----END OPENSSH PRIVATE KEY-----
EOF
    chmod 0600 "$TARGET_PATH"
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/canary-registry.sh"

require_root
require_no_arguments "$@"
require_interactive

printf 'fs-tracker interactive setup\n\n'
prompt_new_canary_name

SERVICE_NAME="fs-file-monitor-$CANARY_NAME.service"
CONFIG_FILE="$CONFIG_DIR/$CANARY_NAME.conf"
SERVICE_FILE="$SERVICE_DIR/$SERVICE_NAME"

[ ! -e "$SERVICE_FILE" ] || fail "$SERVICE_FILE already exists; choose another canary name or deactivate it first"
[ ! -e "$CONFIG_FILE" ] || fail "$CONFIG_FILE already exists; choose another canary name or deactivate it first"
[ ! -e "$REGISTRY_FILE" ] || ! registry_contains "$CANARY_NAME" || fail "canary '$CANARY_NAME' is already registered; choose another name"

printf 'Service: %s\n' "$SERVICE_NAME"
printf 'Target file [%s]: ' "$TARGET_PATH"
IFS= read -r input
[ -n "$input" ] && TARGET_PATH=$input

printf 'JSONL log file [%s]: ' "$LOG_PATH"
IFS= read -r input
[ -n "$input" ] && LOG_PATH=$input

printf 'Executable action file [none]: '
IFS= read -r input
[ -n "$input" ] && ACTION_PATH=$input

MAIL_TO=
MAIL_FROM=
MAIL_SUBJECT=
if [ -z "$ACTION_PATH" ]; then
    printf 'Install bundled canary-mailer action [y/N]: '
    IFS= read -r answer
    case "$answer" in
        y|Y|yes|YES)
            ACTION_PATH="$PREFIX/libexec/fs-tracker/canary-mailer"
            ;;
    esac
fi

PROJECT_ROOT=${PROJECT_ROOT:-/srv/canary-projects}
PROJECT_DIR=
printf 'Generate a passive canary project too? [y/N]: '
IFS= read -r answer
case "$answer" in
    y|Y|yes|YES)
        printf 'Project parent directory [%s]: ' "$PROJECT_ROOT"
        IFS= read -r input
        [ -n "$input" ] && PROJECT_ROOT=$input
        printf 'Project profile [standard/high-noise/stealth] [standard]: '
        IFS= read -r project_mode
        project_mode=${project_mode:-standard}
        case "$project_mode" in
            standard|high-noise|stealth) ;;
            *) fail "project profile must be one of: standard, high-noise, stealth" ;;
        esac
        install -d -m 0755 "$PROJECT_ROOT"
        PROJECT_DIR="$PROJECT_ROOT/$CANARY_NAME"
        printf 'Generating canary project in %s ...\n' "$PROJECT_DIR"
        PYTHONPATH="$PROJECT_DIR/..:$PROJECT_DIR:$PROJECT_DIR/../.." python3 -m tools.canary_project --project-name "$CANARY_NAME" --output-dir "$PROJECT_ROOT" --mode "$project_mode" >/tmp/canary-project-generation.log 2>&1 || {
            cat /tmp/canary-project-generation.log >&2
            fail "canary project generation failed"
        }
        ;;
esac

if [ -n "$ACTION_PATH" ]; then
    ACTION_NAME=$(basename -- "$ACTION_PATH")
    case "$ACTION_NAME" in
        canary-mail-send.sh|canary-mail-send|canary-mailer)
            printf 'Mail recipient (required): '
            IFS= read -r input
            MAIL_TO=$input
            if [ -z "$MAIL_TO" ]; then
                fail "mail action requires a recipient address"
            fi

            HOSTNAME_SHORT=$(hostname 2>/dev/null || printf 'localhost')
            printf 'Mail sender [%s]: ' "fs-tracker@$HOSTNAME_SHORT"
            IFS= read -r input
            [ -n "$input" ] && MAIL_FROM=$input
            MAIL_FROM=${MAIL_FROM:-"fs-tracker@$HOSTNAME_SHORT"}

            printf 'Mail subject [fs-tracker alert]: '
            IFS= read -r input
            [ -n "$input" ] && MAIL_SUBJECT=$input
            MAIL_SUBJECT=${MAIL_SUBJECT:-fs-tracker alert}
            ;;
    esac
fi

case "$TARGET_PATH:$LOG_PATH:$ACTION_PATH" in
    /*:/*:) ;;
    /*:/*:/*) [ -x "$ACTION_PATH" ] || fail "action file must be executable" ;;
    *) fail "target and log paths must be absolute; action must be an executable absolute path" ;;
esac

[ ! -e "$TARGET_PATH" ] || [ ! -d "$TARGET_PATH" ] || fail "target path must be a file"

printf '\nTarget: %s\n' "$TARGET_PATH"
printf 'Log:    %s\n' "$LOG_PATH"
printf 'Install and start the systemd service? [y/N] '
IFS= read -r answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) printf 'Installation cancelled.\n'; exit 0 ;;
esac

PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BINARY="$PROJECT_DIR/dist/fs-tracker"
MAILER_BINARY="$PROJECT_DIR/dist/canary-mailer"
MAILER_INSTALL_DIR="$PREFIX/libexec/fs-tracker"
MAILER_INSTALL_PATH="$MAILER_INSTALL_DIR/canary-mailer"

printf 'Building fs-tracker...\n'
make -C "$PROJECT_DIR" test
make -C "$PROJECT_DIR"
[ -x "$BINARY" ] || fail "build did not produce $BINARY"

install -d -m 0755 "$PREFIX/bin"
install -m 0755 "$BINARY" "$PREFIX/bin/fs-tracker"

if [ -n "$ACTION_PATH" ] && [ "$ACTION_PATH" = "$MAILER_INSTALL_PATH" ]; then
    make -C "$PROJECT_DIR" mailer
    [ -x "$MAILER_BINARY" ] || fail "build did not produce $MAILER_BINARY"
    install -d -m 0755 "$MAILER_INSTALL_DIR"
    install -m 0755 "$MAILER_BINARY" "$MAILER_INSTALL_PATH"
    ACTION_PATH=$MAILER_INSTALL_PATH
fi

TARGET_DIR=$(dirname -- "$TARGET_PATH")
LOG_DIR=$(dirname -- "$LOG_PATH")
install -d -m 0750 "$CONFIG_DIR"
install -d -m 0750 "$TARGET_DIR"
install -d -m 0750 "$LOG_DIR"

if [ ! -e "$TARGET_PATH" ]; then
    write_fake_ssh_private_key
fi

cat > "$CONFIG_FILE" <<EOF
# Generated by install-fs-tracker.sh.
TRACK_PATH=$TARGET_PATH
TRACK_LOG=$LOG_PATH
EOF
if [ -n "$ACTION_PATH" ]; then
    printf 'TRACK_ACTION=%s\n' "$ACTION_PATH" >> "$CONFIG_FILE"
fi
chmod 0644 "$CONFIG_FILE"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=File activity monitor ($CANARY_NAME)
After=local-fs.target

[Service]
Type=simple
ExecStart=$PREFIX/bin/fs-tracker --config $CONFIG_FILE
Restart=on-failure
EOF

if [ -n "$MAIL_TO" ]; then
    cat >> "$SERVICE_FILE" <<EOF
Environment="FS_TRACKER_MAIL_TO=$MAIL_TO"
Environment="MAIL_TO=$MAIL_TO"
Environment="FS_TRACKER_MAIL_FROM=$MAIL_FROM"
Environment="MAIL_FROM=$MAIL_FROM"
Environment="FS_TRACKER_MAIL_SUBJECT=$MAIL_SUBJECT"
Environment="MAIL_SUBJECT=$MAIL_SUBJECT"
EOF
fi

cat >> "$SERVICE_FILE" <<EOF

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
registry_add

printf '\nfs-tracker is active.\n'
printf 'Service: %s\n' "$SERVICE_NAME"
printf 'Target: %s\n' "$TARGET_PATH"
printf 'Log:    %s\n' "$LOG_PATH"
if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
    printf 'Project: %s\n' "$PROJECT_DIR"
    printf 'Project status: interactive scan targets are available under %s\n' "$PROJECT_DIR"
fi
printf 'Status: systemctl status %s\n' "$SERVICE_NAME"
printf 'Events: journalctl -u %s -f\n' "$SERVICE_NAME"
