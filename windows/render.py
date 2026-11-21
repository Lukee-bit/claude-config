#!/usr/bin/env python3
"""Render this repo's macOS-shaped templates for Windows (Git Bash for scripts, PowerShell 7 for services).

The templates (claude/settings.json, mcptoon/config.json, claude/mcpServers.json, launchd/*.plist) stay the single
source of truth: add or remove a hook, MCP server or service there and every platform follows. This file only holds
the *rules* that map macOS paths and launchers to Windows ones. It never edits the templates.

  render.py settings   --home H --out FILE        claude/settings.json  -> ~/.claude/settings.json
  render.py mcptoon    --home H --bash B --out F  mcptoon/config.json   -> ~/.mcptoon/config.json
  render.py mcpservers --home H --out FILE        claude/mcpServers.json (merged into ~/.claude.json by install.ps1)
  render.py service    --home H --plist P --out F launchd/*.plist       -> service spec JSON for windows/run-service.ps1
"""
import argparse, json, plistlib, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UV_TOOLS_WIN = "AppData/Roaming/uv/tools"          # macOS: .local/share/uv/tools

# --- rules: macOS -> Windows -------------------------------------------------------------------------------
# Hooks that Caveman's own installer owns. `caveman setup` writes them natively per OS, so they are not copied.
CAVEMAN_OWNED = ("caveman-proxy' native-hook", "caveman' shrink-hook", "caveman-blocks")
# Interpreter for scripts under .claude-tools/bin (a Windows shell cannot honour a shebang).
INTERPRETER = {"agent-handoff": "python", "kwipu-build.py": "python", "obsidian-trust-vault.py": "python"}
# Homebrew binaries that are npm packages on Windows.
HOMEBREW_BIN = "/opt/homebrew/bin/"
# MCP servers whose Windows invocation needs extra arguments (context-mode 2.x requires `server`).
EXTRA_ARGS = {"context-mode": ["server"]}


def fwd(p) -> str:
    return str(p).replace("\\", "/")


def sub_home(text: str, home: str) -> str:
    return text.replace("__HOME__", fwd(home))


def hook_command(cmd: str, home: str) -> str:
    h = fwd(home)
    # obsidian-wiki's uv tool lives elsewhere and uses Scripts/ and Lib/ on Windows.
    cmd = cmd.replace(f"{h}/.local/share/uv/tools", f"{h}/{UV_TOOLS_WIN}")
    cmd = re.sub(rf"({re.escape(h)}/{UV_TOOLS_WIN}/[^/]+)/bin\b", r"\1/Scripts", cmd)
    cmd = re.sub(r"/lib/python[\d.]+/site-packages", "/Lib/site-packages", cmd)
    first = cmd.split(" ", 1)[0].strip("\"'")
    rest = cmd[len(cmd.split(" ", 1)[0]):]
    base = first.rsplit("/", 1)[-1]
    if first.startswith(f"{h}/.local/bin/") and "." not in base:
        return f"{first}.exe{rest}"
    if first.startswith(f"{h}/.claude-tools/bin/") or first.startswith(f"{h}/.claude/hooks/"):
        interp = INTERPRETER.get(base) or ("node" if base.endswith((".mjs", ".js")) else "bash")
        return f'{interp} "{first}"{rest}'
    return cmd


def render_settings(args):
    tpl = json.loads(sub_home((ROOT / "claude/settings.json").read_text(encoding="utf-8"), args.home))
    out_hooks = {}
    for event, groups in tpl.get("hooks", {}).items():
        kept = []
        for g in groups:
            hs = []
            for h in g.get("hooks", []):
                c = h.get("command", "")
                if any(m in c for m in CAVEMAN_OWNED):
                    continue
                if h.get("type", "command") == "command" and c:
                    h = {**h, "command": hook_command(c, args.home), "shell": "bash"}
                hs.append(h)
            if hs:
                kept.append({**g, "hooks": hs})
        if kept:
            out_hooks[event] = kept
    tpl["hooks"] = out_hooks
    if args.base_url:
        tpl.setdefault("env", {})["ANTHROPIC_BASE_URL"] = args.base_url
    Path(args.out).write_text(json.dumps(tpl, indent=2) + "\n", encoding="utf-8")


def win_command(cmd, home: str, bash: str):
    """Translate one mcptoon `command` (string or list) to a Windows launcher list."""
    cmd = [cmd] if isinstance(cmd, str) else list(cmd)
    h = fwd(home)
    head = cmd[0]
    if head.startswith(f"{h}/.claude-tools/bin/"):
        return [bash, *cmd], None
    if head == "npx":
        cmd[0] = "npx.cmd"
    elif head.startswith(HOMEBREW_BIN):
        name = head[len(HOMEBREW_BIN):]
        cmd[0] = f"{name}.cmd"
        return cmd, EXTRA_ARGS.get(name)
    elif (head.startswith(f"{h}/.local/bin/") or head.startswith(f"{h}/.artcraft/bin/")) and "." not in head.rsplit("/", 1)[-1]:
        cmd[0] = head + ".exe"
    return cmd, None


def render_mcptoon(args):
    cfg = json.loads(sub_home((ROOT / "mcptoon/config.json").read_text(encoding="utf-8"), args.home))
    for name, srv in cfg["servers"].items():
        cmd, extra = win_command(srv["command"], args.home, args.bash)
        srv["command"] = cmd
        if extra:
            srv["args"] = [*extra, *srv.get("args", [])]
    Path(args.out).write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")


def render_mcpservers(args):
    h = fwd(args.home)
    cfg = json.loads(sub_home((ROOT / "claude/mcpServers.json").read_text(encoding="utf-8"), args.home))
    for srv in cfg.values():
        c = srv["command"]
        if c == f"{h}/.local/share/uv/tools/mcptoon/bin/python":
            # Same endpoint as the repo's project .mcp.json, else Claude reports "defined in multiple scopes".
            srv["command"], srv["args"] = "mcptoon", ["serve"]
        elif c.startswith(f"{h}/.") and "." not in c.rsplit("/", 1)[-1]:
            srv["command"] = c + ".exe"
    Path(args.out).write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")


def render_service(args):
    pl = plistlib.loads(Path(args.plist).read_bytes())
    h = fwd(args.home)
    argv = [a.replace("__HOME__", h) for a in pl["ProgramArguments"]]
    exe = argv[0]
    if "." not in exe.rsplit("/", 1)[-1]:
        exe += ".exe"
    env = {k: v.replace("__HOME__", h) for k, v in pl.get("EnvironmentVariables", {}).items() if k != "HOME"}
    if args.listen:
        env["CAVEMAN_LISTEN"] = args.listen
    spec = {"name": pl["Label"], "exe": exe, "args": argv[1:], "env": env,
            "throttle": pl.get("ThrottleInterval", 5), "log": (pl.get("StandardOutPath") or "").replace("__HOME__", h)}
    Path(args.out).write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("what", choices=["settings", "mcptoon", "mcpservers", "service"])
    ap.add_argument("--home", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--bash", default="C:/Program Files/Git/bin/bash.exe")
    ap.add_argument("--base-url", default="")
    ap.add_argument("--plist", default="")
    ap.add_argument("--listen", default="")
    a = ap.parse_args()
    {"settings": render_settings, "mcptoon": render_mcptoon, "mcpservers": render_mcpservers, "service": render_service}[a.what](a)


if __name__ == "__main__":
    sys.exit(main())
