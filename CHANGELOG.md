# Changelog

Newest first. `config-sync` shows these lines to Claude when the repo moves ahead of what is installed; `/config-update` applies them.
Each entry says what changed and whether anything needs doing beyond the re-run installer (`config-sync apply` does the re-run).

## 2026-11-17 comet branch
- Main plus the Comet fallback: `playwright-fallback` / `chrome-devtools-fallback` attach to the real Comet profile (port 9223) via `bin/comet-*`. Merge main into this branch after each main change: `git merge origin/main`.
## 2026-11-17 comet branch stays in sync automatically
- `.github/workflows/sync-comet.yml` merges every push to main into `comet` (the only deviation is the fallback browser). A merge conflict fails the run and leaves `comet` untouched; resolve it by hand. Nothing to do on machines.

## 2026-11-17 Standard Chrome fallback on main; Comet moves to the `comet` branch
- The fallback browser (when Lightpanda cannot do the job) is now Chrome through `playwright-fallback` and `chrome-devtools-fallback`: stock Playwright MCP and Chrome DevTools MCP, each launching its own Chrome with its own profile. Needs only Chrome installed. The `bin/comet-*` helpers and the `*-comet` servers are gone from main.
- Comet users: `git checkout comet` (main plus a fallback that attaches to your real Comet profile on port 9223). The server names are the same on both branches, so `CLAUDE.md` does not differ.
- Action: `mcptoon remove playwright-comet chrome-devtools-comet`, re-run `./install.sh`, and update `~/.claude/CLAUDE.md` browser policy from `claude/CLAUDE.md`. Restart Claude Code.

## 2026-11-17 OpenPencil replaced by FigCraft
- Removed the `open-pencil` gateway server, its skill and the `@open-pencil/*` npm packages. Design work goes through `figcraft` (CLI + MCP, updated to 0.18.1) and the existing `fig-mcp` / `fig-parser` for Figma `.fig` files. `install.sh` now fetches `figcraft-cli` into `~/.artcraft/bin`.
- Action: `mcptoon remove open-pencil`; `npm uninstall -g @open-pencil/cli @open-pencil/mcp`; delete `~/.claude/skills/open-pencil`; drop `open-pencil` from `skillOverrides` in your Claude settings.

## 2026-11-16 Final fold: lightpanda, task skills, obsidian-skills; tool roles
- Lightpanda is reached only through mcptoon (the direct MCP entry is gone from `~/.claude.json`, `claude/mcpServers.json` and the OpenCode render). The 36 task-specific user skills in `tools/folded-skills.txt` are `name-only` in `skillOverrides` and indexed from `~/.claude-tools/skill-catalog/user`. The `obsidian-skills` plugin is disabled (its skills are in the catalog).
- `CLAUDE.md` now carries a tool-role map and the real `mcptoon_call {name, arguments}` form; README has a tool-roles table.
- Action: `./install.sh`, then disable `obsidian@obsidian-skills`, remove `mcpServers.lightpanda` from `~/.claude.json` and copy the `skillOverrides` block from `claude/settings.json` if your settings are not managed by the installer; restart Claude Code. Never run `obsidian-wiki setup` or a bare `mcptoon skills index`.

## 2026-11-16 Skills folded into the mcptoon catalog, project memory switched on
- GSD runs in the `core` profile (8 skills); the full set is snapshotted to `~/.claude-tools/skill-catalog/gsd`. The Candor and obsidian-wiki plugins are disabled (`install.sh` no longer installs them); their skills are indexed from `~/.claude-tools/skill-catalog/{candor,obsidian-wiki}`. `wiki-capture`, `wiki-query` and `llm-wiki` are symlinked into `~/.claude/skills`. Agents find the rest with `mcptoon skills resolve`.
- obsidian-wiki `SessionStart` recap and `UserPromptSubmit` recall hooks are registered next to the existing `Stop` capture. `CLAUDE.md` has a new block telling agents to use Serena, codegraph or jCodeMunch for code relationships and to keep per-project memory (handoff, `obsidian-wiki memory`, `wiki-capture`).
- Removed the context-mode v1 `cache-heal` hook and its data dir.
- Action: `./install.sh` (re-runs the GSD profile, relinks the catalog, registers the hooks). A machine that has Candor or obsidian-wiki enabled: disable both plugins with `claude plugin disable`, then restart Claude Code. Roll GSD back with `npx @opengsd/gsd-core@latest --claude --global --profile=full`.

## 2026-11-16 Stack trimmed
- Removed: free-search, github-direct, the `github` plugin, GitKraken, claude-guardrails, wcag-accessibility, rea, bla, craft-anything, skillspector, reverse-api-engineer, egm, cli-anything, sessionbridge (and `/migrate-session`), Agent-Fusion (and `openjdk@21`). OpenSpec and spec-kit stay.
- mcptoon footer is off (`mcptoon config set footer off`); the jCodeMunch block in `CLAUDE.md` now uses the real `mcptoon_call` path (`route` takes `task`; `index_folder` needs `allow_state_change`).
- Action on a machine that has these: uninstall the plugins (`claude-guardrails`, `egm`, `cli-anything`, `sessionbridge`) and their marketplaces, `npm uninstall -g rea-agents bla-agents`, `uv tool uninstall skillspector reverse-api-engineer`, delete the matching skills and `~/.claude-tools/{agent-fusion,craft-anything,src/Agent-Fusion}`, the per-project `.agent/fusion/` folders, remove their entries from `~/.mcptoon/config.json` and `~/.claude.json`, then `./install.sh` and `mcptoon doctor`.

## 2026-11-15 Cursor / Cursor Code port
- New `cursor/` (`mcp.json` gateway template, `rules/claude-config.mdc`, `render.py`, Windows `wrap-claude-sh-hooks.py`), `install-cursor.sh` (macOS) and `install-cursor.ps1` (Windows 11). Wires Cursor IDE + Cursor Code CLI to the same mcptoon gateway and `~/.claude/skills` from the base install. On Windows, wraps Claude `.sh` hooks that Cursor also loads so Open-with dialogs stop.
- Action: run the base installer for your OS once (if not installed), then `./install-cursor.sh` or `pwsh ./install-cursor.ps1`, fully quit and restart Cursor / Cursor Code. Verify with `mcptoon doctor` and MCP list showing `mcptoon` — details in `cursor/README.md`.

## 2026-11-15 OpenCode V2 port
- New `opencode/` (global `AGENTS.md`, five commands, the `claude-config.js` bridge plugin, `render.py`), `install-opencode.sh` (macOS) and `install-opencode.ps1` (Windows 11): the same templates rendered for OpenCode V2. `~/.claude` is untouched; GSD/RTK/Caveman are wired by their own OpenCode installers.
- Action: run the base installer for your OS once (if not installed), then `./install-opencode.sh` or `pwsh ./install-opencode.ps1` and restart OpenCode. Verify with `opencode mcp list` (caveman, gsd, lightpanda, mcptoon) — details and gotchas in `opencode/README.md`.

## 2026-11-16 more tools
- Added plugins `frontend-design`, `playwright`; skills for agent-desktop, agent-device, Expo and React Native, Orca, google-maps-scraper and karpathy-guidelines; npm `agent-desktop`, `agent-device`.
- Action: re-run the installer.

## 2026-11-15 config-sync: startup hook removed
- The SessionStart `config-sync check` hook is gone; updates are on demand via `/config-update` or `config-sync status`.
- Action: delete the `config-sync check` SessionStart entry from your Claude Code settings if you already have it.

## 2026-11-15 config-sync: update detection
- New `bin/config-sync` and a SessionStart hook. Claude is told when newer commits exist and offers `/config-update`.
- Action: none beyond `./install.sh` (macOS) or `pwsh ./install.ps1` once, so the hook and `config-sync` exist.

## 2026-11-15 Windows 11 port
- `install.ps1`, `windows/`, `bin/_platform.sh` and OS-gated branches in `bin/*`. macOS code paths are unchanged.
- Re-run `./install.sh` on macOS so `bin/_platform.sh` sits next to the scripts that now source it.
- Shared source-build pins: `tools/git-sources.txt`.
- Large Kwipu vaults: build once outside MCP with `python ~/.claude-tools/bin/kwipu-build.py <vault>`.
