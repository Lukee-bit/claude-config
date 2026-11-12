## Code Exploration Policy

jCodeMunch-MCP indexes repo symbols and relations. Use where cheaper; built-in tools (Grep, Glob, Read) where those cheaper.
- **Relationships = index purpose:** who imports symbol, where name used, what change breaks, who calls function, what unreachable.
- **Known name, or file about to work in:** built-in search + `Read` often as cheap. Take fewer steps.
- **Small repo:** built-in tools usually cheaper for finding, reading code.
- Harness requires `Read` before `Edit`/`Write`.

Server runs **front door** surface: three tools reach every jCodeMunch capability, so tool list small, catalogue fetched only when needed.

**Before first jCodeMunch call in session** (skip when task needs none):
- `order { "action": "resolve_repo", "args": { "path": "." } }` — confirm project indexed. If not: `order { "action": "index_folder", "args": { "path": "." } }`

**Then, for task index suits:**
- Know what want → `order { "action": "<name>", "args": { ... } }`
- Know goal, not tool → `route { "query": "your task in a sentence" }` picks action, shapes arguments
- See what exists → `menu { "query": "what you are trying to do" }` returns matching actions with example arguments
- Whole catalogue, usage rules → `jcodemunch_guide`

`menu`, `jcodemunch_guide` list every action server can run, including ones absent from tool list. Expected: front door is way to call them.

**Interpreting results:**
- Search proves absence only when scan citable: `_meta.verdict.evidence_ref` holds `absent:` token, or, where `_meta.verdict` not shown, `_meta.absence_evidence.citable` is `true`. Then report gap; no re-search with different wording. `no_implementation_found` verdict, `state` of `absent` or empty result not proof alone: read note `absence_blocked_by`, re-index if it names index, search again.
- `source: ""` with `source_status` = body unreadable, not empty symbol.

**After editing files:**
- With PostToolUse hooks installed (Claude Code), edited files reindexed automatically.
- Otherwise `order { "action": "register_edit", "args": { "paths": [...] } }` after edit, batched for bulk changes.

**Optional:** announce model once so server sizes answers: `announce_model { "model": "<your-model-id>" }`.

@RTK.md

## Skill catalog (mcptoon)

Machine has skill catalog managed by mcptoon. Before acting on task,
find right skill first — no guessing, no reading whole catalog:

    mcptoon skills resolve "<the user request>" --k 5

Read only SKILL.md files it returns. Nothing found: rephrase, retry,
or run `mcptoon skills list` to pick name by eye. Tools behind
same gateway: `mcptoon manifest` lists them.
## Browser policy (mandatory, all tools, skills, plugins, MCPs, subagents)

Primary browser = Lightpanda (`lightpanda` MCP; `playwright`/`chrome-devtools` via mcptoon are wired to its CDP server at http://127.0.0.1:9222, daemon `io.lightpanda.serve`). Always use it first for any browsing, scraping, page reading, or automation.
Fallback ONLY when Lightpanda cannot do the job (needs real rendering, screenshots, heavy JS, logins): Comet via `playwright-comet` / `chrome-devtools-comet` (mcptoon). State why before falling back.
Never use claude-in-chrome, built-in Claude_Browser, the plugin playwright, or any other browser (denied in settings.json). Skills that name another browser: substitute this policy.
