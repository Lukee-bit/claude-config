# Handoff

<!-- handoff:narrative:begin -->
## Where I stopped
- `main` is the shared config; `comet` is main plus personal/Comet-only settings (Comet fallback browser, `"model": "opusplan"` in `claude/settings.json`).
- `.github/workflows/sync-comet.yml` merges every push to main into `comet`. It uses a deploy key (secret `COMET_SYNC_KEY`) that is on the `protect-main-owner-approval` ruleset bypass list, and `CHANGELOG.md` merges with `merge=union` because both branches prepend entries. PRs #8-#15 are merged.
- Project memory, context and notes (this `.agent/` folder, the Obsidian vault files, `_raw/`, `.specify/`, `openspec/`, `.claude/` commands and skills) are now committed so another harness or fork can pick up from here. Excluded on purpose: `.env`, `.obsidian/plugins/` (holds an API key), `.codegraph/` (rebuildable index), `.claude/settings.local.json`, `.serena/project.local.yml`, caches and `.agent/.buffer/`.

## Next steps
1. Fresh clone: read this file, then `.agent/memory/MEMORY.md`, then `AGENTS.md`.
2. `.agent/mcp-servers.json` lists the MCP servers the original machine ran; import with `mcptoon import --file .agent/mcp-servers.json --write` and fix paths (`$HOME` stands for the home directory).
3. Rebuild the code index with `codegraph init -y`. Re-create `.env` (`OBSIDIAN_VAULT_PATH`) locally.
4. Promote the notes in `_raw/` with `/wiki-ingest`.
5. User-only: remove the GitKraken and github plugins on claude.ai, revoke the github-direct token (see `_meta/todos.md`).

## Open decisions
- The ruleset requires a status check named `check` that no workflow produces; PRs need an admin bypass merge. Add a `check` job or drop the requirement.
- `mcptoon select` ranks weakly; the CLAUDE.md role map covers it.
<!-- handoff:narrative:end -->

<!-- handoff:auto:begin -->
## Auto status (2026-11-21 14:34)
- branch: `comet`
- uncommitted files: 20
- recent commits:
  - 1e3c0bc comet branch: Comet as the fallback browser
  - 3a11a15 Merge pull request #11 from Lukee-bit/standard-browser-fallback
  - a640a32 Standard Chrome fallback on main; Comet moves to the comet branch
  - f71619f Merge pull request #10 from Lukee-bit/figcraft-replaces-openpencil
  - 795bfe4 Replace OpenPencil with FigCraft; pre-approve MCP servers
- OpenSpec active changes: none
<!-- handoff:auto:end -->
