#!/usr/bin/env bash
# OpenCode V2 surface on top of the claude-config base install. Run ./install.sh first:
# this reuses what the base install creates (~/.claude/skills, the Claude plugin cache,
# ~/.claude-tools/bin helpers, npm globals). Safe to re-run: replaced files are backed
# up (*.bak-YYYYmmdd) before opencode.json is merged. Never writes ~/.claude.
#   ./install-opencode.sh --dry-run    print what would happen
#   ./install-opencode.sh              apply
#   ./install-opencode.sh --no-tools   config only (skip the GSD/RTK/Caveman OpenCode installers)
set -euo pipefail
cd "$(dirname "$0")"
DRY=0; TOOLS=1
for a in "$@"; do case "$a" in --dry-run) DRY=1;; --no-tools) TOOLS=0;; *) echo "unknown flag $a"; exit 2;; esac; done
STAMP=$(date +%Y%m%d)
run() { if [ $DRY -eq 1 ]; then echo "  would: $*"; else "$@"; fi; }
say() { printf '\n== %s\n' "$*"; }
OC="$HOME/.config/opencode"

[ -f "$HOME/.claude-tools/config-repo" ] || { echo "base install missing (run ./install.sh first)"; exit 1; }
PY=$(command -v python3 || command -v python || true)
[ -n "$PY" ] || { echo "missing: python"; exit 1; }
command -v node >/dev/null || { echo "missing: node (npx needs it)"; exit 1; }
command -v opencode >/dev/null || echo "note: 'opencode' CLI not found; config is still rendered"

# Copy with backup. The templates hold no __HOME__ placeholders — every
# OS-specific path resolves at runtime (claude-config.js) or in render.py.
place() {
  local src="$1" dst="$2"
  if [ $DRY -eq 1 ]; then echo "  would place $src -> $dst"; return; fi
  mkdir -p "$(dirname "$dst")"
  [ -e "$dst" ] && cp "$dst" "$dst.bak-$STAMP"
  cp "$src" "$dst"
}

say "OpenCode config (~/.config/opencode)"
place opencode/AGENTS.md "$OC/AGENTS.md"
for f in opencode/commands/*.md; do place "$f" "$OC/commands/$(basename "$f")"; done
place opencode/plugins/claude-config.js "$OC/plugins/claude-config.js"
if [ $DRY -eq 1 ]; then
  echo "  would render opencode/render.py -> $OC/opencode.json (backup first)"
else
  mkdir -p "$OC"
  "$PY" opencode/render.py
fi

if [ $TOOLS -eq 1 ]; then
  say "GSD Core (adds its OpenCode commands, agents and hooks)"
  run npx -y @opengsd/gsd-core@latest --opencode --global || true
  say "RTK (OpenCode plugin)"
  run rtk init --global --opencode || true
  say "Caveman (OpenCode provider routes + MCP entry)"
  run caveman setup --yes --agents opencode || true
fi

say "Done. Restart OpenCode (new plugin files need it), then verify: opencode mcp list (caveman, gsd, mcptoon); mcptoon doctor. See opencode/README.md."