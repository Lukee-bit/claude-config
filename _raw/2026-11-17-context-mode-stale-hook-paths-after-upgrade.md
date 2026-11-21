---
title: "context-mode v1→v2 upgrade: running session keeps stale hook paths"
category: skills
tags:
  - topic/claude-code
  - plugins
  - hooks
summary: "After context-mode upgraded 1.0.x→2.2.0, a live session threw 'Cannot find module .../hooks/pretooluse.mjs'. Disk was fine; session held old hook config. Restart fixes."
tier: supporting
related: []
extends: null
contradicts: null
superseded_by: null
capture_source: claude-session
project: "claude-config"
base_confidence: 0.75
lifecycle: draft
lifecycle_changed: 2026-11-17
provenance:
  extracted: 0.8
  inferred: 0.2
sources:
  - "claude-config session (2026-11-17)"
---

## Stale context-mode hook paths after plugin upgrade

**Problem:** Every Bash and ExitPlanMode call printed `PreToolUse/PostToolUse hook failed: Cannot find module '~/.claude/plugins/cache/context-mode/context-mode/2.2.0/hooks/pretooluse.mjs'`.

**Root cause:** v2.x replaced per-event scripts (`hooks/pretooluse.mjs`, `posttooluse.mjs`) with one `hook.mjs --agent claude-code`, wired via `hooks/claude-code.json`. The already-running session had loaded the v1 hook config and resolved it against the new 2.2.0 install path. ^[inferred] The mismatch in `installed_plugins.json` (`version: 1.0.169`, `installPath: .../2.2.0`) is expected: `~/.claude/hooks/context-mode-cache-heal.mjs` symlinks `1.0.169` to `2.2.0`.

**Fix:** Restart Claude Code so hooks reload. No reinstall or downgrade needed.

**Confirmed by:** `echo '{"hook_event_name":"PreToolUse",...}' | node hook.mjs --agent claude-code` exits 0 with no error. Restart itself not yet observed. (Feeding `{}` gives `missing required field hook_event_name`, which is a bad probe, not a failure.)

**Notes:** Diagnose by checking `hooks/` contents and `hooks/claude-code.json` in the cache dir before touching `installed_plugins.json`.
