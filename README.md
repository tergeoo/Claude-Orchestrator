# Claude Orchestrator

Control multiple Macs from your iPhone — interactive Claude Code CLI over WebSocket.

```
iPhone (SwiftUI)
    │  WebSocket
    ▼
Relay Server  ←── each Mac agent registers here
    │  WebSocket
    ▼
Mac Agent (Go daemon)
    │  PTY
    ▼
claude CLI process
```

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| Mac agent | Go 1.21+, `claude` CLI installed |
| Relay server | Local Mac, Linux host, or Docker |
| iOS app | Xcode 15+, iOS 17+ |

---

## Step 1 — Start the relay

The relay routes traffic between your iPhone and Mac agents.

### Local network (recommended)

```bash
make relay-init             # creates relay/.env from example
$EDITOR relay/.env          # set JWT_SECRET, ADMIN_PASSWORD, AGENT_SECRET
make relay                  # builds and starts on :8080
```

### Cloud (Railway, fly.io, etc.)

Deploy `relay/` with a `Dockerfile`. Set the same three environment variables and use the public `wss://` URL in the agent config and iOS app.

---

## Step 2 — Install the agent on each Mac

### One-liner (downloads from GitHub Releases)

```bash
curl -fsSL https://raw.githubusercontent.com/vrtoursuz/claude-orchestrator/main/install.sh | sh
```

Prompts for relay URL and agent secret, installs the binary, and registers a launchd service that starts on login.

### From source

```bash
make agent-init             # creates agent/.env from example
$EDITOR agent/.env          # set RELAY_URL, AGENT_SECRET, AGENT_ID
make agent                  # builds and runs
```

`agent/.env`:

```env
AGENT_ID=550e8400-e29b-41d4-a716-446655440000   # uuidgen | tr A-Z a-z
AGENT_NAME=MacBook Pro
AGENT_SECRET=your-agent-secret                  # must match AGENT_SECRET in relay/.env
RELAY_URL=ws://192.168.1.10:8080                # or wss:// for cloud relay
DEFAULT_COMMAND=claude
```

### Development (foreground, no launchd)

```bash
make agent                  # builds and runs in foreground
```

---

## Step 3 — iOS App

1. Open `Claude Orchestrator.iOS/Claude Orchestrator.xcodeproj` in Xcode
2. Build & run on your device (same Wi-Fi as the relay)
3. Enter relay URL and `ADMIN_PASSWORD` on first launch

---

## Useful commands

```bash
make relay          # start relay locally
make agent          # start agent locally (foreground)
make logs           # tail -f /tmp/claude-agent.log
make relay-logs     # tail -f /tmp/claude-relay.log
make status         # launchctl list | grep claude
make uninstall      # remove launchd service and binary
make release VERSION=v1.2.3   # tag + push → triggers CI build
```

---

## Repository structure

```
claude-orchestrator/
├── Makefile
├── install.sh                  # public one-liner installer (curl | sh)
├── scripts/
│   ├── start-relay.sh          # used by: make relay
│   ├── start-agent.sh          # used by: make agent
│   └── uninstall-agent.sh      # used by: make uninstall
│
├── relay/
│   ├── .env.example
│   ├── Dockerfile
│   ├── main.go                 # HTTP server, env config
│   ├── hub.go                  # connection registry + routing
│   ├── session.go              # message types
│   └── auth.go                 # JWT login / rate limiting
│
├── agent/
│   ├── docker-compose.agent.yml
│   ├── Dockerfile
│   ├── main.go                 # config, startup
│   ├── ws_client.go            # relay connection, message routing
│   ├── pty_session.go          # PTY process management
│   └── fs_ops.go               # file system operations
│
├── proto/
│   └── messages.go             # shared message type definitions
│
└── Claude Orchestrator.iOS/    # Xcode project (SwiftUI)
    ├── App/ClaudeTerminalApp.swift
    ├── Views/
    │   ├── SessionTabsView.swift
    │   ├── AgentListView.swift
    │   ├── TerminalView.swift
    │   └── FileBrowserView.swift
    ├── Models/TerminalSession.swift
    └── Services/
        ├── RelayWebSocket.swift
        └── AuthService.swift
```

---

## Protocol

### Control messages (JSON)

| Direction | Type | Payload |
|-----------|------|---------|
| agent → relay | `register` | `{agent_id, name, secret}` |
| client → relay | `auth` | `{token}` |
| client → relay | `list` | `{}` |
| client → relay | `connect` | `{agent_id, session_id, cols, rows}` |
| client → relay | `resize` | `{session_id, cols, rows}` |
| client → relay | `disconnect` | `{session_id}` |
| client → relay | `fs_list` | `{agent_id, request_id, path}` |
| client → relay | `fs_mkdir` | `{agent_id, request_id, path}` |
| client → relay | `fs_delete` | `{agent_id, request_id, path}` |
| client → relay | `fs_read` | `{agent_id, request_id, path}` |
| relay → client | `agent_list` | `{agents: [{id, name, connected}]}` |
| relay → client | `session_ready` | `{session_id}` |

### Terminal data (binary frames)

```
[4B uint32 BE: session_id length] [session_id bytes] [terminal bytes]
```

---

## Security

| Threat | Mitigation |
|--------|------------|
| Unauthorized access | JWT (15 min access + 30 day refresh) for clients; pre-shared secret for agents |
| Brute force | Rate limiter: max 10 login attempts per minute per IP |
| Session hijacking | `session_id` validated as UUID v4 |
| Oversized messages | 4 MB limit on all incoming WebSocket frames |
| Connection flooding | Max 50 agents / 20 clients |
| Path traversal | `fs_ops` rejects paths outside the home directory |
| Token leakage | Tokens stored in iOS Keychain |
