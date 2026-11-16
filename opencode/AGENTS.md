# claude-config — global instructions for OpenCode

This machine runs the claude-config stack (source of truth: the repo recorded in `~/.claude-tools/config-repo`). Same rules as the Claude Code side; only the surface differs.

## Command output

Command output is condensed to save tokens (RTK + Caveman), keeping every signal and dropping costly noise. Treat condensed results as the complete result: run commands normally, and batch related commands into one call. Truncated results state their own recovery path in their own output. Re-run a command as `rtk bypass <cmd>` only when its result is unusable: empty when output was clearly expected, contradicting its exit code, or garbled.

## Code exploration policy

jCodeMunch-MCP (behind the mcptoon gateway) indexes repo symbols and relations. Use it where cheaper; built-in tools (grep, glob, read) where those are cheaper.

- **Relationships = index purpose:** who imports a symbol, where a name is used, what a change breaks, who calls a function, what is unreachable.
- **Known name, or file about to work in:** built-in search + read is often as cheap. Take fewer steps.
- Before the first jCodeMunch call in a session: `order {"action":"resolve_repo","args":{"path":"."}}`; if not indexed: `order {"action":"index_folder","args":{"path":"."}}`.
- Know the goal, not the tool: `route {"query": "<task in a sentence>"}` picks the action and shapes arguments. See what exists: `menu`.

## MCP surface

One gateway (mcptoon) fronts the local MCP servers — jcodemunch, context-mode, serena, kwipu, lumen, mcp-obsidian, semgrep, figcraft, browsers, and more: call a server tool as `mcptoon call <server> <tool> '<json>'`, list servers with `mcptoon list`, health with `mcptoon doctor`. Direct MCP servers: caveman (compression), lightpanda (browser). Details: skill `mcptoon`.

## Browsing

Use Lightpanda first (CDP `127.0.0.1:9222`). Fallback: Comet on `127.0.0.1:9223` — never launch Comet through an automation-created profile. Prefer `127.0.0.1` over `localhost` on this machine: local interception may answer `localhost` with "500 Request Blocked".

## Project memory and handoff (projects with `.agent/`)

1. Read `.agent/handoff.md` (where work stopped, next steps, open decisions), then `.agent/memory/MEMORY.md` (durable rules and facts). An excerpt is injected at session start; read the full files before changing anything.
2. Hard rules live in `.agent/memory/` — obey them before anything else.
3. Record durable facts one-per-file in `.agent/memory/`, index them in `MEMORY.md`; update the handoff before stopping. Never write inside `map/`.
4. Layout: `.agent/memory/` agent memory; `.agent/graphs/` graph/diagram sources; the repo root is also the Obsidian vault.
5. Durable facts the user states: `obsidian-wiki memory profile set <key> "<value>"`; open threads: `obsidian-wiki memory todo add|done`; non-obvious fixes: `wiki-capture --quick`. Relationship questions about code (who calls X, what breaks): Serena, codegraph or jCodeMunch through the gateway before grep loops.
6. Tool roles: exact string or known file = grep/read; "how does X work" = `codegraph_codegraph_explore`; symbols, references, refactors = Serena; callers, impact, dead code = jCodeMunch (`fallow_*` for JS/TS); semantic search = `lumen_semantic_search`; library docs = `context7`; large output = context-mode `ctx_execute`; browser = `lightpanda_*` through the gateway. Gateway form: `mcptoon_call {name: "<server>_<tool>", arguments}`.

## Anti-sycophancy

Confirmation-seeking statements ("X is right, isn't it?") become open questions (what would change my mind?). See skill `anti-sycophancy`.

## Hygiene

- Never commit secrets; memory files can contain pasted text — scan before pushing.
- Prefer the `~/.claude-tools/bin/` helpers over ad-hoc reimplementation (`config-sync`, `agent-handoff`, `comet-cdp`, …).
- Keep Ollama pinned (repo pin: `tools/brew.txt` / `tools/ollama-models.txt`).