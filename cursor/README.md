# Cursor / Cursor Code port

One source of truth: the base install (`install.sh` / `install.ps1`) still owns tools, skills, plugins, `~/.mcptoon/config.json` and `~/.claude-tools/bin/`. This surface only wires **Cursor IDE** and **Cursor Code CLI** to that stack. Remove a server from `mcptoon/` (or the base install) and it is gone for Cursor too — nothing in `cursor/` lists MCP servers of its own except the gateway entry.

| Piece | How it stays single-source |
|---|---|
| MCP tools (21 servers / compressed gateway) | `~/.cursor/mcp.json` → `mcptoon serve` (same gateway Claude uses). Upstream list lives in `~/.mcptoon/config.json` from the base install. |
| Skills | None copied. Cursor natively discovers `~/.claude/skills` (base install) and project `.cursor/skills` / `.agents/skills`. |
| Claude plugins with a Cursor surface | Already in the Claude plugin cache from the base install (`.cursor-plugin` / `hooks-cursor.json`). |
| GSD Cursor hooks | `npx @opengsd/gsd-core --cursor --global` (owned by GSD). `cursor/render.py` also registers the staged `gsd-cursor-*.js` scripts into `~/.cursor/hooks.json` if present, without removing other user hooks (e.g. Orca). |
| Windows `.sh` Open-with | Cursor Code also loads `~/.claude/settings.json` hooks. Claude auto-prepends `bash` for `.sh`; Cursor does not. `cursor/wrap-claude-sh-hooks.py` (Windows only) adds `~/.claude/hooks/*.cmd` launchers and retargets those commands — original `.sh` scripts stay for Claude. |

## Install (after the base installer)

```bash
./install-cursor.sh --dry-run && ./install-cursor.sh            # macOS
pwsh ./install-cursor.ps1 -DryRun; pwsh ./install-cursor.ps1   # Windows 11
```

Needs the base install first (`~/.claude-tools/config-repo`). Never runs the OpenCode installer. Restarts are required: **fully quit Cursor IDE and Cursor Code CLI**, then reopen.

## What lands where

| Path | Source |
|---|---|
| `~/.cursor/mcp.json` | `cursor/mcp.json` via `cursor/render.py` (backed up as `*.bak-YYYYMMDD`) |
| `~/.cursor/hooks.json` | merge: existing entries kept; GSD `gsd-cursor-*.js` entries added when those scripts exist under `~/.claude/hooks/` |
| `~/.cursor/rules/claude-config.mdc` | `cursor/rules/claude-config.mdc` (always-on user rule; stack pointers) |
| `~/.claude/hooks/*.cmd` (Windows only) | `cursor/wrap-claude-sh-hooks.py` — Cursor interop launchers for Claude `.sh` hooks |

## macOS vs Windows

| | macOS | Windows 11 |
|---|---|---|
| MCP | `mcptoon` on PATH | same (`mcptoon.exe` / shim) |
| Skills | `~/.claude/skills` | same |
| Claude `.sh` hooks Cursor also runs | work (shell runs bash scripts) | need `.cmd` wrappers (installer does this) |
| Git Bash | not required for Cursor hooks | required for many mcptoon upstream stdio servers (base install) |
| `Git\bin` on User PATH | n/a | installer ensures it so `bash` resolves for any remaining scripts |

## Verify

1. `mcptoon doctor` — 0 issues; `mcptoon list` shows the upstream servers.
2. Cursor Settings → MCP (or Cursor Code tools): **mcptoon** connected. Upstream tools via `mcptoon_manifest` / `mcptoon_call` (compact exposure by default).
3. Start a Cursor Code session: no “Select an app to open this .sh file” dialogs on Windows.
4. Skills from the base install appear in the agent skill list (Cursor reads `~/.claude/skills`).

## Not ported (on purpose)

- Caveman as a **top-level** Cursor MCP (Claude keeps `caveman` + `lightpanda` beside mcptoon in `~/.claude.json`). Lightpanda is already one of the servers behind mcptoon. Caveman CLI/proxy remain Claude-side.
- Rewriting Orca / other third-party `~/.cursor/hooks.json` entries — render merges, never wipes.
- Duplicating skills into `~/.cursor/skills` (avoids Mac/Windows cloud-sync path conflicts).
