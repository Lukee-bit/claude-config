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
## Auto status (2026-11-21 19:02)
- branch: `feat/lukes-skills-handoff`
- uncommitted files: 8
- recent commits:
  - 6cea39d Docs: rebrand to Luke's claude-config and refresh the README (#21)
  - 811700e One-click installer (Install.cmd / Install.command) + install fixes (#20)
  - 5764073 Windows: match user mcptoon entry to project scope; link obsidian-skills from new upstream path (#19)
  - c88e4fa install.ps1: fix regex that wrote config-repo (invalid '\' pattern aborted the final step) (#18)
  - 0289739 Windows: drop Temurin JDK; Cursor and OpenCode install GSD core profile (#17)
- OpenSpec active changes: none
<!-- handoff:auto:end -->
