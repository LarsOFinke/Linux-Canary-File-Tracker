# Configuration reference

`fs-tracker` watches one existing target path and appends events to one JSONL
log file.

## Settings

| Setting | Default | Description |
| --- | --- | --- |
| `TRACK_PATH` | `/tmp/secret.txt` | File to mark and monitor. It must exist when the process starts. |
| `TRACK_LOG` | `./fs-events.jsonl` | JSONL file to append events to. |

Settings can be supplied through a config file containing simple `KEY=VALUE`
lines:

```text
TRACK_PATH=/srv/honey/credentials.txt
TRACK_LOG=/var/log/fs-tracker/events.jsonl
```

Blank lines and lines beginning with `#` are ignored. Values are not shell
expanded, so use absolute paths when running as a service.

## Precedence

When the same setting is supplied more than once, the following order applies
from lowest to highest priority:

1. Built-in defaults
2. The file passed to `--config`
3. `TRACK_PATH` and `TRACK_LOG` environment variables
4. `--path` and `--log` command-line options

For example, this keeps the config file for the log destination while changing
the watched file:

```bash
sudo ./fs-tracker \
  --config examples/fs-tracker.conf \
  --path /srv/honey/credentials.txt
```

## Command-line options

```text
--config PATH   Load settings from PATH
--path PATH     Override the watched file
--log PATH      Override the JSONL output file
--help          Print usage information
```

Unknown options, missing option values, unreadable config files, and empty
paths are reported as configuration errors before fanotify is initialized.