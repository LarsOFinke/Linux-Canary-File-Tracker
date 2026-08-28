# Operations and troubleshooting

## Build and test

The Makefile is the shortest local workflow:

```bash
make
make test
```

The equivalent CMake workflow is:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build
```

## Run manually

The watched file must exist before startup:

```bash
install -m 0600 /dev/null /tmp/secret.txt
sudo ./dist/fs-tracker \
  --path /tmp/secret.txt \
  --log /tmp/fs-events.jsonl
```

The program prints its tracking pair to stderr. Generate a test event from a
second terminal, then inspect the JSONL output:

```bash
cat /tmp/secret.txt
tail -n 1 /tmp/fs-events.jsonl
```

## Install with systemd

Use the installer from the repository root:

```bash
sudo scripts/install-fs-tracker.sh
```

The installer builds and tests the program, installs the binary under
`/usr/local/bin`, creates the configured target if necessary, and enables the
provided service. Useful service commands are:

```bash
systemctl status fs-tracker.service
journalctl -u fs-tracker.service -f
systemctl restart fs-tracker.service
```

To stop and disable the service while retaining its generated unit file:

```bash
sudo scripts/deactivate-fs-tracker.sh
```

Deactivation retains the systemd unit, `/usr/local/bin/fs-tracker`,
`/etc/fs-tracker.conf`, the watched target, and the JSONL log. Enable and start
the service again with:

```bash
sudo scripts/activate-fs-tracker.sh
```

This makes it possible to inspect existing events or reactivate without losing
data.

The service reads `/etc/fs-tracker.conf`. Confirm its paths and permissions
before starting it, especially when the log is under `/var/log`.

## Common failures

### Permission or fanotify initialization error

This prototype uses PID-reporting fanotify mode. Run it as root or grant the
capabilities required by the active kernel. The required privilege level can
vary with kernel configuration and fanotify support.

### No event after replacing the file

The initial implementation marks the filesystem object resolved at startup.
Deleting and recreating the path can produce a new inode that is not marked.
Restart the service after replacement, or monitor the parent directory and
re-arm the target in a future implementation.

### Empty process metadata

The process can exit between event delivery and `/proc` inspection. This is
expected best-effort behavior, not necessarily a logging failure.

### Missing `open_exec`

`FAN_OPEN_EXEC` availability depends on the headers and kernel. Script access
through an interpreter should not be assumed to produce an execute-open event
for the script itself.

## Production boundaries

This is a local observability sensor, not a security boundary. A privileged
attacker on the monitored host may stop, alter, or evade it. For stronger
assurance, forward events to storage or a collector outside the host and
restrict access to the local JSONL file.