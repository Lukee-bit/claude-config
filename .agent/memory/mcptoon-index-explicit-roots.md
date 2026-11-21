---
name: mcptoon-index-explicit-roots
description: A bare 'mcptoon skills index' rebuilds from the agent skill folders (347 skills, duplicates)
metadata:
  type: feedback
---

Always index with explicit roots: `mcptoon skills index ~/.local/share/harness-master-controller/skills ~/.claude-tools/skill-catalog`.

**Why:** the default roots are the agent views (~/.claude/skills, ~/.agents/skills, ~/.cursor/skills) and bloat the catalog with copies.
**How to apply:** after adding catalog links, re-run with both roots, then `mcptoon skills stats` (expect 0 duplicates, 0 warnings).
