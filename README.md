# claude-config

A portable snapshot of one Claude Code setup: hooks, plugins, MCP servers, skills, helper scripts and the tool list behind them. Built to cut token use, keep project memory in the repo so any agent harness can pick up where the last one stopped, and give every project an Obsidian vault.

Licensed under MIT (see `LICENSE`); bundled third-party skills keep their own licenses (see Skill sources).

Snapshot taken 2026-11-01 on macOS (Apple Silicon). Paths with your home directory are stored as `__HOME__` and filled in by `install.sh`.

## What the stack does

| Job | Tool | How |
|---|---|---|
| Shrink bash output | RTK | `rtk hook claude` rewrites noisy command output |
| Shrink requests and replies | Caveman (plugin, CLI, local proxy on `127.0.0.1:8788`, caveman-blocks) | compresses input and output, terse style |
| Keep raw data out of context | context-mode (plugin) | sandboxed execution plus search index |
| Hide tool schemas | mcptoon | one gateway in front of 15 MCP servers (314 tools behind a handful of gateway tools) |
| Project memory and handoff | agent-handoff (`bin/agent-handoff`) | writes `.agent/` and a managed block in `AGENTS.md` on session start, logs edits, writes a summary at session end |
| Obsidian vault in every project | `bin/vault-bootstrap`, Obsidian plugin, obsidian-wiki, mcp-obsidian | creates `.obsidian/`, `Home.md`, registers the vault |
| Code lookup | jCodeMunch (symbols), lumen (semantic search), codegraph (graph), fallow (static analysis) | all via mcptoon |
| Knowledge and context server | kwipu (vault Q&A on local Ollama), Agent-Fusion (per-project indexer on a local JVM) | via mcptoon |
| Specs | OpenSpec and spec-kit | scaffolded by `bin/spec-bootstrap` |
| Style | ponytail plugin | smallest-change discipline |
| Other harness sessions | sessionbridge plugin | Claude to Codex session moves |
| Browser | Lightpanda (primary), Comet (fallback) | `lightpanda` MCP plus a CDP daemon on `127.0.0.1:9222`; `playwright` and `chrome-devtools` attach to it; `playwright-comet` and `chrome-devtools-comet` drive `/Applications/Comet.app`. Other browsers are denied in `settings.json`; policy text is in `claude/CLAUDE.md` |
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
4. **lumen:** install the `lumen` binary (version 0.0.42) from https://github.com/ory/lumen and put it on your PATH (`~/.local/bin/lumen`).
5. **figcraft:** install the FigCraft desktop app from https://github.com/storytold/figcraft/releases (macOS `.dmg`, drag to `/Applications`); the MCP server expects its CLI at `~/.artcraft/bin/figcraft-cli`.
6. **Obsidian:** install the app from https://obsidian.md. Open it once so `obsidian-local-rest-api` creates its key; `bin/vault-bootstrap` seeds the key from `~/.claude-tools/obsidian.env`, which is generated on first run and never committed.
7. Restart Claude Code, run `mcptoon doctor` (expect 15 servers OK) and `/context`.

## Layout

```
claude/            CLAUDE.md, RTK.md, settings.json (hooks, plugins, env), commands/, hooks/, mcpServers.json, plugins.json
skills/            user skills (third-party skills keep their own licenses)
bin/               helper scripts that the hooks call
mcptoon/           gateway config (15 servers)
launchd/           caveman proxy and Lightpanda CDP daemon
tools/             brew, uv, npm and Ollama model lists with versions
export.py          re-snapshot this machine into the repo
```

## Known limits
- Agent-Fusion holds about 4 GB of RAM per active project while running and takes about 2.5 minutes to index a repo the first time. Its HTTP port opens only after that index finishes. `bin/agent-fusion-run` turns off `git_intent_links` (it failed on every file and stalled startup) and refuses to watch `$HOME`.
- The Caveman proxy is a single point of failure for every request; savings are not measured here.
- OpenSpec and spec-kit overlap; both are kept on purpose.
- `claude/settings.json` contains Caveman's generated hooks with absolute Homebrew paths. Re-run `caveman setup` if Node lives elsewhere.

- Browser policy: Lightpanda is the primary browser. `playwright` needs `--isolated` against it (otherwise "No page on the STARTUP session"). The Comet fallback fails with "browser is already running" while Comet is open, so quit Comet first. Claude Desktop's own browser setting cannot be pointed at Lightpanda; the deny rules cover Claude Code only. `lightpanda mcp` and CDP attach were tested; screenshots and logged-in pages need the Comet fallback.

## Keeping it current
Run `python3 export.py` after changing the stack, review `git diff`, commit. The script scans its output for secret-like strings and stops if it finds any. Never add `~/.claude.json`, transcripts, `obsidian.env` or `.env` files.

## Source repositories
Upstream repo for every tool in the stack. `install.sh` installs the Homebrew packages (rtk, ollama, gh, openjdk@21) through `brew`; their sites are https://www.rtk-ai.app/ and https://ollama.com/. Links were taken from package metadata, `plugins.json`, the local clones and `gh repo view`.

| Tool | Source |
|---|---|
| RTK | https://github.com/rtk-ai/rtk |
| Caveman (plugin, CLI, proxy) | https://github.com/JuliusBrussee/caveman |
| context-mode | https://github.com/mksglu/context-mode |
| mcptoon | https://github.com/activeing123/mcptoon |
| agent-handoff, vault-bootstrap, spec-bootstrap, index-bootstrap | this repo (`bin/`) |
| Obsidian helper skills (`obsidian` plugin) | https://github.com/kepano/obsidian-skills |
| obsidian-wiki | https://github.com/Ar9av/obsidian-wiki |
| mcp-obsidian | https://github.com/MarkusPfundstein/mcp-obsidian |
| Obsidian Local REST API plugin | https://github.com/coddingtonbear/obsidian-local-rest-api |
| jCodeMunch | https://github.com/jgravelle/jcodemunch-mcp |
| lumen | https://github.com/ory/lumen |
| codegraph | https://github.com/colbymchenry/codegraph |
| fallow | https://github.com/fallow-rs/fallow |
| Kwipu | https://github.com/benmaster82/Kwipu |
| Agent-Fusion | https://github.com/krokozyab/Agent-Fusion |
| OpenSpec | https://github.com/Fission-AI/OpenSpec |
| spec-kit | https://github.com/github/spec-kit |
| ponytail | https://github.com/DietrichGebert/ponytail |
| sessionbridge | https://github.com/tongtongtju/sessionbridge |
| figcraft | https://github.com/storytold/figcraft |
| open-pencil | https://github.com/open-pencil/open-pencil |
| fig-mcp | https://github.com/bilalba/fig-mcp |
| shadcn MCP | https://github.com/shadcn-ui/ui |
| Lightpanda | https://github.com/lightpanda-io/browser |
| playwright MCP | https://github.com/microsoft/playwright-mcp |
| chrome-devtools MCP | https://github.com/ChromeDevTools/chrome-devtools-mcp |
| ui-ux-pro-max (CLI and skill) | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill |
| Context7 MCP | https://github.com/upstash/context7 |
| Ollama | https://github.com/ollama/ollama |

## Skill sources
Each folder in `skills/` with its upstream repo. Every repo below was confirmed by listing its file tree for that skill, except where marked.

| Skill | Source |
|---|---|
| composition-patterns, react-best-practices, react-native-skills, react-view-transitions, web-design-guidelines, writing-guidelines, deploy-to-vercel, vercel-cli-with-tokens, vercel-optimize | https://github.com/vercel-labs/agent-skills |
| banner-design, brand, design, design-system, slides, ui-styling, ui-ux-pro-max | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill (`.claude/skills/`) |
| shadcn, migrate-radix-to-base | https://github.com/shadcn-ui/ui (`skills/`) |
| open-pencil | https://github.com/open-pencil/open-pencil (`skills/open-pencil`) |
| harness-init, vault-context, vault-discover, obsidian-tooling | https://github.com/nickyeolk/agentic_doc_harness (`.claude/skills/`) |
| architecture-decision-records | https://github.com/affaan-m/ECC |
| humanizer, structural-humanizer | https://github.com/NulightJens/humanizer-stack (humanizer is based on https://github.com/blader/humanizer) |
| frontend-design | https://github.com/anthropics/skills |
| wcag-accessibility | https://github.com/mrKanoh/wcag-accessibility-audit-skill |
| design-review | https://github.com/AslanMazhidov/design-review-skill |
| fig-parser | https://github.com/sunyui/figma-parser |
| figcraft | https://github.com/storytold/figcraft (skill pack: https://github.com/Vinciux99/artcraft-claude-skills, not tree-checked) |
| mcptoon | https://github.com/activeing123/mcptoon |
| unslop | https://github.com/heydamir/unslop (CC-BY-4.0) |
| untangle-codebase | https://github.com/caldoai/skills (`skills/untangle-codebase`) |

Plugin-provided skills are not copied here; `install.sh` installs them from the marketplaces listed in `claude/plugins.json` (see Source repositories above).

Third-party skills keep their original licenses and copyrights; this repo's license does not apply to them. Check each skill's upstream repository for its terms before reusing it.
