#!/usr/bin/env bash
# Pre-approve every MCP tool this setup uses so agents never wait for a tool-use prompt.
# Usage: allow-tools.sh          explicit allow rules (server, wildcard and per-tool forms)
#        allow-tools.sh bypass   also set permissions.defaultMode=bypassPermissions (no prompts at all, built-in tools too)
set -euo pipefail
S="$HOME/.claude/settings.json"
cp "$S" "$S.bak-$(date +%Y%m%d%H%M%S)"
python3 - "$S" "${1:-}" <<'PY'
import json, sys
p, mode = sys.argv[1], sys.argv[2]
d = json.load(open(p))
perm = d.setdefault("permissions", {})
allow = perm.setdefault("allow", [])
rules = []
for srv in ("mcptoon", "caveman", "plugin_context-mode_context-mode"):
    rules += [f"mcp__{srv}", f"mcp__{srv}__*"]
rules += ["mcp__mcptoon__mcptoon_call", "mcp__mcptoon__mcptoon_inspect", "mcp__mcptoon__mcptoon_manifest"]
for r in rules:
    if r not in allow:
        allow.append(r)
if mode == "bypass":
    perm["defaultMode"] = "bypassPermissions"
    d["skipDangerousModePermissionPrompt"] = True
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
open(p, "a").write("\n")
print("mcp allow rules:", [r for r in allow if r.startswith("mcp__")])
print("defaultMode:", perm.get("defaultMode"))
PY
echo "done. Quit and restart the Claude Code session (new terminal tab), not just a new prompt."
