# Luke's claude-config

**One repo, every agent.** A tuned, token-lean, self-remembering AI coding environment that installs with a double-click on Windows and macOS, for Claude Code, Cursor and OpenCode.

Licensed under MIT (see `LICENSE`); bundled third-party skills keep their own licenses (see Skill sources).

## Why it exists

It started on 2026-11-01 as a portable snapshot of one Claude Code setup: the hooks, plugins, MCP servers and skills that one machine had grown. It is now more than a backup. It is a single source of truth that renders the same stack for three agent harnesses on two operating systems, installs it, checks it and keeps it current.

- **One double-click.** `Install.cmd` (Windows) or `Install.command` (macOS) detects your OS and which harnesses are on the machine, installs what is missing, configures the ones you pick (default: all) and ends with a PASS/FAIL report and a log. Re-running is safe: nothing is duplicated and replaced files are kept as `*.bak-YYYYMMDD`.
- **Three harnesses, one source.** `claude/`, `mcptoon/`, `skills/`, `bin/` and `tools/` define every tool, hook, server and skill once. `windows/render.py`, `cursor/render.py` and `opencode/render.py` turn them into each harness's own config. Remove a tool from the source and it is gone everywhere.
- **Cheaper every turn.** RTK shrinks command output, the Caveman proxy and style shrink requests and replies, context-mode keeps raw data out of the conversation, and the mcptoon gateway puts 18 MCP servers (280 tools) behind a handful of gateway tools. Skills load on demand from a catalog instead of being described every session.
- **Agents that remember.** `.agent/handoff.md`, `.agent/memory/` and the obsidian-wiki hooks record where work stopped and which rules bind the project. Any harness can pick it up, and every project becomes an Obsidian vault.
- **One owner per job.** Each task (searching code, finding callers, reading docs, browsing, memory) has exactly one designated tool, so tools do not fight. The table is below.
- **Guarded by default.** The guard-pack hooks block piped remote scripts, `--no-verify`, secret reads and force pushes. Semgrep runs locally with no account. Browsing goes through Lightpanda first. `export.py` scans for secrets before anything is committed.
- **Stays current.** `bin/config-sync` notices when the repo moves ahead of the machine, and `CHANGELOG.md` says what changed and whether you need to act. A personal branch (`comet`) follows `main` automatically.
- **Made for people and for agents.** Humans double-click. An agent can be pointed at [`INSTALL-FOR-AGENTS.md`](INSTALL-FOR-AGENTS.md) or run the same installer without prompts.

The idea: build one carefully tuned workshop, then carry it to any machine and hand it to any agent, with no re-explaining and no drift.

## Install (one double-click)

Download or clone this repo, then double-click:

| Your computer | Double-click |
|---|---|
| Windows 10/11 | `Install.cmd` |
| macOS | `Install.command` (first time: right-click, Open) |

It installs what is missing (Git, Node, uv, Python, and on a Mac Homebrew), finds which of **Claude Code, Cursor and OpenCode** are on the machine, and asks what to set up. Press Enter for the recommended choice, all detected harnesses. A harness that is missing can be installed from the same menu. When it finishes it checks the result (MCP gateway, each harness, the browser service) and prints PASS or FAIL for each check. Re-running it is safe: nothing is duplicated and replaced files are kept as `*.bak-YYYYMMDD`. A full log is written to `~/.claude-tools/install-<date>.log`.

Without a menu (scripts and agents): `pwsh ./setup/setup.ps1 -All -Yes` on Windows, `./setup/setup.sh --all --yes` on a Mac; `-Only claude,cursor,opencode` (`--only` on a Mac) names the harnesses and installs any that is missing. A ZIP download (no `.git`) is turned into a checkout of this branch so `config-sync` updates work.

## Supported harnesses and systems

| Harness | Windows 10/11 | macOS | Details |
|---|---|---|---|
| Claude Code | yes | yes | this README, [`windows/README.md`](windows/README.md) |
| Cursor IDE and Cursor Code CLI | yes | yes | [`cursor/README.md`](cursor/README.md) |
| OpenCode V2 | yes | yes | [`opencode/README.md`](opencode/README.md) |

The base installer (`install.ps1` / `install.sh`) owns the shared stack; the Cursor and OpenCode installers wire those harnesses to it. The one-click setup runs them in order.

## Branches

- `main` is the shared configuration.
- `comet` is `main` plus personal settings (the Comet browser fallback and a Claude model preference). A workflow merges every push to `main` into `comet`, so it never falls behind.
- `.config-branch` names the branch a ZIP download should become a git checkout of, so `config-sync` updates keep working.

## What the stack does

| Job | Tool | How |
|---|---|---|
| Shrink bash output | RTK | `rtk hook claude` rewrites noisy command output |
| Shrink requests and replies | Caveman (plugin, CLI, local proxy on `127.0.0.1:8788`, caveman-blocks) | compresses input and output, terse style |
| Keep raw data out of context | context-mode (plugin) | sandboxed execution plus search index |
| Hide tool schemas | mcptoon | one gateway in front of 18 MCP servers (280 tools behind a handful of gateway tools) |
| Project memory and handoff | agent-handoff (`bin/agent-handoff`) | writes `.agent/` and a managed block in `AGENTS.md` on session start, logs edits, writes a summary at session end |
| Obsidian vault in every project | `bin/vault-bootstrap`, Obsidian plugin, obsidian-wiki, mcp-obsidian | creates `.obsidian/`, `Home.md`, registers the vault |
| Code lookup | jCodeMunch (symbols), lumen (semantic search), codegraph (graph), fallow (static analysis) | all via mcptoon |
| Knowledge and context server | kwipu (vault Q&A on local Ollama) | via mcptoon |
| Specs | OpenSpec and spec-kit | scaffolded by `bin/spec-bootstrap` |
| Style | ponytail plugin | smallest-change discipline |
| Code intelligence | Serena (symbol-level code tools) | via mcptoon |
| Workflow and review | Superpowers, GSD Core, pr-review-toolkit plugins | GSD is installed by `install.sh` through its own installer (hooks, statusline) in the `core` profile (8 skills); the other GSD skills load on demand from the mcptoon skill catalog |
| Anti-sycophancy | anti-sycophancy skill plus `UserPromptSubmit` hook; Candor personas (catalog) | rewrites confirmation-seeking prompts and adds critical-response rules to `CLAUDE.md`; the Candor plugin is disabled and its 12 skills load on demand |
| Skill catalog | mcptoon `skills resolve`, `~/.claude-tools/skill-catalog/` | GSD (full snapshot), Candor, the 40 obsidian-wiki skills and the task-specific user skills in `tools/folded-skills.txt` (set to `name-only` through `skillOverrides`) are indexed there instead of being described natively every session; `wiki-capture`, `wiki-query` and `llm-wiki` stay native |
| Project memory | `.agent/handoff.md`, `.agent/memory/`, obsidian-wiki hooks (`SessionStart` recap, `UserPromptSubmit` recall, `Stop` capture) | the `CLAUDE.md` policy block tells agents to read the handoff, record durable facts with `obsidian-wiki memory`, and run `/save-handoff` before stopping |
| Safety and security | claude-code-hooks `guard-pack`, Semgrep's local MCP server | guards block piped remote scripts, `--no-verify`, secret reads, force pushes; Semgrep runs locally through `bin/semgrep-mcp-run` with tracing and metrics off (no account needed) |
| Browser | Lightpanda (primary), Comet (fallback) | `lightpanda` reached through mcptoon (no direct MCP entry) plus a CDP daemon on `127.0.0.1:9222`; `playwright` and `chrome-devtools` attach to it; `playwright-fallback` and `chrome-devtools-fallback` attach to `/Applications/Comet.app` on debug port 9223 via `bin/comet-cdp`. Other browsers are denied in `settings.json`; policy text is in `claude/CLAUDE.md` |
| Agent and device control | agent-desktop, agent-device, orca-cli, orca-computer-use, orchestration skills | desktop/mobile GUI automation, Orca worktrees and workers |
| Mobile and app skills | expo-animation, expo-design-system, expo-native-ui, expo-router, react-native-best-practices | Expo and React Native guidance |
| Other skills and plugins | google-maps-scraper, karpathy-guidelines skills; frontend-design, playwright plugins | `playwright` stays on the deny list (browser policy) |
| Design and web | figcraft (CLI + MCP, for real Figma files and FigCraft), fig-mcp, shadcn, playwright, chrome-devtools MCPs plus the design and Vercel skills in `skills/` | |

### Tool roles (one owner each, so nothing fights)

| Job | Owner | Not the owner |
|---|---|---|
| Bash output shrinking | RTK hook (`rtk`), then context-mode for anything over about 20 lines | caveman `shrink-hook` only trims what is left; the caveman proxy compresses requests, not tool output |
| Recovering compressed content | `caveman_retrieve` (caveman MCP stays direct so its results are never re-compressed) | mcptoon (`compress=smart` applies to gateway results only) |
| Exact string, known file | built-in Grep and Read | |
| "How does X work", before an edit | `codegraph_explore` | |
| Symbols, references, refactors | Serena | |
| Callers, impact, dead code | jCodeMunch (any language), `fallow_*` (JS/TS) | |
| Semantic and graph search | `lumen_semantic_search`, `kwipu_query_graph` | |
| Library docs | `context7` | |
| Browser | Lightpanda through mcptoon, Comet fallback | |
| Where work stopped | `.agent/handoff.md` (`/save-handoff`, `agent-handoff`) | |
| Binding project rules | `.agent/memory/` | |
| User facts, open threads, findings | obsidian-wiki (`memory profile`, `memory todo`, `wiki-capture`) | |
| Code-structure notes | Serena memories | |
| Skill discovery | superpowers and GSD core natively, everything else `mcptoon skills resolve` | |

Never run `obsidian-wiki setup` (it reinstalls all 40 skills) or a bare `mcptoon skills index` (it rebuilds from the agent skill folders); index with explicit roots.


### What happens in a new project
On the first session in a directory, SessionStart hooks run:
1. `vault-bootstrap` makes it an Obsidian vault (skips `$HOME`, system folders and `~/Projects` itself).
2. `spec-bootstrap` runs `specify init` and `openspec init`.
3. `index-bootstrap` builds the codegraph index in the background.
4. `agent-handoff init` creates `.agent/` (handoff, memory), `AGENTS.md`, `.mcp.json` and a managed `.gitignore` block, then prints the last handoff.

Opt out per project by touching `.agent-handoff-off`, `.spec-bootstrap-off` or `.index-bootstrap-off`.

> **Giving this repo to an agent?** Point it at [`INSTALL-FOR-AGENTS.md`](INSTALL-FOR-AGENTS.md). Updates are detected by `bin/config-sync` and described in [`CHANGELOG.md`](CHANGELOG.md).

## Advanced: run the macOS installer directly

The one-click setup runs this for you. Paths with your home directory are stored as `__HOME__` and filled in by `install.sh`.

```bash
git clone <this repo> claude-config && cd claude-config
./install.sh --dry-run     # read what it will do
./install.sh               # apply (add --no-tools to skip package installs)
```

Kwipu, lumen, Caveman and the launchd services are set up by the installer itself. Only the apps remain by hand:
1. (done by the installer) `caveman setup`, then load the proxy: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.caveman.proxy.plist`. `settings.json` points `ANTHROPIC_BASE_URL` at `127.0.0.1:8788`; if the proxy is not running, Claude Code cannot reach the API. Remove that env var to bypass it.
2. **Kwipu:** `git clone https://github.com/benmaster82/Kwipu ~/.claude-tools/Kwipu`, create its `.venv` and install its requirements.
3. **lumen:** install the `lumen` binary (version 0.0.42) from https://github.com/ory/lumen and put it on your PATH (`~/.local/bin/lumen`).
4. **figcraft:** install the FigCraft desktop app from https://github.com/storytold/figcraft/releases (macOS `.dmg`, drag to `/Applications`); the MCP server expects its CLI at `~/.artcraft/bin/figcraft-cli`.
5. **Obsidian:** install the app from https://obsidian.md. Open it once so `obsidian-local-rest-api` creates its key; `bin/vault-bootstrap` seeds the key from `~/.claude-tools/obsidian.env`, which is generated on first run and never committed.
6. Restart Claude Code, run `mcptoon doctor` (all servers OK) and `/context`.

## Layout

```
Install.cmd        Windows double-click installer (Install.command on macOS)
setup/             setup.ps1 / setup.sh: detect, choose, install, verify
install.*          base installers (tools, MCP gateway, skills, plugins, services)
claude/            CLAUDE.md, RTK.md, settings.json (hooks, plugins, env), commands/, hooks/, mcpServers.json, plugins.json
skills/            user skills (third-party skills keep their own licenses)
bin/               helper scripts that the hooks call
mcptoon/           gateway config (upstream servers behind the gateway)
launchd/           caveman proxy and Lightpanda CDP daemon
tools/             brew, uv, npm and Ollama model lists with versions
windows/           Windows render of the same templates (install.ps1)
opencode/          OpenCode V2 surface (install-opencode.*)
cursor/            Cursor IDE + Cursor Code surface (install-cursor.*)
export.py          re-snapshot this machine into the repo
.agent/           handoff and durable project memory for any agent
CHANGELOG.md       what changed and whether you must act
INSTALL-FOR-AGENTS.md  steps for an agent given this repo
.config-branch     branch a ZIP download becomes a checkout of
```

## Known limits
- The Caveman proxy is a single point of failure for every request; savings are not measured here.
- OpenSpec and spec-kit overlap; both are kept on purpose.
- Caveman writes its own hooks per machine (`caveman setup`); the installer strips the copies in the repo and substitutes your Homebrew prefix. If Node moves, re-run the installer.

- Browser policy: Lightpanda is the primary browser. `playwright` needs `--isolated` against it (otherwise "No page on the STARTUP session"). This is the `comet` branch: main plus a fallback that attaches to Comet on debug port 9223; if Comet is already open without that port, quit it (Cmd+Q) and the next fallback call relaunches it normally. Launching Comet via automation (`--userDataDir`) once wiped its extensions and sign-in, so do not do that. Claude Desktop's own browser setting cannot be pointed at Lightpanda; the deny rules cover Claude Code only. `lightpanda mcp` and CDP attach were tested; screenshots and logged-in pages need the Comet fallback.

- Serena runs in its `claude-code` context, so through mcptoon it exposes `initial_instructions` and `serena_repl`; the symbol tools are called through the repl. Only `guard-pack` from claude-code-hooks is installed (it bundles the seven guard hooks); the other catalog plugins are not. Guard plugins block edits to hook and settings files by design: disable one for a session if you need to change them. Perplexity MCP and Semgrep Guardian were dropped because they need paid accounts.

## Keeping it current
Run `python3 export.py` after changing the stack, review `git diff`, commit. The script scans its output for secret-like strings and stops if it finds any. Never add `~/.claude.json`, transcripts, `obsidian.env` or `.env` files.

## Source repositories
Upstream repo for every tool in the stack. `install.sh` installs the Homebrew packages (rtk, ollama, gh) through `brew`; their sites are https://www.rtk-ai.app/ and https://ollama.com/. Links were taken from package metadata, `plugins.json`, the local clones and `gh repo view`.

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
| OpenSpec | https://github.com/Fission-AI/OpenSpec |
| spec-kit | https://github.com/github/spec-kit |
| ponytail | https://github.com/DietrichGebert/ponytail |
| figcraft | https://github.com/storytold/figcraft |
| fig-mcp | https://github.com/bilalba/fig-mcp |
| shadcn MCP | https://github.com/shadcn-ui/ui |
| Lightpanda | https://github.com/lightpanda-io/browser |
| Serena | https://github.com/oraios/serena |
| Superpowers | https://github.com/obra/superpowers |
| GSD Core | https://github.com/open-gsd/gsd-core |
| Candor | https://github.com/itsryanlenk/candor |
| anti-sycophancy | https://github.com/0xcjl/anti-sycophancy |
| pr-review-toolkit | https://github.com/anthropics/claude-plugins-official/tree/main/plugins/pr-review-toolkit |
| Semgrep (local MCP) | https://github.com/semgrep/semgrep |
| claude-code-hooks | https://github.com/karanb192/claude-code-hooks |
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
| harness-init, vault-context, vault-discover, obsidian-tooling | https://github.com/nickyeolk/agentic_doc_harness (`.claude/skills/`) |
| architecture-decision-records | https://github.com/affaan-m/ECC |
| humanizer, structural-humanizer | https://github.com/NulightJens/humanizer-stack (humanizer is based on https://github.com/blader/humanizer) |
| frontend-design | https://github.com/anthropics/skills |
| design-review | https://github.com/AslanMazhidov/design-review-skill |
| fig-parser | https://github.com/sunyui/figma-parser |
| figcraft | https://github.com/storytold/figcraft (skill pack: https://github.com/Vinciux99/artcraft-claude-skills, not tree-checked) |
| mcptoon | https://github.com/activeing123/mcptoon |
| astryx | https://www.npmjs.com/package/@astryxdesign/cli (installed by `tools/npm-global.txt`; the skill is generated by the CLI) |
| unslop | https://github.com/heydamir/unslop (CC-BY-4.0) |
| untangle-codebase | https://github.com/caldoai/skills (`skills/untangle-codebase`) |

Plugin-provided skills are not copied here; `install.sh` installs them from the marketplaces listed in `claude/plugins.json` (see Source repositories above).

Third-party skills keep their original licenses and copyrights; this repo's license does not apply to them. Check each skill's upstream repository for its terms before reusing it.
