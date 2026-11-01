---
description: Scaffold spec-kit (.specify) and OpenSpec (openspec/) in the current project for Claude Code
allowed-tools: Bash(specify:*), Bash(openspec:*), Bash(ls:*), Read
---
Scaffold spec-driven development in the current project. Skip any part already present.

1. If `.specify/` is missing: `specify init --here --force --non-interactive --integration claude`.
2. If `openspec/` is missing: `openspec init --tools claude`.
3. Report what was created. Mention `/speckit-*` skills (spec-kit) and `/opsx:*` (OpenSpec) commands now available in this project.
