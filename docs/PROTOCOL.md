# MCP Embedded UI — Protocol Specification

Cross-language implementation reference for the MCP Embedded UI.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Browser (HTML/JS — self-contained)         │
│  Fetches: /tools, /tools/{name},             │
│           /tools/{name}/call                │
└──────────────┬──────────────────────────────┘
               │ HTTP (JSON)
┌──────────────▼──────────────────────────────┐
│  mcp-embedded-ui (language-specific lib)    │
│                                             │
│  Inputs:                                    │
│    - tools_provider: Tool[] | () -> Tool[]  │
│    - handle_call: (name, args) -> Result    │
│    - auth_hook: (request) -> guard          │
│    - config: { allow_execute, title }       │
│                                             │
│  Outputs:                                   │
│    - HTTP routes / ASGI app / Handler       │
└─────────────────────────────────────────────┘
```

## Endpoints

### `GET /`

Returns the self-contained HTML page. The HTML is static (generated once
with the configured `title`). The `title` must be HTML-escaped before
injection.

**Response**: `text/html`

### `GET /tools`

Returns a summary list of all available tools. If `tools_provider` is a
callable, it is invoked on each request (no caching).

**Response** (`application/json`):
```json
[
  {
    "name": "my_tool",
    "description": "Does something useful",
    "annotations": { "readOnlyHint": true }
  }
]
```

- `annotations` is **omitted** (not `null`) when the tool has no annotations.

### `GET /tools/{name}`

Returns full detail for a single tool, including `inputSchema`.

**Response** (`application/json`):
```json
{
  "name": "my_tool",
  "description": "Does something useful",
  "inputSchema": {
    "type": "object",
    "properties": {
      "message": { "type": "string" }
    }
  },
  "annotations": { "readOnlyHint": true }
}
```

**Error** (tool not found):
```json
// 404
{ "error": "Tool not found: unknown_tool" }
```

### `POST /tools/{name}/call`

Execute a tool. Request body is the tool's input arguments.

**Request** (`application/json`):
```json
{ "message": "hello" }
```

**Preconditions**:
1. If `allow_execute` is false → `403 {"error": "Tool execution is disabled."}`
2. If tool not found → `404 {"error": "Tool not found: {name}"}`
3. If `auth_hook` is set and rejects → `401 {"error": "Unauthorized"}`
4. If request body is not valid JSON → treat as `{}`

**Success Response** (`200`):
```json
{
  "content": [{ "type": "text", "text": "result here" }],
  "isError": false,
  "_meta": { "_trace_id": "abc-123" }
}
```

**Error Response** (`500`):
```json
{
  "content": [{ "type": "text", "text": "error message" }],
  "isError": true
}
```

- `_meta` is **omitted** when `trace_id` is null/empty.
- `content` items follow MCP content types: `TextContent` (`type: "text"`),
  `ImageContent` (`type: "image"`, with `mimeType` and base64 `data`), or
  other types. The frontend renders each type appropriately.

## Abstractions (language-specific mapping)

### ToolsProvider

Provides the list of tools. Can be static or dynamic.

| Language | Implementation |
|----------|---------------|
| Python | `list[Tool] \| Callable[[], list] \| Callable[[], Awaitable[list]]` |
| TypeScript | `Tool[] \| (() => Tool[]) \| (() => Promise<Tool[]>)` |
| Go | `[]Tool` or `ToolProvider interface { Tools() []Tool }` |
| Rust | `Vec<Tool>` or `impl Fn() -> Vec<Tool>` |

### ToolCallHandler

Executes a tool by name with the given arguments.

**Signature**: `(name, args[, request]) -> (content, is_error, trace_id)`

The handler accepts an **optional** third parameter — the HTTP request
object. Implementations should auto-detect whether the handler accepts 2 or
3 parameters (e.g. via `inspect.signature` in Python, `Function.length` in
JS). This allows integrations to access request context (headers, identity,
etc.) without breaking existing 2-parameter handlers.

| Language | 2-param (basic) | 3-param (with request) |
|----------|----------------|----------------------|
| Python | `async def handler(name, args) -> tuple[list, bool, str \| None]` | `async def handler(name, args, request) -> tuple[list, bool, str \| None]` |
| TypeScript | `(name: string, args: Record) => Promise<[Content[], boolean, string?]>` | `(name: string, args: Record, req: Request) => Promise<[Content[], boolean, string?]>` |
| Go | `HandleCall(name string, args map[string]any) ([]Content, bool, string, error)` | `HandleCall(ctx context.Context, name string, args map[string]any) ([]Content, bool, string, error)` ¹ |
| Rust | `async fn handle_call(name: &str, args: Value) -> Result<CallResult>` | `async fn handle_call(name: &str, args: Value, req: &Request) -> Result<CallResult>` |

¹ Go uses `context.Context` idiomatically; retrieve the request via `RequestFromContext(ctx)`.

**Detection logic** (Python example):
```python
import inspect

sig = inspect.signature(handle_call)
if len(sig.parameters) >= 3:
    content, is_error, trace_id = await handle_call(name, args, request)
else:
    content, is_error, trace_id = await handle_call(name, args)
```

### AuthHook

Guards tool execution. Runs before `handle_call`. Raise/panic/error to
reject with 401.

| Language | Pattern |
|----------|---------|
| Python | Context manager (`with auth_hook(request): ...`) |
| TypeScript | Middleware (`(req, next) => { validate(req); return next(); }`) |
| Go | `http.Handler` middleware wrapper |
| Rust | Tower middleware / extractor |

**Security rule**: Auth rejection must return `{"error": "Unauthorized"}`
without leaking internal exception details.

### Output (framework integration)

| Language | Output type |
|----------|-------------|
| Python | `list[Route]` / `Mount` / `ASGIApp` |
| TypeScript | Express `Router` / Hono app / standalone `http.Server` |
| Go | `http.Handler` / Chi `Router` / mount path |
| Rust | Axum `Router` / Actix scope |

## HTML Frontend

The HTML page is a **single self-contained string** with embedded CSS and
JavaScript. No external dependencies, no build step.

**Key behaviors**:
- Uses `window.location.pathname` as base URL for all API calls
- Fetches `/tools` on load to render the tool list
- Lazy-loads tool detail on expand (fetches `/tools/{name}`)
- `esc()` function escapes all user-provided text before DOM insertion
- Authorization header field sends `Bearer` token with all requests
- Generates copyable cURL commands after execution
- Result/Raw MCP tab toggle for response viewing

**Template variables**:
- `{{TITLE}}` — replaced with HTML-escaped title at render time. Appears in `<title>` and `<h1>`.
- `{{ALLOW_EXECUTE}}` — replaced with `true` or `false` (JS literal, no quotes). **Defaults to `false`**. Set to `true` to enable tool execution — must be enforced at the handler level, not just the UI.
- `{{PROJECT_LINK}}` — replaced with a footer link fragment. Empty string if `project_name` is not configured. If `project_name` is set without `project_url`, renders as plain text. If both are set, renders as a clickable link. Both values must be HTML-escaped before injection.

## Security Checklist

- [ ] HTML-escape `title` before template injection (prevent XSS)
- [ ] Do not leak auth error details in 401 responses
- [ ] `allow_execute` must block at the handler level, not just the UI; consider setting to `false` in production if execution is not needed
- [ ] Tool `name` from URL path params must be validated against known tools
- [ ] `esc()` in frontend must escape all user content before `innerHTML`
