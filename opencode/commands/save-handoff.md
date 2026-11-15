---
description: Write the project handoff (where I stopped, next steps, open decisions) to .agent/handoff.md and snapshot tool memory
---

Write a handoff so another harness (or a fresh session) can continue this project with no other context. Never write inside `map/`.

1. Run `~/.claude-tools/bin/agent-handoff init` if `.agent/` is missing.
2. Read `.agent/handoff.md`. Replace ONLY the text between `<!-- handoff:narrative:begin -->` and `<!-- handoff:narrative:end -->` with, from this session's real work (no guesses):
   - **Where I stopped** – what was done, what is half-done, files touched.
   - **Next steps** – ordered, concrete, each with the file or command.
   - **Open decisions** – questions waiting on the user, options considered, and your recommendation.
   Keep it under ~60 lines. No secrets, tokens or pasted credentials.
3. New durable facts or rules learned this session go to `.agent/memory/<slug>.md` (one fact per file, frontmatter `name`/`description`/`metadata`), indexed in `.agent/memory/MEMORY.md`.
4. Run `~/.claude-tools/bin/agent-handoff snapshot` and report what changed.