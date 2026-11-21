# .agent - portable agent memory

Committed text only. Everything here is meant to be read by a human or any coding agent.

| Path | What | Written by |
|---|---|---|
| `handoff.md` | where work stopped / next steps / open decisions (+ auto status block) | `/save-handoff`, SessionEnd hook |
| `memory/` | the project's durable agent memory (Claude Code auto-memory is a symlink into here) | agents |
| `graphs/` | graph / diagram sources worth keeping (JSON, Mermaid, SVG) | agents |
| `aliases` | extra names this project is known by in tool memory (one per line) | you |

Not committed (see `.gitignore`): code indexes, caches, `.env`.
Managed by `~/.claude-tools/bin/agent-handoff`. Opt out: `touch .agent-handoff-off`.
