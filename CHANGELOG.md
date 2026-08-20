# Changelog

All notable changes to this project will be documented in this file.

## [0.5.0] - 2026-08-20

### Changed

- **BREAKING (F6/FR-1): the Try-It editor prefill no longer fabricates values.**
  It now emits exactly the keys listed in `inputSchema.required`, using each
  property's declared `default` when it has one and `null` otherwise.
  Optional properties are omitted entirely, generation does not recurse into
  nested objects, and a schema with no `required` prefills `{}`.

  The previous rule invented a type-based value for *every* property
  (`"string"` → `""`, `"number"` → `0`, ...). Two consequences motivated
  the change. First, size: a 257-property schema produced a 259-line prefill
  inside a 120px editor. Second, and more seriously, the prefill emitted a key
  for every property and drew every value from the declared type, so it
  satisfied `required` and the type constraints unconditionally -- making the
  0.4.0 Validate button (F7/FR-8) incapable of failing on a fresh prefill for
  any schema. `null` supplies the key without asserting a value and is
  rejected wherever the schema does not admit it, so Validate now answers a
  real question on its first click.

  SDKs must resync `explorer.html`. TC-1 is rewritten accordingly; new
  criteria TC-17 through TC-20 cover the empty-`required`, omitted-optional,
  orphan-name/no-recursion, and Validate-rejects-the-prefill cases.

### Added

- **F4/FR-1b: the Python/TypeScript exclusion is now conditional.** It was
  written as `MUST NOT add one` — a permanent ban resting on a premise that
  could change. Restated as `SHOULD NOT`, tied explicitly to the hook shape:
  if a binding's hook stops carrying the call, it comes under the clause like
  any other. Re-evaluate against the premise, not the sentence.

- **PROTOCOL.md now marks the Go mappings as forward-looking.** They describe
  intent for a future implementation; no Go SDK is published. Reading those
  rows as evidence of a shipped SDK is exactly how the 0.4.0 changelog came to
  claim Go had been "added to the official implementation list".

- **MANIFEST versions carry a `pending release` marker.** The table stated
  v0.5.0 while the registries still serve v0.4.0. The marker is dropped as part
  of publishing.

- **Security: `project_url` must be scheme-checked, not merely HTML-escaped.**
  HTML escaping does not neutralise `javascript:` — that string contains no
  character an escaper touches. The rule also requires stripping TAB/LF/CR and
  trimming *before* the check, because browsers ignore those while resolving a
  scheme (`java<TAB>script:` resolves to `javascript:`), which would otherwise
  defeat a naive prefix test. Only `http://`, `https://`, `mailto:` and a
  leading `/` are accepted; anything else renders the project name as plain
  text. Added to the Security Checklist.

  Note this was **not** an exploitable vulnerability: `project_url` comes from
  deployment configuration (a CLI flag or a function argument), not from an
  external caller. It is defence in depth against a future refactor wiring that
  value to something less trusted.

- **F7: `ValidateResult` and `ValidationFailure` SHOULD be exported.** The
  `/validate` response shapes are protocol, not implementation detail — a
  caller in a typed language should be able to name what the endpoint returns.
  The naming is normalised (`ValidationFailure`, not `ValidationError`: these
  are data records, and `Error` names an exception type in most languages). New
  criterion TC-12; subsequent criteria renumbered.

- **F5: template rendering is explicitly NOT public surface.**
  `render_explorer_html` / `renderExplorerHtml` and `EXPLORER_HTML_TEMPLATE`
  are implementation details and must not be exported from the package root —
  exporting them makes every template-variable rename a breaking change for a
  capability no known caller uses. Python and Rust already treat them as
  private; TypeScript has deprecated both for removal.

- **F3/PROTOCOL: the optional `request` parameter does not guarantee a readable
  body.** The body has already been consumed and reaches the handler as `args`.
  Some runtimes leave it re-readable (Starlette caches it), others cannot
  (axum's body is a consumed stream). Handlers reading the body from that
  parameter rely on a runtime accident and do not port across languages.

- **F4/FR-1b: identity propagation is now conditioned on hook shape.** FR-1
  ("identity propagation is the caller's responsibility") silently assumed the
  language's hook *carries the call* — true for Python's context manager and
  TypeScript's `(req, next)`, both of which receive the continuation. Rust's
  `AuthHook` is `Fn(Parts) -> Future<Result<(), AuthError>>`: no continuation,
  no return value, so a caller cannot scope an identity around a call it never
  sees, and FR-1 was structurally unachievable there.

  FR-1b states the rule and permits such an implementation to expose an
  additional **authenticator** abstraction, explicitly as a *parity mechanism,
  not a feature* — observable behaviour must stay identical across languages.
  Rust's existing `Authenticator` / `Identity` / `AUTH_IDENTITY` is now
  documented under this clause instead of having no spec basis; Python and
  TypeScript MUST NOT add one. New criteria TC-7 through TC-11 cover the
  authenticator path where it applies.

- **F7: contract for an uncompilable `inputSchema`.** A tool whose schema is not
  itself valid JSON Schema now returns `200 {"valid": false, "errors": [{"path":
  "", "keyword": "schema", "message": "Invalid schema: …"}]}`. This was
  previously unspecified and the three SDKs disagreed: TypeScript and Python
  crashed with a 500, Rust silently answered `valid: true` — reproducing exactly
  the "Validate cannot fail" defect this release removes elsewhere. New
  criterion TC-12; also recorded in `PROTOCOL.md`.

### Fixed

- An explicit `default: null` in a schema is now honoured. The previous guard
  (`props[key]['default'] != null`) discarded it and fell through to a
  fabricated type default.
- **The README Rust quick start called an API that does not exist.**
  `ExplorerOptions` and `axum_handler` appear nowhere in the crate, and the
  snippet used axum 0.7 wildcard syntax (`/*path`) against an axum 0.8
  dependency. Replaced with the real `create_mount` / `UiConfig` entry point and
  compile-checked against the crate. CI publishes this README as the docs site
  index, so it was the first thing a new Rust user copied.
- F5's cross-language mapping table mixed symbol names and return types between
  cells; every cell is now `symbol → return type`, and TypeScript's deliberate
  naming divergence (`createHandler`/`createNodeHandler`) is stated rather than
  left to be inferred.
- F5 claimed "all eight symbols must be importable" above an example listing
  seven.
- MANIFEST SDK versions updated to v0.5.0, and Go is listed explicitly as
  planned — reconciling the README / PROTOCOL / MANIFEST disagreement over
  whether a Go SDK exists.

## [0.4.0] - 2026-04-28

### Added

- **`POST /tools/{name}/validate` endpoint (F7)** — read-only schema validation, no execution. Specified in `PROTOCOL.md` and the new `docs/features/tool-validation-api.md` so all SDKs implement it identically (path, request shape, error normalization, gating rules). Resolves EUI-1 — the SDKs cannot register this route on their own; the protocol must define it first.
- **Validate button in `explorer.html`** — sits next to Execute, calls `/validate`, surfaces `path: message` errors inline. Stays visible even when `allow_execute` is `false`, since validation has no side effects.
- **`project_name` and `project_url` configuration** — allows downstream users to display their project identity in the UI footer.
- **Rust SDK support** — added Rust type definitions to the protocol and officially added `mcp-embedded-ui-rust` to the manifest.
- **Go SDK support** — added Go SDK to the official implementation list.
- **Quick start guides** — introduced language-specific quick start guides in the documentation.

### Changed

- F5 (Framework Integration) and F6 (Try-It Console) dependencies updated to include F7. Try-It Console gains FR-8 (schema validation) plus three new test criteria (TC-14–TC-16).
- The `/call` 403 handler in `explorer.html` now removes only the Execute button and inserts a disabled-message paragraph, preserving the Validate button and the input editor.
- Refined Rust and Go implementation details in `PROTOCOL.md` (e.g., `Arc<dyn Tool>` for Rust, `context.Context` for Go).
- Restructured project documentation for better clarity and discoverability.

## [0.3.1] - 2026-03-22

### Changed
- Rebrand: aipartnerup → aiperceivable

## [0.3.0] - 2026-03-11

### Added

- **Dark mode** — theme toggle button with light/dark switching, `localStorage` persistence, and system preference auto-detection. FOUC prevention via inline `<head>` script.

### Changed

- **`allow_execute` default changed to `false`** — secure by default; callers must explicitly opt in with `allow_execute=True` to enable tool execution.
- All hardcoded CSS colors replaced with CSS custom properties for theme support.
- Theme toggle script isolated in separate `<script>` block from main app logic.
- PROTOCOL.md, feature specs, and ROADMAP.md updated to reflect new defaults.

## [0.2.0] - 2026-03-10

### Removed

- **`/meta` endpoint** — replaced by `{{ALLOW_EXECUTE}}` HTML template variable. Config is now baked into the HTML at render time, eliminating a runtime HTTP round-trip.

### Added

- **`{{ALLOW_EXECUTE}}` template variable** — defaults to `true`; set to `false` to disable tool execution.
- **`{{PROJECT_LINK}}` template variable** — optional footer link for downstream projects (`project_name` + `project_url`).
- **ToolCallHandler 3-param support** — handler can optionally accept a third parameter (HTTP request) for accessing headers, identity, etc. Auto-detected via signature inspection.
- **Tool search/filter** — search input in the HTML frontend to filter tools by name or description.
- **Multi-content-type rendering** — frontend now renders `ImageContent` (base64 images) alongside `TextContent`.
- **Execution time display** — shows elapsed time after tool execution.
- **cURL escaping fix** — proper escaping of single quotes in generated cURL commands.
- **"Powered by mcp-embedded-ui" footer** — subtle branding link for discoverability.
- **ROADMAP.md** — documents deferred features (tool grouping, dark mode, request history).
- **TypeScript quick start** and package links in README.
- **TypeScript** added to MANIFEST.md cross-language implementations table.

### Changed

- Protocol endpoint count reduced from 5 to 4.
- `allow_execute` default aligned to `true` across PROTOCOL.md, feature specs, and both implementations.
- F5 cross-language mapping updated to reflect TypeScript's actual API (`createHandler`, `createNodeHandler`).
- README updated with language implementation table including PyPI/npm install links.

## [0.1.0] - 2025-12-01

### Added

- Initial protocol specification and shared HTML template.
- Feature specs: HTML Frontend, Tool Discovery API, Tool Execution API, Auth Hook, Framework Integration, Try-It Console.
- MkDocs documentation site configuration.
