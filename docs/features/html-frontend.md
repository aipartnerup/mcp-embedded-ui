# F1: HTML Frontend

**Status:** P0 | **Complexity:** M | **Dependencies:** None

## Overview

A single, self-contained HTML page (`docs/explorer.html`) that serves as the
browser-based UI for every MCP server using this library. The file contains
all markup, styles, and scripts inline -- no external dependencies, no build
step. Language-specific backends serve it as-is after substituting one
template variable.

## Scope

- Self-contained HTML/CSS/JS in a single file.
- Tool list rendering with expand/collapse interaction.
- JSON Schema display for each tool's `inputSchema`.
- Annotation badge rendering: `readOnly`, `destructive`, `idempotent`,
  `closedWorld` (displayed when `openWorldHint === false`).
- Auth token input field with live status indicator.
- `esc()` utility function for XSS prevention.
- `{{TITLE}}` template variable replaced server-side before serving.
- Uses `window.location.pathname` as base URL for all relative API calls.

## Functional Requirements

### FR-1: Page Structure

The page renders four top-level elements in order:

1. **Title heading** (`<h1>`) -- displays the server name.
2. **Auth bar** -- Bearer token input with status indicator.
3. **Loading indicator** -- shown while the tool list is being fetched.
4. **Tool list** (`<ul>`) -- populated from `GET {base}/tools`.

### FR-2: Tool List

Each tool is rendered as a list item showing:

- **Name** -- the tool's `name` field, displayed with `font-weight: 600`.
- **Description** -- the tool's `description` field, muted color.
- **Annotation badges** -- inline hints derived from `tool.annotations`:
  - `readOnlyHint` -- green badge labelled "readOnly".
  - `destructiveHint` -- red badge labelled "destructive".
  - `idempotentHint` -- blue badge labelled "idempotent".
  - `openWorldHint === false` -- grey badge labelled "closedWorld".

All text values are escaped via `esc()` before insertion into the DOM.

### FR-3: Expand / Collapse

- Clicking a tool header toggles the detail panel for that tool.
- Only one tool can be expanded at a time; expanding a tool collapses the
  previously expanded one.
- The toggle arrow (right-pointing triangle) rotates 90 degrees when expanded.
- Detail content is lazy-loaded on first expand via
  `GET {base}/tools/{name}`.

### FR-4: Detail Panel

When expanded, a tool's detail panel displays:

- **Input Schema** -- the tool's `inputSchema` rendered as formatted JSON
  inside a `<pre>` block (dark theme).
- **Annotations** -- if `tool.annotations` is present, rendered as a second
  formatted JSON block.

### FR-5: Auth Bar

- A text input labelled "Authorization" with placeholder
  `Bearer eyJhbGci...`.
- A status badge that updates on every `input` event:
  - **Token set** -- green badge, when the input is non-empty.
  - **No token** -- red badge, when the input is empty.
- The entered token is sent as an `Authorization` header on all API
  requests. If the value does not already start with `Bearer `, the prefix
  is prepended automatically.

### FR-6: Base URL

The base URL for all API calls is derived at page load:

```js
var base = window.location.pathname.replace(/\/$/, '');
```

This strips a trailing slash so that relative paths like
`base + '/tools'` resolve correctly regardless of whether the page URL
ends with `/`.

### FR-7: Template Variable

The `{{TITLE}}` placeholder appears in two locations:

1. `<title>{{TITLE}}</title>` -- the browser tab title.
2. `<h1>{{TITLE}}</h1>` -- the visible page heading.

The backend replaces both occurrences with the configured server title
**after HTML-escaping** the value (see Security section).

## Security

### SEC-1: `esc()` Function

All user-provided or server-returned text is escaped before innerHTML
injection using the `esc()` function:

```js
function esc(s) {
  var d = document.createElement('div');
  d.appendChild(document.createTextNode(s));
  return d.innerHTML;
}
```

This leverages the browser's own `textContent` encoding to neutralize
`<`, `>`, `&`, `"`, and `'` characters in any string that will be
interpolated into HTML.

### SEC-2: Template Injection

The `{{TITLE}}` value is replaced server-side via simple string
substitution. Because this happens before the HTML is parsed by the
browser, the replacement value **must be HTML-escaped by the backend**
before injection. Failing to escape allows an attacker-controlled title
(e.g., `<script>alert(1)</script>`) to execute arbitrary JavaScript.

Each language implementation is responsible for performing this escaping
(e.g., `html.escape()` in Python, template-literal escaping in
TypeScript).

## Cross-Language Notes

- The HTML file (`docs/explorer.html`) is **identical** across all language
  implementations. It is maintained in this repository and copied or
  embedded into each language package at build/release time.
- A language-specific backend only needs to:
  1. Read the HTML template (or use an embedded copy).
  2. Replace `{{TITLE}}` with the HTML-escaped server title.
  3. Serve the resulting string as `text/html` at `GET /`.
- No language-specific logic exists in the frontend. All behavioral
  differences (auth enforcement, execution gating) are handled by the
  backend API responses the frontend consumes.

## Test Criteria

| # | Assertion | Method |
|---|-----------|--------|
| TC-1 | `GET /` returns HTTP 200 with `Content-Type: text/html`. | Integration test |
| TC-2 | Response body contains the configured title text. | String match on response body |
| TC-3 | A title containing `<script>` is rendered as `&lt;script&gt;` in the served HTML. | Set title to `<script>alert(1)</script>`, verify escaped output |
| TC-4 | The `{{TITLE}}` placeholder does not appear in the served HTML. | Negative string match |
