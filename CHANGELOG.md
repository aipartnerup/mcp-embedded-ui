# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-03-09

### Added

- Protocol specification (`docs/PROTOCOL.md`) — endpoints, data shapes, security checklist
- Self-contained HTML template (`docs/explorer.html`) with `{{TITLE}}` placeholder
- Feature specs for cross-language implementation:
  - HTML Frontend — self-contained page with XSS-safe escaping
  - Tool Discovery API — `GET /tools`, `GET /tools/{name}`
  - Tool Execution API — `POST /tools/{name}/call` with MCP CallToolResult format
  - Auth Hook — sync/async context manager pattern for request authorization
  - Framework Integration — 3-tier API (routes / app / mount)
  - Try-It Console — in-browser tool execution with cURL export
- Feature manifest with dependency graph and recommended implementation order
- Cross-language abstraction mapping tables (Python, TypeScript, Go, Rust)
- Security checklist (XSS, auth leak, execution guard, input validation)
