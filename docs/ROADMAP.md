# MCP Embedded UI — Roadmap

Planned improvements not yet implemented.

## Tool Grouping (Namespace)

MCP tools often use `/` or `.` delimiters for namespacing (e.g.
`image/resize`, `file/read`). The current flat list does not scale well
for servers with many namespaced tools.

**Plan**: Group tools by the first segment of their name, with collapsible
group headers showing the count of tools in each group.

```
▶ image (3 tools)
  ├ image/resize
  ├ image/crop
  └ image/compress
▶ file (2 tools)
  ├ file/read
  └ file/write
```

**Blocked on**: Confirming the naming convention (`/` vs `.` vs `_`) across
real-world MCP servers before committing to a grouping strategy.

## Request History

Save recent tool calls to `localStorage` and display them in the tool
detail panel for quick replay.

**Plan**:
- Store last N calls per tool as `{ args, timestamp }` in localStorage
- Show a "Recent calls" section below the input editor
- Click to re-fill the input editor with previous arguments
