#!/usr/bin/env bash
# Cursor / Cursor Code surface on top of the claude-config base install.
# Run ./install.sh first. Reuses ~/.claude/skills, the Claude plugin cache,
# ~/.claude-tools/bin helpers and ~/.mcptoon/config.json.
# Safe to re-run: replaced files are backed up (*.bak-YYYYmmdd).
# Never runs the OpenCode installer. Does not rewrite Claude plugins/skills.
#   ./install-cursor.sh --dry-run    print what would happen
#   ./install-cursor.sh              apply
#   ./install-cursor.sh --no-tools   config only (skip GSD --cursor)
set -euo pipefail
cd "$(dirname "$0")"
DRY=0; TOOLS=1
for a in "$@"; do case "$a" in --dry-run) DRY=1;; --no-tools) TOOLS=0;; *) echo "unknown flag $a"; exit 2;; esac; done
run() { if [ $DRY -eq 1 ]; then echo "  would: $*"; else "$@"; fi; }
say() { printf '\n== %s\n' "$*"; }

[ -f "$HOME/.claude-tools/config-repo" ] || { echo "base install missing (run ./install.sh first)"; exit 1; }
PY=$(command -v python3 || command -v python || true)
[ -n "$PY" ] || { echo "missing: python"; exit 1; }
command -v mcptoon >/dev/null || echo "note: mcptoon not on PATH; install/base tool step may still be needed"
command -v node >/dev/null || echo "note: node not found; GSD --cursor will be skipped if missing"

say "Cursor config (~/.cursor)"
if [ $DRY -eq 1 ]; then
  "$PY" cursor/render.py --dry-run
else
  "$PY" cursor/render.py
fi

if [ $TOOLS -eq 1 ]; then
  if command -v npx >/dev/null; then
    say "GSD Core (Cursor hooks / commands)"
    run npx -y @opengsd/gsd-core@latest --cursor --global --profile=core || true
    # Re-merge in case GSD rewrote hooks.json
    if [ $DRY -eq 0 ]; then "$PY" cursor/render.py; fi
  else
    echo "  skip GSD: npx not found"
  fi
fi

say "Done. Fully quit and restart Cursor IDE + Cursor Code CLI, then verify: mcptoon doctor; MCP list shows mcptoon. See cursor/README.md."
