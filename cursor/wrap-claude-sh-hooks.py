#!/usr/bin/env python3
"""Windows-only: wrap Claude Code .sh hooks that Cursor also executes.

Cursor Code loads ~/.claude/settings.json as third-party hooks. Claude auto-prepends
bash for .sh on Windows; Cursor does not, so bare .sh paths become \"Select an app\"
dialogs. This script:

  1. Writes ~/.claude/hooks/<name>.cmd launchers that call absolute bash.exe on the .sh
  2. Retargets matching settings.json command strings to those .cmd files
  3. Leaves the original .sh scripts in place (Claude still runs them via the .cmd)

Safe to re-run. No-ops on non-Windows. Does not touch OpenCode or other agents' configs.

Usage: python3 cursor/wrap-claude-sh-hooks.py [--dry-run]
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
HOOKS = HOME / ".claude" / "hooks"
SETTINGS = HOME / ".claude" / "settings.json"
BASH = Path(r"C:\Program Files\Git\bin\bash.exe")
DRY = "--dry-run" in sys.argv


def write_cmd(name: str, sh: Path, extra_path: str | None = None) -> Path:
    cmd_path = HOOKS / f"{name}.cmd"
    lines = ["@echo off", "setlocal"]
    if extra_path:
        lines.append(f'set "PATH={extra_path};%PATH%"')
    lines.append(f'"{BASH}" "{sh}" %*')
    lines.append("exit /b %ERRORLEVEL%")
    body = "\r\n".join(lines) + "\r\n"
    if DRY:
        print(f"  would write {cmd_path}")
    else:
        cmd_path.write_text(body, encoding="ascii")
    return cmd_path


def main() -> int:
    if sys.platform != "win32":
        print("skip: wrap-claude-sh-hooks is Windows-only")
        return 0
    if not BASH.exists():
        print(f"missing Git bash: {BASH} (install Git for Windows)", file=sys.stderr)
        return 1
    if not SETTINGS.exists():
        print(f"missing {SETTINGS}", file=sys.stderr)
        return 1

    data = json.loads(SETTINGS.read_text(encoding="utf-8"))
    replacements: dict[str, str] = {}

    # Known scripts under ~/.claude/hooks
    for sh in sorted(HOOKS.glob("*.sh")):
        if sh.name.startswith("gsd-node-runner"):
            continue  # helper, not a hook entry by itself
        if sh.name == "caveman-statusline.sh":
            continue  # statusline, not a Cursor hook event
        cmd = write_cmd(sh.stem, sh)
        old = sh.as_posix()
        new = cmd.as_posix()
        replacements[old] = new
        replacements[f'"{old}"'] = f'"{new}"'
        replacements[f"bash {old}"] = new
        replacements[f'bash "{old}"'] = new

    # wiki-stop lives outside ~/.claude/hooks
    wiki_sh = HOME / "AppData/Roaming/uv/tools/obsidian-wiki/Lib/site-packages/obsidian_wiki/_data/hooks/wiki-stop-capture.sh"
    wiki_scripts = HOME / "AppData/Roaming/uv/tools/obsidian-wiki/Scripts"
    if wiki_sh.exists():
        wiki_cmd = write_cmd(
            "wiki-stop-capture",
            wiki_sh,
            extra_path=str(wiki_scripts) if wiki_scripts.exists() else None,
        )
        old = wiki_sh.as_posix()
        new = wiki_cmd.as_posix()
        # match the PATH=... bash "..." form
        replacements[
            f'PATH="{wiki_scripts.as_posix()}:$PATH" bash "{old}"'
        ] = new
        replacements[f'bash "{old}"'] = new
        replacements[old] = new

    changed: list[str] = []

    def walk(o, path=""):
        if isinstance(o, dict):
            if "command" in o and isinstance(o["command"], str):
                raw = o["command"]
                if ".cmd" in raw:
                    return
                # Prefer longest old keys first
                for old in sorted(replacements.keys(), key=len, reverse=True):
                    if old in raw or raw == old:
                        new = replacements[old]
                        o["command"] = new if raw == old else raw.replace(old, new)
                        # If still starts with bash after replace to a .cmd, strip bash
                        c = o["command"].strip()
                        m = re.match(r'^bash\s+"?(.+?\.cmd)"?\s*$', c)
                        if m:
                            o["command"] = m.group(1)
                        # Strip PATH=... prefix left in front of a .cmd
                        m2 = re.match(r'^PATH="[^"]*"\s+(.+\.cmd)\s*$', o["command"].strip())
                        if m2:
                            o["command"] = m2.group(1)
                        changed.append(f"{path}")
                        break
            for k, v in o.items():
                walk(v, f"{path}.{k}")
        elif isinstance(o, list):
            for i, v in enumerate(o):
                walk(v, f"{path}[{i}]")

    walk(data.get("hooks", {}))

    # Also catch any remaining bare .sh path commands
    def wrap_bare(o, path=""):
        if isinstance(o, dict):
            c = o.get("command")
            if isinstance(c, str) and ".sh" in c and ".cmd" not in c and "bash.exe" not in c.lower():
                m = re.fullmatch(r'"?(?P<p>[A-Za-z]:[^"\n]+\.sh)"?', c.strip())
                if m:
                    sh = Path(m.group("p"))
                    if sh.exists():
                        cmd = write_cmd(sh.stem, sh)
                        o["command"] = cmd.as_posix()
                        changed.append(f"{path}: bare")
            for k, v in o.items():
                wrap_bare(v, f"{path}.{k}")
        elif isinstance(o, list):
            for i, v in enumerate(o):
                wrap_bare(v, f"{path}[{i}]")

    wrap_bare(data.get("hooks", {}))

    if DRY:
        print(f"  would retarget {len(changed)} hook command(s)")
        for c in changed:
            print("   ", c)
        return 0

    if changed:
        stamp = datetime.now().strftime("%Y%m%d")
        backup = SETTINGS.with_name(f"settings.json.bak-cursorwrap-{stamp}")
        if not backup.exists():
            shutil.copy2(SETTINGS, backup)
        SETTINGS.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print(f"  retargeted {len(changed)} hook command(s); backup {backup.name}")
    else:
        print("  no Claude .sh hook commands needed retargeting")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
