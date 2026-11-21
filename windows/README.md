# Windows 11 port

One source of truth: `claude/`, `mcptoon/`, `launchd/`, `skills/`, `bin/` and `tools/` are the only places a tool, hook, MCP server,
plugin or service is defined. Remove it there and it is gone on macOS and Windows. Nothing in `windows/` lists tools of its own except
where Windows needs a different *package* (`windows/tools/`).

| Piece | How it stays single-source |
|---|---|
| `claude/settings.json` hooks | `windows/render.py settings` rewrites paths and launchers at install time. Caveman's own hooks are skipped: `caveman setup` writes them per OS. |
| `mcptoon/config.json` | `render.py mcptoon` adds the Git Bash launcher, `.cmd`/`.exe` suffixes. |
| `claude/mcpServers.json` | `render.py mcpservers`. |
| `launchd/*.plist` | `render.py service` turns the same plist into a scheduled task (`windows/run-service.ps1` keeps it alive). |
| `bin/*` | Same scripts on both OSes. `bin/_platform.sh` is the only place that knows about Windows; on macOS every function in it is a no-op. |
| `tools/*.txt` | Shared version lists. Windows adds `windows/tools/winget.txt` (the brew counterpart) and `npm-overrides.txt` (versions verified on Windows). |

## Install

**Double-click `Install.cmd`** in the repo root. It installs the prerequisites with winget, detects Claude Code, Cursor and OpenCode, asks which to set up (Enter = all detected) and verifies the result. Details and the scripted form (`pwsh ./setup/setup.ps1 -All -Yes`) are in the top-level README. The commands below are the underlying installer.

```powershell
git clone <this repo> claude-config; cd claude-config
pwsh ./install.ps1 -DryRun     # read what it will do
pwsh ./install.ps1             # apply (-NoTools skips winget/uv/npm/ollama)
```

Needs PowerShell 7, Git for Windows (Git Bash runs the scripts), Node, uv and Python 3 first.
Existing files are backed up as `*.bak-YYYYMMDD`. After it finishes: restart Claude Code, run `mcptoon doctor` (0 issues; 19 servers). The installer also snapshots GSD into `~/.claude-tools/skill-catalog`, trims it to the `core` profile, links Candor, obsidian-wiki and `tools/folded-skills.txt` skills there with directory junctions, and registers the obsidian-wiki hooks (see CHANGELOG 2026-11-16).

Optional surfaces after the base install: **Cursor** — `pwsh ./install-cursor.ps1` (see `cursor/README.md`); **OpenCode** — `pwsh ./install-opencode.ps1`.

## Known Windows differences and gotchas

- **Ollama + ad blockers/VPN filters:** AdGuard answered `http://localhost:11434` with `500 Request Blocked`, so Ollama never saw its runner as healthy (hangs on embed and chat). Exclude `ollama.exe` and `llama-server.exe` from the filter.
- **Caveman proxy route:** `caveman doctor --fix` refuses if `ANTHROPIC_BASE_URL` differs from the route Caveman recorded at setup. `install.ps1` reads that route and runs the proxy on it; do not hand-edit the URL.
- **Obsidian Restricted mode** is per vault (localStorage key `enable-plugin-<vaultId>`). `bin/obsidian-trust-vault.py` pre-seeds it when `vault-bootstrap` creates a vault, but only while Obsidian is closed; otherwise toggle it once in the UI.
- **Kwipu:** storage is one global directory shared by all vaults. The first graph build over a large vault takes hours; run `python ~/.claude-tools/bin/kwipu-build.py <vault>` outside MCP (a first build inside a tool call hits mcptoon's 30 s timeout). The venv is created with `UV_LINK_MODE=copy` (hardlinked files fail its path-security check).
- **Lightpanda** has no official Windows build; the installer uses the unsigned community port `qidiai/lightpanda-windows-port` (portable-v0.2.5). Review it before trusting it.
- **obsidian-wiki** timezone stays UTC unless `tzdata` is added to its uv tool.
- Version drift: this port was verified with context-mode 2.2.0, @caveman-ai/cli 4.1.0 and openspec 2.0.0 (see `windows/tools/npm-overrides.txt`); `tools/npm-global.txt` still pins the macOS snapshot.
