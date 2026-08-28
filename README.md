# fs-tracker

A small Linux file-activity sensor built on `fanotify`.

## Documentation

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
src/main.c             orchestration only
src/config.c           defaults, env, config-file and CLI parsing
src/fanotify_source.c  Linux fanotify interaction
src/proc_info.c        /proc process enrichment
src/jsonl_sink.c       JSONL serialization/output
src/event_names.c      fanotify mask -> stable event names
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
make test
```

Or with CMake:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build
```

## Install as a service

The tracker is a long-running fanotify listener, so use the provided installer
and systemd service rather than cron:

```bash
sudo scripts/install-fs-tracker.sh
```

The script interactively asks for the target and log paths, using sensible
defaults. It builds and tests the program, installs it under `/usr/local/bin`,
creates the target file if needed, writes `/etc/fs-tracker.conf`, and enables
the service. Check it with:

```bash
systemctl status fs-tracker.service
journalctl -u fs-tracker.service -f
```

## Quick start

Create a target (the watched file must exist when the tracker starts):

```bash
echo 'super secret' > /tmp/secret.txt
```

Run the tracker:

```bash
sudo ./dist/fs-tracker \
  --path /tmp/secret.txt \
  --log /tmp/fs-events.jsonl
```

In another terminal:

```bash
cat /tmp/secret.txt
```

Then inspect the log:

```bash
cat /tmp/fs-events.jsonl
```

Example record:

```json
{"ts":"2026-08-28T10:21:43.918223411Z","path":"/tmp/secret.txt","mask":32,"events":["open"],"process":{"pid":18442,"ppid":17201,"uid":1000,"exe":"/usr/bin/cat","cmdline":"cat /tmp/secret.txt"},"parent":{"pid":17201,"ppid":17198,"uid":1000,"exe":"/usr/bin/bash","cmdline":"bash"}}
```

## Configuration

Defaults:

```text
TRACK_PATH=/tmp/secret.txt
TRACK_LOG=./fs-events.jsonl
```

Environment variables:

```bash
sudo env \
  TRACK_PATH=/srv/honey/credentials.txt \
  TRACK_LOG=/var/log/fs-tracker/events.jsonl \
  ./dist/fs-tracker
```

Simple config file:

```bash
sudo ./dist/fs-tracker --config examples/fs-tracker.conf
```

Config syntax is intentionally just:

```text
TRACK_PATH=/tmp/secret.txt
TRACK_LOG=/tmp/fs-events.jsonl
```

CLI options may override values loaded earlier:

```bash
sudo ./dist/fs-tracker \
  --config examples/fs-tracker.conf \
  --path /srv/honey/credentials.txt
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
