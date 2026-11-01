---
name: obsidian-tooling
description: One-time installation and configuration of Obsidian community plugins that the harness can leverage — primarily Smart Connections (semantic embeddings). Run after /harness-init, before /vault-discover, on a vault that will be opened in Obsidian. Idempotent: detects already-installed plugins and skips them.
---

# Obsidian Tooling Skill

Installs and configures Obsidian community plugins so the harness can use Obsidian's existing infrastructure for embeddings instead of building its own.

Currently supports:
- **Smart Connections** — semantic similarity via local embeddings, used by `vault-context` Hybrid Mode for query-aware traversal. Default install.
- **Dataview** — structured metadata queries (frontmatter, tags), useful for self-updating MOC/hub notes with live query blocks. Opt-in only — the harness cannot execute or read Dataview queries directly (no CLI, no cache); it can only generate query blocks for Obsidian to render.

Do NOT run this if the vault is not opened in Obsidian — the `.obsidian/` directory must exist before plugins can be installed.

---

## When to Use

- After `/harness-init`, on a vault that the user opens in Obsidian
- When `vault-context` Hybrid Mode is desired (query-aware embedding-scored traversal)
- When the user mentions Smart Connections, Dataview, or "embedding-aware" navigation
- After upgrading: re-run to fetch latest plugin releases (idempotent on version match)

---

## Phase 1: Detect

**1.1 — Obsidian install detection**

Check whether Obsidian is installed locally. Skill does NOT install Obsidian itself; it only detects and reports.

Common install paths to check:
- macOS: `/Applications/Obsidian.app`
- Windows: `%LOCALAPPDATA%\Obsidian\Obsidian.exe`, `C:\Program Files\Obsidian`
- Linux: `/opt/Obsidian`, snap/flatpak install paths

If absent: report path checked, link the user to https://obsidian.md/download, stop. Do not attempt install.

**1.2 — Vault `.obsidian/` directory check**

```bash
test -d "VAULT_ROOT/.obsidian"
```

If absent: the vault has never been opened in Obsidian. Stop. Report:
> Open this vault in Obsidian once before running this skill. Obsidian creates `.obsidian/` on first vault open.

**1.3 — Existing plugin inventory**

For each candidate plugin, check whether it is already installed AND already enabled:
```bash
ls "VAULT_ROOT/.obsidian/plugins/<plugin-id>/manifest.json"   # installed
grep -q "\"<plugin-id>\"" "VAULT_ROOT/.obsidian/community-plugins.json"   # enabled
```

Read installed version from each `manifest.json`. Compare to latest GitHub release.

**1.4 — Community Plugins enablement**

Check `VAULT_ROOT/.obsidian/app.json` for whether Community Plugins are enabled. If the file doesn't exist or doesn't have the flag, report that the user must enable Community Plugins in Settings on first plugin use (one-time action).

---

## Phase 2: Clarify

Present exactly these 3 questions in a single numbered list. Wait for all answers before proceeding.

1. **Which plugins?** "I can install: [Smart Connections (embeddings), Dataview (metadata queries)]. Which do you want? Default: Smart Connections only. Dataview is opt-in — useful if you want self-updating query blocks in hub notes, but not required for the harness."

2. **Embedding model for Smart Connections** (only ask if Smart Connections selected):
   "Which embedding model? Options:
   - `TaylorAI/bge-micro-v2` — default, ~30 MB, 384 dims, fast (recommended for first install)
   - `nomic-ai/nomic-embed-text-v1` — 768 dims, 2,048 token context (matches eval baseline)
   - `andersonbcdefg/bge-small-4096` — 384 dims, 4,096 token context (long notes)
   - `text-embedding-3-small` — OpenAI API, 1,536 dims (requires API key)
   
   Default: `bge-micro-v2`."

3. **Add `.smart-env/` to `.gitignore`?** (only ask if vault is a git repo, detected via `test -d VAULT_ROOT/.git`):
   "The Smart Connections embedding cache lives in `.smart-env/` (often 10–100 MB, regenerable). Add it to `.gitignore`? Default: yes."

---

## Phase 3: Install

For each selected plugin:

**3.1 — Fetch latest release metadata**

Hit the GitHub API for the latest release tag and asset URLs:
```
https://api.github.com/repos/<owner>/<repo>/releases/latest
```

Plugin coordinates:
| Plugin | GitHub repo | Plugin ID |
|--------|------------|-----------|
| Smart Connections | `brianpetro/obsidian-smart-connections` | `smart-connections` |
| Dataview | `blacksmithgu/obsidian-dataview` | `dataview` |

**3.2 — Download release files**

Required assets per plugin: `main.js`, `manifest.json`, and `styles.css` (if present in the release).

Run `python3 .claude/scripts/install_obsidian_plugin.py <plugin-id> <vault-root>` — see `install_plugin.py` for the implementation.

Place files in `VAULT_ROOT/.obsidian/plugins/<plugin-id>/`.

**3.3 — Enable in `community-plugins.json`**

Read `VAULT_ROOT/.obsidian/community-plugins.json` (a JSON array). If absent, create with `[]`. Append `"<plugin-id>"` if not already present. Write back with sorted, deduplicated entries.

**3.4 — Pre-configure plugin `data.json`**

For Smart Connections, write `VAULT_ROOT/.obsidian/plugins/smart-connections/data.json` with the chosen embedding model and sensible exclusions:

```json
{
  "smart_sources": {
    "embed_model_key": "TaylorAI/bge-micro-v2"
  },
  "file_exclusions": [
    "VAULT_INDEX.md",
    "**/CLAUDE.md",
    ".claude/",
    ".obsidian/",
    "Assets/"
  ]
}
```

Do NOT overwrite an existing `data.json` — only write if absent. The plugin owns its config once installed.

For Dataview, no pre-configuration needed; defaults are fine.

**3.5 — `.gitignore` update**

If user opted in (Phase 2 Q3), append to `VAULT_ROOT/.gitignore`:
```
.smart-env/
```

Do not duplicate if already present.

---

## Phase 4: Report

Output this structured summary:

```
## Obsidian Tooling Install Complete

### Plugins installed / updated
- Smart Connections [version] — embedding model: bge-micro-v2
- Dataview [version]

### Files written
- .obsidian/plugins/smart-connections/{main.js, manifest.json, styles.css, data.json}
- .obsidian/plugins/dataview/{main.js, manifest.json, styles.css}
- .obsidian/community-plugins.json (added: smart-connections, dataview)
- .gitignore (added .smart-env/)

### Manual steps required
1. Open Obsidian → Settings → Community plugins → Turn on if you haven't already (one-time per vault)
2. Reload the vault (close and re-open, or use Cmd/Ctrl+R if a window is already open)
3. Smart Connections will run an initial embedding pass (~1-2 minutes per 100 notes)
4. After indexing completes, the .smart-env/ directory will populate

### Next step
Run /vault-context in Hybrid Mode once .smart-env/ contains data — the skill will detect it
automatically and use embedding-scored traversal alongside wikilinks.
```

---

## Idempotency Rules

| Action | On re-run |
|--------|-----------|
| Plugin already at latest version | Skip download, report "already current" |
| Plugin installed but older version | Download + replace files; preserve `data.json` |
| `data.json` already present | Skip; user owns config |
| Plugin already in `community-plugins.json` | Skip |
| `.gitignore` entry already present | Skip |

---

## Edge Cases

- **GitHub rate limit on unauthenticated API:** The releases API allows ~60 unauthenticated requests/hour. For a 2-plugin install this is fine. If rate-limited, report and suggest re-running later.
- **Vault on cloud sync (iCloud/Dropbox/OneDrive):** Plugin files written to a sync folder may race with the sync client. Warn the user; recommend pausing sync briefly.
- **No `.obsidian/` directory:** Stop with instruction to open vault in Obsidian first. Do not create the directory manually — Obsidian initialises it with required schema.
- **Obsidian running with vault open:** File writes are safe (Obsidian re-reads plugin files on activation), but the user must reload the vault (Cmd+R) for new plugins to register.
- **Custom plugin install location:** If the user has a non-default `.obsidian/plugins/` path (rare), respect any `installedPlugins` config in `app.json`.

---

## Anti-Patterns

- **Don't auto-install Obsidian itself** — it's a GUI app with OS-level integration; the user installs it deliberately.
- **Don't auto-enable Community Plugins** — Obsidian gates this behind a user consent dialog for security; bypassing that is hostile.
- **Don't overwrite plugin `data.json`** — once the plugin runs once, it owns its config; the user may have customised settings.
- **Don't auto-update plugins on every harness invocation** — only on explicit re-run of this skill.
- **Don't include `.smart-env/` in any harness scan** — it's the plugin's private cache; treat as opaque infrastructure.
