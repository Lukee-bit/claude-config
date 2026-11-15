#!/usr/bin/env python3
"""Render the claude-config Cursor surface into ~/.cursor/.

Writes:
  ~/.cursor/mcp.json          from cursor/mcp.json (mcptoon gateway only)
  ~/.cursor/rules/claude-config.mdc
  merges GSD gsd-cursor-*.js into ~/.cursor/hooks.json (keeps other hooks)

On Windows, also runs wrap-claude-sh-hooks.py so Cursor Code can execute the
Claude settings hooks it auto-loads without Open-with dialogs.

Usage: python3 cursor/render.py [--dry-run]
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HOME = Path.home()
CURSOR = HOME / ".cursor"
IS_WIN = sys.platform == "win32"
DRY = "--dry-run" in sys.argv
STAMP = datetime.now().strftime("%Y%m%d")

GSD_HOOKS = {
    "sessionStart": "gsd-cursor-session-start.js",
    "preToolUse": "gsd-cursor-pre-tool.js",
    "postToolUse": "gsd-cursor-post-tool.js",
    "stop": "gsd-cursor-stop.js",
    "subagentStart": "gsd-cursor-subagent-start.js",
    "subagentStop": "gsd-cursor-subagent-stop.js",
}


def backup(path: Path) -> None:
    if path.exists():
        bak = path.with_name(f"{path.name}.bak-{STAMP}")
        if not bak.exists():
            shutil.copy2(path, bak)


def write_mcp() -> None:
    src = REPO / "cursor" / "mcp.json"
    dst = CURSOR / "mcp.json"
    data = json.loads(src.read_text(encoding="utf-8"))
    # Prefer PATH-resolved mcptoon; on Windows, pin .exe shim if present
    if IS_WIN:
        for cand in (
            HOME / ".local" / "bin" / "mcptoon.exe",
            HOME / "scoop" / "persist" / "uv" / "tools" / "shims" / "mcptoon.exe",
        ):
            if cand.exists():
                data["mcpServers"]["mcptoon"]["command"] = cand.as_posix()
                break
    if DRY:
        print(f"  would write {dst}: {json.dumps(data)}")
        return
    CURSOR.mkdir(parents=True, exist_ok=True)
    backup(dst)
    dst.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"  wrote {dst}")


def write_rule() -> None:
    src = REPO / "cursor" / "rules" / "claude-config.mdc"
    dst = CURSOR / "rules" / "claude-config.mdc"
    if DRY:
        print(f"  would place {src} -> {dst}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    backup(dst)
    shutil.copy2(src, dst)
    print(f"  wrote {dst}")


def merge_gsd_hooks() -> None:
    hooks_dir = HOME / ".claude" / "hooks"
    node = shutil.which("node") or (
        r"C:\Program Files\nodejs\node.exe" if IS_WIN else "/usr/local/bin/node"
    )
    if IS_WIN and not Path(node).exists():
        node = "node"

    dst = CURSOR / "hooks.json"
    if dst.exists():
        data = json.loads(dst.read_text(encoding="utf-8"))
    else:
        data = {"version": 1, "hooks": {}}

    hooks = data.setdefault("hooks", {})
    data.setdefault("version", 1)
    added = []

    for event, script_name in GSD_HOOKS.items():
        script = hooks_dir / script_name
        if not script.exists():
            continue
        cmd = f'"{node}" "{script.as_posix()}"' if IS_WIN else f"{node} {script.as_posix()}"
        arr = hooks.setdefault(event, [])
        if any(script_name in (x.get("command") or "") for x in arr):
            continue
        arr.append({"command": cmd, "timeout": 10})
        added.append(f"{event}:{script_name}")

    present = [n for n in GSD_HOOKS.values() if (hooks_dir / n).exists()]
    if DRY:
        if added:
            print(f"  would merge GSD cursor hooks: {added}")
        elif present:
            print(f"  GSD cursor hooks already registered ({len(present)} scripts on disk)")
        else:
            print("  GSD cursor hook scripts not present (run GSD --cursor or base+GSD install)")
        return
    if added:
        backup(dst)
        CURSOR.mkdir(parents=True, exist_ok=True)
        dst.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print(f"  merged GSD hooks into {dst}: {', '.join(added)}")
    elif present:
        print(f"  GSD cursor hooks already registered ({len(present)} scripts on disk)")
    else:
        print("  GSD cursor hook scripts not present (run GSD --cursor or base+GSD install)")


def ensure_git_bin_on_path() -> None:
    """Windows: User PATH must include Git\\bin so bash resolves for wrappers."""
    if not IS_WIN or DRY:
        if DRY and IS_WIN:
            print("  would ensure Git\\bin on User PATH")
        return
    git_bin = r"C:\Program Files\Git\bin"
    if not Path(git_bin).exists():
        print(f"  note: {git_bin} missing — install Git for Windows")
        return
    import winreg

    key = winreg.OpenKey(
        winreg.HKEY_CURRENT_USER, r"Environment", 0, winreg.KEY_READ | winreg.KEY_SET_VALUE
    )
    try:
        try:
            current, _ = winreg.QueryValueEx(key, "Path")
        except FileNotFoundError:
            current = ""
        parts = [p for p in current.split(";") if p]
        if not any(p.replace("/", "\\").lower() == git_bin.lower() for p in parts):
            winreg.SetValueEx(key, "Path", 0, winreg.REG_EXPAND_SZ, current.rstrip(";") + ";" + git_bin)
            print(f"  added {git_bin} to User PATH (new shells pick it up)")
        else:
            print("  Git\\bin already on User PATH")
    finally:
        winreg.CloseKey(key)


def wrap_windows_sh() -> None:
    if not IS_WIN:
        return
    script = REPO / "cursor" / "wrap-claude-sh-hooks.py"
    args = [sys.executable, str(script)]
    if DRY:
        args.append("--dry-run")
    print("  Windows Cursor interop: wrap Claude .sh hooks")
    subprocess.check_call(args)


def main() -> int:
    write_mcp()
    write_rule()
    merge_gsd_hooks()
    ensure_git_bin_on_path()
    wrap_windows_sh()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
