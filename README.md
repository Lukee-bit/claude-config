# claude-config

A portable snapshot of one Claude Code setup: hooks, plugins, MCP servers, skills, helper scripts and the tool list behind them. Built to cut token use, keep project memory in the repo so any agent harness can pick up where the last one stopped, and give every project an Obsidian vault.

Snapshot taken 2026-11-01 on macOS (Apple Silicon). Paths with your home directory are stored as `__HOME__` and filled in by `install.sh`.

## What the stack does

| Job | Tool | How |
|---|---|---|
| Shrink bash output | RTK | `rtk hook claude` rewrites noisy command output |
| Shrink requests and replies | Caveman (plugin, CLI, local proxy on `127.0.0.1:8788`, caveman-blocks) | compresses input and output, terse style |
| Keep raw data out of context | context-mode (plugin) | sandboxed execution plus search index |
| Hide tool schemas | mcptoon | one gateway in front of 14 MCP servers (314 tools behind a handful of gateway tools) |
| Project memory and handoff | agent-handoff (`bin/agent-handoff`) | writes `.agent/` and a managed block in `AGENTS.md` on session start, logs edits, writes a summary at session end |
| Obsidian vault in every project | `bin/vault-bootstrap`, Obsidian plugin, obsidian-wiki, mcp-obsidian | creates `.obsidian/`, `Home.md`, registers the vault |
| Code lookup | jCodeMunch (symbols), lumen (semantic search), codegraph (graph), fallow (static analysis) | all via mcptoon |
| Knowledge and context server | kwipu (vault Q&A on local Ollama), Agent-Fusion (per-project indexer on a local JVM) | via mcptoon |
| Specs | OpenSpec and spec-kit | scaffolded by `bin/spec-bootstrap` |
| Style | ponytail plugin | smallest-change discipline |
| Other harness sessions | sessionbridge plugin | Claude to Codex session moves |
| Design and web | figcraft, open-pencil, fig-mcp, shadcn, playwright, chrome-devtools MCPs plus the design and Vercel skills in `skills/` | |

### What happens in a new project
On the first session in a directory, SessionStart hooks run:
1. `vault-bootstrap` makes it an Obsidian vault (skips `$HOME`, system folders and `~/Projects` itself).
2. `spec-bootstrap` runs `specify init` and `openspec init`.
3. `index-bootstrap` builds the codegraph index in the background and starts Agent-Fusion for that project.
4. `agent-handoff init` creates `.agent/` (handoff, memory), `AGENTS.md`, `.mcp.json` and a managed `.gitignore` block, then prints the last handoff.

Opt out per project by touching `.agent-handoff-off`, `.spec-bootstrap-off` or `.index-bootstrap-off`.

## Restore on a new Mac

```bash
git clone <this repo> claude-config && cd claude-config
./install.sh --dry-run     # read what it will do
./install.sh               # apply (add --no-tools to skip package installs)
```

Then, by hand:
1. `caveman setup`, then load the proxy: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.caveman.proxy.plist`. `settings.json` points `ANTHROPIC_BASE_URL` at `127.0.0.1:8788`; if the proxy is not running, Claude Code cannot reach the API. Remove that env var to bypass it.
2. **Agent-Fusion:** `git clone https://github.com/krokozyab/Agent-Fusion ~/.claude-tools/src/Agent-Fusion`, build `./gradlew shadowJar`, copy `build/libs/orchestrator-0.1.0-all.jar` to `~/.claude-tools/agent-fusion/`. Needs `openjdk@21`.
3. **Kwipu:** `git clone https://github.com/benmaster82/Kwipu ~/.claude-tools/Kwipu`, create its `.venv` and install its requirements.
4. **lumen:** install the `lumen` binary on your PATH (source not recorded in this snapshot; version 0.0.42).
5. Open Obsidian once so `obsidian-local-rest-api` creates its key; `bin/vault-bootstrap` seeds the key from `~/.claude-tools/obsidian.env`, which is generated on first run and never committed.
6. Restart Claude Code, run `mcptoon doctor` (expect 14 servers OK) and `/context`.

## Layout

```
claude/            CLAUDE.md, RTK.md, settings.json (hooks, plugins, env), commands/, hooks/, mcpServers.json, plugins.json
skills/            user skills (third-party skills keep their own licenses)
bin/               helper scripts that the hooks call
mcptoon/           gateway config (14 servers)
launchd/           caveman proxy service
tools/             brew, uv, npm and Ollama model lists with versions
export.py          re-snapshot this machine into the repo
```

## Known limits
- Agent-Fusion holds about 4 GB of RAM per active project while running and takes about 2.5 minutes to index a repo the first time. Its HTTP port opens only after that index finishes. `bin/agent-fusion-run` turns off `git_intent_links` (it failed on every file and stalled startup) and refuses to watch `$HOME`.
- The Caveman proxy is a single point of failure for every request; savings are not measured here.
- OpenSpec and spec-kit overlap; both are kept on purpose.
- `claude/settings.json` contains Caveman's generated hooks with absolute Homebrew paths. Re-run `caveman setup` if Node lives elsewhere.

## Keeping it current
Run `python3 export.py` after changing the stack, review `git diff`, commit. The script scans its output for secret-like strings and stops if it finds any. Never add `~/.claude.json`, transcripts, `obsidian.env` or `.env` files.

## Skill sources
`skills/` was copied from: ui-ux-pro-max (nextlevelbuilder/ui-ux-pro-max-skill), wcag-accessibility (mrKanoh/wcag-accessibility-audit-skill), design-review (AslanMazhidov/design-review-skill), humanizer and structural-humanizer (NulightJens/humanizer-stack), fig-parser (sunyui/figma-parser), shadcn (shadcn-ui/ui), plus Vercel and Obsidian helper skills. Check each folder's LICENSE before making this repo public.
