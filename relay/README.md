# claude-relay

WebSocket relay server. Routes traffic between the iOS app and Mac agents.

```
iOS client  ──/ws/client──▶  relay  ◀──/ws/agent──  Mac agent
```

The relay only routes — it never reads terminal content.

## Configuration

All config via environment variables.

| Variable | Required | Description |
|---|---|---|
| `JWT_SECRET` | yes | HMAC key for signing JWT tokens. `openssl rand -hex 32` |
| `ADMIN_PASSWORD` | yes | Password for the iOS app login screen |
| `AGENT_SECRET` | yes | Pre-shared secret agents use to authenticate |
| `PORT` | no | Port to listen on (default: `8080`) |

## Local development

```bash
cp .env.example .env
$EDITOR .env          # fill in the three required values
make relay            # builds and starts on :8080
```

## Production (Railway / fly.io)

Set the three env vars in the dashboard and deploy — `docker/Dockerfile` is the entry point.

```bash
make release VERSION=v1.2.3   # tag + push → GitHub Actions builds and releases
```

## Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check — returns `ok` |
| `POST` | `/auth/login` | Login with `{"password": "..."}` → returns JWT pair |
| `POST` | `/auth/refresh` | Refresh access token (`Authorization: Bearer <refresh_token>`) |
| `WS` | `/ws/agent` | Agent connection — first frame must be `register` |
| `WS` | `/ws/client` | iOS client connection — first frame must be `auth` |

## Authentication

- **Clients** (iOS): JWT access token (15 min) + refresh token (30 days). Access token sent as first WebSocket frame after connecting.
- **Agents** (Mac): pre-shared `AGENT_SECRET` sent in the `register` frame.

## Build

```bash
go build -o /tmp/claude-relay ./cmd/
```

## Package structure

```
relay/
├── cmd/main.go     HTTP server, env config, route wiring
├── hub.go          Hub — connection registry and message routing
├── auth.go         Auth — JWT generation and validation
├── session.go      Message — wire protocol envelope type
└── docker/
    └── Dockerfile
```
