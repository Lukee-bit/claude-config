#!/usr/bin/env bash
# Restore this Claude Code stack on a Mac. Safe to re-run: existing files are backed up (*.bak-YYYYmmdd) before they are replaced.
#   ./install.sh --dry-run    print what would happen
#   ./install.sh              apply
#   ./install.sh --no-tools   config only (skip brew/uv/npm/ollama installs)
set -euo pipefail
cd "$(dirname "$0")"
DRY=0; TOOLS=1
for a in "$@"; do case "$a" in --dry-run) DRY=1;; --no-tools) TOOLS=0;; *) echo "unknown flag $a"; exit 2;; esac; done
STAMP=$(date +%Y%m%d)
run() { if [ $DRY -eq 1 ]; then echo "  would: $*"; else "$@"; fi; }
say() { printf '\n== %s\n' "$*"; }

# Copy a file with __HOME__ replaced by $HOME; back up what it replaces.
place() {
  local src="$1" dst="$2"
  if [ $DRY -eq 1 ]; then echo "  would place $src -> $dst"; return; fi
  mkdir -p "$(dirname "$dst")"
  [ -e "$dst" ] && cp "$dst" "$dst.bak-$STAMP"
  sed "s#__HOME__#$HOME#g" "$src" > "$dst"
  [ -x "$src" ] && chmod +x "$dst" || true
}

say "Prerequisites"
for c in brew uv npm node git; do command -v $c >/dev/null || { echo "missing: $c (install it first)"; exit 1; }; done
command -v claude >/dev/null || echo "note: 'claude' CLI not found; plugin steps will be skipped"

if [ $TOOLS -eq 1 ]; then
  say "Homebrew packages"
  run brew install rtk openjdk@21 ollama node pnpm gh
  say "uv tools"
  for t in jcodemunch-mcp mcp-obsidian mcptoon obsidian-wiki specify-cli; do run uv tool install "$t" || true; done
  say "npm globals"
  while read -r pkg; do [ -n "$pkg" ] && [ "${pkg%%@*}" != "npm" ] && run npm install -g "$pkg"; done < tools/npm-global.txt
  say "Other tools (manual, see README): lumen, Kwipu, Agent-Fusion jar"
  say "Ollama models"
  while read -r m; do [ -n "$m" ] && run ollama pull "$m"; done < tools/ollama-models.txt
fi

say "Claude Code config"
place claude/CLAUDE.md "$HOME/.claude/CLAUDE.md"
place claude/RTK.md "$HOME/.claude/RTK.md"
place claude/settings.json "$HOME/.claude/settings.json"
for f in claude/commands/* claude/hooks/*; do place "$f" "$HOME/.claude/${f#claude/}"; done
if [ $DRY -eq 0 ]; then mkdir -p "$HOME/.claude/skills"; cp -R skills/. "$HOME/.claude/skills/"; else echo "  would copy skills/ -> ~/.claude/skills"; fi

say "Helper scripts and mcptoon"
for f in bin/*; do place "$f" "$HOME/.claude-tools/bin/$(basename "$f")"; done
place mcptoon/config.json "$HOME/.mcptoon/config.json"

say "MCP servers in ~/.claude.json (mcptoon, caveman)"
if [ $DRY -eq 0 ]; then
python3 - <<'PY'
import json, os
home = os.path.expanduser("~")
p = os.path.join(home, ".claude.json")
c = json.load(open(p)) if os.path.exists(p) else {}
new = json.loads(open("claude/mcpServers.json").read().replace("__HOME__", home))
c.setdefault("mcpServers", {}).update(new)
json.dump(c, open(p, "w"), indent=2)
print("  merged:", ", ".join(new))
PY
else echo "  would merge claude/mcpServers.json into ~/.claude.json"; fi

say "Lightpanda (primary browser, Comet is the fallback)"
if [ $DRY -eq 0 ] && [ ! -x "$HOME/.local/bin/lightpanda" ]; then
  case "$(uname -m)" in arm64) LP=lightpanda-aarch64-macos;; *) LP=lightpanda-x86_64-macos;; esac
  mkdir -p "$HOME/.local/share/lightpanda" "$HOME/.local/bin"
  gh release download 1.0.3 --repo lightpanda-io/browser -p "$LP" -D "$HOME/.local/share/lightpanda" --clobber
  chmod +x "$HOME/.local/share/lightpanda/$LP"; xattr -d com.apple.quarantine "$HOME/.local/share/lightpanda/$LP" 2>/dev/null || true
  ln -sf "$HOME/.local/share/lightpanda/$LP" "$HOME/.local/bin/lightpanda"
else echo "  would install lightpanda 1.0.3 from GitHub releases (or already present)"; fi
place launchd/io.lightpanda.serve.plist "$HOME/Library/LaunchAgents/io.lightpanda.serve.plist"
echo "  start the CDP daemon: launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/io.lightpanda.serve.plist"
D="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
if [ $DRY -eq 0 ] && [ -f "$D" ]; then python3 - "$D" <<'PY'
import json, os, sys
p = sys.argv[1]; d = json.load(open(p))
d.setdefault("mcpServers", {})["lightpanda"] = {"command": os.path.expanduser("~/.local/bin/lightpanda"), "args": ["mcp"]}
json.dump(d, open(p, "w"), indent=2)
PY
else echo "  would add lightpanda to Claude Desktop config"; fi

say "Plugins"
if command -v claude >/dev/null; then
python3 - <<'PY' | while read -r repo; do run claude plugin marketplace add "$repo" || true; done
import json
for n, s in json.load(open("claude/plugins.json"))["marketplaces"].items(): print(s["repo"])
PY
python3 - <<'PY' | while read -r p; do run claude plugin install "$p" || true; done
import json
print("\n".join(json.load(open("claude/plugins.json"))["enabled"]))
PY
fi

say "Caveman proxy (launchd)"
place launchd/com.caveman.proxy.plist "$HOME/Library/LaunchAgents/com.caveman.proxy.plist"
echo "  after 'caveman setup' has installed ~/.caveman, load it with:"
echo "  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.caveman.proxy.plist"

say "Done. Next steps are in README.md (Agent-Fusion jar, Kwipu, lumen, Obsidian, restart Claude Code)."
