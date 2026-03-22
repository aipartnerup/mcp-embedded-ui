# mcp-embedded-ui

A cross-language specification and shared assets for embedding a browser-based tool explorer into any [MCP](https://modelcontextprotocol.io/) (Model Context Protocol) server.

**Official SDKs:** 
[**Python** (PyPI)](https://github.com/aiperceivable/mcp-embedded-ui-python) | 
[**TypeScript** (npm)](https://github.com/aiperceivable/mcp-embedded-ui-typescript) |
[**Go** (Coming Soon)]

---

## Quick Start

=== "Python"
    **SDK:** [aiperceivable/mcp-embedded-ui-python](https://github.com/aiperceivable/mcp-embedded-ui-python)

    ```bash
    pip install mcp-embedded-ui
    ```

    ```python
    from fastapi import FastAPI
    from mcp_embedded_ui import create_mount

    app = FastAPI()

    # Mount the explorer UI to your FastAPI app
    app.routes.append(create_mount(
        tools=my_tools,
        handle_call=my_handler,
        prefix="/explorer"
    ))

    # Visit http://localhost:8000/explorer/
    ```

=== "TypeScript"
    **SDK:** [aiperceivable/mcp-embedded-ui-typescript](https://github.com/aiperceivable/mcp-embedded-ui-typescript)

    ```bash
    npm install mcp-embedded-ui
    ```

    ```typescript
    import http from "node:http";
    import { createNodeHandler } from "mcp-embedded-ui";

    const handler = createNodeHandler(myTools, myHandler, {
      prefix: "/explorer",
    });

    http.createServer(handler).listen(8000);
    // Visit http://localhost:8000/explorer/
    ```

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

## Key Features

The embedded explorer page provides:

- **Tool list** — browse all registered tools with descriptions and annotations.
- **Schema inspector** — expand any tool to view its full JSON Schema (`inputSchema`).
- **Try-it console** — type JSON arguments, execute the tool, see results instantly.
- **cURL export** — copy a ready-made cURL command for any execution.
- **Auth support** — enter a Bearer token in the UI, sent with all requests.

No build step. No CDN. No external dependencies. The entire UI is a single HTML string embedded in your server binary/package.

## Documentation for Developers

| Document | Description |
|----------|-------------|
| [Protocol Spec](docs/PROTOCOL.md) | Endpoint spec, data shapes, cross-language abstraction mapping. |
| [Feature Manifest](docs/features/MANIFEST.md) | Implementation roadmap and dependency graph for new SDKs. |
| [HTML Template](docs/explorer.html) | The shared "source of truth" HTML file used by all SDKs. |

### Feature Deep Dives

- [F1: HTML Frontend](docs/features/html-frontend.md)
- [F2: Tool Discovery API](docs/features/tool-discovery-api.md)
- [F3: Tool Execution API](docs/features/tool-execution-api.md)
- [F4: Auth Hook](docs/features/auth-hook.md)
- [F5: Framework Integration](docs/features/framework-integration.md)
- [F6: Try-It Console](docs/features/try-it-console.md)

## How to Add a New Language

1. Read the [Protocol Specification](docs/PROTOCOL.md) — the authoritative source for endpoints and data shapes.
2. Follow the [Feature Manifest](docs/features/MANIFEST.md) implementation order: **F1 → F2 → F3 → F4 → F6 → F5**.
3. Use the [explorer.html](docs/explorer.html) template (do not modify the HTML content).
4. Ensure you follow the [Security Checklist](docs/PROTOCOL.md#security-checklist).
5. Open a PR to add your implementation to this list!

## Design Principles

- **Zero frontend build** — No npm/webpack/CDN. Just one HTML string.
- **Framework-agnostic** — Standard HTTP routes that mount anywhere.
- **Cross-language consistency** — Identical UX across Python, TS, Go, etc.
- **Secure by default** — XSS protection and auth sanitization built-in.

## License

Apache-2.0
