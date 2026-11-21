---
name: never-run-obsidian-wiki-setup
description: obsidian-wiki setup reinstalls all 40 skills into ~/.claude and undoes the mcptoon fold
metadata:
  type: feedback
---

Never run `obsidian-wiki setup`. The CLI nags "37 skills missing, run setup" on every command; that warning is intentional (only wiki-capture, wiki-query, llm-wiki are native).

**Why:** the other skills are served from the mcptoon catalog to save about 2.4k tokens per session.
**How to apply:** ignore the warning; hooks already discard stderr.
