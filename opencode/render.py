#!/usr/bin/env python3
"""Render the claude-config OpenCode V2 surface into ~/.config/opencode/opencode.json.

Single source of truth: `claude/mcpServers.json` for the MCP entries, and the
base install's plugin installs (npm globals, Claude plugin cache) for the
OpenCode `plugins[]` dirs. Merges both into the user's opencode.json, backed
up first as *.bak-<date>. Idempotent: re-running replaces the same keys;
anything it does not own — model, provider routes (caveman), the gsd MCP
entry, permissions — is preserved untouched.

Owned keys:
  mcp.mcptoon, mcp.lightpanda   (caveman and gsd write their own MCP entries)
  plugins[] entries for context-mode, ponytail and superpowers (id-aware: an
  existing entry for the same plugin id is replaced, not duplicated)

Usage: python3 opencode/render.py [--dry-run]
"""
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HOME = Path.home()
IS_WIN = sys.platform == "win32"
OC = HOME / ".config" / "opencode"

MCP_SERVERS = ("mcptoon", "lightpanda")  # rendered from claude/mcpServers.json
# Scalar, on purpose: installed OpenCode 2.x rejects the timeout *object*
# ({startup,catalog,execution}) that the current website schema documents —
# the server silently vanishes from `opencode mcp list` with a
# `configuration normalization diagnostic ... kind=invalid` log line.
# mcptoon's tools/list loads every upstream manifest on first call (~30s
# cold on Windows vs the ~5s default request timeout); warm answers are
# instant. Re-check the object shape on OpenCode upgrades.
MCP_TIMEOUTS = {"mcptoon": 60000}
# OpenCode plugin dirs. context-mode ships its OpenCode part as an npm global
# (tools/npm-global.txt); ponytail and superpowers live in the Claude plugin
# cache (claude/plugins.json). Both are created by the base installer.
PLUGIN_ORDER = ("context-mode", "ponytail", "superpowers")
PLUGIN_CACHE = HOME / ".claude" / "plugins" / "cache"


def render_mcp():
    tpl = json.loads((REPO / "claude" / "mcpServers.json").read_text(encoding="utf-8"))
    out = {}
    for name in MCP_SERVERS:
        e = tpl[name]
        cmd = e["command"].replace("__HOME__", str(HOME))
        args = list(e.get("args", []))
        if IS_WIN:
            if name == "mcptoon":
                shim = HOME / ".local" / "bin" / "mcptoon.exe"
                if shim.exists():  # uv shim (what the base install creates)
                    cmd, args = shim.as_posix(), ["serve"]
            if not cmd.endswith(".exe"):
                cmd += ".exe"  # uv-tools venv python / home-local builds
            cmd = Path(cmd).as_posix()
        entry = {"type": "local", "command": [cmd, *args], "enabled": True}
        if name in MCP_TIMEOUTS:
            entry["timeout"] = MCP_TIMEOUTS[name]
        out[name] = entry
    return out


def npm_global(name):
    npm = shutil.which("npm")  # bare "npm" is npm.cmd on Windows: CreateProcess needs the resolved path
    if not npm:
        return None
    try:
        root = subprocess.run(
            [npm, "root", "-g"], capture_output=True, text=True, timeout=60, check=True
        ).stdout.strip()
        p = Path(root) / name
        return p if (p / "package.json").exists() else None
    except Exception:
        return None


def latest_version_dir(base):
    if not base.is_dir():
        return None
    versions = [p for p in base.iterdir() if p.is_dir() and re.fullmatch(r"\d+(?:\.\d+)+", p.name)]
    return max(versions, key=lambda p: tuple(int(x) for x in p.name.split("."))) if versions else None


def plugin_dirs():
    return {
        "context-mode": npm_global("context-mode"),
        "ponytail": latest_version_dir(PLUGIN_CACHE / "ponytail" / "ponytail"),
        "superpowers": latest_version_dir(PLUGIN_CACHE / "claude-plugins-official" / "superpowers"),
    }


def plugin_id(path):  # .../ponytail/ponytail/5.3.3 -> ponytail
    parts = [p for p in re.split(r"[\\/]+", str(path).strip("\\/")) if p]
    while parts and re.fullmatch(r"\d+(?:\.\d+)+", parts[-1]):
        parts.pop()
    return parts[-1] if parts else str(path)


def main():
    dry = "--dry-run" in sys.argv
    mcp = render_mcp()
    plugins = plugin_dirs()
    missing = sorted(p for p in PLUGIN_ORDER if not plugins[p])
    if missing:
        sys.exit(
            "missing plugin installs: " + ", ".join(missing)
            + " — run the base installer (./install.sh / install.ps1) first"
        )
    plugins = {k: v.as_posix() for k, v in plugins.items()}

    cfg_path = OC / "opencode.json"
    cfg = json.loads(cfg_path.read_text(encoding="utf-8")) if cfg_path.exists() else {}

    # Installed 2.x puts server names directly under mcp (its own GSD/caveman
    # writers do too); a newer schema nests them under mcp.servers. Follow
    # whichever shape the file already uses.
    mcp_cfg = cfg.setdefault("mcp", {})
    target = mcp_cfg["servers"] if isinstance(mcp_cfg.get("servers"), dict) else mcp_cfg
    target.update(mcp)

    incoming = set(PLUGIN_ORDER)
    kept = [p for p in cfg.get("plugins", []) if plugin_id(p) not in incoming]
    cfg["plugins"] = kept + [plugins[p] for p in PLUGIN_ORDER]

    if dry:
        print("would merge mcp entries: " + ", ".join(mcp))
        for name, entry in mcp.items():
            print(f"  {name}: {json.dumps(entry)}")
        print("would set plugins[]:")
        for p in PLUGIN_ORDER:
            print(f"  {p}: {plugins[p]}")
        return

    OC.mkdir(parents=True, exist_ok=True)
    if cfg_path.exists():
        shutil.copy2(cfg_path, str(cfg_path) + ".bak-" + time.strftime("%Y%m%d"))
    cfg_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
    print(
        f"merged mcp entries ({', '.join(mcp)}) + {len(PLUGIN_ORDER)} plugin paths -> {cfg_path}"
    )


if __name__ == "__main__":
    main()