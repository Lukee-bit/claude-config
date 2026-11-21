---
title: Pre-approving MCP servers in Claude Code
tags: [claude-code, permissions, mcp]
summary: Server-name allow rules in permissions.allow cover all tools of that MCP server; sessions started earlier may still prompt.
project: claude-config
base_confidence: 0.6
provenance:
  extracted: 0.7
  inferred: 0.3
lifecycle_changed: 2026-11-16
sources:
  - "claude-config session (2026-11-16)"
---

# Finding
- `permissions.allow` entries `mcp__mcptoon`, `mcp__caveman`, `mcp__plugin_context-mode_context-mode` (no tool suffix) cover every tool of that server. Gateway tools behind mcptoon ride on `mcp__mcptoon`.
- Prompts persisted after the rules were added. Unverified cause: session started before the change, a hook forcing ask, or the desktop permission-mode picker. Check a fresh session first.
- guard-pack blocks Bash edits to settings files; permission changes go in a user-run script (`bin/allow-tools.sh`).
- `export.py` pulls personal `effortLevel` into `claude/settings.json`; drop it before committing.
