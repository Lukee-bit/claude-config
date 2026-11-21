#!/usr/bin/env bash
# Restore this Claude Code stack on a Mac. Safe to re-run: existing files are backed up (*.bak-YYYYmmdd) before they are replaced.
#   ./install.sh --dry-run    print what would happen
#   ./install.sh              apply
#   ./install.sh --no-tools   config only (skip brew/uv/npm/ollama installs)
#   ./install.sh --harnesses opencode,cursor   leave Claude Code's own config alone (Install.command passes your choice)
# Most people should double-click Install.command instead: it installs the prerequisites and asks which harnesses to set up.
set -euo pipefail
cd "$(dirname "$0")"
DRY=0; TOOLS=1; HARNESSES=claude,cursor,opencode
while [ $# -gt 0 ]; do case "$1" in
  --dry-run) DRY=1;; --no-tools) TOOLS=0;;
  --harnesses) HARNESSES="${2:?--harnesses needs a list}"; shift;; --harnesses=*) HARNESSES="${1#*=}";;
  *) echo "unknown flag $1"; exit 2;; esac; shift; done
case ",$HARNESSES," in *,claude,*) WITH_CLAUDE=1;; *) WITH_CLAUDE=0;; esac
STAMP=$(date +%Y%m%d)
run() { if [ $DRY -eq 1 ]; then echo "  would: $*"; else "$@"; fi; }
say() { printf '\n== %s\n' "$*"; }

BP=/opt/homebrew; command -v brew >/dev/null && BP="$(brew --prefix)"
# Plain HTTPS download: needs no gh login (a fresh Mac has none).
fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

# Copy a file with __HOME__ replaced by $HOME (and /opt/homebrew by this Mac's Homebrew prefix); back up what it replaces.
place() {
  local src="$1" dst="$2"
  if [ $DRY -eq 1 ]; then echo "  would place $src -> $dst"; return; fi
  mkdir -p "$(dirname "$dst")"
  [ -e "$dst" ] && cp "$dst" "$dst.bak-$STAMP"
  sed -e "s#__HOME__#$HOME#g" -e "s#/opt/homebrew#$BP#g" "$src" > "$dst"
  [ -x "$src" ] && chmod +x "$dst" || true
}

say "Prerequisites"
export PATH="$HOME/.local/bin:$HOME/.caveman/bin:$PATH"
for c in brew uv npm node git python3 curl; do command -v $c >/dev/null || { echo "missing: $c (install it first)"; exit 1; }; done
command -v claude >/dev/null || echo "note: 'claude' CLI not found; plugin steps will be skipped"

if [ $TOOLS -eq 1 ]; then
  say "Homebrew packages"
  run brew install rtk ollama node pnpm gh
  say "uv tools"
  for t in jcodemunch-mcp mcp-obsidian mcptoon obsidian-wiki specify-cli; do run uv tool install "$t" || true; done
  run uv tool install -p 3.13 serena-agent || true
  say "npm globals"
  while read -r pkg; do [ -n "$pkg" ] && [ "${pkg%%@*}" != "npm" ] && run npm install -g "$pkg"; done < tools/npm-global.txt
  say "lumen (single binary)"
  if ! command -v lumen >/dev/null; then
    case "$(uname -m)" in arm64) LU=arm64;; *) LU=amd64;; esac
    if [ $DRY -eq 1 ]; then echo "  would download lumen 0.0.42"; else mkdir -p "$HOME/.local/bin" && fetch "https://github.com/ory/lumen/releases/download/v0.0.42/lumen-0.0.42-darwin-$LU" "$HOME/.local/bin/lumen" && chmod +x "$HOME/.local/bin/lumen" && { xattr -d com.apple.quarantine "$HOME/.local/bin/lumen" 2>/dev/null || true; }; fi
  fi
  say "Ollama models"
  while read -r m; do [ -n "$m" ] && run ollama pull "$m"; done < tools/ollama-models.txt
fi

say "Claude Code config"
if [ $WITH_CLAUDE -eq 1 ]; then
place claude/CLAUDE.md "$HOME/.claude/CLAUDE.md"
place claude/RTK.md "$HOME/.claude/RTK.md"
place claude/settings.json "$HOME/.claude/settings.json"
# Caveman owns its hooks (paths differ per Mac and per Homebrew prefix): drop the copied ones; `caveman setup` below writes them natively.
if [ $DRY -eq 0 ]; then python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json"); s = json.load(open(p))
own = ("caveman-proxy' native-hook", "caveman' shrink-hook", "caveman-blocks")
for ev, groups in list(s.get("hooks", {}).items()):
    for g in groups:
        g["hooks"] = [h for h in g.get("hooks", []) if not any(m in h.get("command", "") for m in own)]
    s["hooks"][ev] = [g for g in groups if g["hooks"]]
    if not s["hooks"][ev]: del s["hooks"][ev]
json.dump(s, open(p, "w"), indent=2)
PY
fi
for f in claude/commands/* claude/hooks/*; do place "$f" "$HOME/.claude/${f#claude/}"; done
else echo "  skipped: Claude Code is not in --harnesses"; fi
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
if [ $WITH_CLAUDE -eq 0 ]; then echo "  skipped: Claude Code is not in --harnesses"
elif [ $DRY -eq 0 ]; then
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

say "Third-party repos built from source (tools/git-sources.txt)"
while read -r name url rev; do
  [ -z "$name" ] && continue; case "$name" in \#*) continue;; esac
  if [ "$name" = Kwipu ]; then dir="$HOME/.claude-tools/Kwipu"; else dir="$HOME/.claude-tools/src/$name"; fi
  if [ -d "$dir" ]; then echo "  $name present"; continue; fi
  if [ $DRY -eq 1 ]; then echo "  would clone $name @ $rev"; continue; fi
  mkdir -p "$(dirname "$dir")" && git clone -q "$url" "$dir" && git -C "$dir" checkout -q "$rev"
done < tools/git-sources.txt
if [ $DRY -eq 0 ] && [ -d "$HOME/.claude-tools/Kwipu" ] && [ ! -x "$HOME/.claude-tools/Kwipu/.venv/bin/python" ]; then
  UV_LINK_MODE=copy uv venv "$HOME/.claude-tools/Kwipu/.venv" --python 3.13 && UV_LINK_MODE=copy uv pip install --python "$HOME/.claude-tools/Kwipu/.venv/bin/python" -r "$HOME/.claude-tools/Kwipu/requirements.txt"
fi
say "Obsidian Local REST API plugin (copied into each vault by bin/vault-bootstrap)"
PLG="$HOME/.claude-tools/obsidian-plugins/obsidian-local-rest-api"
if [ $DRY -eq 0 ] && [ ! -f "$PLG/main.js" ]; then
  mkdir -p "$PLG"; for a in main.js manifest.json styles.css; do fetch "https://github.com/coddingtonbear/obsidian-local-rest-api/releases/latest/download/$a" "$PLG/$a"; done
else echo "  would download the plugin (or already present)"; fi
say "Lightpanda (primary browser, Chrome is the fallback)"
if [ $DRY -eq 0 ] && [ ! -x "$HOME/.local/bin/lightpanda" ]; then
  case "$(uname -m)" in arm64) LP=lightpanda-aarch64-macos;; *) LP=lightpanda-x86_64-macos;; esac
  mkdir -p "$HOME/.local/share/lightpanda" "$HOME/.local/bin"
  fetch "https://github.com/lightpanda-io/browser/releases/download/1.0.3/$LP" "$HOME/.local/share/lightpanda/$LP"
  chmod +x "$HOME/.local/share/lightpanda/$LP"; xattr -d com.apple.quarantine "$HOME/.local/share/lightpanda/$LP" 2>/dev/null || true
  ln -sf "$HOME/.local/share/lightpanda/$LP" "$HOME/.local/bin/lightpanda"
else echo "  would install lightpanda 1.0.3 from GitHub releases (or already present)"; fi
say "FigCraft CLI + MCP server (design; the app itself is a manual download from the figcraft releases page)"
if [ $DRY -eq 0 ] && [ ! -x "$HOME/.artcraft/bin/figcraft-cli" ]; then
  FT=$(mktemp -d); mkdir -p "$HOME/.artcraft/bin"
  FU=$(curl -fsSL https://api.github.com/repos/storytold/figcraft/releases/latest | python3 -c "import sys,json;print(next(a['browser_download_url'] for a in json.load(sys.stdin)['assets'] if a['name'].startswith('figcraft-cli-') and a['name'].endswith('macos-universal.zip')))") \
    && fetch "$FU" "$FT/figcraft-cli.zip" \
    && unzip -oq "$FT"/figcraft-cli-*.zip -d "$FT" \
    && cp "$(find "$FT" -name figcraft-cli -type f | head -1)" "$HOME/.artcraft/bin/figcraft-cli" \
    && chmod 755 "$HOME/.artcraft/bin/figcraft-cli" && xattr -dr com.apple.quarantine "$HOME/.artcraft/bin/figcraft-cli" 2>/dev/null || true
  rm -rf "$FT"
else echo "  would install figcraft-cli (latest release) to ~/.artcraft/bin (or already present)"; fi
place launchd/io.lightpanda.serve.plist "$HOME/Library/LaunchAgents/io.lightpanda.serve.plist"
# bootout first so a re-run reloads instead of failing on "already loaded"
load_agent() { local pl="$HOME/Library/LaunchAgents/$1.plist"; [ $DRY -eq 1 ] && { echo "  would load $1"; return; }; launchctl bootout "gui/$(id -u)/$1" 2>/dev/null || true; launchctl bootstrap "gui/$(id -u)" "$pl" && echo "  loaded: $1"; }
load_agent io.lightpanda.serve
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
  OS="$HOME/.claude/plugins/marketplaces/obsidian-skills/plugins/obsidian/skills"; [ -d "$OS" ] || OS="$HOME/.claude/plugins/marketplaces/obsidian-skills/skills"; [ -d "$OS" ] && ln -sfn "$OS" "$C/obsidian-skills"
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
# Caveman records the proxy route it wired into each agent; the proxy must listen on exactly that route.
CM=""; [ $WITH_CLAUDE -eq 1 ] && CM="claude"
case ",$HARNESSES," in *,opencode,*) CM="${CM:+$CM,}opencode";; esac
place launchd/com.caveman.proxy.plist "$HOME/Library/LaunchAgents/com.caveman.proxy.plist"
if [ -z "$CM" ]; then echo "  caveman: neither Claude Code nor OpenCode selected, skipped"
elif [ $DRY -eq 1 ]; then echo "  would run caveman setup --yes --agents $CM and load the proxy on the route it records"
elif command -v caveman >/dev/null; then
  caveman setup --yes --agents "$CM" || true
  ROUTE=$(python3 - "$CM" <<'PY'
import json, os, sys
for a in sys.argv[1].split(","):
    f = os.path.expanduser(f"~/.caveman/integrations/{a}.json")
    if os.path.exists(f):
        for op in json.load(open(f)).get("operations", []):
            r = (op.get("owned") or {}).get("route")
            if r: print(r.split("//", 1)[-1].split("/", 1)[0]); raise SystemExit
PY
)
  if [ -n "$ROUTE" ]; then
    PL="$HOME/Library/LaunchAgents/com.caveman.proxy.plist"
    sed -i '' "s#<string>127\.0\.0\.1:[0-9]*</string>#<string>$ROUTE</string>#" "$PL"
    if [ $WITH_CLAUDE -eq 1 ]; then
      python3 - "$ROUTE" <<'PY'
import json, os, sys
p = os.path.expanduser("~/.claude/settings.json"); s = json.load(open(p))
s.setdefault("env", {})["ANTHROPIC_BASE_URL"] = "http://%s/w/claude" % sys.argv[1]
json.dump(s, open(p, "w"), indent=2)
PY
    fi
    load_agent com.caveman.proxy
    [ $WITH_CLAUDE -eq 1 ] && { caveman doctor claude --fix || true; }
  fi
else echo "  @caveman-ai/cli is missing: re-run the installer once its npm install has succeeded"; fi

mkdir -p "$HOME/.claude-tools"
if [ $DRY -eq 0 ]; then pwd > "$HOME/.claude-tools/config-repo"; git rev-parse HEAD > "$HOME/.claude-tools/.config-rev" 2>/dev/null || true; fi

say "Done. Remaining by hand: figcraft app, open Obsidian once per vault, restart Claude Code. See README.md."
