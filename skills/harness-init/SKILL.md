---
name: harness-init
description: One-time initialisation of the Claude + Obsidian agentic harness. Scans the vault, asks 5 targeted clarifying questions, then generates VAULT_INDEX.md, root CLAUDE.md, per-section CLAUDE.md files, harness-config.json, check_frontmatter.py, and settings.local.json with the correct absolute path for the PostToolUse hook. Designed for the OneNote/Notion/Evernote migrant case — flat notes, no wikilinks, no existing harness. Idempotent: safe to re-run after major vault restructuring.
---

# Harness Init Skill

One-time setup that builds the full Claude + Obsidian agentic harness from a raw or partially-structured vault. After completion, run `/vault-discover` to begin building the wikilink graph.

Do NOT run this to update the harness after routine note additions — use the Harness Update Protocol in `VAULT_INDEX.md §7` instead.

---

## When to Use

- First time setting up the harness on a new vault
- Vault has just been populated by a bulk import (OneNote Importer, Notion export, Evernote ENEX)
- Harness files are absent, stale, or need full regeneration
- Vault structure has changed significantly (new sections added, major reorganisation)

---

## Phase 1: Scan

Walk the vault directory tree and collect structural data. Use Bash. Do not load note content yet — work from filenames, paths, and shallow body scans only.

**1.1 — Folder inventory**

List all top-level folders and their second-level subfolders. For each content folder, count `.md` files recursively:

```bash
find "VAULT_ROOT" -mindepth 1 -maxdepth 1 -type d | sort
find "VAULT_ROOT/SECTION" -name "*.md" | wc -l
```

Flag infrastructure folders that are not content sections — skip these in generation:
`.obsidian/`, `.claude/`, `.smart-env/`, `.trash/`, `Assets/`, `Excalidraw/`, `templates/`

**1.2 — Wikilink density per section**

Count total `[[` occurrences across all notes in the section, then divide by note count. This gives average wikilinks per note — a more meaningful signal than counting notes-with-any-link.

```bash
# Total wikilink occurrences across all notes in section
find "SECTION_PATH" -name "*.md" | xargs grep -c "\[\[" 2>/dev/null | awk -F: '{sum+=$NF} END {print sum}'

# Total notes in section
find "SECTION_PATH" -name "*.md" | wc -l
```

Flag sections with density < 0.5 as flat/unlinked (typical of fresh imports). Flag sections with density > 3.0 as already-linked.

**1.2b — Subfolder splitting**

For each content section, check whether it has 2+ second-level subfolders each containing > 5 notes. If yes, create a separate §1 row for each qualifying subfolder rather than one row for the parent.

```bash
find "SECTION_PATH" -mindepth 1 -maxdepth 1 -type d | while read subdir; do
  count=$(find "$subdir" -name "*.md" | wc -l)
  echo "$count | $subdir"
done
```

If 2+ subfolders have > 5 notes: use subfolders as §1 rows, not the parent folder.

**1.3 — Hub candidate detection**

Scan all `.md` filenames for these hub signals:
- Title contains (case-insensitive): `dashboard`, `index`, `moc`, `map of content`, `strategy`, `overview`, `home`, `readme`, `vision`, `plan`
- File is mentioned by name in 3+ other notes — run this for each candidate filename:

```bash
grep -ril "CANDIDATE_TITLE" "VAULT_ROOT" --include="*.md" | grep -v "CANDIDATE_FILE" | wc -l
```

Collect the top 10 candidates per section ranked by mention count.

For each confirmed hub candidate (3+ inbound mentions), read the first 5 lines of the note body (after frontmatter) to extract a one-line description for §2. Do not use "mentioned in N notes" as the description — read the actual note.

```bash
# Read opening lines for description
head -20 "HUB_NOTE_PATH" | grep -v "^---\|^tags:\|^date:\|^aliases:\|^$" | head -3
```

**1.4 — Cross-section mention scan**

Take the top-3 most-mentioned note titles in each section. Grep for those titles in all *other* sections. Any hits are candidate bridge points between sections.

**1.5 — Time-series log detection**

Find notes that have 3+ date-style headers or filenames containing `log`, `journal`, `diary`, `daily`:

```bash
grep -rl "# [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\|# Day [0-9]\|# Week [0-9]\|# Session [0-9]" "VAULT_ROOT" --include="*.md"
find "VAULT_ROOT" -name "*log*" -o -name "*journal*" -o -name "*diary*" | grep "\.md$"
```

These are candidates for the Temporal Index (VAULT_INDEX §6).

**1.6 — Credential risk scan**

Grep for credential patterns across all `.md` files, excluding `.claude/`:

```bash
grep -ril "api.key\|api_key\|secret\|password\|token\|private.key\|bearer\|auth.key" \
  "VAULT_ROOT" --include="*.md" \
  --exclude-dir=".claude" --exclude-dir=".obsidian"
```

Record file paths only — never display matched content. These paths go into the Security Flags section of root `CLAUDE.md`.

---

## Phase 2: Clarify

Present exactly these 5 questions in a single numbered list. Wait for all answers before proceeding to Phase 3. Do not ask more than these 5.

1. **Section classification:** "I found these folders with note counts: [list from Phase 1.1]. Which are primary content sections you want Claude to navigate? Which should be excluded (utilities, archive, trash)?"

2. **Life/personal planning section:** "Is there a folder for personal life-planning notes — goals, finances, career, health? Which folder? This section gets 2-hop traversal in VAULT_INDEX because its notes are densely cross-linked."

3. **Work section structure:** "Is there a folder for work notes — projects, meetings, 1:1s, strategy? Does it follow a PARA structure (Projects/Areas/Resources/Archive) or another layout?"

4. **Privacy exclusions:** "Are there notes or folders that should never be read or surfaced to Claude — credentials, private journal, sensitive personal records? List paths." *(Skip this question if Phase 1.6 found credential-risk files — instead present those paths and ask: "I found these files that may contain sensitive content: [paths]. Should these be listed as security flags that Claude will never display?")*

5. **Existing hub notes:** "Do you have any 'map of content' or index notes — notes that exist specifically to link to many others? Name them if so. Otherwise I'll infer hub candidates from the scan."

---

## Phase 3: Generate

Write files in this order. Show a one-line status message before writing each file.

**3.1 — `.claude/harness-config.json`**

Write a config file mapping section paths to their type classification. Use the Phase 2 answers for section names;

Example structure:
```json
{
  "vault_root": "RESOLVED_ABSOLUTE_PATH",
  "sections": {
    "[your-life-planning-folder]": "life-plan",
    "[your-projects-folder]": "project",
    "[your-1on1-folder]": "1on1",
    "[your-reference-folder]": "reference"
  },
  "security_flags": [
    "path/to/credentials.md"
  ],
  "generated": "YYYY-MM-DD"
}
```

Resolve `vault_root` using `pwd` — this is the absolute path Claude Code is running from.

**3.2 — `VAULT_INDEX.md`** (vault root — always regenerate)

Generate all 7 sections:

- **§1 Section Inventory:** One row per content section. Columns: Section | Notes | Link density | Purpose | Entry point | Traversal. Use Phase 1 scan data for counts and density. Traversal = "✅ Up to 2 hops" for the life-planning section, "✅ 1 hop" for work/reference sections, "⬜ On request only" for archive/personal.

- **§2 Hub Nodes:** Group hub candidates by section cluster. If Phase 1.3 found confirmed hubs (3+ inbound mentions), list them. If hub detection is uncertain (link density < 0.3), list top candidates with a note: "Candidate — confirm after running /vault-discover Mode 1".

- **§3 Bridge Points:** Table with From | Bridge | To columns. Populate from Phase 1.4 results. If no cross-section mentions were found, write a placeholder row for each likely section pair: `| [Section A] | unlinked — run /vault-discover Mode 4 | [Section B] |`

- **§4 Routing Heuristics:** Intent → entry point → next hops table. Generate rows from the section classification given in Phase 2. Always include these catch-all rows at the end:
  - "Signal / publishing / reputation" → section CLAUDE.md for life-planning section
  - "Synthesis / cross-domain decision" → load hub nodes from 2+ sections
  - "Unclear intent" → load VAULT_INDEX.md, state ambiguity, ask for clarification

- **§5 Isolated Clusters:** List folders marked as excluded in Phase 2. Add a note that these are available on explicit request only.

- **§6 Temporal Index:** Populate from Phase 1.5 log detection. Use four columns: Log | Location | Coverage | What to look for. For "What to look for", skim the first 10 lines of each detected log to infer its purpose (e.g. "session gaps > 3 weeks = push trigger" for a travel log, "task load ratio over time" for a to-do list). If no logs detected, write: "No time-series logs detected. Add entries here manually as you identify them."

- **§7 Harness Update Protocol:** Write this verbatim (it is generic and vault-independent):

  ```
  When new notes arrive via import or sync, run this protocol:
  1. Identify new/changed files (from script args or your description)
  2. Classify each: which section? new project, person, or section — or update to existing?
  3. Add missing frontmatter — tags: and date: are required
  4. Scan for wikilink opportunities: mentions of existing note names without [[links]]
  5. If new project / person / section detected: update §1 (Section Inventory) and §2 (Hub Nodes)
  6. If new cross-section connection found: update §3 (Bridge Points)
  7. Update root CLAUDE.md Import History (keep last 2–3 entries)
  ```

**3.3 — `CLAUDE.md`** (vault root)

If root `CLAUDE.md` already exists: preserve the Import History table and append a new row dated today. Regenerate all other sections. If it does not exist: generate from scratch.

Sections to include:
- Vault name + owner (use Phase 2 answers, or placeholder "Vault Owner")
- Entry Protocol block: "Always read VAULT_INDEX.md first"
- Vault Sections table: one row per content section + its section CLAUDE.md path
- Note Conventions: wikilink syntax `[[Note Name]]`, frontmatter template, image embed `![[filename.png]]`
- Security Flags: list paths from Phase 1.6 credential scan (if any) — "do not display or copy contents of these notes"
- Sync Scripts: document any sync/import scripts found in `.claude/scripts/`
- Import History table: date | action (preserve existing rows; append new row for today)

**3.4 — Per-section `CLAUDE.md` files**

For each primary content section from Phase 2, write `[Section]/CLAUDE.md`. Skip if the section has fewer than 5 notes.

If a section CLAUDE.md already exists: skip and note in the Phase 4 report — do not overwrite user-maintained section context.

Each section CLAUDE.md should include:
- Section name heading + one-line purpose
- Back-reference: "For vault-wide routing → VAULT_INDEX.md"
- Content map table: one row per hub note (or top 10 notes by size if no hubs confirmed), with "Use it when" column
- Wikilink cluster map: ASCII tree or flat list showing hub → related notes (inferred from outbound links if available, otherwise from title co-mention)
- For the life-planning section: add a "Key Open Decisions" table (empty rows with column headers: Decision | Status | Deadline)

**3.5 — `.claude/scripts/check_frontmatter.py`**

Check if the file exists. If it exists: skip (never overwrite a user-modified validator). If it does not exist: write the canonical version.

The canonical version must:
- Read `.claude/harness-config.json` to determine section type templates (fall back to default template if config absent or section not matched)
- Skip infrastructure files: `CLAUDE.md`, `VAULT_INDEX.md`, `SKILL.md`, `MEMORY.md`, `.claude/`, `.obsidian/`, `Assets/`, non-`.md` files, `.base`, `.canvas`, `.excalidraw`
- Validate: frontmatter exists, has `tags:` and `date:` fields
- Output path-appropriate template warning using section types from harness-config.json
- Always exit 0 (never block saves)

**3.6 — `.claude/settings.local.json`**

Write the PostToolUse hook configuration. Resolve the vault absolute path using `pwd`. Double-quote the path in the command string to handle spaces.

Structure:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [{"type": "command", "command": "python3 \"VAULT_ROOT/.claude/scripts/check_frontmatter.py\""}]
      },
      {
        "matcher": "Edit",
        "hooks": [{"type": "command", "command": "python3 \"VAULT_ROOT/.claude/scripts/check_frontmatter.py\""}]
      }
    ]
  },
  "permissions": {
    "allow": []
  }
}
```

Replace `VAULT_ROOT` with the resolved absolute path. Merge with any existing permissions already in `settings.local.json` — do not discard them.

**3.7 — `.claude/settings.json`**

If `settings.json` contains a PostToolUse hook block: remove it (hooks now live in `settings.local.json`). Preserve any other content (permissions, other settings).

---

## Phase 4: Report

Output this structured summary after all files are written:

```
## Harness Init Complete

### Files created / updated
- VAULT_INDEX.md — [N] sections, [N] hub nodes, [N] bridge points
- CLAUDE.md (root) — orientation layer [created / updated, Import History preserved]
- [list each section CLAUDE.md created or skipped]
- .claude/harness-config.json — [N] sections configured
- .claude/scripts/check_frontmatter.py — [created / skipped (already exists)]
- .claude/settings.local.json — PostToolUse hooks wired (absolute path: VAULT_ROOT)
- .claude/settings.json — hook block removed

### Needs human review
- Hub nodes: [list sections where hubs are inferred, not confirmed — recommend /vault-discover Mode 1]
- Bridge points: [list any placeholder rows in VAULT_INDEX §3]
- Security flags: [list credential-risk file paths if any]

### Notes missing frontmatter
[N] notes are missing frontmatter. The check_frontmatter.py hook will warn on next edit.
To batch-review: ask Claude to "scan for notes missing frontmatter in [section]".

### Recommended next step
Run /vault-discover Mode 1 to confirm hub candidates and find all unlinked mentions.
This is the first step in building your wikilink graph.
```

---

## Idempotency Rules

| File | Behaviour on re-run |
|------|---------------------|
| `VAULT_INDEX.md` | Always regenerate from current vault state |
| `CLAUDE.md` (root) | Regenerate; preserve and append to Import History |
| `[Section]/CLAUDE.md` | Skip if exists (user may have edited) |
| `harness-config.json` | Always regenerate (reflects current Phase 2 answers) |
| `check_frontmatter.py` | Skip if exists |
| `settings.local.json` | Always write (machine-specific path) |
| `settings.json` | Remove hook block if present; preserve other content |

---

## Edge Cases

- **Empty vault (zero notes):** Complete scan and clarify; generate skeleton files with placeholder content. Note in report that files need to be filled in as notes are added.
- **Single flat folder (all notes in root):** Generate harness files, but add this note to the report: "All notes are in the vault root with no section folders. Consider creating folders by theme (e.g. Work/, Learning/, Personal/) then re-running /harness-init to generate per-section context files."
- **Partial harness (some files exist):** Apply idempotency rules. List all skipped files in the Phase 4 report with reason.
- **Python 3 not available:** Detect with `python3 --version`. If absent: skip steps 3.5 and 3.6. Add to report: "Python 3 not found — frontmatter hook not installed. Install Python 3 and re-run /harness-init."
- **Path contains spaces:** Always double-quote the vault path in the settings.local.json `command` field.
- **Vault moved to a new path:** Re-run `/harness-init`. It will regenerate `harness-config.json` and `settings.local.json` with the new absolute path.
