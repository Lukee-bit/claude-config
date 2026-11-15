# Changelog

Newest first. `config-sync` shows these lines to Claude when the repo moves ahead of what is installed; `/config-update` applies them.
Each entry says what changed and whether anything needs doing beyond the re-run installer (`config-sync apply` does the re-run).

## 2026-11-15 Cursor / Cursor Code port
- New `cursor/` (`mcp.json` gateway template, `rules/claude-config.mdc`, `render.py`, Windows `wrap-claude-sh-hooks.py`), `install-cursor.sh` (macOS) and `install-cursor.ps1` (Windows 11). Wires Cursor IDE + Cursor Code CLI to the same mcptoon gateway and `~/.claude/skills` from the base install. On Windows, wraps Claude `.sh` hooks that Cursor also loads so Open-with dialogs stop.
- Action: run the base installer for your OS once (if not installed), then `./install-cursor.sh` or `pwsh ./install-cursor.ps1`, fully quit and restart Cursor / Cursor Code. Verify with `mcptoon doctor` and MCP list showing `mcptoon` — details in `cursor/README.md`.

## 2026-11-15 OpenCode V2 port
- New `opencode/` (global `AGENTS.md`, six commands, the `claude-config.js` bridge plugin, `render.py`), `install-opencode.sh` (macOS) and `install-opencode.ps1` (Windows 11): the same templates rendered for OpenCode V2. `~/.claude` is untouched; GSD/RTK/Caveman are wired by their own OpenCode installers.
- Action: run the base installer for your OS once (if not installed), then `./install-opencode.sh` or `pwsh ./install-opencode.ps1` and restart OpenCode. Verify with `opencode mcp list` (caveman, gsd, lightpanda, mcptoon) — details and gotchas in `opencode/README.md`.

## 2026-11-15 config-sync: update detection
- New `bin/config-sync` and a SessionStart hook. Claude is told when newer commits exist and offers `/config-update`.
- Action: none beyond `./install.sh` (macOS) or `pwsh ./install.ps1` once, so the hook and `config-sync` exist.

## 2026-11-15 Agent-Fusion dashboard no longer opens a browser
- `bin/agent-fusion-run` sets `[web] autoLaunchBrowser = false` in each project's `fusionagent.toml` (also patches existing ones).
- Search and the MCP port are unchanged. Takes effect the next time a project's Agent-Fusion server starts; to apply now, stop the old `java ... orchestrator` process and open a new session.

## 2026-11-15 Windows 11 port
- `install.ps1`, `windows/`, `bin/_platform.sh` and OS-gated branches in `bin/*`. macOS code paths are unchanged.
- Re-run `./install.sh` on macOS so `bin/_platform.sh` sits next to the scripts that now source it.
- Shared source-build pins: `tools/git-sources.txt` (Agent-Fusion e22d2a6 needs `tools/agent-fusion/ReciprocalRankFusion.kt` copied into `src/main/kotlin/com/orchestrator/context/search/` before `./gradlew shadowJar`).
- Large Kwipu vaults: build once outside MCP with `python ~/.claude-tools/bin/kwipu-build.py <vault>`.
