---
title: "sync-comet workflow fails on CHANGELOG.md; fix with merge=union"
category: skills
tags:
  - topic/github-actions
  - topic/git-merge
summary: "Auto-merging main into comet always conflicts on CHANGELOG.md because both prepend entries at the top. Union merge via .git/info/attributes fixes it."
tier: supporting
related: []
extends: null
contradicts: null
superseded_by: null
capture_source: claude-session
project: "claude-config"
base_confidence: 0.75
lifecycle: draft
lifecycle_changed: 2026-11-21
provenance:
  extracted: 0.85
  inferred: 0.15
sources:
  - "claude-config session (2026-11-21)"
---

## Auto-merge of main into comet conflicts on CHANGELOG.md

**Problem:** `.github/workflows/sync-comet.yml` failed with `CONFLICT (content): Merge conflict in CHANGELOG.md`.

**Root cause:** `comet` carries its own changelog entry at the top of `CHANGELOG.md`, and every main change also prepends at the same spot, so a text merge always conflicts.

**Fix:** in the workflow, before the merge:
```bash
echo 'CHANGELOG.md merge=union' >> .git/info/attributes
```
Attributes are read from the working tree when the merge starts, so a `.gitattributes` line added on main would not help the first merge into comet. `.git/info/attributes` in the workflow does not depend on either branch. Union keeps both sides' lines; it can drop a blank line between entries.

**Confirmed by:** local merge of `origin/main` into `origin/comet` finished clean, no markers. Not yet run on GitHub. PR: Lukee-bit/claude-config#13.

**Gotcha:** writing to `.git/info/attributes` while testing in a worktree edits the shared common dir, so it leaks into the main checkout. Remove the line afterward.
