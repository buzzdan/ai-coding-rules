# go-mini

Backend for the device fleet. Devices post heartbeats over HTTP, a scheduler
runs snapshot jobs, alerts go out over email, Slack, or PagerDuty, and a status
endpoint reports what the fleet looks like.

## Running

```
task build
PORT=8080 ./bin/svc --store devices.json
```

Pass `--dry-run` to keep devices in memory instead of writing the JSON store.

Configuration comes from the environment:

| Variable          | Default | Meaning                                   |
|-------------------|---------|-------------------------------------------|
| `PORT`            | 8080    | HTTP listen port                          |
| `NUM_WORKERS`     | 4       | snapshot worker goroutines                |
| `BATCH`           | 64      | job queue depth                           |
| `FLAP_WINDOW_SEC` | 30      | seconds before DOWN -> READY counts as up |
| `QUEUE_ADDR`      |         | address of the job queue                  |
| `REGION`          | us      | region this instance serves               |

## Development

```
task test
task lint
```

See `docs/` for protocol notes.
