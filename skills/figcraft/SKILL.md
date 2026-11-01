---
name: figcraft
description: Design interfaces, components and prototypes with FigCraft (Figma-style, ArtCraft suite, not the official Figma tools) through MCP, the CLI or the control channel, and set up, connect or troubleshoot its MCP server on Windows and macOS.
---

# FigCraft for Claude

FigCraft (ArtCraft suite, storytold/figcraft) is a clean-room, open-source Rust reimplementation of **Figma Design**: frames and sections, auto layout (including wrap and grid), components/variants/instances/slots, vector networks and booleans, styles and variables with modes (Light/Dark), prototypes, Dev Mode (CSS/HTML/React/Leptos/SwiftUI/Compose code), comments, versions, branches, live sessions. Native format `.figcraft` (archive); imports SVG, images, `.fig` (best effort) and Figma REST-API JSON; exports PNG, JPG, WebP, SVG, PDF and `.fig` (experimental). Status: **alpha**. It is not Figma: no account, no cloud.

**Every action is a command** with an `id` (e.g. `node.set`, `layout.add`) and JSON parameters: one registry of 400+ commands used by menus, shortcuts, the Actions palette, CLI, control channel and MCP.

> Note: some sessions also have the **official Figma** MCP/skills (`use_figma`, `get_design_context`, `figma:*` skills). This skill is for **FigCraft, a different local app**: tools like `run_command`, `create_node`, `inspect_document`. Do not mix them and do not load `figma:*` skills for FigCraft.

## Quick check: is the MCP server connected?

1. Look at the tools you have. If tools from the MCP server `figcraft` are available (for example `list_commands`, `execute` or `inspect_*` tools) the server is connected: skip to "Operating knowledge" below and use them directly.
2. If they are missing, check whether the user installed it under the name `figcraft` or `figcraft-headless`. In Claude Desktop the server may show as **disconnected**.
3. **Most common cause of "disconnected":** the live server (`mcp --attach {port}`) exits when FigCraft is not running at the moment Claude starts. Fix: open FigCraft with the **"FigCraft (Claude)" launcher** (it starts the app with its control channel on), then re-enable the server in Claude's settings or fully quit and reopen Claude.
4. If the user does not need to watch the app live, **headless mode** always starts (no window, works on files). See "Live, headless or both".
5. If nothing is configured yet, follow "Set up the MCP server" below. Ask the user which OS they use if you do not know.

## Set up the MCP server (guide the user)

Walk the user through this step by step. Ask for the OS (Windows or macOS) first. If you have a shell on the user's machine you may run the steps yourself, but **ask before editing any config file and always back it up first**. Never print tokens or keys in chat.

### 1. Prerequisites
- Install FigCraft from its upstream releases page: https://github.com/storytold/figcraft/releases (Windows: the `.msi` installer; macOS: the `.dmg`, then drag the app to `/Applications`).
- Install Claude Desktop and/or Claude Code. For Claude Desktop, fully quit and reopen it after any config change.
- The MCP server is the **CLI** that ships with the app: `figcraft-cli`. Windows installs it next to the app (`C:\Program Files\FigCraft\figcraft-cli.exe`, not on `PATH`). On macOS the CLI is a separate release download (asset `figcraft-cli-<version>-macos-universal.zip`) unless it is bundled in the app (unverified): the setup script below fetches it into `~/.artcraft/bin/` and clears the macOS quarantine flag.
- Upstream docs use port 7979; this kit uses **7984** so that all 13 ArtCraft apps can run together without clashing.

### 2. Option A: automatic setup (recommended)
The setup script finds the app and CLI, creates the launcher, backs up and updates Claude Desktop's config, registers the server in Claude Code (if the `claude` command exists) and installs this skill. Preview first with a dry run: nothing is changed.

Windows (PowerShell):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Vinciux99/artcraft-claude-skills/main/install.ps1))) -Apps figcraft"
```
macOS (Terminal):
```sh
curl -fsSL https://raw.githubusercontent.com/Vinciux99/artcraft-claude-skills/main/install.sh | bash -s -- --apps figcraft
```
Or clone/download this repository and double-click `setup-windows.cmd` (Windows) or `setup-macos.command` (macOS; first time: right-click, Open). Useful options: `-Mode live|headless|both` / `--mode ...` (default `live`; `both` registers `figcraft` live and `figcraft-headless`), `-DryRun` / `--dry-run`, `-NoLauncher`, `-NoClaudeDesktop`, `-NoClaudeCode`, `-NoSkill` (macOS: `--no-launcher`, `--no-claude-desktop`, `--no-claude-code`, `--no-skill`).

What it changes: Claude Desktop config (`%APPDATA%\Claude\claude_desktop_config.json` plus the Microsoft Store/MSIX copy under `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\`; macOS `~/Library/Application Support/Claude/claude_desktop_config.json`; backup saved next to it as `<file>.backup-<timestamp>`), the launcher "FigCraft (Claude)" (Windows: Desktop shortcut; macOS: `~/Applications/FigCraft (Claude).app` plus a Desktop alias), Claude Code's user-scope MCP list, and `~/.claude/skills/figcraft/`.

### 3. Option B: manual setup
**Windows** - edit `%APPDATA%\Claude\claude_desktop_config.json` (if Claude was installed from the Microsoft Store, also the copy under `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\`). Keep other servers; add this inside `mcpServers`. Backslashes must be doubled in JSON.
```json
{
  "mcpServers": {
    "figcraft": {
      "command": "C:\\Program Files\\FigCraft\\figcraft-cli.exe",
      "args": [
        "mcp",
        "--attach",
        "7984"
      ]
    },
    "figcraft-headless": {
      "command": "C:\\Program Files\\FigCraft\\figcraft-cli.exe",
      "args": [
        "mcp"
      ]
    }
  }
}
```
**macOS** - edit `~/Library/Application Support/Claude/claude_desktop_config.json`. Use the absolute CLI path (replace `YOUR_NAME`; JSON does not expand `~`). The CLI path is unverified if your install differs: check with `ls ~/.artcraft/bin /Applications/FigCraft.app/Contents/MacOS`.
```json
{
  "mcpServers": {
    "figcraft": {
      "command": "/Users/YOUR_NAME/.artcraft/bin/figcraft-cli",
      "args": [
        "mcp",
        "--attach",
        "7984"
      ]
    },
    "figcraft-headless": {
      "command": "/Users/YOUR_NAME/.artcraft/bin/figcraft-cli",
      "args": [
        "mcp"
      ]
    }
  }
}
```
**Launcher** (starts the app with the control channel; needed before the live server can connect):
- Windows: create a Desktop shortcut named "FigCraft (Claude)" with target `"C:\Program Files\FigCraft\figcraft.exe" --control 7984`
- macOS: run `open -n -a "/Applications/FigCraft.app" --args --control 7984`, or save it as an app with Script Editor/`osacompile` (the setup script does this for you).

**Claude Code** (any OS; run once):
Windows (PowerShell):
```powershell
claude mcp add --scope user figcraft -- "C:\Program Files\FigCraft\figcraft-cli.exe" mcp --attach 7984
claude mcp add --scope user figcraft-headless -- "C:\Program Files\FigCraft\figcraft-cli.exe" mcp
```
macOS (Terminal):
```sh
claude mcp add --scope user figcraft -- "$HOME/.artcraft/bin/figcraft-cli" mcp --attach 7984
claude mcp add --scope user figcraft-headless -- "$HOME/.artcraft/bin/figcraft-cli" mcp
```
Check with `claude mcp list`.

### 4. Authentication
FigCraft needs no token: the control channel listens on loopback (`127.0.0.1`) only and has no authentication. Anyone on the machine can drive the app while it is open, so close it when you are done.

### 5. Finish and verify
1. **Fully quit and reopen Claude** (Desktop: quit from the tray/menu bar, not just close the window).
2. Open FigCraft with the **"FigCraft (Claude)" launcher** before asking Claude to use it.
3. In Claude, confirm the server `figcraft` is connected and call its `list_commands` tool (or equivalent). A non-empty command list means it works.

### Live, headless or both
- **Live** (`figcraft`): drives the open app; the user sees every change and screenshots/UI tools work. Needs the launcher first.
- **Headless** (`figcraft-headless`): in-process engine, no window; always starts; works on files; UI/screenshot tools are not available.
- **Both**: register both and pick per task. Switch with `-Mode` / `--mode`, or by editing the config entries above.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Server shows "disconnected" right after Claude starts | Live server exits when FigCraft is not running | Open FigCraft with the "FigCraft (Claude)" launcher, then re-enable the server or restart Claude; or use headless mode |
| "Port already in use" / app opens but Claude cannot connect | Another app or an old FigCraft instance holds port 7984 | Quit all FigCraft windows, check the launcher uses the kit port, make sure no other ArtCraft app uses the same port |
| `command not found` / spawn error | CLI path wrong or the CLI is not installed (Windows: not on `PATH`; macOS: separate download) | Use the full absolute path in the config; macOS: run the setup script (it downloads the CLI to `~/.artcraft/bin/`) |
| macOS: "cannot be opened because the developer cannot be verified" | Gatekeeper/quarantine on the app or CLI | Right-click the app, Open; for the CLI: `xattr -dr com.apple.quarantine ~/.artcraft/bin/figcraft-cli` |
| Anyone else can drive the app | The control channel has no authentication (loopback only) | Start the app with the control channel only when needed and quit it when done |
| Config edited but nothing changed (Windows) | Claude installed from the Microsoft Store reads the MSIX copy of the config | Edit/update `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\claude_desktop_config.json` too |
| JSON config error / server not listed | Unescaped backslashes or trailing comma | Double the backslashes on Windows; validate the JSON; restore the `.backup-*` file if needed |
| App crashes on start or window is blank | Graphics backend problem | Windows: set `WGPU_BACKEND=vulkan` (or `dx12`) for one launch; avoid `gl` on some AMD drivers |
| Changes do not appear in the window | You are on the headless server | Use the live server (launcher first) |
| Quotes disappear in PowerShell JSON arguments | Windows PowerShell 5.1 quoting for `.exe` | Use `--script`/files where the CLI supports them, or single-quote the whole JSON |

## Operating knowledge

## App, settings, environment
- Other app arguments: a file to open (`.figcraft`, `.svg`, image; also `file://`), an invite link `figcraft://join?...` (joins the session), `--version`.
- Settings folder: Windows `%APPDATA%\FigCraft`; macOS `~/Library/Application Support/FigCraft` (unverified). It holds `Plugins/` and `state.json` (preferences **including owner tokens of online files**: never read or print it). Logs: not documented.
- Env: `FIGCRAFT_NO_SYSTEM_FONTS=1` (internal fonts only, identical renders everywhere; also applies to the app), `FIGCRAFT_CA_FILE` (CA for private `wss://` servers), `FIGCRAFT_SERVER_KEY` (key for `plugin publish`).

## Connecting

| Mode | How to start | What it does |
|---|---|---|
| **MCP headless** | `figcraft-cli mcp` (optional `--no-system-fonts`) | In-process engine, one untitled document, no window, CPU rendering |
| **MCP attached to the app** | app with `figcraft --control 7984`, then `figcraft-cli mcp --attach 7984` (also accepts `host:port`) | Drives the open app: the user sees every edit live; enables `screenshot {window: true}` and full `inspect_ui` |
| **CLI** | `figcraft-cli info / export / convert / render / run / commands` | One-shot jobs, no window |
| **Control channel** | `figcraft --control 7984 [file]` | JSON lines over TCP `127.0.0.1:7984` |

- **Port:** upstream docs use **7979** (and the README uses `--attach 47800` as an example); this kit uses **7984** because 7979 belongs to VectorCraft.
- **Authentication: none**, no token; the channel listens on `127.0.0.1` only. Enable it only when needed.
- **Read/write roots for automation: not documented.** Commands read/write the paths you pass: it is on you not to overwrite originals.
- In attached mode a call that fails with a transport error **is not retried** (the app may have applied it): inspect the document before retrying. The next call reconnects by itself.
- The live MCP server (`--attach`) exits if the app is not open when Claude starts: open the app with the launcher first.
- Web build: no control channel, no file system.

### Choosing the channel
1. **An MCP server is available** (tools `list_commands`, `run_command`, `create_node`, ...) → use it.
2. **A shell on the user's machine** → the CLI with its full path; for multi-step jobs write a JSON script and use `run`. Without MCP, talk to the channel with a TCP socket (snippet in "Control channel").
3. **A cloud-sandbox shell** is another machine: it cannot run the user's app or reach `127.0.0.1:7984`. It can only prepare files (`run` JSON scripts, SVG, images, variable JSON).
4. **Fallback: computer use** on the GUI. Non-US keyboards: shortcuts with `[` `]` (e.g. Bring to front Ctrl+Shift+], list indent Cmd+]) and AltGr ones may not arrive: prefer commands and menus.

## Ground rules
- **Units and coordinates:** page units (1 unit = 1 px at 100%), x right, **y down**. `x`/`y` of `create_node` / `node.set` are **relative to the parent frame** (to the page if none). Groups and boolean groups have no space of their own: children are positioned in the containing frame (or page). `get_node` also gives `absoluteBounds` in page coordinates. `pointer` works in page coordinates.
- **Auto layout:** children are positioned by the layout: use `layout` (`horizontal`/`vertical`/`grid`), `gap`, `padding`, `mainAlign` (`min|center|max|spaceBetween|spaceEvenly|spaceAround`), `crossAlign` (also `baseline`), `sizingH`/`sizingV` (`fixed|hug|fill`), `wrap` + `crossGap`, `absolute: true`, `min/maxWidth/Height`. Grid: `gridColumns`, `gridRows`, `columnTracks`/`rowTracks` (`[120, "1fr", "auto"]`), on children `gridColumn`/`gridRow` (0-based), `gridColumnSpan`/`gridRowSpan`. A `fill` child makes a hugging parent `fixed`.
- **References:** layers have **numeric ids** (result of creator commands, `{"id": N}`); in the CLI `--node` accepts `12`, `0:12` or the name. In a new document the first page is id 1 and the first layer 2, then in order (useful in `run` scripts). Styles `S:<n>`, variables `VariableID:<n>` (large numbers in live sessions: pass them as-is). Variables, collections and modes can also be given by name.
- **Target:** most commands act on `ids` if given, otherwise on the **selection**; new layers become the selection.
- **Colors:** `"#RRGGBB"` / `"#RRGGBBAA"`; over MCP gradients are written `{"type": "linearGradient", "stops": ["#7048E8", "#1098AD"]}`. Fill/stroke/effect/grid lists go **bottom-up**: index 0 is painted first (the panel shows them reversed).
- **Undo:** each mutation = one step; `batch` (= `command.batch`) = one step, all-or-nothing on the document (not on preferences, clipboard, tool state). A failed command leaves the document unchanged. Tools `undo`/`redo`, commands `edit.undo`/`edit.redo`; in a live session they undo only your steps.
- **Strict parameters or not: undocumented.** Type errors are JSON-RPC errors, but it is not written whether unknown keys are ignored: check names with `list_commands` / `figcraft://command/{id}` and verify the effect with `get_node`.
- **`$N` references in batches: not documented** (neither in `batch` nor in `run`). Use separate calls reading the returned id, or in `run` scripts the predictable ids of a new document.
- **Never dialogs from a program:** commands ask for UI but the channel discards it; only `ui.menu.invoke` acts like a click (may open a dialog). `object.rename` without `name` does nothing in headless.
- **Text in the app:** `text.create` / `node.create {type: text}` without `fill` in the app with a dark page gives **white** text (black headless): always pass a `fill`. New pages are `#F5F5F5` (dark only with the dark theme).
- **Instances:** you can override fill, stroke, effects, opacity, visibility, names, radii, text, padding/gap/alignment, interactions; moving/resizing/adding layers inside an instance (outside slots) is **rejected**: edit the main component or the whole instance.
- **Long jobs:** channel: UI timeout 60 s per request, queue max 8. Templates 10–190 ms; system fonts are indexed at the first text. Calls to servers (team library, collab) wait a few seconds.
- **Risks:** `collab.share` (default `via: "online"`) **uploads the file to the public server `collab.craftapps.dev`**, not end-to-end encrypted: only if the user asks. `plugin.directory.install` needs `confirm: true` only after showing the permissions to the user. `app.quit` closes **without** asking to save. `.fig` files open best-effort, `.fig` export is experimental.

## MCP tools (18 + 4 resources + 4 prompts)

| Tool | Arguments | Notes |
|---|---|---|
| `list_commands` | `filter?` | id, label, menu, shortcut, undoable, params doc |
| `run_command` | `command`, `params` | Any command |
| `batch` | `commands: [{command, params}]`, `label?` | One undo step, all-or-nothing |
| `create_node` | `type`, `x`, `y`, `width`, `height`, `parent`, `index`, `name`, `text`, `path`, `props` | `type`: frame, rectangle, ellipse, polygon, star, line, arrow, text, vector, section, component, slice → `{id, node}` |
| `set_properties` | `ids`, `props` | = `node.set`: geometry, fill, stroke, effects, radii, auto layout, sizing, constraints, masks (`isMask`, `maskType`), `devStatus`, text |
| `inspect_document` | `depth`, `allPages` | Layer tree, styles, selection, history |
| `get_node` | `id`, `depth` | One layer (overrides, boundVariables, interactions, annotations, ...) |
| `select` | `ids` | `[]` deselects |
| `export` | `ids`, `format` (png/jpg/svg/webp/pdf/fig), `scale` or `size` (`2x`, `512w`, `512h`), `path?`, `bleed?`, `cropMarks?`, `bleedMarks?`, `cmyk?`, `contentsOnly?`, `includeBoundingBox?`, `svgOutlineText?`, `svgIdAttribute?`, `svgSimplifyStroke?` | Without `path`: inline image (SVG as text) |
| `screenshot` | `ids?`, `scale?`, `maxSize?` (default 1600), `window?` | PNG of page/layer; `window: true` = app window (attached only) |
| `open_file` / `save_file` | `path`, `variables?` / `path?` | Opens `.figcraft`, `.json`, `.fig`, `.svg`, images; saves `.figcraft` |
| `undo` / `redo` | — | |
| `pointer` | `kind` (click/double/drag/down/move/up/hover), `x`, `y`, `to?`, `steps?`, `tool?`, `shift`, `alt`, `cmd`, `pressure?`, `pressureTo?` | Gestures with the current tool, page coordinates |
| `key` | `key`, `shift`, `alt`, `cmd` | As typed on the canvas; `cmd` = Ctrl on Windows; names like `A`, `Enter`, `ArrowLeft`, `Plus` |
| `type_text` | `text`, `id?` | Into the text being edited, or replaces the content of layer `id` |
| `inspect_ui` | — | Tool, view, state; attached also panels, timing, `windows` |

Resources: `figcraft://document`, `figcraft://commands`, `figcraft://node/{id}`, `figcraft://command/{id}`. Prompts: `mobile_screen` (`screen`, `device`, `brand_color`), `design_system` (`name`, `primary`), `landing_page` (`product`, `width`, `accent`), `prototype_flow` (`screens`, `transition`): they return a step-by-step plan. Tool errors: `isError: true` with a message. The real schema is in `tools/list`.

## Recipes (from the docs)

Card with auto layout, text and verification:
```text
create_node {"type":"frame","name":"Card","x":100,"y":100,"width":320,
             "props":{"fill":"#FFFFFF","cornerRadius":16,"layout":"vertical","padding":24,"gap":12,"sizingV":"hug",
                      "effects":[{"type":"dropShadow","color":"#00000026","offset":[0,4],"radius":16}]}}   → id 2
create_node {"type":"text","parent":2,"text":"Ada Lovelace","props":{"fontSize":24,"fontStyle":"Bold","fill":"#111111"}}
get_node    {"id":2,"depth":2}
screenshot  {"ids":[2]}
```

Component + instance with overridden text (the instance's text id from `get_node`):
```text
run_command {"command":"component.create","params":{"ids":[2]}}
run_command {"command":"instance.create","params":{"component":2,"x":500,"y":100}}
type_text   {"id":7,"text":"Grace Hopper"}
```

Align and distribute in one step:
```text
batch {"label":"Tidy","commands":[{"command":"align.top","params":{"ids":[3,4,5]}},
                                  {"command":"distribute.horizontal","params":{"ids":[3,4,5]}}]}
```

Start from a template (`mobile-app`, `landing-page`, `dashboard`, `design-system`, `wireframe-kit`, `social-posts`, `slides`, `icon-set`):
```text
run_command {"command":"template.list"}
run_command {"command":"file.newFromTemplate","params":{"template":"dashboard"}}
export      {"format":"png","path":"/Users/me/Desktop/dashboard.png"}
```

Draw like a user (channel): `engine.execute {command: "tool.set", params: {tool: "ellipse"}}` then `ui.pointer {kind: "drag", x: 200, y: 200, to: [300, 260], shift: true}`. `tool.place {tool?, x?, y?}` = Enter with a shape tool (100×100 centered).

More documented (exact parameters: `list_commands {"filter": "..."}`):
- **Text:** properties on the whole layer or on `start`..`end` (`text.style {id, start, end, ...}`); `fontVariations` `{"wght": 550}`; `features {"liga": false}`; lists `listStyle` (`none|bulleted|numbered`), `indentation` 0–8; `text.fonts {family, axes: true}`; text on a path `text.onPath {start?, flip?}`.
- **Styles:** `style.create {type: "text", name}`, `style.apply {style, ids?, start?, end?, target?}`, `style.detach {which}`, `style.update`; editing a styled fill **detaches** the style.
- **Variables:** `variable.bind {ids, field, variable}` (fields `fill`, `fills/<i>/color`, `effects/<i>/radius`, `layoutGrids/<i>/gutter`, `componentProperties/<name>`, `strokeWeight`, `arcSweep`, ...), `variable.addMode {from}`, `variable.setMode` (`mode: null` = Auto), `variable.export {format: json|css, path?}`, `variable.import {variables}`.
- **Effects:** `effect.add {type}` (`dropShadow`, `innerShadow`, `layerBlur`, `backgroundBlur`, `noise`, `texture`, `glass`); progressive blur `{"blurType":"progressive","startRadius":0,"radius":24,"startOffset":[0.5,0],"endOffset":[0.5,1]}`.
- **Booleans and vectors:** `bool.union/subtract/intersect/exclude {ids?}`, `bool.flatten`; `shapeBuilder.regions` → `shapeBuilder.merge {ids, points}`; `vector.edit.begin` ... `vector.edit.end`.
- **Prototypes:** `proto.interaction.add` (actions `navigate`, `openOverlay`, `scrollTo`, `setVariable` with `expression: "count + 1"`, `setVariableMode`, `conditional`), `proto.flow.add`, `proto.settings {device: "iPhone 16", rotation?, responsive?}`, `proto.evaluate {expression}`, `proto.preview`.
- **Dev Mode:** `inspect.code {id, language: react|leptos|swiftui|compose}` (also CSS/HTML, `unit: rem`), `inspect.properties {colorFormat}`, `node.set {devStatus: readyForDev}`, `annotation.add`, `dev.compare`.
- **Layer export settings:** `export.add/update/remove`, `file.exportLayers {ids?, dir?, assets?}`, `file.exportFramesPdf {page?, path?}`; print PDF `bleed: "3mm"`, `cropMarks`, `cmyk` (naive CMYK, no profile).
- **Versions/branches:** `file.saveVersion {name}`, `version.list/restore`, `branch.create` → `branch.review` → `branch.merge {resolutions}`.

## CLI
Exit 2 = wrong arguments (prints usage), 1 = error. Every subcommand accepts `--no-system-fonts`.
```sh
figcraft-cli info app.figcraft [--json]                         # pages, top-level frames with ids, counts
figcraft-cli export app.figcraft -o exports/ --scale 2         # one PNG per top-level frame of the first page
figcraft-cli export app.figcraft -o hero.svg --node "Hero"
figcraft-cli export app.figcraft -o screens.pdf --page "Screens"
figcraft-cli export app.figcraft -o poster.pdf --node "Poster" --bleed 3mm --crop-marks --cmyk
figcraft-cli convert design.svg design.figcraft                # by extension: .figcraft .json .fig .svg images → .figcraft .json .svg .png/.jpg/.webp .pdf .fig
figcraft-cli render landing.figcraft -o landing.png --scale 2 [--page NAME]
figcraft-cli run build-card.json [--in base.figcraft] --out card.figcraft
figcraft-cli commands --filter autoLayout [--json]
figcraft-cli mcp [--attach 7984]
```
(Windows: `& "C:\Program Files\FigCraft\figcraft-cli.exe" ...`.)
- `export`: `--format png|jpg|svg|webp|pdf|fig`, `--scale` (default 1, max 64, raster only), `--page`, `--node` (id or name), `--bleed` (pt or `3mm`/`0.125in`, max 2 in), `--crop-marks`, `--bleed-marks`, `--cmyk`. `-o` folder = one file per frame; `-o` with extension = one file (`--node` or whole page).
- `run`: script = JSON array of `{"command", "params"}`, or `{"commands": [...]}`, or JSON lines (blank lines and `//` skipped). Prints one JSON line per step (`{"command","ok","result","step"}`); at the first error it exits 1 and **does not save**. It can begin with `file.newFromTemplate`. Example:
```json
[
  {"command": "frame.create", "params": {"preset": "iPhone 16", "x": 0, "y": 0, "name": "Home"}},
  {"command": "node.create", "params": {"type": "text", "parent": 2, "x": 24, "y": 64, "text": "Welcome", "props": {"fontSize": 32, "fill": "#111111"}}},
  {"command": "layout.add", "params": {"ids": [2], "direction": "vertical"}}
]
```
- Others: `plugin publish <folder> --server ws://host:port/` (key from `FIGCRAFT_SERVER_KEY`), `perf`.
- `run` is one-shot: no `collab.*` or plugin directory (they need `mcp`). There is no subcommand to talk to the open app: use `mcp --attach` or the socket.

## Control channel
- TCP `127.0.0.1:<port>` (here 7984), **JSON lines**: one request per line, one response per line, in order. Request `{"id": 1, "method": "...", "params": {...}}` → `{"id": 1, "ok": true, "result": ...}` or `{"id": 1, "ok": false, "error": "..."}`. Invalid JSON → `{"id": null, "ok": false, "error": "bad JSON: ..."}`.
- Limits: line max **32 MiB** (beyond: error and close), max **8 connections**, socket idle timeout 60 s, UI timeout 60 s, queues of 8 (`"control request queue is full"`). No authentication.
- Requests run on the UI thread at the next frame: replies reflect real state.
- Every method accepts `window` (id from `window.list`, `0` = main); without it, it goes to the foreground window.

| Method | Params | What it does |
|---|---|---|
| `engine.execute` | `{command, params?}` | Run a command; dialogs discarded; creators → `{"id": N}` |
| `engine.commands` | — | `[{id, label, params, menu, shortcut, undoable}]` |
| `document.inspect` | `{depth?, allPages?}` | Document (selection, pages, styles, `colorProfile`, history) |
| `node.get` | `{id, depth?}` | One layer |
| `ui.inspect` | — | Panels, cursor, tool (`arcHandles`, `shapeHandles`), canvas rect, timing, prototype player, `live`, `tabs` |
| `ui.pointer` | `{kind, x, y \| sx, sy, to?, steps?, shift?, alt?, cmd?, ctrl?, pressure?, pressureTo?}` | Canvas gesture (page or screen pixels) → `{selection, tool}` |
| `ui.key` / `ui.type` | `{key, shift?, alt?, cmd?, ctrl?}` / `{text}` | Key on the canvas (→ `{"command": id}`) / text in edit |
| `ui.input` | `{events: [{move}, {down}, {up}, {key}, {text}, {scroll}, {leave}, {hold}, {gamepad}]}` | Raw input to panels and fields (window points); press and release in separate calls |
| `ui.menu.invoke` | `{id}` | Like clicking the menu item (may open a dialog) → `{ok, lastError}` |
| `ui.set` | `{rightTab: design\|prototype\|inspect, leftTab: file\|assets, theme, home, palette, variables, preview, ...}` | Panels and modes → `ui.inspect` |
| `ui.screenshot` | `{path}` | PNG of the window with UI → `{path, width, height}` |
| `ui.render` | `{path, scale?, ids?}` | PNG of the document without UI (selection, or top-level layers) |
| `window.new` / `window.list` / `window.focus` | `{path?, index?}` / — / `{id}` | Windows |
| `app.quit` | — | Closes everything **without asking to save**: avoid |

```json
{"id":1,"method":"engine.execute","params":{"command":"frame.create","params":{"preset":"iPhone 16","x":0,"y":0}}}
{"id":2,"method":"engine.execute","params":{"command":"node.set","params":{"ids":[2],"props":{"fill":"#FF6B6B","cornerRadius":8}}}}
{"id":3,"method":"ui.screenshot","params":{"path":"/Users/me/Desktop/figcraft.png"}}
```
From PowerShell without MCP (generic .NET socket, not from the docs):
```powershell
$c=[Net.Sockets.TcpClient]::new('127.0.0.1',7984); $s=$c.GetStream()
$w=[IO.StreamWriter]::new($s); $w.AutoFlush=$true; $r=[IO.StreamReader]::new($s)
$w.WriteLine('{"id":1,"method":"ui.inspect","params":{}}'); $r.ReadLine(); $c.Close()
```
Element ids: numeric layers (from `document.inspect` or results); windows from `window.list`; hotspot areas and handles in `ui.inspect`.

## Commands by family (ids cited in the docs)
Partial list: **discover the rest with `list_commands {"filter": "..."}` / `figcraft-cli commands --filter ...`** and parameters with `figcraft://command/<id>`. `a/b` = distinct commands `family.a`, `family.b`.

- **file.** `new`, `open`, `openRecent`, `import {path | data + name, x?, y?, center?}`, `save`, `revert`, `export`, `exportLayers`, `exportFramesPdf`, `newFromTemplate`, `colorProfile {profile: srgb|displayP3}`, `saveVersion`, `versionHistory` · **template.** `list`
- **frame.** `create {preset?, x, y, name?}` · **shape.** `rectangle {x, y, width, height}` (other `shape.*`: list_commands) · **node.** `create`, `set`, `reparent`, `reorder`
- **edit.** `undo`, `redo`, `repeat`, `copy`, `paste`, `delete` · **command.** `batch {label, commands}`
- **select.** `set`, `all`, `inverse`, `area {x, y, width, height, add?, deep?}`, `layersAt {x, y}`, `children`, `parent`, `next`, `previous`
- **align./distribute.** `align.left`, `align.top`, `distribute.horizontal`, `distribute.vertical` (other sides: list_commands)
- **transform.** `nudge {dx, dy}`, `rotate`, `scale {factor, cx?, cy?}`, `rotationOrigin`, `setRotationOrigin`
- **object.** `rename`, `batchRename {find?, regex?, replace?, name?}`, `wrapInSection`, `resizeToFit`, `convertToGroup`, `convertToFrame`, `flipH`, `flipV`, `opacityKeys {digits}` · **section.** `toggleContents`
- **layout.** `add {ids, direction}`, `setTrack {axis, index, sizing, value?}`
- **page.** `add`, `list`, `rename`, `move`, `duplicate`, `delete` · **doc.** `list`, `switch {index}`, `nextTab`, `previousTab`
- **fill./stroke./effect./grid.** `fill.set/add/remove/move/pattern`, `stroke.set/remove/move/widthProfile/brush`, `effect.add/set/remove/move`, `grid.move/remove`
- **image.** `place`, `adjust {preset?, filters?}`, `presets`, `savePreset`, `deletePreset`
- **text.** `create`, `set`, `style`, `setVariations`, `fonts`, `edit.begin`, `bulletList`, `numberList`, `listStyle`, `listIndent`, `listOutdent`, `onPath`, `pathOptions`, `removeFromPath`, `preview`, `endPreview`
- **style.** `create`, `apply`, `detach`, `update`, `list`, `bind`, `move`, `duplicate`, `renameFolder`
- **variable.** `create`, `set`, `bind`, `update`, `delete`, `deleteCollection`, `addMode`, `renameMode`, `removeMode`, `moveMode`, `setMode`, `resetOverride`, `export`, `import`
- **component.** `create`, `list`, `properties`, `addProperty`, `editProperty`, `bindProperty`, `exposeInstance`, `makeSlot`, `removeSlot`, `resetOverride`, `resetInstance`, `pushChanges`, `restoreMain`, `hideWhenPublishing`, `playground`
- **instance.** `create`, `place`, `swap`, `swapAt`, `setProperties`, `slotInsert`, `resetSlot`, `exposed`
- **library.** `publish`, `publishToServer`, `add`, `remove`, `list`, `place`, `import`, `swapAt`, `applyStyle`, `bindVariable`, `aliasVariable`, `setVariableMode`, `importVariable`, `extendCollection`, `updates`, `acceptUpdates`, `usage`, `swap`
- **bool.** `union`, `subtract`, `intersect`, `exclude`, `flatten` · **shapeBuilder.** `regions`, `merge`, `remove`, `mode`
- **vector.** `edit.begin/end/state/tool/select/selectAll/pen/penEnd/paint/cut/erase/lasso/delete/moveVertices/nudge/position/setHandle/moveHandles/mirroring/smooth/bend/addVertex/connect/cornerRadius/strokeCap/strokeJoin/bounds/resize/rotate/transform/widthPoint`, `deleteHeal`, `join`, `smoothJoin`, `outlineStroke`
- **proto.** `interaction.add/set/remove/clear`, `action.add/set/remove/move`, `conditional.addBlock/setCondition/removeBlock`, `flow.add/rename/remove`, `settings`, `evaluate`, `present`, `preview`, `closePreview`, `presentOptions`
- **Dev Mode:** `inspect.code`, `inspect.componentCode`, `inspect.properties`, `inspect.assets`, `inspect.readyForDev`, `dev.compare/focus/unfocus/resolveChange`, `annotation.add/edit/remove/list/categories/addCategory/editCategory/removeCategory`, `devResource.add/edit/remove/list`, `codeConnect.set/remove/export/import`
- **export.** `add`, `update`, `remove` · **measure.** `distances`, `padding` · **guide.** `add`, `move`, `remove`, `clear`, `select`
- **comment.** `add {x, y, text, anchor?}`, `reply`, `edit`, `delete`, `react`, `resolve`, `move`, `list`, `markRead`, `link`, `open`, `next`, `zoom`, `people`
- **version.** `list`, `restore`, `rename`, `delete`, `duplicate`, `preview`, `exitPreview`, `autosave` · **branch.** `create`, `list`, `open`, `review`, `merge`, `updateFromMain`, `archive`
- **collab.** `share`, `stop`, `host`, `join`, `leave`, `publish`, `peers`, `files`, `openFile`, `forgetFile`, `manageFile`, `serverInfo`, `report`, `cursor`, `cursorChat`, `follow`, `spotlight`, `diff`, `registerLinks`, `recoverFile`
- **plugin.** `import`, `list`, `remove`, `run`, `ui`, `event`, `close`, `directory.list`, `directory.install`, `directory.publish`, `directory.unpublish` · `plugins.runLast` · **widget.** `insert`, `click`, `list`
- **tool.** `set {tool}`, `place`, `scaleAnchor`, `pencilBrush` (tool ids for `pointer`: e.g. `tool.text`, `tool.scale`, `tool.shapeBuilder`)
- **view.** (app only; no-op headless) `zoomAt`, `pan`, `designPrototype`, `devMode`, `leftSidebar`, `outlines*`, `proofSrgb`, `panelWidths`, `fullscreen`, `contextMenu`, `nextRegion`, `previousRegion`, `multiplayerCursors` · **window.** `new`, `focus`
- **pref.** `language`, `reduceMotion`, `userName`, `publishServer` · **help.** `gettingStarted`

## Recommended workflow
1. **Orient:** choose the channel. `inspect_document` (or `document.inspect`) for pages, frame ids, styles, selection; attached also `inspect_ui` and `screenshot {window: true}`. If the app shows the home screen, `ui.set {home: false}`.
2. **Open or create on a copy:** `open_file` of a copy (or `file.newFromTemplate`, `create_node` on a new document). `.fig` and REST JSON open as a new untitled document. Never re-save over the original.
3. **Find commands:** `list_commands {"filter": "..."}` or `figcraft-cli commands --filter ...`, then `figcraft://command/<id>` for exact parameters.
4. **Edit in small steps:** `create_node` / `set_properties` / `run_command`; group with `batch` what should be one undo. Parent-relative coordinates, auto layout via properties, explicit colors for text. After an error in attached mode, inspect before retrying.
5. **Verify:** `get_node` for numbers, `screenshot {ids: [...]}` for pixels (look at the PNG), `inspect_ui` in the app.
6. **Save/export only with the user's OK**, under a new name: `save_file {path}` (`.figcraft`), `export` or CLI `export`. No `collab.share`/`publish` without an explicit request, no `app.quit`.
7. **Close port 7984** when done (no authentication): quit the app opened with the "FigCraft (Claude)" launcher or reopen it normally.
