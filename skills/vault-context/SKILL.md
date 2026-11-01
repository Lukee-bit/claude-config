---
name: vault-context
description: Navigate an Obsidian vault progressively using its own wikilink graph. Use when working with any vault note, answering questions about vault content, or doing synthesis across multiple notes. Provides depth mode (directed task navigation) and synthesis mode (cross-note pattern discovery).
---

# Vault Context Navigation Skill

Progressive disclosure navigation for your Obsidian vault. Instead of loading everything upfront, follow the vault's own wikilink graph contextually — depth for directed tasks, synthesis for cross-domain pattern finding.

---

## Session Initialization

**Always read `VAULT_INDEX.md` first.** It is the only guaranteed load in every session. It gives:
- All section locations and purpose (enough to route any task)
- Hub nodes — high-value notes worth loading regardless of task
- Bridge points — cross-section connections for synthesis
- Routing heuristics — intent → entry point → next hops
- Temporal index — dated logs for pattern queries

Nothing else is pre-loaded. All section content is on-demand.

---

## Navigation Modes

### Depth Mode (default for specific tasks)

Use for directed, single-domain tasks: editing a note, answering a question about one project or area, updating a specific file.

**Steps:**
1. Read routing heuristics from `VAULT_INDEX.md`
2. Load the entry point note for the matched intent
3. Follow wikilinks 1–2 hops as needed to build sufficient context
4. Stop when context is enough to complete the task — don't pre-load more

**Hop limits:**
- **Dense sections** (life planning, strategy — sections where notes heavily cross-reference each other) — up to 2 hops. Check `VAULT_INDEX.md §1` Traversal column.
- **Sparse sections** (work projects, reference, imported notes) — 1 hop max. Depth rarely adds value beyond the entry point.

**Example:**
Task: "update the project status for [ProjectName]"
→ routing heuristics → load section entry point → follow 1 hop to the specific project note → done

---

### Synthesis Mode (cross-domain or pattern-finding queries)

Use for: "how does X relate to my goals?", "find connections between Y and Z", "am I still on track?", "what patterns do I see across my notes?", "help me think through a decision".

**Steps:**
1. Identify all relevant sections (typically 2+)
2. Load hub nodes from each relevant section simultaneously
3. Traverse bridge points between sections — these are the reasoning backbone
4. Pull temporal data if the query is time-sensitive (see `VAULT_INDEX.md §6` Temporal Index)
5. Surface connections the user may not have made explicitly — this is the value of synthesis mode

**Bridge points to traverse** (populated by `/harness-init` for your vault — replace these with your own):

| From | Bridge | To |
|------|--------|----|
| `[Life planning hub]` | life goals ↔ career direction | `[Work strategy note]` |
| `[Work project note]` | project learning ↔ personal skill | `[Learning hub]` |
| `[Career note]` | signal ↔ publishing artifact | `[Personal project note]` |
| `[Goal note]` | monthly triggers ↔ reflection log | `[Reflection log]` |
| `[Goal note]` | transition gates ↔ financial runway | `[Financial note]` |

> Run `/harness-init` to auto-populate this table from your vault's actual cross-section connections.

**Example:**
Query: "how does [personal project] relate to my career goals?"
→ Load personal-project hub + career hub notes from relevant sections
→ Traverse bridge: [career note] ↔ [personal project note]
→ Surface connections the user may not have made explicitly

---

### Hybrid Mode (Path 1: anchor scoring) — when Smart Connections is installed

Use when `<vault>/.smart-env/multi/` exists and contains embedding data. Hybrid Mode has two
complementary moves: it **filters** outbound wikilinks by similarity to the entry note, and
it **surfaces** topically-relevant notes that wikilink traversal would never reach. Both
operate on the entry note's own embedding as the anchor — no runtime query embedder needed,
no new Python ML dependencies for the harness.

Validated on the eval vault (2026-05-10): hybrid+orphan-surfacing dominates pure traversal
on every dimension (faithfulness +0.27, grounding +0.40, novelty +0.20, relevancy +0.13).

**When Hybrid Mode helps:**
- Cross-domain queries where naive wikilink traversal pulls in irrelevant context
- Sparse-link entry points where pure traversal terminates early
- Topically-relevant orphan notes that the wikilink graph never connected

**When to stay in pure Depth/Synthesis Mode:**
- The user explicitly asks "follow my wikilinks" or "use only what's linked"
- `.smart-env/multi/` is absent, empty, or stale (re-indexing in progress)

**Steps:**

1. **Detect** — confirm `<vault>/.smart-env/multi/` has at least one `.ajson` file. If absent,
   fall back silently to Depth/Synthesis Mode.

2. **At each hop, filter outbound links** against the parent note's embedding. Follow links
   where `cosine(anchor, candidate) ≥ 0.65` (default; tune per vault). Drop the rest.
   ```bash
   python3 .claude/scripts/smart_connections_reader.py "VAULT_ROOT" \
     --model "TaylorAI/bge-micro-v2" \
     --mode score-anchor \
     --anchor-path "[your-section]/[entry-note].md" \
     --paths-file /tmp/candidate_links.json
   ```

3. **After traversal completes, surface unconnected topical neighbours.** For each entry-point
   note, take top-k similar notes across the *whole* vault (`top-k` mode), drop anything
   already loaded or below `orphan-threshold` (default 0.55), load up to 5. These are notes
   the wikilink graph would never have reached but that the embedding identifies as on-topic.
   ```bash
   python3 .claude/scripts/smart_connections_reader.py "VAULT_ROOT" \
     --model "TaylorAI/bge-micro-v2" \
     --mode top-k --k 15 \
     --query-embedding-file /tmp/anchor_embedding.json
   ```
   (The "query embedding" here is the entry note's own cached embedding — read it from the
   `smart_sources:<path>` record in `.smart-env/multi/<path_underscored>.ajson`.)

4. **Cap total notes loaded** at the same `MAX_NOTES` limit as Depth/Synthesis Mode (typically
   10–12). Entry points first, then wikilink-followed, then surfaced orphans.

5. **Report what was loaded and how it got in** — three categories: followed via wikilink (with
   score), surfaced as topical orphan (with score), or entry point. This makes the navigation
   auditable and helps the user decide whether to add explicit `[[wikilinks]]` between high-
   scoring-but-unconnected pairs.

**Defaults (validated on eval vault, 99 notes, bge-micro-v2):**
- Wikilink follow threshold: `0.65` (Pareto-optimal on faithfulness + grounding)
- Orphan-surfacing threshold: `0.55`
- Orphan-k: `5` per query

These are starting points; threshold distributions vary by embedding model and vault content
(check ranges first with a quick top-k probe before changing).

**Anti-pattern:** Don't treat the orphan surface as "search the whole vault" — it's bounded
by k and threshold for a reason. Loading 20+ topical notes drowns out the wikilink-followed
context and degrades faithfulness.

**Skip 0-byte stub files when resolving wikilinks** — Obsidian auto-creates empty notes when
users click unresolved `[[links]]` in the UI. These have no embedding and will always score 0;
the resolver should prefer the underscored canonical filename and skip zero-byte matches.

**Index freshness:** Smart Connections re-embeds on note save. After a bulk import or wikilink
scan (`/vault-discover` Mode 2), allow ~30s per 100 notes for re-indexing before relying on
Hybrid Mode.

---

## Fallback Rule

If task intent is unclear or spans multiple domains:
1. Load hub nodes from the 2 most plausible sections
2. Attempt a useful response with that context
3. Surface the ambiguity explicitly: "This could be about X or Y — I've loaded context for both. Which direction?"

Do NOT silently pick one path and miss the other half of the question.

---

## Anti-Patterns

- **Don't load archive, trash, or personal-interest sections unless explicitly requested** — check `VAULT_INDEX.md §5` for which sections are isolated
- **Don't attempt to load all notes** — progressive disclosure exists precisely to prevent this
- **Don't pre-load section CLAUDE.md files speculatively** — load them only when routing heuristics direct you to that section
- **Prefer 2–3 notes deep over 20 notes shallow** — depth compounds; breadth creates noise
- **Don't skip VAULT_INDEX.md** — it's the map; loading notes without it means navigating blind

---

## Harness Update (when new notes arrive)

When new notes arrive via import or sync, run this protocol:
1. Identify new/changed files
2. Classify: which section? new project/person/section or update to existing?
3. Check frontmatter on new notes; add if missing
4. Scan for wikilink opportunities: mentions of existing note names without `[[links]]`
5. If new project/person/section detected: update `VAULT_INDEX.md §1` and `§2`
6. If new cross-section connection found: update `VAULT_INDEX.md §3`
