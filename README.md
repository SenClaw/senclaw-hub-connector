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

Published images (linux/amd64 + linux/arm64) live on GHCR:

```bash
docker run -p 18080:18080 -v hub-data:/data ghcr.io/senclaw/senclaw-hub-connector:latest
```

`.github/workflows/docker.yml` builds them on native runners and smoke-tests
each one (register a channel, verify its token) before publishing:

| event | result |
|---|---|
| pull request | build + smoke test, nothing pushed |
| push to `main` | `:edge`, `:sha-<short>` |
| tag `v1.2.3` | `:1.2.3`, `:1.2`, `:latest` (not for pre-releases), `:sha-<short>` |

The first push creates the package as private; make it public under the
package settings, or give the cluster a pull token (see below).

## Deploy to k3s

`deploy/terraform` runs the image on k3s/Kubernetes: namespace, PVC for the
SQLite database (`/data/hub.db`), Deployment, ClusterIP Service and an optional
Ingress (WebSocket timeouts included).

```bash
cd deploy/terraform
cp env/prod.tfvars.example env/prod.tfvars   # cluster, domain, ...
make init
make plan  ENV=prod TAG=0.1.0
make apply ENV=prod TAG=0.1.0
terraform output url
```

- `TAG` is the image tag, i.e. the git tag without the `v`. Pin a version or
  `sha-…`: moving tags (`edge`, `latest`) do not roll the pod on `apply`.
- The hub always runs as one replica with the `Recreate` strategy. Channels sit
  in SQLite and both ends of a relay must land on the same process.
- `ingress_class` defaults to `nginx`; set `traefik` on a stock k3s. Leave
  `domain` empty to skip the Ingress and use `kubectl port-forward`.
- A private GHCR package needs `registry_username` / `registry_password`
  (token with `read:packages`); a public one needs neither.
- State is a local `<ENV>.tfstate` next to the config (git-ignored, back it up).
  `env/*.tfvars` is git-ignored too: it holds cluster credentials.

## Release

Push a semver tag to trigger the release workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

That builds multi-platform binaries and publishes them on the GitHub Release;
the same tag also publishes the Docker image.
