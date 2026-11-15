---
description: Scaffold spec-kit (.specify) and OpenSpec (openspec/) in the current project for OpenCode
---

Scaffold spec-driven development in the current project. Skip any part already present.

1. If `.specify/` is missing: `specify init --here --force --non-interactive --integration opencode`.
2. If `openspec/` is missing: `openspec init --tools opencode`.
3. Report what was created. Mention `/gsd-*` commands and the speckit/OpenSpec skills now available in this project.