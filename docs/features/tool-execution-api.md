# F3: Tool Execution API

| Field | Value |
|-------|-------|
| **Feature ID** | F3 |
| **Title** | Tool Execution API |
| **Complexity** | S |
| **Priority** | P0 |
| **Dependencies** | F2 (Tool Discovery API) |
| **Status** | Draft |

## Overview

Defines the `POST /tools/{name}/call` endpoint that executes a named tool with
caller-supplied arguments and returns an MCP-compliant `CallToolResult` response.
Execution is delegated to a `ToolCallHandler` abstraction provided by the host
application.

## Endpoint

```
POST /tools/{name}/call
Content-Type: application/json
```

### Request Body

The request body contains the tool's input arguments as a JSON object:

```json
{ "message": "hello" }
```

If the body is not valid JSON, it is silently treated as an empty object (`{}`).

## Precondition Checks

Preconditions are evaluated **in order**. The first failing check short-circuits
the request.

| Order | Condition | HTTP Status | Response Body |
|:-----:|-----------|:-----------:|---------------|
| 1 | `allow_execute` is `false` | 403 | `{"error": "Tool execution is disabled."}` |
| 2 | Tool `{name}` not found | 404 | `{"error": "Tool not found: {name}"}` |
| 3 | Request body is invalid JSON | — | Treat as `{}`, continue |
| 4 | `auth_hook` configured and rejects | 401 | `{"error": "Unauthorized"}` (see F4) |
| 5 | All checks pass | — | Call handler |

## ToolCallHandler Abstraction

The handler is an asynchronous function provided by the host application. It
receives the tool name and parsed arguments, and returns a three-element tuple.

**Signature** (language-neutral):

```
async (name: string, args: dict) -> (content, is_error, trace_id)
```

| Return Element | Type | Description |
|----------------|------|-------------|
| `content` | `list[TextContent]` | List of MCP TextContent objects: `[{"type": "text", "text": "..."}]` |
| `is_error` | `boolean` | `true` if the tool invocation represents a logical error |
| `trace_id` | `string \| null` | Optional trace identifier; `null` or empty string means omit `_meta` |

### Cross-Language Type Mapping

| Language | ToolCallHandler Type |
|----------|---------------------|
| Python | `async def(name: str, args: dict) -> tuple[list, bool, str \| None]` |
| TypeScript | `(name: string, args: Record<string, unknown>) => Promise<[Content[], boolean, string?]>` |
| Go | `HandleCall(name string, args map[string]any) ([]Content, bool, string, error)` |
| Rust | `async fn(name: &str, args: Value) -> Result<CallResult>` |

## Response Format

All responses use `Content-Type: application/json` and conform to the MCP
`CallToolResult` schema.

### Success (200)

Returned when the handler completes without exception and `is_error` is `false`.

```json
{
  "content": [{ "type": "text", "text": "result here" }],
  "isError": false,
  "_meta": { "_trace_id": "abc-123" }
}
```

### Handler Error (500)

Returned when the handler completes without exception but `is_error` is `true`.

```json
{
  "content": [{ "type": "text", "text": "something went wrong" }],
  "isError": true
}
```

### Handler Exception (500)

Returned when the handler raises an unhandled exception. The exception is caught
and logged server-side; its message is surfaced in the response.

```json
{
  "content": [{ "type": "text", "text": "exception message" }],
  "isError": true
}
```

## Response Rules

1. **`_meta` omission**: The `_meta` field is **omitted entirely** (not set to
   `null`) when `trace_id` is `null` or an empty string.
2. **HTTP status mapping**:
   - `200` — handler returned successfully with `is_error=false`.
   - `500` — handler returned with `is_error=true`, or an unhandled exception
     occurred.
3. **Exception safety**: Handler exceptions must be caught, logged, and returned
   as an `isError=true` response. They must never propagate as unhandled 500
   errors with framework-default error pages.
4. **Content format**: The `content` array always contains MCP `TextContent`
   objects (`{"type": "text", "text": "..."}`).

## Security Considerations

- The `allow_execute` gate is enforced at the handler level, not merely in the
  UI. This prevents direct API calls from bypassing the restriction.
- Tool `name` from the URL path is validated against the known tool list before
  any execution occurs (precondition 2).
- Auth hook rejection must return a generic `{"error": "Unauthorized"}` without
  leaking internal details (see F4).
- Handler exception messages are included in the response body. Implementations
  should ensure sensitive internal state is not exposed through exception text.

## Test Criteria

| # | Scenario | Expected Result |
|:-:|----------|-----------------|
| 1 | Successful tool call | 200 with `content` array and `_meta` containing `_trace_id` |
| 2 | Handler returns `is_error=true` | 500 with `isError: true` in response body |
| 3 | Tool name not found | 404 with `{"error": "Tool not found: {name}"}` |
| 4 | `allow_execute` is `false` | 403 with `{"error": "Tool execution is disabled."}` |
| 5 | Invalid JSON request body | Body treated as `{}`; tool executes normally |
| 6 | Handler raises an exception | 500 with `isError: true` and exception message in `content` |
| 7 | `trace_id` is `null` or empty | Response has no `_meta` field |

## References

- [PROTOCOL.md](../PROTOCOL.md) — Full protocol specification
- [F2: Tool Discovery API](tool-discovery-api.md) — Tool lookup (dependency)
- [F4: Auth Hook](auth-hook.md) — Auth guard (precondition 4)
- [MCP Specification — CallToolResult](https://spec.modelcontextprotocol.io/) — Upstream schema
