# mcp-embedded-ui

A cross-language specification and shared assets for embedding a browser-based tool explorer into any [MCP](https://modelcontextprotocol.io/) (Model Context Protocol) server.

## What is this?

If you build an MCP server, your users interact with tools through JSON — no visual feedback, no schema browser, no quick way to test. **mcp-embedded-ui** solves this by defining a standard set of HTTP endpoints and a self-contained HTML page that any MCP server can serve, in any language.

```
┌───────────────────────────────────┐
│  Browser                          │
│  Tool list → Schema → Try it      │
└──────────────┬────────────────────┘
               │ HTTP / JSON
┌──────────────▼────────────────────┐
│  Your MCP Server                  │
│  + mcp-embedded-ui library        │
│    (Python / TypeScript / Go / …) │
└───────────────────────────────────┘
```

**One import. One mount. Full UI.**

## What does the UI look like?

The embedded explorer page provides:

- **Tool list** — browse all registered tools with descriptions and annotations
- **Schema inspector** — expand any tool to view its full JSON Schema (`inputSchema`)
- **Try-it console** — type JSON arguments, execute the tool, see results instantly
- **cURL export** — copy a ready-made cURL command for any execution
- **Auth support** — enter a Bearer token in the UI, sent with all requests

No build step. No CDN. No external dependencies. The entire UI is a single HTML string embedded in your server binary/package.

## This repo vs. language repos

| Repository | What it contains |
|------------|-----------------|
| **mcp-embedded-ui** (this repo) | Protocol spec, shared HTML template, feature specs — the "source of truth" |
| [mcp-embedded-ui-python](https://github.com/aipartnerup/mcp-embedded-ui-python) | Python implementation (`pip install mcp-embedded-ui`) |

This repo does **not** contain runnable code. It defines *what* to build. Language repos contain *how* to build it.

## Quick start (for users)

Pick your language and follow the language-specific README:

### Python

```bash
pip install mcp-embedded-ui
```

```python
from fastapi import FastAPI
from mcp_embedded_ui import create_mount

app = FastAPI()
app.routes.append(create_mount(tools=my_tools, handle_call=my_handler))
# Visit http://localhost:8000/explorer/
```

### Other languages

Coming soon. See [How to Add a New Language](#how-to-add-a-new-language) to contribute.

## Protocol overview

The library exposes 5 HTTP endpoints under a configurable prefix (default `/explorer`):

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Self-contained HTML explorer page |
| GET | `/meta` | JSON config — `{ title, allow_execute }` |
| GET | `/tools` | Summary list of all tools |
| GET | `/tools/{name}` | Full tool detail with `inputSchema` |
| POST | `/tools/{name}/call` | Execute a tool, returns MCP `CallToolResult` |

See [PROTOCOL.md](docs/PROTOCOL.md) for the full specification including request/response shapes, error codes, and security rules.

## Documentation

| Document | Description |
|----------|-------------|
| [PROTOCOL.md](docs/PROTOCOL.md) | Endpoint spec, data shapes, cross-language abstraction mapping, security checklist |
| [explorer.html](docs/explorer.html) | Self-contained HTML template — shared across all language implementations |
| [features/MANIFEST.md](docs/features/MANIFEST.md) | Feature list with dependency graph and implementation order |

### Feature specs

| ID | Feature | Description |
|----|---------|-------------|
| F1 | [HTML Frontend](docs/features/html-frontend.md) | Self-contained page with `{{TITLE}}` injection and XSS escaping |
| F2 | [Tool Discovery API](docs/features/tool-discovery-api.md) | `GET /tools` and `GET /tools/{name}` endpoints |
| F3 | [Tool Execution API](docs/features/tool-execution-api.md) | `POST /tools/{name}/call` with auth guard and error handling |
| F4 | [Auth Hook](docs/features/auth-hook.md) | Pluggable auth via context manager / middleware pattern |
| F5 | [Framework Integration](docs/features/framework-integration.md) | 3-tier API: routes → app → mount |
| F6 | [Try-It Console](docs/features/try-it-console.md) | In-browser execution with result viewer and cURL export |

## How to add a new language

1. Read [PROTOCOL.md](docs/PROTOCOL.md) — the authoritative endpoint and data shape spec
2. Read [features/MANIFEST.md](docs/features/MANIFEST.md) — implementation order and dependency graph
3. Copy [explorer.html](docs/explorer.html) as your HTML template string (do not modify the HTML — it is shared)
4. Implement features in order: **F1 → F2 → F3 → F4 → F6 → F5**
5. Each feature spec includes a cross-language mapping table and test criteria
6. Follow the [Security Checklist](docs/PROTOCOL.md#security-checklist) before release
7. Add your repo to the [Language Implementations](#this-repo-vs-language-repos) table above

## Design principles

- **Zero frontend build** — no npm, no webpack, no CDN. One HTML string.
- **Framework-agnostic** — output is standard HTTP routes. Mount in any web framework.
- **Cross-language consistency** — same endpoints, same response shapes, same HTML across all implementations.
- **Secure by default** — XSS escaping, auth error sanitization, server-side execution guard.
- **Minimal surface** — 5 endpoints, 3 abstractions (`ToolsProvider`, `ToolCallHandler`, `AuthHook`). Nothing more.

## License

MIT
