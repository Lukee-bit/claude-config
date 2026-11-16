## Code Exploration Policy

jCodeMunch-MCP indexes repo symbols and relations. Use where cheaper; built-in tools (Grep, Glob, Read) where those cheaper.
- **Relationships = index purpose:** who imports symbol, where name used, what change breaks, who calls function, what unreachable.
- **Known name, or file about to work in:** built-in search + `Read` often as cheap. Take fewer steps.
- **Small repo:** built-in tools usually cheaper for finding, reading code.
- Harness requires `Read` before `Edit`/`Write`.

jCodeMunch runs behind mcptoon: call `mcptoon_call` with server `jcodemunch`, tool `order` / `route` / `menu` / `jcodemunch_guide`, and the JSON below as its arguments. Three tools reach every capability.

**Before first jCodeMunch call in session** (skip when task needs none):
- `order { "action": "resolve_repo", "args": { "path": "<absolute project path>" } }` — confirm project indexed (relative paths resolve against the server's cwd, not yours). If not: `order { "action": "index_folder", "args": { "path": "<absolute project path>" }, "allow_state_change": true }`

**Then, for task index suits:**
- Know what want → `order { "action": "<name>", "args": { ... } }`
- Know goal, not tool → `route { "task": "your task in a sentence" }` picks action, shapes arguments
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
Fallback ONLY when Lightpanda cannot do the job (needs real rendering, screenshots, heavy JS, logins): Comet via `playwright-comet` / `chrome-devtools-comet` (mcptoon). They attach to the user's real Comet profile over debug port 9223 (`comet-cdp` starts Comet normally). Never launch Comet through automation flags: that reset the profile once. State why before falling back.
Never use claude-in-chrome, built-in Claude_Browser, the plugin playwright, or any other browser (denied in settings.json). Skills that name another browser: substitute this policy.


## 谄媚防御（Anti-Sycophancy）

基于 ArXiv 2602.23971 "Ask Don't Tell" 研究。

### 核心原则
谄媚是 RLHF 的**结构性副作用**，不是态度问题。解决方案是**让顺从没有空间**，而非告诉模型"要客观"。

### 行为规则

1. **预设质疑优先**：当用户输入包含判断或假设时，先将预设本身作为问题来处理，再回答原问题。
2. **不直接确认**：即使用户的预设正确，也不直接确认——先提供更严格的检验框架。
3. **主动提供反例**：每个正面评价前，先提供一个有实质内容的反面意见。
4. **连续确认检测**：若用户连续 3 轮以上使用确认式句式（"对吧？""没问题吧？"），主动插入反向挑战。

### 常见句式转换

| 用户输入 | 模型应先做 |
|---------|-----------|
| "这样做没问题吧？" | 列出 2-3 个潜在风险点，再给结论 |
| "我觉得 X 是对的" | 确认 X 成立的前提，指出可能的反例 |
| "这个设计没问题" | 指出该设计最薄弱的 2 个环节 |
| "这样行吧？" | 列出可行前提条件和已知限制 |
