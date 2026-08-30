# linux-canary-file-tracker

A small Linux file-activity sensor built on `fanotify`.

## Documentation

- [User guide](docs/user-guide.md)
- [Configuration reference](docs/configuration.md)
- [Event format](docs/event-format.md)
- [Operations and troubleshooting](docs/operations.md)

The project deliberately avoids wrapping `cat`, `cp`, editors, or other
userspace utilities. Instead it listens at the Linux filesystem notification
layer and enriches events with process metadata from `/proc`.

## What it records

For one configured target file:

- open (`FAN_OPEN`)
- access/read-like activity (`FAN_ACCESS`)
- modification (`FAN_MODIFY`)
- execute-open (`FAN_OPEN_EXEC`, when supported by the headers/kernel)
- close after writing (`FAN_CLOSE_WRITE`)
- close without writing (`FAN_CLOSE_NOWRITE`)
- queue overflow (`FAN_Q_OVERFLOW`)

Each event is written as one JSON object per line (JSONL), together with:

- PID / PPID
- UID
- `/proc/<pid>/exe`
- `/proc/<pid>/cmdline`
- the same basic information for the immediate parent process

## Design

The code is intentionally split by responsibility rather than by framework:

```text
src/app/main.c                    orchestration only
src/config/config.c               defaults, env, config-file and CLI parsing
src/monitoring/fanotify_source.c  Linux fanotify interaction
src/process/proc_info.c           /proc process enrichment
src/output/jsonl_sink.c           JSONL serialization/output
src/events/event_names.c          fanotify mask -> stable event names
```

This keeps the design KISS while applying the useful parts of SOLID in C:

- **Single Responsibility:** each module owns one reason to change.
- **Open/Closed:** another sink or event source can be added without mixing it
  into `/proc` parsing or JSON serialization.
- **Dependency direction:** `main.c` composes the modules; low-level modules do
  not depend on the application orchestrator.
- No premature interfaces, plugin system, DI container, or generic object model.

## Build

```bash
make
make mailer
make test
```

Or with CMake:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build
```

The Make build produces one runnable distribution file for the tracker and a
frozen single-file action binary for the mailer:

- `dist/fs-tracker`
- `dist/canary-mailer`

The mailer is intended to be used as a `TRACK_ACTION` executable, which makes
it easy to drop into the event call chain without carrying a Python runtime or
module import path around on the target host. The interactive installer can also
bundle and deploy that frozen binary automatically, including the required
mail environment variables for the canary service.

To remove a canary install completely, use the matching uninstall script:

```bash
sudo scripts/uninstall-fs-tracker.sh
```

`make test` keeps its C test binaries in a temporary directory and removes them
afterward, then runs the mailer unit tests in the project virtual environment.

## Install as a service

The tracker is a long-running fanotify listener, so use the provided installer
and systemd service rather than cron:

```bash
sudo scripts/install-fs-tracker.sh
```

The installer optionally accepts an executable action file. It runs after each
event is written and receives the event path, raw fanotify mask, and PID as its
three positional arguments. Leave the prompt blank to disable it.

Action tools belong in the root `tools/` directory. A basic HTTP POST action is
provided at `tools/canary-curl-post.sh`; enter that path at the installer prompt
and set `FS_TRACKER_POST_URL` in the service environment.

The installer prompts for a canary name. For example, naming two installations
`finance` and `engineering` creates separate units and configs:

```text
fs-file-monitor-finance.service       /etc/fs-tracker/finance.conf
fs-file-monitor-engineering.service  /etc/fs-tracker/engineering.conf
```

Canary names may contain letters, digits, underscores, and hyphens. The name
is used by the activate and deactivate scripts to select the matching unit.
The installer keeps these mappings in `/etc/fs-tracker/canaries`; the lifecycle
scripts show registered canaries as a numbered list.

To stop and disable the service while retaining the installed binary,
configuration, target, and event log:

```bash
sudo scripts/deactivate-fs-tracker.sh
```

## Canary project generator

This repo also includes a small generator for a realistic but passive canary web
application that mimics common exposed targets such as `/api/.env`,
`/config/app.env`, `/public/index.php`, and `/wp-config.php`.

```bash
python3 -m tools.canary_project --project-name demo-site --output-dir /tmp --mode standard
```

The generated project records request metadata automatically in a local log file,
without active exfiltration or user interaction. It is intended for defensive
monitoring, realistic scan telemetry, and detection exercises.

To enable and start it again:

```bash
sudo scripts/activate-fs-tracker.sh
```

The script interactively asks for the canary name, target, and log paths, using
sensible defaults. It builds and tests the program, installs the shared binary
under `/usr/local/bin`, creates the target file if needed, writes the named
config under `/etc/fs-tracker/`, and enables that canary's service. The
deactivation script stops and disables the selected unit while retaining the
unit file and data. Check a canary with:

```bash
systemctl status fs-file-monitor-finance.service
journalctl -u fs-file-monitor-finance.service -f
```

## Quick start

Create a target file that looks like a private SSH key (the watched file must exist when the tracker starts):

```bash
mkdir -p /srv/honey/.ssh
cat > /srv/honey/.ssh/id_ed25519 <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEIBw5FJ1nWQm3C0hA+uI8v2mP1eOUb6j4i+J5nE8S8n0s
YHnj+R1fH2Ew5iE4m6m7gA0o7KfX9fFZK2kcG+00r9fT9UC3JzQq86naV8Q==
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 0600 /srv/honey/.ssh/id_ed25519
```

Run the tracker:

```bash
sudo ./dist/fs-tracker \
  --path /srv/honey/.ssh/id_ed25519 \
  --log /tmp/fs-events.jsonl
```

In another terminal:

```bash
cat /srv/honey/.ssh/id_ed25519
```

Then inspect the log:

```bash
cat /tmp/fs-events.jsonl
```

Example record:

```json
{"ts":"2026-08-28T10:21:43.918223411Z","path":"/srv/honey/.ssh/id_ed25519","mask":32,"events":["open"],"process":{"pid":18442,"ppid":17201,"uid":1000,"exe":"/usr/bin/cat","cmdline":"cat /srv/honey/.ssh/id_ed25519"},"parent":{"pid":17201,"ppid":17198,"uid":1000,"exe":"/usr/bin/bash","cmdline":"bash"}}
```

## Configuration

Defaults:

```text
TRACK_PATH=/srv/honey/.ssh/id_ed25519
TRACK_LOG=./fs-events.jsonl
```

Environment variables:

```bash
sudo env \
  TRACK_PATH=/srv/honey/.ssh/id_ed25519 \
  TRACK_LOG=/var/log/fs-tracker/events.jsonl \
  ./dist/fs-tracker
```

Simple config file:

```bash
sudo ./dist/fs-tracker --config packaging/fs-tracker.conf
```

Config syntax is intentionally just:

```text
TRACK_PATH=/srv/honey/.ssh/id_ed25519
TRACK_LOG=/tmp/fs-events.jsonl
```

CLI options may override values loaded earlier:

```bash
sudo ./dist/fs-tracker \
  --config packaging/fs-tracker.conf \
  --path /srv/honey/.ssh/id_ed25519
```

The precedence is deterministic: defaults < config file < environment < CLI overrides.

## Important semantics

### `FAN_ACCESS` is not a syscall trace

`fanotify` reports filesystem events, not every individual `read(2)` invocation.
Events may be merged. If you need exact syscall-level tracing, eBPF/tracepoints are
usually a better next step.

### `FAN_OPEN_EXEC` and scripts

A directly executed binary can generate `FAN_OPEN_EXEC`. An interpreter reading
`script.py` or another script as input is not necessarily equivalent to the
script file itself generating an execute-open event.

### Process information is best-effort

The process may exit between receiving the fanotify event and reading `/proc`.
In that case some fields can be empty. `/proc/<pid>/cmdline` is useful context,
but it should not be treated as a cryptographically trustworthy identity.

### Replacing the watched file

This first version marks the currently resolved filesystem object. If the target
is deleted and recreated, it may become a different inode and the original mark
no longer represents the replacement. A production version should additionally
watch the parent directory / filesystem and re-arm the target after rename,
delete, or recreation.

### Privileges

This prototype intentionally uses fd-based fanotify events plus the originating
PID. On current Linux, an unprivileged fanotify listener must use file-handle
reporting and does not receive the PID for events generated by other processes.
Run this prototype as root / with the capability required by `fanotify_init()`
for this mode. The quick-start uses `sudo` for that reason.

## Scope

This is a defensive observability / honeyfile-style sensor, not a security
boundary. A sufficiently privileged attacker controlling the monitored host can
potentially stop, alter, or evade local monitoring. For stronger detection,
ship JSONL events to a collector outside the monitored machine.

## Next sensible extensions

Keep them incremental:

1. parent-directory watch and automatic re-arming after replacement
2. recursive process ancestry instead of only the immediate parent
3. `FAN_REPORT_PIDFD` where supported to reduce PID-reuse races
4. Unix-socket or remote append-only event sink
5. systemd unit with a narrowly scoped capability set
6. eBPF backend only if syscall-level fidelity is actually required
