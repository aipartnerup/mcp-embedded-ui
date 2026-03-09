# F2: Tool Discovery API

| Field        | Value                                |
|--------------|--------------------------------------|
| Feature ID   | F2                                   |
| Title        | Tool Discovery API                   |
| Complexity   | S                                    |
| Priority     | P0                                   |
| Dependencies | None                                 |
| Status       | Draft                                |

## Overview

Three read-only HTTP endpoints that expose MCP server metadata and tool
definitions to the embedded frontend. The endpoints are backed by a
`ToolsProvider` abstraction that supports static lists, sync callables,
and async callables across all target languages.

## Endpoints

### `GET /meta`

Returns server-level metadata used by the frontend to configure itself
without probe requests.

**Response** `200 OK` `application/json`

```json
{
  "title": "My MCP Server",
  "allow_execute": true
}
```

| Field           | Type   | Description                                      |
|-----------------|--------|--------------------------------------------------|
| `title`         | string | Human-readable server name                       |
| `allow_execute` | bool   | Whether the execution endpoint (F3) is enabled   |

---

### `GET /tools`

Returns a JSON array of tool summaries. If the `ToolsProvider` is a
callable, it is invoked on every request (no caching -- caller's
responsibility).

**Response** `200 OK` `application/json`

```json
[
  {
    "name": "get_weather",
    "description": "Fetch current weather for a city.",
    "annotations": {
      "readOnlyHint": true,
      "openWorldHint": true
    }
  },
  {
    "name": "delete_record",
    "description": "Delete a record by ID."
  }
]
```

| Field         | Type            | Description                                         |
|---------------|-----------------|-----------------------------------------------------|
| `name`        | string          | Tool identifier                                     |
| `description` | string          | Human-readable description                          |
| `annotations` | object \| _omitted_ | MCP annotations; **omitted entirely** when the tool has none (never `null`) |

**Annotations fields** (all optional booleans):
`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`.

---

### `GET /tools/{name}`

Returns a single tool with full detail, including its input schema.

**Response** `200 OK` `application/json`

```json
{
  "name": "get_weather",
  "description": "Fetch current weather for a city.",
  "annotations": {
    "readOnlyHint": true,
    "openWorldHint": true
  },
  "inputSchema": {
    "type": "object",
    "properties": {
      "city": { "type": "string", "description": "City name" }
    },
    "required": ["city"]
  }
}
```

| Field         | Type                | Description                                      |
|---------------|---------------------|--------------------------------------------------|
| `name`        | string              | Tool identifier                                  |
| `description` | string              | Human-readable description                       |
| `annotations` | object \| _omitted_ | MCP annotations; omitted when none               |
| `inputSchema` | object              | JSON Schema describing the tool's input parameters |

**Error** `404 Not Found`

```json
{
  "error": "Tool not found: unknown_tool"
}
```

## ToolsProvider Abstraction

The `ToolsProvider` is the single source of tool definitions. It accepts
three shapes:

| Shape          | Description                                      |
|----------------|--------------------------------------------------|
| Static list    | A plain list/array of `Tool` objects              |
| Sync callable  | A zero-argument function returning `Tool[]`       |
| Async callable | A zero-argument async function returning `Tool[]` |

### Resolution Algorithm

```
1. If provider is a list  -> use it directly.
2. Otherwise              -> call it.
3. If the result is awaitable -> await it.
4. Use the resolved list.
```

When the provider is callable it is invoked on **every request**. The
library performs no internal caching; callers who need caching must
implement it in their callable.

### Cross-Language Mapping

| Language   | ToolsProvider type                                          |
|------------|-------------------------------------------------------------|
| Python     | `list \| Callable \| AsyncCallable`                        |
| TypeScript | `Tool[] \| (() => Tool[]) \| (() => Promise<Tool[]>)`      |
| Go         | `[]Tool` or `ToolProvider interface { Tools() []Tool }`     |
| Rust       | `Vec<Tool>` or `impl Fn() -> Vec<Tool>`                    |

## Tool Object Protocol

Tools are duck-typed. Any object exposing the following attributes is
accepted:

| Attribute     | Type               | Description                                 |
|---------------|--------------------|---------------------------------------------|
| `name`        | string             | Tool identifier                             |
| `description` | string             | Human-readable description                  |
| `inputSchema` | dict / object      | JSON Schema for input parameters            |
| `annotations` | object \| null     | Optional MCP annotations (see above)        |

## Serialization Rules

Tool objects are serialized to plain dicts for JSON output. The
following strategies are tried in order:

1. **Pydantic v2** -- object has `.model_dump()` -> call
   `model_dump(exclude_none=True)`.
2. **Pydantic v1** -- object has `.dict()` -> call
   `dict(exclude_none=True)`.
3. **Plain dict** -- recurse into values (apply the same rules to nested
   objects).
4. **Everything else** -- pass through as-is.

The `exclude_none=True` parameter ensures that `annotations` (and any
other optional field set to `None`) is omitted from the output rather
than serialized as `null`.

## Test Criteria

- [ ] `GET /meta` returns correct `title` and `allow_execute` values.
- [ ] `GET /tools` returns all tools with correct fields.
- [ ] `GET /tools` returns `annotations` only when present (key is
      omitted, not `null`).
- [ ] `GET /tools/{name}` returns `inputSchema` in the response.
- [ ] `GET /tools/{unknown}` returns `404` with an error message.
- [ ] Sync callable provider is invoked on each request (no caching).
- [ ] Async callable provider resolves correctly.
