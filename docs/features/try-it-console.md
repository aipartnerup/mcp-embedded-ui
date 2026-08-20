# F6: Try-It Console

**Status:** P1 | **Complexity:** M | **Dependencies:** F1, F3, F7

## Overview

An interactive console embedded in the tool detail panel that lets users
compose JSON input, execute a tool, and inspect the result -- all from the
browser. The console generates a skeleton input from the tool's `inputSchema`,
sends the request through the execution API (F3), and renders the response
in two complementary views (parsed result and raw MCP envelope). A cURL
command is generated for every execution so users can reproduce calls
outside the UI.

Execution can be disabled server-side. The frontend reads the
`{{ALLOW_EXECUTE}}` template variable (injected at render time) and
gracefully replaces the console with a disabled message.

## Scope

- JSON input editor pre-filled with a skeleton of the schema's required keys.
- Execute button with loading state and disabled-execution detection.
- Result display with two tabs: Result and Raw MCP.
- cURL command generation with copy-to-clipboard.
- Execution-disabled detection via `{{ALLOW_EXECUTE}}` template variable.
- 401/403 error handling in the UI.

## Functional Requirements

### FR-1: Input Editor

The Try-It console displays a `<textarea>` pre-filled with a JSON object
that acts as a **skeleton** for a valid call. It contains exactly the keys
listed in `inputSchema.required` -- no more:

- For each name in `required`:
  1. If `properties[name]` declares an explicit `default`, use it --
     including falsy values such as `0`, `false`, `""`, and `null`.
  2. Otherwise emit `null`.
- Key order is **unspecified**. Implementations SHOULD emit keys in the
  order `required` lists them, but MUST NOT be tested on it: JavaScript
  objects hoist integer-like keys (`"2"` sorts before `"zebra"`) and Go
  maps serialise in lexicographic order, so no cross-language guarantee
  is possible. Tests MUST compare parsed objects, not JSON strings.
- Names in `required` with no entry in `properties` still emit `null`.
- Properties **not** listed in `required` are not emitted, even when they
  declare a `default`. The full schema is already displayed directly above
  the editor (F1), and omitting them keeps the prefill bounded by
  `required.length` for any schema.
- Generation does **not** recurse into nested object properties.
- A schema with no `required`, or an empty `required`, prefills `{}`.
- The generated JSON is pretty-printed (2-space indent) in the textarea.
- On every execution attempt, the textarea content is parsed with
  `JSON.parse()`. If parsing fails, an inline error message is displayed
  below the textarea and the request is **not** sent.

**Rationale.** The prefill supplies structure, never values. A type-based
placeholder (`""`, `0`, `false`) is not "unset" -- it is a specific and
usually wrong value that satisfies both `required` and the declared type,
which makes the FR-8 Validate button incapable of failing on a fresh
prefill for any schema. `null` supplies the key without asserting a value,
and the validator rejects it wherever the schema does not admit it. Where
the schema *does* admit null, reporting the input as valid is correct.

### FR-2: Execute Button

- A button labelled "Execute" triggers the tool call.
- While a request is in flight:
  - The button is **disabled** (`disabled` attribute set).
  - The button text changes to "Executing...".
- After the response (success or error) is received:
  - The button is **re-enabled**.
  - The button text reverts to "Execute".
- When execution is disabled (see FR-3), the button is **hidden** or
  replaced with a message indicating that execution is not available.

### FR-3: Execution Disabled Detection

The `{{ALLOW_EXECUTE}}` template variable is replaced with a JS literal
(`true` or `false`) at render time, defaulting to `false`. The frontend
reads this value synchronously on page load.

- If `executeEnabled === false`, the Try-It console section is replaced
  with a disabled message (e.g.,
  "Tool execution is disabled. Launch with --allow-execute to enable.").
- As a fallback, if a `POST /tools/{name}/call` request returns HTTP
  **403**, the Try-It section is also replaced with the disabled message.
- A 403 from an execution attempt is treated identically -- the console
  is permanently replaced for the remainder of the page session.

### FR-4: Result Display

After a successful execution, the response is rendered in a two-tab view:

#### "Result" Tab (default)

- Extracts the text content from the MCP response (typically
  `response.content[0].text`).
- Attempts `JSON.parse()` on the extracted text:
  - If parsing succeeds, displays the pretty-printed JSON.
  - If parsing fails, displays the raw text as-is.
- This tab is selected by default after each execution.

#### "Raw MCP" Tab

- Displays the **full** MCP response JSON as returned by the server,
  including `content`, `isError`, and `_meta` fields.
- Pretty-printed with 2-space indent.
- No extraction or transformation is applied.

#### Tab Behavior

- Tabs are switched via click.
- The active tab is visually highlighted (e.g., bold text or underline).
- Tab state resets to "Result" on each new execution.

### FR-5: Error Display

- If the MCP response has `isError: true`, the result text is displayed
  with **red styling** (e.g., red text color or red-bordered container)
  in the Result tab.
- HTTP **401** responses show an "Unauthorized" message directing the user
  to enter a token in the auth bar (e.g., "Unauthorized -- enter a
  Bearer token in the auth bar above.").
- HTTP **403** responses replace the entire Try-It section with the
  execution-disabled message (same behavior as FR-3 fallback).

### FR-6: cURL Generation

After each execution, a cURL command is generated and displayed below the
result area:

- The command includes:
  - `curl -X POST` method.
  - The full URL of the executed endpoint.
  - `-H "Content-Type: application/json"` header.
  - `-H "Authorization: Bearer <token>"` header (only when a token is
    set in the auth bar).
  - `-d '<request body>'` with the JSON body as sent.
- A "Copy" button copies the command to the clipboard via
  `navigator.clipboard.writeText()`.
- On successful copy, the button text changes to "Copied!" and reverts
  after **1.5 seconds**.

### FR-8: Schema Validation

A "Validate" button sits next to "Execute" in the console. It calls
`POST /tools/{name}/validate` (F7) with the current editor body and
renders the result inline:

- **Valid** -- a single green line ("Input is valid.") replaces any
  prior validation output. The result area is otherwise untouched.
- **Invalid** -- a red panel lists each error as
  `<path>: <message>` (path empty for root errors). The panel also
  includes the raw JSON error body in a `<details>` block for the
  curious.
- **Network / 4xx errors** -- surfaced as a generic red message
  identical in styling to the F3 error path. A 404 means the tool
  vanished between page load and click; a 400 means the editor body
  is not even valid JSON, and the local `JSON.parse()` error message
  takes precedence over the server reply.

The Validate button is **always visible**, even when
`{{ALLOW_EXECUTE}}` is `false`. This is intentional: validation has
no execution side-effects and is the most useful UI affordance left
when execution is disabled.

A 401 response is **not expected** from `/validate` (the endpoint is
not auth-gated by spec). If one is observed -- e.g. because the host
applied framework-level middleware -- it is rendered identically to
the FR-5 "Unauthorized" message.

### FR-7: Auth Integration

- All `fetch()` requests from the Try-It console include authorization
  headers obtained from `getAuthHeaders()`.
- `getAuthHeaders()` reads the auth bar input value:
  - If empty, no `Authorization` header is added.
  - If the value does not start with `Bearer `, the prefix is
    auto-prepended.
  - If the value already starts with `Bearer `, it is used as-is.
- The same logic applies when generating the cURL command (FR-6): the
  `Authorization` header is included only when a token is set.

## Security

### SEC-1: Input Sanitization

All server-returned text displayed in the result area is escaped via
`esc()` (defined in F1) before innerHTML insertion. This prevents
a malicious tool response from injecting scripts into the page.

### SEC-2: Auth Token Handling

The auth token is never persisted to `localStorage` or cookies. It exists
only in the text input for the duration of the page session. Closing or
refreshing the page clears the token.

## Cross-Language Notes

- This feature is **purely frontend** (JavaScript) -- the implementation
  is identical across all language backends.
- The backend only needs to serve the HTML (F1) and implement the
  following endpoints:
  - `GET /tools` -- tool list.
  - `GET /tools/{name}` -- tool detail with `inputSchema`.
  - `POST /tools/{name}/validate` -- schema validation (F7).
  - `POST /tools/{name}/call` -- tool execution.
- The `{{ALLOW_EXECUTE}}` template variable is injected server-side
  (same mechanism as `{{TITLE}}`), eliminating the need for a `/meta`
  endpoint.
- No language-specific code is required for this feature.

## Test Criteria

| # | Assertion | Method |
|---|-----------|--------|
| TC-1 | The prefill contains exactly the keys listed in `required`; each value is the property's declared `default` when present -- including falsy ones such as `0`, `false`, `""` and `null` -- and `null` otherwise. | Unit test: provide schema, assert generated JSON matches the expected skeleton. |
| TC-2 | Execute button is disabled and shows "Executing..." during an in-flight request. | UI test: trigger execution, assert button disabled state and text before response arrives. |
| TC-3 | Execute button re-enables after response or error. | UI test: complete request, assert button is enabled with "Execute" text. |
| TC-4 | Result tab shows parsed/pretty-printed content extracted from MCP response. | UI test: execute tool returning JSON text, assert formatted output in Result tab. |
| TC-5 | Raw MCP tab shows the full MCP response envelope as-is. | UI test: execute tool, switch to Raw MCP tab, assert full response JSON displayed. |
| TC-6 | `isError: true` responses render with red error styling. | UI test: execute tool that returns error, assert red styling on result text. |
| TC-7 | 401 response shows "Unauthorized" message referencing the auth bar. | UI test: trigger 401, assert message text and no result display. |
| TC-8 | 403 response replaces Try-It section with disabled message. | UI test: trigger 403, assert console is replaced with disabled text. |
| TC-9 | cURL command includes `Authorization: Bearer <token>` header when a token is set. | UI test: set token, execute, assert cURL output contains auth header. |
| TC-10 | cURL command omits auth header when no token is set. | UI test: clear token, execute, assert cURL output has no auth header. |
| TC-11 | Copy button shows "Copied!" feedback for 1.5 seconds. | UI test: click copy, assert button text change and revert timing. |
| TC-12 | `{{ALLOW_EXECUTE}}` set to `false` replaces Try-It section with disabled message on page load. | UI test: render HTML with `{{ALLOW_EXECUTE}}` = `false`, assert console is not rendered. |
| TC-13 | Invalid JSON in textarea shows inline error and does not send request. | UI test: enter malformed JSON, click Execute, assert error message and no network request. |
| TC-14 | Validate button is visible even when `{{ALLOW_EXECUTE}}` is `false`. | UI test: render with execute disabled, assert Validate button is present and Execute is hidden. |
| TC-15 | Valid input shows the green "Input is valid." line. | UI test: provide schema-conforming JSON, click Validate, assert green confirmation. |
| TC-16 | Invalid input lists `<path>: <message>` per error. | UI test: omit a required field, click Validate, assert red panel lists `/<field>: is required`. |
| TC-17 | A schema with no `required`, or an empty `required`, prefills `{}`. | Unit test: provide schema without `required`, assert generated JSON is an empty object. |
| TC-18 | Optional properties never appear in the prefill, even when they declare a `default`. | Unit test: provide schema with a defaulted optional property, assert the key is absent. |
| TC-19 | A name in `required` with no matching entry in `properties` prefills as `null`; nested object properties are not recursed into. | Unit test: provide schema with an orphan required name and a nested object, assert both yield `null`. |
| TC-20 | Clicking Validate on an untouched prefill reports the input as invalid whenever a required property has no `default`. | Integration test: schema with required `type: "string"` and no `default`, click Validate without editing, assert `valid: false` and the error path is rendered. |
