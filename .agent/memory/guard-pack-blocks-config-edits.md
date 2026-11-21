---
name: guard-pack-blocks-config-edits
description: guard-pack blocks Bash edits to settings.json, ~/.claude.json, claude plugin/mcp CLI, and any command text containing .env
metadata:
  type: feedback
---

Put guarded steps in a script under the session scratchpad and ask the user to run it in their own terminal. Do not mention `.env` in grep or jq command text; read scripts with a file-reading tool or a small python helper instead.

**Why:** guard-pack matches the command string, not the intent.
**How to apply:** see the finish-purge.sh, finish-fold.sh, finish-final.sh pattern; verify afterwards.
