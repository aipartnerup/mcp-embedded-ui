# F5: Framework Integration

| Field        | Value                                |
|--------------|--------------------------------------|
| Feature ID   | F5                                   |
| Title        | Framework Integration                |
| Complexity   | S                                    |
| Priority     | P0                                   |
| Dependencies | F2, F3, F4                           |
| Status       | Draft                                |

## Overview

A three-tier API surface that composes the tool discovery (F2), tool
execution (F3), and auth hook (F4) features into ready-to-use web
application primitives. Each tier trades flexibility for convenience:
a low-level route builder, a standalone app factory, and a framework
mount helper. All three share a common parameter set and are exported
from the package root alongside the public type aliases they depend on.

## Scope

- Three factory functions at increasing levels of abstraction.
- Common parameter contract shared by all three.
- Public type exports from the package root.
- Backward-compatible deprecated alias for the legacy entry point.
- Cross-language mapping for Python, TypeScript, Go, and Rust.

## API Surface

### Tier 1: `build_ui_routes(tools, handle_call, **config)` -- Route Builder

Low-level entry point for power users who need fine-grained control
over routing. Returns framework-native route objects that the caller
is responsible for registering.

**Signature (Python)**

```python
def build_ui_routes(
    tools: ToolsProvider,
    handle_call: ToolCallHandler,
    *,
    allow_execute: bool = True,
    auth_hook: AuthHook | None = None,
    title: str = "MCP Tool Explorer",
) -> list[Route]:
    ...
```

**Returns:** A list of framework-native route objects (e.g.,
Starlette `Route`, Express `Router`, Go `[]Route`).

---

### Tier 2: `create_app(tools, handle_call, **config)` -- App Factory

Universal entry point that returns a standalone HTTP application
conforming to the framework's standard protocol (ASGI for Python,
HTTP handler for Go, etc.). Any framework with adapter support can
mount the returned app directly.

**Signature (Python)**

```python
def create_app(
    tools: ToolsProvider,
    handle_call: ToolCallHandler,
    *,
    allow_execute: bool = True,
    auth_hook: AuthHook | None = None,
    title: str = "MCP Tool Explorer",
) -> ASGIApp:
    ...
```

**Returns:** A framework-native application object (e.g., Starlette
`Starlette` app implementing `ASGIApp`, Node `http.Server` / Hono
app, Go `http.Handler`).

---

### Tier 3: `create_mount(prefix, *, tools, handle_call, **config)` -- Mount Helper

Convenience wrapper for framework users who want to mount the UI
under a URL prefix with a single call.

- `prefix` is **positional** with a default of `"/explorer"`.
- `tools` and `handle_call` are **keyword-only**.

**Signature (Python)**

```python
def create_mount(
    prefix: str = "/explorer",
    *,
    tools: ToolsProvider,
    handle_call: ToolCallHandler,
    allow_execute: bool = True,
    auth_hook: AuthHook | None = None,
    title: str = "MCP Tool Explorer",
) -> Mount:
    ...
```

**Returns:** A mounted sub-application (e.g., Starlette `Mount`,
Express `app.use(prefix, ...)`, Go `mux.Handle(prefix, ...)`).

## Common Parameters

All three factory functions accept the same configuration parameters:

| Parameter       | Type                  | Default               | Description                        |
|-----------------|-----------------------|-----------------------|------------------------------------|
| `tools`         | `ToolsProvider`       | _required_            | Static list or callable            |
| `handle_call`   | `ToolCallHandler`     | _required_            | Execution callback                 |
| `allow_execute` | `bool`                | `true`                | Enable/disable execution endpoint  |
| `auth_hook`     | `AuthHook \| null`    | `null`                | Auth guard (see F4)                |
| `title`         | `string`              | `"MCP Tool Explorer"` | Page title (substituted into HTML) |

## Public Type Exports

The following types are exported from the package root so consumers
never need to reach into internal modules:

| Export            | Kind                  | Description                                      |
|-------------------|-----------------------|--------------------------------------------------|
| `ToolsProvider`   | Type alias            | `list \| Callable \| AsyncCallable` (see F2)     |
| `ToolCallHandler` | Type alias            | Callback invoked to execute a tool               |
| `AuthHook`        | Type alias            | Request guard returning pass/fail (see F4)       |
| `CallResult`      | TypedDict / interface | Structured response from tool execution (see F3) |
| `build_ui_routes` | Function              | Tier 1 route builder                             |
| `create_app`      | Function              | Tier 2 app factory                               |
| `create_mount`    | Function              | Tier 3 mount helper                              |
| `build_mcp_ui_routes` | Function (deprecated) | Legacy alias for `build_ui_routes` (see Backward Compatibility) |

All eight symbols must be importable via a single import from the
package root:

```python
from mcp_embedded_ui import (
    ToolsProvider,
    ToolCallHandler,
    AuthHook,
    CallResult,
    build_ui_routes,
    create_app,
    create_mount,
)
```

## Backward Compatibility

### Deprecated Alias: `build_mcp_ui_routes()`

The legacy entry point `build_mcp_ui_routes()` is retained as a thin
wrapper that:

1. Emits a deprecation warning (e.g., Python `warnings.warn` with
   `DeprecationWarning`, TypeScript `console.warn`).
2. Delegates to `build_ui_routes()` with identical arguments.

The warning message must include the replacement function name:

```
build_mcp_ui_routes() is deprecated; use build_ui_routes() instead.
```

**Removal timeline:** the alias is removed after one minor version
bump following the release that introduces `build_ui_routes()`.

## Cross-Language Mapping

| Language   | `build_ui_routes`              | `create_app`                   | `create_mount`                   |
|------------|--------------------------------|--------------------------------|----------------------------------|
| Python     | `list[Route]`                  | `ASGIApp` (Starlette)          | `Mount`                          |
| TypeScript | `Route[]` (`buildUIRoutes`)    | `createHandler()` → Web Fetch handler | `createNodeHandler({prefix})` → Node handler |
| Go         | `[]Route` / `http.Handler`     | `http.Handler`                 | `mux.Handle(prefix, ...)`        |
| Rust       | `axum::Router`                 | `axum::Router`                 | `.nest(prefix, ...)`             |

## Test Criteria

- [ ] `create_app` returns a working ASGI/HTTP app that serves
      `GET /` (HTML with template variables) and `GET /tools` correctly.
- [ ] `create_mount` defaults to `/explorer` prefix when no prefix
      is supplied.
- [ ] `create_mount` with a custom prefix (e.g., `/ui`) mounts the
      app under that prefix.
- [ ] `build_mcp_ui_routes()` emits a deprecation warning and
      delegates to `build_ui_routes()`.
- [ ] All public types (`ToolsProvider`, `ToolCallHandler`,
      `AuthHook`, `CallResult`) are importable from the package root.
- [ ] `create_app` with a dynamic tools provider (callable) invokes
      the callable on each request.
