# SenClaw Hub Connector

Encrypted **relay hub** for [SenClaw](https://github.com/SenClaw/senclaw) —
pairs a daemon with remote clients (Connect, desktop Channels UI) over one
WebSocket channel and exposes a small REST surface for channel register/verify
plus placeholder skill-registry routes.

Migrated from the old SemaClaw `hub-backend` package.

## Run locally

```bash
cp .env.example .env
go run ./cmd/server
```

Default listen address: `:18080`.

- `POST /v1/channels/register` — mint `channel_id` + `access_token`
- `POST /v1/channels/verify` — validate a channel token
- `GET /v1/relay/ws?channel_id=…&access_token=…` — encrypted relay WebSocket

## Docker

```bash
docker compose up --build
```

## Release

Push a semver tag to trigger the release workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

That builds multi-platform binaries and publishes them on the GitHub Release.
