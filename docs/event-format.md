# Event format

The output is newline-delimited JSON: one JSON object per event. The log is
opened in append mode, so existing records are retained across restarts.

## Record fields

| Field | Type | Description |
| --- | --- | --- |
| `ts` | string | UTC timestamp with nanosecond precision when available |
| `path` | string | Path associated with the event |
| `mask` | number | Raw Linux fanotify event mask |
| `events` | array | Stable names decoded from `mask` |
| `process` | object | Best-effort metadata for the event PID |
| `parent` | object | Best-effort metadata for the immediate parent PID |

Process objects contain `pid`, `ppid`, `uid`, `exe`, and `cmdline`. The process
and parent objects may be absent or contain empty strings if the process exits
before `/proc` can be read. Treat these fields as context, not as a trusted
identity.

## Event names

The sensor can emit:

- `open`
- `access`
- `modify`
- `open_exec` when supported by the running kernel and headers
- `close_write`
- `close_nowrite`
- `queue_overflow`

`access` represents a fanotify filesystem event, not every individual
`read(2)` call. fanotify may merge notifications.

## Example

```json
{"ts":"2026-08-28T10:21:43.918223411Z","path":"/tmp/secret.txt","mask":32,"events":["open"],"process":{"pid":18442,"ppid":17201,"uid":1000,"exe":"/usr/bin/cat","cmdline":"cat /tmp/secret.txt"},"parent":{"pid":17201,"ppid":17198,"uid":1000,"exe":"/usr/bin/bash","cmdline":"bash"}}
```

Consumers should tolerate additional fields and event names in future
versions, and should parse each line independently so one malformed or partial
record does not require discarding the entire file.

## Executable action

When `TRACK_ACTION` is configured, the tracker executes that file after the
JSONL record is written. It passes three positional arguments: the event path,
the raw fanotify mask, and the originating PID (or `0` when unavailable).

The action must be executable and should finish promptly because the listener
waits for it before processing the next event. A non-zero exit status is
reported to stderr but does not stop event monitoring. The action is executed
directly, without a shell.