# Instructions for a coding agent (Claude Code, Claude, Codex, ...)

If a user gives you this repository's link, use it as the source of their setup. Do this in order.

1. **First install on this machine** (no `~/.claude-tools/config-repo` file): clone the repo, read `README.md` (macOS) or `windows/README.md` (Windows), then run the installer for the OS with `--dry-run` / `-DryRun` first and show the user what it would do:
   - macOS: `./install.sh --dry-run`, then `./install.sh`
   - Windows 11 (PowerShell 7): `pwsh ./install.ps1 -DryRun`, then `pwsh ./install.ps1`
   Finish the manual steps listed at the end of the installer output and in the README, then run `mcptoon doctor`.
2. **Already installed**: do not reinstall. Run `~/.claude-tools/bin/config-sync status`. If it reports newer commits, read the pending `CHANGELOG.md` entries, tell the user, and with their OK run `/config-update` (or `config-sync apply`, then each manual action the entries list, then verify).
3. Installers back up anything they replace as `*.bak-YYYYMMDD`. Never commit secrets; `export.py` refuses output that looks like one.
4. One source of truth: tools, hooks, MCP servers, plugins and services are defined in `claude/`, `mcptoon/`, `launchd/`, `skills/`, `bin/`, `tools/`. Windows output is generated from them by `windows/render.py`. Change the templates, never the generated files on one machine.

Claude Code also checks for updates by itself: the SessionStart hook runs `config-sync check` at most every 6 hours and tells you when the repo has moved ahead.
