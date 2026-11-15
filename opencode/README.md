# OpenCode V2 port

One source of truth: the OpenCode surface renders from what the repo already defines — `claude/mcpServers.json` (MCP entries), `claude/commands/` (adapted to OpenCode tool names), `claude/plugins.json` (which plugin dirs to expose), `skills/` and `bin/` (used as-is). `opencode/` holds only what OpenCode needs in its own shape. Remove it there and it is gone on macOS and Windows.

## Install (after the base installer)

The base install (`./install.sh` macOS, `pwsh ./install.ps1` Windows 11) must run first: the OpenCode surface reuses what it creates — `~/.claude/skills` (V2's global-compat skills source), the Claude plugin cache, `~/.claude-tools/bin/` helpers and `~/.mcptoon/config.json`.

```bash
./install-opencode.sh --dry-run && ./install-opencode.sh            # macOS
pwsh ./install-opencode.ps1 -DryRun; pwsh ./install-opencode.ps1   # Windows 11
```

Then **restart OpenCode** (config hot-reloads mid-session; a new plugin file needs the restart). Never writes `~/.claude`.

## What lands where

| OpenCode file (under `~/.config/opencode/`) | Source | Notes |
|---|---|---|
| `AGENTS.md` | `opencode/AGENTS.md` | V2 loads global `AGENTS.md` only — no `CLAUDE.md` fallback |
| `commands/*.md` (6) | `opencode/commands/` | `claude/commands` adapted: no `allowed-tools` frontmatter (OpenCode permissions are config-side), lowercase tool names |
| `plugins/claude-config.js` | `opencode/plugins/claude-config.js` | the bridge plugin (below); auto-discovered loose `.js`, runtime OS-adaptive — no rendering needed |
| `opencode.json` MCP entries | `opencode/render.py` renders `claude/mcpServers.json` | `mcptoon` + `lightpanda`; **caveman** and **gsd** entries are written by their own native installers |
| `opencode.json` `plugins[]` dirs | `opencode/render.py` resolves the base install's plugin paths | context-mode (npm global, `tools/npm-global.txt`), ponytail + superpowers (Claude plugin cache, latest installed version) |
| skills | none copied | V2 natively discovers `~/.claude/skills` (global-compat) and `.claude/skills` (project-compat) |
| GSD, RTK, Caveman | their own OpenCode installers | run by `install-opencode.*`: `npx -y @opengsd/gsd-core@latest --opencode --global`, `rtk init --global --opencode`, `caveman setup --yes --agents opencode` |

`opencode/render.py` merges into the user's `opencode.json` (backed up first) and only replaces what it owns: `mcp.mcptoon`, `mcp.lightpanda` and the three plugin-dir paths (id-aware: an existing entry for the same plugin id is replaced, not duplicated). Model, provider routes (caveman owns those), GSD's entries and anything else are preserved. It follows the file's existing MCP shape: server names directly under `mcp` (what installed 2.x accepts — GSD's and caveman's own writers do the same), or under `mcp.servers` if the file already uses that (newer schema).

## The bridge plugin (`plugins/claude-config.js`)

Maps V2 plugin events to the repo's Claude hook contracts, spawning the same scripts the Claude side uses (fail-open everywhere):

- `tool.execute.before` → guard-pack safety gate (`~/.claude/plugins/cache/claude-code-hooks/guard-pack/<latest>/guard-pack.js`): dangerous commands, secrets, test silencing, force-pushes. `deny` → throw (OpenCode blocks the call); `ask` → stderr advisory only (V2's before-hook has no ask surface).
- `tool.execute.after` (edit-class tools) → `~/.claude-tools/bin/agent-handoff tool` (edit log) + `jcodemunch-mcp hook-posttooluse` (background reindex).
- `session.prompt` → `agent-handoff prompt` nudge (delivered with the next request, caveman-native's pending pattern).
- `session.context` → inject the `.agent/handoff.md` + `.agent/memory/MEMORY.md` excerpt into every model request.
- `session.created` → `agent-handoff init` + `vault-bootstrap` + `spec-bootstrap` + `index-bootstrap` (each idempotent, self-filtering; via Git Bash on Windows, with `CLAUDE_PROJECT_DIR`).
- `session.deleted` → `agent-handoff end` (snapshot + detached summary).

Opt out of the session-start bootstraps with `CLAUDE_CONFIG_OC_BOOTSTRAP=0`.

## Gotchas

- **`timeout` must be a scalar.** Installed OpenCode 2.x rejects the timeout *object* (`{startup,catalog,execution}`) documented on the current website: the server silently vanishes from `mcp list` with a `configuration normalization diagnostic ... kind=invalid` log line. `render.py` writes `"timeout": 60000` (mcptoon's `tools/list` loads all 21 upstream manifests on first call — ~30s cold on Windows vs the default ~5s request timeout; warm answers are instant). Re-check the object shape on OpenCode upgrades.
- **`spec-init` records `--integration opencode` / `openspec init --tools opencode`**, which switches `.specify/integration.json` away from `claude` on machines that ran the Claude-side `spec-init`.
- caveman routing is per-agent (`127.0.0.1:8787/w/opencode/*`); `caveman setup` owns both the provider routes and its MCP entry.

## Not ported (claude-only, on purpose)

- `claude/hooks/context-mode-cache-heal.mjs` — Claude plugin cache specific; V2 has no equivalent cache.
- `claude/hooks/caveman-statusline.sh` — Claude Code statusline only.
- Real sessionbridge migration (`migrate-session` command is a stub on OpenCode; sessionbridge is Claude ↔ Codex).

## Verify

1. `opencode mcp list` — caveman, gsd, lightpanda, mcptoon connected.
2. Restart OpenCode; in a project with `.agent/`: the handoff excerpt appears in context, a `git push --force` is denied with a guard-pack reason, edits land in `.agent/.buffer/<session>.jsonl`.