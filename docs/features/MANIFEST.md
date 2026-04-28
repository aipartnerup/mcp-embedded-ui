# Feature Manifest: mcp-embedded-ui

## Overview

A lightweight, cross-language embedded Web UI library for any MCP server.
Provides browser-based tool discovery, schema inspection, and execution
via a self-contained HTML page served by a thin backend API layer.

## Features

| ID | Feature | Complexity | Priority | Dependencies |
|----|---------|:----------:|:--------:|:------------:|
| F1 | [HTML Frontend](html-frontend.md) | M | P0 | None |
| F2 | [Tool Discovery API](tool-discovery-api.md) | S | P0 | None |
| F3 | [Tool Execution API](tool-execution-api.md) | S | P0 | F2 |
| F4 | [Auth Hook](auth-hook.md) | S | P1 | F3 |
| F5 | [Framework Integration](framework-integration.md) | S | P0 | F2, F3, F4, F7 |
| F6 | [Try-It Console](try-it-console.md) | M | P1 | F1, F3, F7 |
| F7 | [Tool Validation API](tool-validation-api.md) | S | P0 | F2 |

## Dependency Graph

```
F1 (HTML Frontend)          F2 (Tool Discovery API)
       │                         │
       │                         ├──────────────────────┐
       ▼                         ▼                      ▼
F6 (Try-It Console) ──→ F3 (Tool Execution API)  F7 (Tool Validation API)
       │                       │                        │
       └───────────────────────┤                        │
                               ▼                        │
                         F4 (Auth Hook)                 │
                               │                        │
                               ▼                        │
                         F5 (Framework Integration) ◀───┘
```

## Recommended Implementation Order

1. **F1** — HTML Frontend (no deps, shared asset across all languages)
2. **F2** — Tool Discovery API (no deps, core endpoints)
3. **F3** — Tool Execution API (depends on F2 for tool lookup)
4. **F4** — Auth Hook (guards F3)
5. **F7** — Tool Validation API (depends on F2 for `inputSchema`; independent of F3/F4)
6. **F6** — Try-It Console (frontend feature, needs F3 + F7 backends)
7. **F5** — Framework Integration (composes everything, final packaging)

## Cross-Language Implementations

| Language | Repository | Status |
|----------|-----------|--------|
| Python | [mcp-embedded-ui-python](https://github.com/aiperceivable/mcp-embedded-ui-python) | v0.4.0 |
| TypeScript | [mcp-embedded-ui-typescript](https://github.com/aiperceivable/mcp-embedded-ui-typescript) | v0.4.0 |
| Rust | [mcp-embedded-ui-rust](https://github.com/aiperceivable/mcp-embedded-ui-rust) | v0.4.0 |
