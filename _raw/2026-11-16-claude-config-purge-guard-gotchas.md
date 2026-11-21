---
title: "Purging tools from a guarded Claude Code stack: guard, classifier and mcptoon gotchas"
category: skills
tags:
  - topic/claude-code
  - topic/mcptoon
  - config-management
summary: "guard-pack and the auto classifier block config edits and skill deletions; jCodeMunch via mcptoon needs different call args than its stock CLAUDE.md block says."
tier: supporting
related: []
extends: null
contradicts: null
superseded_by: null
capture_source: claude-session
project: "claude-config"
base_confidence: 0.75
lifecycle: draft
lifecycle_changed: 2026-11-16
provenance:
  extracted: 0.85
  inferred: 0.15
sources:
  - "claude-config session (2026-11-16)"
---

## guard-pack blocks config edits and the `claude plugin` CLI

**Behavior:** With `guard-pack` enabled, Bash calls that copy, move or edit `~/.claude/settings.json` and `~/.claude.json`, or run `claude plugin uninstall` / `claude plugin marketplace remove`, fail in a PreToolUse hook. The message suggests `CONFIG_GUARD_ALLOW=true`.

**Explanation:** The hook runs before the command, so `export CONFIG_GUARD_ALLOW=true` inside the command does nothing. The variable must already be in Claude Code's own environment.

**Workaround / Pattern:** Start the session with the variable set, or disable guard-pack for one session. Do not copy or edit the files through another interpreter to get around the guard. Plan these steps as a batch for after the guard is relaxed.

**Confirmed by:** three separate Bash calls blocked with the same message.

## Auto-mode classifier denies recursive deletes under `~/.claude/skills`

**Behavior:** A batch of `rm -rf` calls was denied, and so was a single `rm -rf` of four skill folders. A second guard rejects `rm -rf $d/...` when `$d` is an unquoted variable.

**Workaround / Pattern:** Use explicit paths (or `${var:?}`) and small batches. Deletes outside `~/.claude` (`~/.claude-tools`, project `.agent/` folders) went through. If a folder deletion is still denied, hand the exact command to the user.

**Confirmed by:** same command denied twice; narrower deletes elsewhere succeeded.

## jCodeMunch behind mcptoon

**Behavior:** jCodeMunch's stock CLAUDE.md block assumes direct `order` / `route` / `menu` tools. Behind mcptoon they are `mcptoon_call` with server `jcodemunch`.

**Explanation:** `route` takes `task` (not `query`). `index_folder` is a state-changing action and needs `allow_state_change: true`. `resolve_repo` resolves relative paths against the server's working directory, so pass an absolute path.

**Confirmed by:** `mcptoon inspect jcodemunch route|order|menu` and a live `resolve_repo` call.

## Smaller facts

- `mcptoon config set footer off` stops the per-turn savings line. `mcptoon status` prints server and tool counts (19 servers, 418 tools after the purge).
- Lightpanda page state persists across separate `mcptoon_call`s (`goto`, then `getUrl` and `markdown`), so the direct Lightpanda MCP entry is redundant for Claude Code. It is still needed by `opencode/render.py` and the Claude Desktop config in this repo.
- `caveman-blocks` is a script-reuse system (`.blocks/`), not a Bash output compressor. Do not count it as redundant with RTK or context-mode.
- `rea uninstall --purge-data` and `bla uninstall` remove their own client registrations; both reported nothing to remove here. Then `npm uninstall -g rea-agents bla-agents`.
- `brew uses --installed openjdk@21` showed no dependents once Agent-Fusion was gone, so it could be uninstalled.
- A `.agent/fusion/` data folder reached 2.1 GB in one project; check per-project data dirs when removing an indexer.

**Notes:** Plugin and settings removals from this session were still pending when this was captured; check `claude plugin list` before assuming the purge is complete.
