---
name: vault-discover
description: On-demand discovery skill for building the wikilink graph in a flat or partially-linked Obsidian vault. Four modes — Hub Discovery (rank all notes by inbound mention frequency), Link Scan (find unlinked mentions of a specific note and propose [[wikilinks]]), Orphan Detection (find notes with no inbound or outbound links), Cluster Discovery (group notes by shared vocabulary to surface thematic gaps). Run after /harness-init for vaults imported from OneNote, Notion, or Evernote. Never applies edits silently — always shows proposed changes before writing.
---

# Vault Discover Skill

Progressive wikilink graph builder for flat or under-linked vaults. Run after `/harness-init` to transform a collection of imported notes into a navigable knowledge graph. Each mode addresses a different stage of graph maturity.

For navigation once the graph is built, use the `vault-context` skill instead.

---

## Choosing a Mode

| Mode | Use when | Primary output |
|------|----------|----------------|
| **1 — Hub Discovery** | Starting fresh; want to know which notes should become hubs or MOCs | Ranked candidate list by inbound mention count |
| **2 — Link Scan** | You know a specific note is important; want to wire in all its unlinked mentions | Proposed `[[wikilink]]` edits per file |
| **3 — Orphan Detection** | Vault feels disconnected; want to find lost or dead notes | Classified orphan list with recommended action |
| **4 — Cluster Discovery** | Want to understand thematic structure before building MOCs | Vocabulary clusters with gap analysis |

Recommended sequence for a fresh import: **Mode 1 → Mode 2 (for each confirmed hub) → Mode 3 → Mode 4** (optional).

---

## Output Contract (all modes)

Every mode follows this structure — do not deviate:

1. **Scan summary** — what was scanned, note count, findings overview
2. **Findings** — structured tables or classified lists as shown in each mode
3. **Proposed edits** — shown explicitly before any file is written
4. **Apply prompt** — "Apply all? [Yes / Yes to this file / Skip / Review each]" — never apply silently
5. **Post-apply report** — what was changed, what still needs attention
6. **Next step recommendation** — which mode or skill to run next

---

## Mode 1: Hub Discovery

**Goal:** Rank all notes by how often their title is mentioned across the rest of the vault. High-frequency mentions = hub candidates.

**Steps:**

1. Collect all note titles from the vault (excluding infrastructure):
   ```bash
   find "VAULT_ROOT" -name "*.md" \
     -not -path "*/.claude/*" -not -path "*/Assets/*" \
     -not -path "*/.obsidian/*" -not -name "CLAUDE.md" \
     -not -name "VAULT_INDEX.md" \
     | xargs -I{} basename {} .md | sort
   ```

2. For each title, count how many *other* notes mention it (plain text or wikilink):
   ```bash
   grep -ril "TITLE" "VAULT_ROOT" --include="*.md" \
     --exclude-dir=".claude" --exclude-dir=".obsidian" \
     | grep -v "EXACT_FILENAME" | wc -l
   ```
   Focus on titles longer than 4 characters to avoid noise from short common words.

3. Rank titles by mention count descending. Separate into tiers:
   - **Tier 1 (confirmed hub candidates):** mentioned in 5+ other notes
   - **Tier 2 (possible hubs):** mentioned in 2–4 other notes
   - **Tier 3 (isolated):** mentioned in 0–1 other notes → orphan candidates for Mode 3

4. For each Tier 1 note, check if it already has outbound `[[wikilinks]]`:
   ```bash
   grep -c "\[\[" "NOTE_PATH"
   ```
   A note with many inbound mentions but few outbound links is an under-linked hub — prime candidate for Mode 2.

5. Present results:

   ```
   ## Hub Discovery Results

   Scanned: [N] notes across [sections]

   ### Tier 1 — Confirmed Hub Candidates (5+ inbound mentions)
   | Note | Mentioned in (files) | Outbound [[links]] | Recommended action |
   |------|--------------------|--------------------|--------------------|
   | [Hub Candidate A] | 9 | 7 | Already hub-like — add to VAULT_INDEX §2 if not there |
   | [Hub Candidate B] | 12 | 3 | Under-linked hub — run Mode 2 to wire in 9 unlinked mentions |

   ### Tier 2 — Candidate Hubs (2–4 mentions)
   | Note | Mentions | Action |
   ...

   ### Summary
   [N] Tier 1 candidates, [N] Tier 2 candidates.
   ```

6. Offer to update `VAULT_INDEX.md §2 Hub Nodes` with Tier 1 confirmed hubs. Show proposed additions before writing. Ask: "Add these to VAULT_INDEX §2? [Yes / Review each / Skip]"

---

## Mode 2: Link Scan

**Goal:** For a given note, find every other note that mentions its title without a `[[wikilink]]`, and propose adding the link.

**Input:** One note name (e.g. a confirmed hub like `[Hub Title]`), a comma-separated list, or `all tier-1` to use Mode 1 Tier 1 results.

**Steps:**

1. Resolve the exact note title (strip `.md`, normalise case). Build a two-pass grep — first find all mentions, then exclude already-linked forms:
   ```bash
   # All mentions
   grep -rn "TITLE" "VAULT_ROOT" --include="*.md" \
     --exclude-dir=".claude" | grep -v "TITLE\.md:"

   # Already-linked forms to exclude (pipe through grep -v)
   grep -v "\[\[TITLE"
   ```

2. For each match, record: file path, line number, 1 line of surrounding context.

3. Group results by file. For each file with unlinked mentions, format:

   ```
   **[Section]/[Subsection]/[Note name].md** (3 unlinked mentions)
   Line 14: "...follows the pattern described in [Hub Title], specifically the ..."
   Line 47: "Per [Hub Title] section 3, we use..."
   Line 89: "See also [Hub Title] for the related topology..."

   Proposed:
   - Line 14: [Hub Title] → [[Hub Title]]
   - Line 47: [Hub Title] → [[Hub Title]]
   - Line 89: [Hub Title] → [[Hub Title]]
   ```

4. After showing all proposed edits: "Apply changes? [Yes — all files / Yes — this file / Skip this file / Review each edit]"
   - **Yes — all files:** apply all proposed edits across all files in one pass
   - **Yes — this file:** apply current file, prompt again for each remaining file
   - **Skip this file:** skip, move to next
   - **Review each edit:** show each individual line change and ask Y/N

5. After applying: report total links added. If the target note now has many confirmed inbound links but is not yet in `VAULT_INDEX.md §2`, offer to add it.

**Batch mode:** When input is `all tier-1`, run the scan for each hub title in sequence, aggregate all proposed edits by file, then present the full change set before applying. Do not apply file by file — show the complete picture first.

**Anti-pattern — do not do this:** Do not run Mode 2 on every note in the vault. Only run it on confirmed hub candidates (Tier 1 from Mode 1) or notes the user names explicitly. Scanning all 200+ notes for each title produces noise and context bloat.

**Session guardrail:** If a single Mode 2 run proposes edits to more than 30 files, pause after showing the summary and ask: "This will edit [N] files. Continue with all, or limit to the top [10] files by mention count?"

---

## Mode 3: Orphan Detection

**Goal:** Find notes with zero inbound AND zero outbound wikilinks. Classify each to distinguish dead notes from undiscovered hubs.

**Steps:**

1. Find notes with at least one outbound link:
   ```bash
   grep -rl "\[\[" "VAULT_ROOT" --include="*.md" \
     --exclude-dir=".claude" --exclude-dir=".obsidian" \
     > /tmp/has_outbound.txt
   ```

2. Extract all link targets referenced across the vault:
   ```bash
   grep -roh "\[\[[^\]]*\]\]" "VAULT_ROOT" --include="*.md" \
     --exclude-dir=".claude" \
     | sed 's/\[\[//; s/\]\]//' \
     | sed 's/|.*//' | sed 's/#.*//' \
     | sort | uniq > /tmp/linked_targets.txt
   ```

3. Find all content notes (exclude infrastructure):
   ```bash
   find "VAULT_ROOT" -name "*.md" \
     -not -path "*/.claude/*" -not -path "*/Assets/*" \
     -not -path "*/.obsidian/*" -not -name "CLAUDE.md" \
     -not -name "VAULT_INDEX.md" -not -name "SKILL.md"
   ```

4. Orphans = notes NOT in `has_outbound.txt` AND whose basename is NOT in `linked_targets.txt`.

5. For each orphan, classify it:
   - **Dead note** (< 100 words OR mostly whitespace/empty): likely an import artifact
     ```bash
     wc -w "ORPHAN_PATH"
     ```
   - **Isolated reference** (100–300 words, real content, zero mentions elsewhere): standalone note not yet connected
   - **Undiscovered hub** (> 300 words AND title mentioned in 2+ other notes): high-value note not yet wired in
     ```bash
     grep -ril "$(basename ORPHAN .md)" "VAULT_ROOT" --include="*.md" | wc -l
     ```

6. Present the classified list:

   ```
   ## Orphan Detection Results

   Total orphans: [N] (zero inbound + zero outbound links)

   ### Dead notes — likely import artifacts ([N])
   - [Section]/Untitled-YYYYMMDDHHMMSS.md (47 words)
     → Recommended: review content, delete if empty/duplicate

   ### Isolated references — real content, no connections ([N])
   - [Section]/[Note name].md (820 words, 0 external mentions)
     → Recommended: run Mode 2 on this note's title, or manually link from a related hub

   ### Undiscovered hubs — high-value, not yet wired ([N])
   - [Section]/[Subsection]/[Hub candidate].md (1,240 words; "[Hub Title]" mentioned 8x elsewhere)
     → Recommended: run Mode 2 on "[Hub Title]" immediately
   ```

7. For each undiscovered hub candidate, offer to immediately run Mode 2: "Run Link Scan on '[Hub Title]' now? [Yes / Skip]"

---

## Mode 4: Cluster Discovery

**Goal:** Group notes by shared vocabulary to surface thematic clusters. Identify clusters that lack a hub note, indicating a gap in the knowledge graph.

**Steps:**

1. Extract shared vocabulary signals per note:
   - Existing frontmatter tags:
     ```bash
     grep -rh "  - " "VAULT_ROOT" --include="*.md" | sort | uniq -c | sort -rn | head -50
     ```
   - Wikilink targets (most-referenced = shared vocabulary):
     ```bash
     grep -roh "\[\[[^\]]*\]\]" "VAULT_ROOT" --include="*.md" \
       | sed 's/\[\[//; s/\]\]//' | sed 's/|.*//' | sed 's/#.*//' \
       | sort | uniq -c | sort -rn | head -50
     ```

2. Group notes into clusters. Two notes belong to the same cluster if they:
   - Share 2+ frontmatter tags, OR
   - Both contain wikilinks to 2+ of the same targets

3. For each cluster, determine:
   - **Hub note exists?** — a note that links to ≥ 50% of cluster members
   - **Section CLAUDE.md covers it?** — check the relevant section's CLAUDE.md
   - **Top 5 concepts** — most-referenced link targets within the cluster

4. Present clusters with gap analysis:

   ```
   ## Cluster Discovery Results

   ### Cluster: [Theme A] (18 notes)
   Top concepts: [concept-1], [concept-2], [concept-3], [concept-4], [concept-5]
   Hub note: [Hub Title].md ✅ (links to 9/18 members)
   Section context: [Section]/CLAUDE.md ✅
   Gap: 9 cluster members not linked from hub → run Mode 2 on "[Hub Title]"

   ### Cluster: [Theme B] (6 notes)
   Top concepts: [concept-1], [concept-2], [concept-3]
   Hub note: ❌ None
   Section context: [Section]/CLAUDE.md ✅
   Gap: No MOC exists → recommend creating a hub note (e.g. [theme-b]_hub.md)

   ### Cluster: [Personal-only theme] (11 notes)
   Top concepts: [concept-1], [concept-2]
   Hub note: ❌ None
   Section context: ❌ None
   Gap: Isolated personal cluster — low cross-vault navigation value
   → Recommended action: mark as on-request-only in VAULT_INDEX §5
   ```

5. For clusters with no hub note and cross-vault value: offer to create a stub MOC note:
   "Create a stub hub note for '[Theme]' cluster with wikilinks to its 6 members? [Yes / Skip]"
   The stub includes: frontmatter, a one-line purpose, and a list of `[[wikilinks]]` to each cluster member.

6. Offer to update `VAULT_INDEX.md §5 Isolated Clusters` with confirmed low-value clusters.

---

## Integration with Other Skills

- **After `/harness-init`:** Run Mode 1 first to confirm hub candidates. Mode 2 on each Tier 1 hub. Mode 3 to find orphans. Mode 4 is optional but useful if the import includes tagged notes.
- **Before `vault-context`:** The navigation skill works best once hub notes have outbound links and `VAULT_INDEX.md §2` is populated with confirmed hubs. Use vault-discover to reach that state.
- **After bulk import:** Re-run Mode 1 and Mode 3 to catch new hub candidates and orphans introduced by the import. Use the import protocol in `VAULT_INDEX.md §7` as the trigger.

---

## Anti-Patterns

- **Do not run Mode 2 on every note** — only on confirmed hub candidates or explicitly named notes. Scanning all notes for every title produces noise.
- **Do not auto-apply all link edits without showing them first** — some plain-text mentions are conceptual references, not navigational links. Always show proposed edits before writing.
- **Do not create MOC notes for isolated personal clusters** — Mode 4 will surface narrow personal-interest clusters that have no cross-vault navigation value (e.g. notes about a single hobby or pet). Mark them as on-request-only rather than creating hubs for them.
- **Do not confuse orphans with intentionally unlinked notes** — credentials, scratch notes, and archived content should stay unlinked. Check word count and classify before acting.
- **Do not run all four modes in a single session on a large vault** — 200+ notes × 4 modes generates significant context. Run Mode 1 first, then pause and assess before proceeding.
