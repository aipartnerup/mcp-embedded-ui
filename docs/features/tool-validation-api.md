# F7: Tool Validation API

| Field        | Value                                |
|--------------|--------------------------------------|
| Feature ID   | F7                                   |
| Title        | Tool Validation API                  |
| Complexity   | S                                    |
| Priority     | P0                                   |
| Dependencies | F2 (Tool Discovery API)              |
| Status       | Draft                                |

## Overview

Defines `POST /tools/{name}/validate`, a read-only endpoint that
validates request arguments against a tool's `inputSchema` **without
executing the tool**. The endpoint exists because the SDKs cannot add
this route on their own — the protocol must define it once so all
language implementations agree on the path, request body, response
envelope, and gating rules.

The endpoint enables the Try-It console (F6) to give users actionable
feedback before they hit Execute, and lets headless callers verify a
payload before paying for a real tool invocation. Validation is purely
structural; semantic checks ("does this city exist?") still belong in
the tool handler.

## Endpoint

```
POST /tools/{name}/validate
Content-Type: application/json
```

### Request Body

```json
{ "city": "Paris" }
```

The body is the same shape as `POST /tools/{name}/call`: a JSON object
of the tool's input arguments.

## Precondition Checks

Preconditions are evaluated **in order**. The first failing check
short-circuits the request.

| Order | Condition | HTTP Status | Response Body |
|:-----:|-----------|:-----------:|---------------|
| 1 | Tool `{name}` not found | 404 | `{"error": "Tool not found: {name}"}` |
| 2 | Request body is invalid JSON | 400 | `{"valid": false, "errors": [{"path": "", "message": "Invalid JSON: {detail}", "keyword": "format"}]}` |
| 3 | All checks pass | 200 | Run schema validation; see Response below |

### Gating Rules

- `allow_execute` is **NOT** consulted. Validation is read-only and
  carries the same risk profile as `GET /tools/{name}` — both reveal
  schema-derived information, and the schema is already public.
- `auth_hook` is **NOT** invoked. Aligns with the discovery endpoints
  (F2) and with the principle that `auth_hook` gates execution only
  (F4 / SEC-2).

These choices are deliberate: a host that disables execution still
benefits from giving users live schema feedback, and a host that
demands authentication for the schema itself can apply framework-level
middleware to all routes uniformly.

## Validation

The library delegates to a language-idiomatic JSON Schema validator
(see PROTOCOL.md → "JSON Schema validation"). Each implementation
normalizes the validator's native error shape to the wire format
defined below.

### Tools Without `inputSchema`

A tool exposing no `inputSchema` (or one set to `null` / missing) is
treated as having the always-true schema `{}`. Validation always
returns `{"valid": true}` for such tools.

### Schemas That Cannot Be Compiled

A tool may expose an `inputSchema` that is not itself a valid JSON
Schema -- `{"type": "no-such-type"}`, a `$ref` that does not resolve,
and so on. No validator can be built from it, so no meaningful
validation is possible.

Such a schema MUST be reported as a **single validation failure**:

```json
{
  "valid": false,
  "errors": [
    { "path": "", "message": "Invalid schema: {detail}", "keyword": "schema" }
  ]
}
```

- HTTP status stays **200**. The endpoint ran; it simply could not
  validate against the declared schema.
- It MUST NOT surface as a 5xx. A broken schema is a property of the
  registered tool, not a server fault, and a crash hides which tool is
  at fault behind a generic error.
- It MUST NOT be reported as `valid`. Answering `{"valid": true}` here
  means the console says "Input is valid." with nothing having been
  checked -- the same failure mode F6/FR-1 was rewritten to eliminate.
- `{detail}` is the underlying validator's own message. Implementations
  are **not** required to normalize its wording across languages.

Implementations legitimately disagree on *which* schemas are
compilable: `{"required": "url"}` is rejected by Ajv and by the Rust
`jsonschema` crate, but accepted by Python's `jsonschema`. That is
acceptable -- this contract fixes the **response shape when compilation
fails**, not a shared definition of "malformed".

## Response Format

`Content-Type: application/json` for all responses.

### Valid (200)

```json
{ "valid": true }
```

The `errors` field is **omitted entirely** (not set to `[]` or `null`)
when validation passes.

### Invalid (200)

```json
{
  "valid": false,
  "errors": [
    { "path": "/city",  "message": "is required",       "keyword": "required" },
    { "path": "/count", "message": "must be integer",   "keyword": "type" }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `valid` | `boolean` | `false` whenever `errors` is non-empty |
| `errors` | `array<ValidationError>` | One entry per validator-reported failure; never empty when `valid` is `false` |
| `errors[].path` | `string` | JSON Pointer (RFC 6901) to the offending field. Root errors use `""` |
| `errors[].message` | `string` | Human-readable message. Should match the validator's native message verbatim — no translation, no reformatting |
| `errors[].keyword` | `string` (optional) | The failing JSON Schema keyword (`required`, `type`, `minimum`, `pattern`, …). Omit if the validator does not expose it |

### Status Code Rules

- `200` whenever schema validation actually runs — regardless of
  whether the input is valid.
- `400` only when the request body cannot be parsed as JSON.
- `404` only when the tool does not exist.
- `5xx` is reserved for unhandled implementation errors and must not
  be used to indicate "validation failed".

This separates **transport health** (4xx/5xx) from **validation
result** (`valid: true|false` in a 200 body), letting frontends
distinguish "the request reached us and the answer is no" from "the
request never reached the validator".

## Public Type Exports

The response shapes are part of the protocol, not an implementation detail —
a caller in a typed language should be able to name what this endpoint
returns. Each SDK **SHOULD** export both from the package root:

| Spec name | Shape |
|-------------------|-------------------------------------------------|
| `ValidateResult` | `{ valid: bool, errors?: ValidationFailure[] }` — `errors` omitted when valid |
| `ValidationFailure` | `{ path: string, message: string, keyword?: string }` |

Use these names, adjusted only for the language's casing convention. Prefer
`ValidationFailure` over `ValidationError`: these are plain data records, and
in most languages `Error` names an exception type, which this is not.

This is a SHOULD rather than a MUST because a language without a meaningful
type surface (or one whose JSON handling is untyped) gains nothing from it.
Where types exist, exporting them is expected: defining the type internally
and withholding it from the package root is the one outcome to avoid — the
API returns a shape its own users cannot name.

## Cross-Language Mapping

| Language   | Validator dependency |
|------------|----------------------|
| Python     | [`jsonschema`](https://pypi.org/project/jsonschema/) — Draft 2020-12 by default; honors `$schema` if declared |
| TypeScript | [`ajv`](https://www.npmjs.com/package/ajv) + `ajv-formats` |
| Go         | [`santhosh-tekuri/jsonschema/v5`](https://pkg.go.dev/github.com/santhosh-tekuri/jsonschema/v5) |
| Rust       | [`jsonschema`](https://crates.io/crates/jsonschema) |

Each SDK MUST normalize its validator's native error shape to the
`{path, message, keyword}` envelope before returning.

### Error Normalization Examples

**Python — `jsonschema`:**

```python
from jsonschema import Draft202012Validator

errors = []
for err in Draft202012Validator(schema).iter_errors(data):
    errors.append({
        "path": "/" + "/".join(str(p) for p in err.absolute_path),
        "message": err.message,
        "keyword": err.validator,
    })
```

**TypeScript — `ajv`:**

```typescript
const validate = ajv.compile(schema);
if (!validate(data)) {
  errors = (validate.errors ?? []).map(e => ({
    path: e.instancePath || "",   // ajv already emits JSON Pointers
    message: e.message ?? "validation failed",
    keyword: e.keyword,
  }));
}
```

## Security Considerations

- The endpoint MUST NOT call the tool handler under any condition.
  Implementations should structure the route so handler invocation is
  unreachable from this code path (separate function, separate
  module).
- Validation error messages come from a third-party validator — they
  are safe to surface to clients, but implementations should avoid
  appending host-side context (file paths, internal IDs) to the
  message.
- Rate-limiting is the host's responsibility. The endpoint is cheap
  per call but trivially DoSable with deeply nested schemas; hosts
  with public exposure should apply a request limiter at the
  framework layer.

## Test Criteria

| # | Scenario | Expected Result |
|:-:|----------|-----------------|
| 1 | Valid input matching `inputSchema` | `200 {"valid": true}` |
| 2 | Missing required field | `200 {"valid": false, "errors": [...]}` with `keyword: "required"` and `path` pointing to the missing field |
| 3 | Wrong type (e.g. integer field given a string) | `200 {"valid": false, "errors": [...]}` with `keyword: "type"` |
| 4 | Multiple violations in one payload | All violations present in `errors`; order follows the validator's natural traversal |
| 5 | Tool name not found | `404 {"error": "Tool not found: {name}"}` |
| 6 | Body is not JSON | `400 {"valid": false, "errors": [{"path": "", "keyword": "format", ...}]}` |
| 7 | Tool with no `inputSchema` | `200 {"valid": true}` regardless of body |
| 8 | `allow_execute=false` | Endpoint still returns 200 (NOT 403) |
| 9 | `auth_hook` configured to reject | Endpoint still returns 200 (auth hook is NOT invoked) |
| 10 | Handler is never invoked | Verify via spy/mock that `handle_call` was not called for any of the above |
| 11 | Errors omit `errors` key when valid | Response is exactly `{"valid": true}`; no `errors: []` |
| 12 | `ValidateResult` and `ValidationFailure` are importable from the package root | Import both from the package root in a fresh module; assert they resolve. Skip only where the language has no type surface. |
| 13 | Tool whose `inputSchema` cannot be compiled | `200 {"valid": false, "errors": [{"path": "", "keyword": "schema", "message": "Invalid schema: …"}]}` — never 5xx, never `valid: true` |

## References

- [PROTOCOL.md](../PROTOCOL.md) — Full protocol specification
- [F2: Tool Discovery API](tool-discovery-api.md) — Source of `inputSchema`
- [F3: Tool Execution API](tool-execution-api.md) — Sibling endpoint that does invoke the handler
- [F4: Auth Hook](auth-hook.md) — Explains why validation is not auth-gated (SEC-2)
- [F6: Try-It Console](try-it-console.md) — Primary consumer of this endpoint
- [JSON Pointer (RFC 6901)](https://datatracker.ietf.org/doc/html/rfc6901) — `path` format
