# User guide

`fs-tracker` is a lightweight Linux file-activity monitor for a single target file. It listens at the `fanotify` layer and records events as JSON Lines (JSONL), adding process metadata from `/proc` so you can see which program touched the canary file and which parent process launched it.

This guide is meant for operators and developers who want to run the tracker, install it as a service, or inspect the resulting event log.

## What it monitors

The tracker watches one configured path and records events such as:

- `open`
- `access`
- `modify`
- `open_exec` (when supported by the kernel and headers)
- `close_write`
- `close_nowrite`
- `q_overflow`

Each log record includes:

- timestamp
- watched path
- raw `fanotify` mask value
- normalized event names
- PID, PPID, UID
- `/proc/<pid>/exe`
- `/proc/<pid>/cmdline`
- parent process info

## Prerequisites

- Linux kernel with `fanotify` support
- Root access or equivalent capability for the running process
- A file that already exists before the watcher starts

The project is intentionally simple and is not a full security boundary. It is intended for local observability and canary-style monitoring.

## Quick start

The repository is designed around the interactive installer for real deployments. That process prompts for the canary name, target file, log path, and optional action script, rather than requiring a long command line.

Create a target file:

```bash
echo 'super secret' > /tmp/secret.txt
```

Install and start the service interactively:

```bash
sudo scripts/install-fs-tracker.sh
```

If you are testing the binary directly without the installer, use a manual override example such as:

```bash
sudo ./dist/fs-tracker \
  --path /tmp/secret.txt \
  --log /tmp/fs-events.jsonl
```

In another terminal, trigger an event:

```bash
cat /tmp/secret.txt
```

Read the JSONL output:

```bash
cat /tmp/fs-events.jsonl
```

Example record:

```json
{"ts":"2026-08-28T10:21:43.918223411Z","path":"/tmp/secret.txt","mask":32,"events":["open"],"process":{"pid":18442,"ppid":17201,"uid":1000,"exe":"/usr/bin/cat","cmdline":"cat /tmp/secret.txt"},"parent":{"pid":17201,"ppid":17198,"uid":1000,"exe":"/usr/bin/bash","cmdline":"bash"}}
```

## Configuration

The project’s preferred operator workflow is the interactive installer, which prompts for the canary name, target file, log path, and optional action script. The CLI options still exist, but they mainly act as explicit overrides for direct runs and ad hoc testing.

The tracker supports three configuration inputs, with a clear precedence order:

1. built-in defaults
2. `--config` file
3. environment variables
4. CLI overrides

The default settings are:

```text
TRACK_PATH=/tmp/secret.txt
TRACK_LOG=./fs-events.jsonl
```

### Config file

A simple configuration file looks like this:

```text
TRACK_PATH=/srv/honey/credentials.txt
TRACK_LOG=/var/log/fs-tracker/events.jsonl
```

Load it with:

```bash
sudo ./dist/fs-tracker --config packaging/fs-tracker.conf
```

### Environment variables

```bash
sudo env \
  TRACK_PATH=/srv/honey/credentials.txt \
  TRACK_LOG=/var/log/fs-tracker/events.jsonl \
  ./dist/fs-tracker
```

### CLI overrides

```bash
sudo ./dist/fs-tracker \
  --config packaging/fs-tracker.conf \
  --path /srv/honey/credentials.txt
```

The full command-line options are:

```text
--config PATH   Load settings from PATH
--path PATH     Override the watched file
--log PATH      Override the JSONL output file
--help          Print usage information
```

## Install and run as a systemd service

This is the canonical workflow for real usage. The installer prompts for the canary name and paths interactively instead of requiring a long command line.

From the repository root, run the installer:

```bash
sudo scripts/install-fs-tracker.sh
```

The installer:

- builds and tests the program
- installs the shared binary under `/usr/local/bin`
- creates the configured target if needed
- writes a per-canary config under `/etc/fs-tracker/`
- enables a matching `systemd` unit

The unit naming pattern is:

```text
fs-file-monitor-<canary>.service
```

and the config file is stored at:

```text
/etc/fs-tracker/<canary>.conf
```

The installer also keeps a registry file at:

```text
/etc/fs-tracker/canaries
```

This helps track all installed canaries and makes activation and deactivation easier for operators.

### Check service status

```bash
systemctl status fs-file-monitor-finance.service
journalctl -u fs-file-monitor-finance.service -f
```

### Deactivate and reactivate

Stop the service without deleting the canary data:

```bash
sudo scripts/deactivate-fs-tracker.sh
```

Then restart it later:

```bash
sudo scripts/activate-fs-tracker.sh
```

## Action hook

The installer can optionally add an executable action script that runs after each event is logged. The action receives:

- event path
- raw `fanotify` mask
- PID

Manual override example:

```bash
sudo ./dist/fs-tracker \
  --path /tmp/secret.txt \
  --log /tmp/fs-events.jsonl
```

A basic example is included at:

```text
tools/canary-curl-post.sh
```

This hook is useful for forwarding events to a remote endpoint or local alerting tool.

## Operational notes

### File must exist before startup

The watcher attaches to the target file at startup. If the target path is missing at launch, the tracker will not monitor it correctly.

### `FAN_ACCESS` is not a syscall trace

`fanotify` reports filesystem events, not every underlying `read(2)` call. Some events may be coalesced by the kernel.

### `FAN_OPEN_EXEC` depends on kernel support

A binary executed directly may produce `FAN_OPEN_EXEC`, but script execution through an interpreter is not necessarily reported the same way for the script file itself.

### Process metadata is best effort

The process may exit between event delivery and `/proc` inspection. In those cases, some metadata may be missing or partial.

## Troubleshooting

### Permission or `fanotify` initialization errors

This prototype uses `fanotify` in PID-reporting mode, so it typically needs root or suitable capabilities.

### No event after replacing the file

The initial implementation marks the object resolved at startup. If the file is deleted and recreated, the new inode may not be tracked. Restart the service after replacement if needed.

### Empty or partial process metadata

This is expected when the process exits quickly. The tracker records what it can observe at the time of processing.

## Recommended workflow

1. Build the project:

   ```bash
   make
   ```

2. Run it manually in a test environment.
3. Confirm the JSONL output matches the expected event pattern.
4. Install it as a service for production-style monitoring.
5. Keep the log file under a controlled path and restrict local file access.

## Security and boundaries

This is a local observability tool, not a security boundary. An attacker with sufficient host access may stop, alter, or evade it. For stronger assurance, forward events to a dedicated collector or log pipeline outside the monitored host and restrict access to the local JSONL log.

For more detail, see:

- [Configuration reference](configuration.md)
- [Event format](event-format.md)
- [Operations and troubleshooting](operations.md)
