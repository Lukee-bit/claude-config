---
title: Syncing live Claude config to the claude-config repo
tags: [claude-code, mcptoon, config-sync]
summary: Repo-to-live sync is a bin/ copy plus a protected settings hook the user must add; guard-pack blocks settings writes.
project: claude-config
base_confidence: 0.75
provenance:
  extracted: 0.8
  inferred: 0.2
lifecycle_changed: 2026-11-15
sources:
  - "claude-config session (2026-11-15)"
---

## Finding
- Live scripts in `~/.claude-tools/bin` drift from `bin/` in the repo; compare with `cmp`, then `cp` and `chmod +x`. `_platform.sh` must exist live because the newer scripts source it.
- guard-pack blocks any Bash command whose text mentions the Claude settings file (even a read-only diff). Keep settings paths out of commands and have the user add settings hooks, e.g. the startup `config-sync check` hook.
- `config-sync check` compares `~/.claude-tools/.config-rev` with repo HEAD. After a manual sync, write `git rev-parse HEAD` into it, or it keeps reporting an update.
- `mcptoon health`: `*-comet` servers die with "Comet is running without a debug port" until Comet is quit and relaunched via `comet-cdp`. `agent-fusion` can time out at 20s (cause not investigated).
