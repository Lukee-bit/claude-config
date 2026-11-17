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
  run brew install rtk ollama node pnpm gh
  say "uv tools"
  for t in jcodemunch-mcp mcp-obsidian mcptoon obsidian-wiki specify-cli; do run uv tool install "$t" || true; done
  run uv tool install -p 3.13 serena-agent || true
  say "npm globals"
  while read -r pkg; do [ -n "$pkg" ] && [ "${pkg%%@*}" != "npm" ] && run npm install -g "$pkg"; done < tools/npm-global.txt
  say "Other tools (manual, see README): lumen, Kwipu"
  say "Ollama models"
  while read -r m; do [ -n "$m" ] && run ollama pull "$m"; done < tools/ollama-models.txt
fi

say "Claude Code config"
place claude/CLAUDE.md "$HOME/.claude/CLAUDE.md"
place claude/RTK.md "$HOME/.claude/RTK.md"
place claude/settings.json "$HOME/.claude/settings.json"
for f in claude/commands/* claude/hooks/*; do place "$f" "$HOME/.claude/${f#claude/}"; done
if [ $DRY -eq 0 ]; then mkdir -p "$HOME/.claude/skills"; cp -R skills/. "$HOME/.claude/skills/"; else echo "  would copy skills/ -> ~/.claude/skills"; fi

say "GSD Core (full install is snapshotted into the mcptoon skill catalog, then trimmed to the core profile)"
run npx -y @opengsd/gsd-core@latest --claude --global --profile=full || true
if [ $DRY -eq 0 ]; then
  mkdir -p "$HOME/.claude-tools/skill-catalog/gsd"
  for d in "$HOME"/.claude/skills/gsd-*/; do [ -d "$d" ] && { rm -rf "$HOME/.claude-tools/skill-catalog/gsd/$(basename "$d")"; cp -R "$d" "$HOME/.claude-tools/skill-catalog/gsd/$(basename "$d")"; }; done
fi
run npx -y @opengsd/gsd-core@latest --claude --global --profile=core || true

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
say "FigCraft CLI + MCP server (design; the app itself is a manual download from the figcraft releases page)"
if [ $DRY -eq 0 ] && [ ! -x "$HOME/.artcraft/bin/figcraft-cli" ]; then
  FT=$(mktemp -d); mkdir -p "$HOME/.artcraft/bin"
  gh release download --repo storytold/figcraft -p 'figcraft-cli-*-macos-universal.zip' -D "$FT" --clobber \
    && unzip -oq "$FT"/figcraft-cli-*.zip -d "$FT" \
    && cp "$(find "$FT" -name figcraft-cli -type f | head -1)" "$HOME/.artcraft/bin/figcraft-cli" \
    && chmod 755 "$HOME/.artcraft/bin/figcraft-cli" && xattr -dr com.apple.quarantine "$HOME/.artcraft/bin/figcraft-cli" 2>/dev/null || true
  rm -rf "$FT"
else echo "  would install figcraft-cli (latest release) to ~/.artcraft/bin (or already present)"; fi
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

say "Skill catalog (mcptoon) and project memory (obsidian-wiki)"
if [ $DRY -eq 0 ]; then
  C="$HOME/.claude-tools/skill-catalog"; mkdir -p "$C"
  CS="$HOME/.claude/plugins/marketplaces/candor/plugins/candor/skills"; [ -d "$CS" ] && ln -sfn "$CS" "$C/candor"
  OS="$HOME/.claude/plugins/marketplaces/obsidian-skills/skills"; [ -d "$OS" ] && ln -sfn "$OS" "$C/obsidian-skills"
  mkdir -p "$C/user"; while read -r s; do [ -n "$s" ] && [ -d "$HOME/.claude/skills/$s" ] && [ ! -d "$HOME/.local/share/harness-master-controller/skills/$s" ] && ln -sfn "$HOME/.claude/skills/$s" "$C/user/$s"; done < tools/folded-skills.txt
  OW="$(ls -d "$HOME"/.local/share/uv/tools/obsidian-wiki/lib/python*/site-packages/obsidian_wiki/_data/skills 2>/dev/null | head -1)"
  if [ -n "$OW" ]; then
    ln -sfn "$OW" "$C/obsidian-wiki"
    for s in llm-wiki wiki-capture wiki-query; do ln -sfn "$OW/$s" "$HOME/.claude/skills/$s"; done
  fi
  roots="$C"; [ -d "$HOME/.local/share/harness-master-controller/skills" ] && roots="$HOME/.local/share/harness-master-controller/skills $C"
  command -v mcptoon >/dev/null && { mcptoon skills index $roots || true; }
  if command -v obsidian-wiki >/dev/null; then
    obsidian-wiki hooks install || true; obsidian-wiki hooks install --only UserPromptSubmit || true
  fi
else echo "  would link candor + obsidian-wiki skills into ~/.claude-tools/skill-catalog, index them, register the obsidian-wiki recap/recall hooks"; fi

say "Caveman proxy (launchd)"
place launchd/com.caveman.proxy.plist "$HOME/Library/LaunchAgents/com.caveman.proxy.plist"
echo "  after 'caveman setup' has installed ~/.caveman, load it with:"
echo "  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.caveman.proxy.plist"

mkdir -p "$HOME/.claude-tools"
if [ $DRY -eq 0 ]; then pwd > "$HOME/.claude-tools/config-repo"; git rev-parse HEAD > "$HOME/.claude-tools/.config-rev" 2>/dev/null || true; fi

say "Done. Next steps are in README.md (Kwipu, lumen, Obsidian, restart Claude Code)."
