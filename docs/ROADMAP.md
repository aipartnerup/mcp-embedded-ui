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

## Optional Field Picker

FR-1 prefills only the keys listed in `required`, which keeps the editor
usable on large schemas but leaves optional properties undiscoverable from
the editor itself -- a user has to read the schema panel above and type the
key by hand.

**Plan**: an "Add optional field" control below the editor listing the
properties absent from `required`, each inserting its key (with its declared
`default`, or `null`) into the editor on click.

**Deferred because**: this is a new functional requirement with its own test
criteria and another full `explorer.html` resync across every SDK. It was
kept out of the 0.5.0 prefill fix so that a defect correction and a feature
addition ship separately.

## Request History

Save recent tool calls to `localStorage` and display them in the tool
detail panel for quick replay.

**Plan**:
- Store last N calls per tool as `{ args, timestamp }` in localStorage
- Show a "Recent calls" section below the input editor
- Click to re-fill the input editor with previous arguments
