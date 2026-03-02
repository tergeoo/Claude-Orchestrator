# clrc — Claude Remote Control

Use Claude CLI on your Mac from your iPhone.

```
iPhone ──WebSocket──▶ Relay ◀──WebSocket── clrc (Mac daemon)
                                                  │ PTY
                                                  ▼
                                             claude / bash
```

---

## Install

### Mac agent — one-liner

```sh
curl -fsSL https://raw.githubusercontent.com/tergeoo/clrc/main/install.sh | sh
```

Prompts for relay URL and secret, downloads the binary, sets up auto-start on login.

### Mac agent — from source

```sh
git clone https://github.com/tergeoo/clrc
cd clrc
make agent-init      # create agent/.env
$EDITOR agent/.env   # set RELAY_URL and AGENT_SECRET
make agent           # build and run
```

---

## Usage

```sh
clrc start     # start daemon in background
clrc stop      # stop daemon
clrc restart   # restart
clrc status    # running or stopped
clrc logs      # tail -f /tmp/clrc.log
```

Config: `~/.config/clrc/.env`

Override per-run:
```sh
clrc --relay wss://my-relay.com --secret mysecret --name "My Mac"
```

---

## Relay

The relay routes traffic between phone and Macs — deploy once, use from anywhere.

### Local network

```sh
make relay-init      # create relay/.env
$EDITOR relay/.env   # set JWT_SECRET, ADMIN_PASSWORD, AGENT_SECRET
make relay           # start on :8080
```

### Cloud (Railway, fly.io)

Deploy `relay/` with Docker. Set the three env vars in the dashboard.

---

## iOS App

Open `Claude Orchestrator.iOS/Claude Orchestrator.xcodeproj` in Xcode.
Build & run on your device (same Wi-Fi as the relay for local setup).

---

## Makefile reference

```sh
make agent-init    # create agent/.env from example
make relay-init    # create relay/.env from example
make agent         # build and run clrc in foreground
make relay         # build and run relay in foreground
make app           # build "Claude Remote Control.app" (double-clickable)
make build         # build both binaries to /tmp/
make logs          # tail /tmp/clrc.log
make relay-logs    # tail /tmp/claude-relay.log
make status        # show launchd service status
make uninstall     # remove launchd service and binary
make release VERSION=v1.2.3
```

---

## Config reference (`~/.config/clrc/.env`)

| Variable | Required | Description |
|---|---|---|
| `RELAY_URL` | yes | `ws://` for LAN, `wss://` for cloud |
| `AGENT_SECRET` | yes | Must match `AGENT_SECRET` on relay |
| `AGENT_ID` | no | Auto-generated and persisted on first run |
| `AGENT_NAME` | no | Display name in iOS app (default: hostname) |
| `DEFAULT_COMMAND` | no | Command in new terminal sessions (default: `bash`) |

---

## Structure

```
clrc/
├── install.sh              # one-liner installer
├── Makefile
├── scripts/
│   ├── start-agent.sh
│   ├── start-relay.sh
│   ├── make-app.sh         # builds .app bundle
│   └── uninstall-agent.sh
├── agent/                  # clrc binary (Go)
│   ├── cmd/main.go         # start/stop/status/logs subcommands
│   ├── config.go           # config + stable agent ID
│   ├── ws_client.go        # relay connection + message routing
│   ├── pty_session.go      # PTY process management
│   └── fs_ops.go           # file system operations
├── relay/                  # relay server (Go)
│   ├── cmd/main.go
│   ├── hub.go              # connection registry + routing
│   ├── auth.go             # JWT + rate limiting
│   └── session.go          # message types
└── Claude Orchestrator.iOS/ # SwiftUI iOS app
```
