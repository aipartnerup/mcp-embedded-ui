# Changelog

All notable changes to this project will be documented in this file.

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
