# MCP Embedded UI — Protocol Specification

Cross-language implementation reference for the MCP Embedded UI.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Browser (HTML/JS — self-contained)         │
│  Fetches: /tools, /tools/{name},             │
│           /tools/{name}/validate,           │
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

### `POST /tools/{name}/validate`

Validate request arguments against the tool's `inputSchema` **without
executing the tool**. The endpoint is read-only and is **not** gated by
`allow_execute` or by `auth_hook`; it simply restates the schema check
that the host would otherwise perform inside the handler.

**Request** (`application/json`): the same shape as `/call` — the tool's
input arguments as a JSON object.

```json
{ "city": "Paris" }
```

**Preconditions** (evaluated in order):
1. If tool not found → `404 {"error": "Tool not found: {name}"}`
2. If request body is not valid JSON → `400 {"valid": false, "errors": [{"path": "", "message": "Invalid JSON: {detail}", "keyword": "format"}]}`
3. Otherwise → run JSON Schema validation against `inputSchema`

**Success Response** (`200`, valid input):
```json
{ "valid": true }
```

**Failure Response** (`200`, invalid input):
```json
{
  "valid": false,
  "errors": [
    { "path": "/city", "message": "is required", "keyword": "required" },
    { "path": "/count", "message": "must be integer", "keyword": "type" }
  ]
}
```

- `path` uses JSON Pointer (RFC 6901). The root is the empty string `""`.
- `keyword` is the JSON Schema keyword that failed (`required`, `type`,
  `minimum`, `pattern`, …). Optional but recommended.
- HTTP status is **always `200`** when validation runs (regardless of
  whether the input is valid). Non-200 statuses are reserved for the
  preconditions above and for transport errors.
- If the tool's `inputSchema` is not itself a valid JSON Schema, the response
  is `200 {"valid": false, "errors": [{"path": "", "message": "Invalid schema:
  …", "keyword": "schema"}]}`. It must never be a 5xx and must never report
  `valid: true`. See F7 → "Schemas That Cannot Be Compiled".
- Validation is purely structural — based on `inputSchema`. Semantic
  validation (e.g. "city must exist in our database") belongs in the
  tool handler, not here.

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

## JSON Schema validation (for `/validate`)

The library performs structural validation by feeding the request body
and the tool's `inputSchema` into the language-idiomatic JSON Schema
validator. SDKs are expected to depend on a community-standard library
rather than rolling their own validator.

| Language   | Validator |
|------------|-----------|
| Python     | [`jsonschema`](https://pypi.org/project/jsonschema/) (Draft 2020-12 by default; falls back to the `$schema`-declared dialect) |
| TypeScript | [`ajv`](https://www.npmjs.com/package/ajv) (with `ajv-formats`) |
| Go         | [`santhosh-tekuri/jsonschema`](https://pkg.go.dev/github.com/santhosh-tekuri/jsonschema/v5) |
| Rust       | [`jsonschema`](https://crates.io/crates/jsonschema) |

**Error normalization** — each validator emits errors in its own shape;
the library normalizes them to `{path, message, keyword}` before
returning. `path` MUST be a JSON Pointer. `message` SHOULD be the
validator's human-readable string verbatim (no translation, no
reformatting). `keyword` SHOULD be the failing JSON Schema keyword when
the underlying validator exposes it; omit otherwise.

**Tools without an `inputSchema`** — treat as the always-true schema
(`{}`); validation always passes.

## Abstractions (language-specific mapping)

> **Go rows are forward-looking.** No Go SDK is published yet (see
> `docs/features/MANIFEST.md`). The Go mappings below exist so that an
> implementation has a spec to follow — they describe intent, not shipped code.
> Do not read them as evidence that a Go SDK exists.

### ToolsProvider

Provides the list of tools. Can be static or dynamic.

| Language | Implementation |
|----------|---------------|
| Python | `list[Tool] \| Callable[[], list] \| Callable[[], Awaitable[list]]` |
| TypeScript | `Tool[] \| (() => Tool[]) \| (() => Promise<Tool[]>)` |
| Go | `[]Tool` or `ToolProvider interface { Tools() []Tool }` |
| Rust | `Vec<Arc<dyn Tool>>` or `impl ToolsProvider` trait |

### ToolCallHandler

Executes a tool by name with the given arguments.

**Signature**: `(name, args[, request]) -> (content, is_error, trace_id)`

The handler accepts an **optional** third parameter — the HTTP request
object. Implementations should auto-detect whether the handler accepts 2 or
3 parameters (e.g. via `inspect.signature` in Python, `Function.length` in
JS). This allows integrations to access request context (headers, identity,
etc.) without breaking existing 2-parameter handlers.

**The request body is NOT guaranteed to be readable from this parameter.**
It has already been consumed and parsed — its contents reach the handler as
`args`. Some runtimes happen to leave it re-readable (Starlette caches the
body on the request object), others cannot (Rust's axum body is a consumed
stream, and `mcp-embedded-ui-rust` passes an empty body). Handlers that read
the body from this parameter are relying on a runtime accident and will not
port across languages. Use it for headers, identity, and connection context
only.

| Language | 2-param (basic) | 3-param (with request) |
|----------|----------------|----------------------|
| Python | `async def handler(name, args) -> tuple[list, bool, str \| None]` | `async def handler(name, args, request) -> tuple[list, bool, str \| None]` |
| TypeScript | `(name: string, args: Record) => Promise<[Content[], boolean, string?]>` | `(name: string, args: Record, req: Request) => Promise<[Content[], boolean, string?]>` |
| Go | `HandleCall(name string, args map[string]any) ([]Content, bool, string, error)` | `HandleCall(ctx context.Context, name string, args map[string]any) ([]Content, bool, string, error)` ¹ |
| Rust | `Fn(String, Value) -> Future<Result<(Vec<Content>, bool, Option<String>)>>` | `Fn(String, Value, Request) -> Future<Result<(Vec<Content>, bool, Option<String>)>>` |

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
| Rust | Async function (`async fn(parts: Parts) -> Result<(), AuthError>`) |

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

  **`project_url` must additionally be scheme-checked**, because HTML escaping
  alone does not neutralise `javascript:` — that string contains no character
  an escaper would touch. Before building the anchor:

  1. Remove every TAB (U+0009), LF (U+000A) and CR (U+000D) from the value,
     then trim leading and trailing whitespace. Browsers ignore these while
     resolving a scheme, so `java&#9;script:alert(1)` resolves to
     `javascript:alert(1)` and would otherwise slip past a naive prefix check.
  2. Accept the value only if it then begins with `http://`, `https://` or
     `mailto:` (ASCII case-insensitive), or with `/` (site-relative).
  3. Otherwise render `project_name` as plain text with no anchor. Do not
     silently drop the footer, and do not emit a partial anchor.

## Security Checklist

- [ ] HTML-escape `title` before template injection (prevent XSS)
- [ ] Scheme-check `project_url` before placing it in `href` — HTML escaping
      alone does not stop `javascript:`. Strip TAB/LF/CR and trim first, then
      allow only `http://`, `https://`, `mailto:` or a leading `/`
- [ ] Do not leak auth error details in 401 responses
- [ ] `allow_execute` must block at the handler level, not just the UI; consider setting to `false` in production if execution is not needed
- [ ] Tool `name` from URL path params must be validated against known tools
- [ ] `/tools/{name}/validate` must not invoke the tool handler under any code path
- [ ] `esc()` in frontend must escape all user content before `innerHTML`
