#!/usr/bin/env python3
"""Snapshot the live Claude Code stack into this repo.

Copies config, scripts, commands, hooks, skills and tool manifests from this machine,
replaces the home directory with __HOME__ (install.sh puts it back), and refuses to
finish if anything that looks like a secret ends up in the output.
Run again any time the stack changes, then review `git diff` before committing.
"""
from __future__ import annotations
import json, os, re, shutil, subprocess, sys
from pathlib import Path

HOME = Path.home()
OUT = Path(__file__).resolve().parent
CLAUDE = HOME / ".claude"
TOOLS = HOME / ".claude-tools"

BIN_SCRIPTS = ["agent-handoff", "vault-bootstrap", "spec-bootstrap", "index-bootstrap",
               "agent-fusion-run", "kwipu-mcp", "mcp-obsidian-run", "codegraph-run"]
# Third-party skills keep their own licenses; skip app-managed and unknown-origin ones.
SKILL_SKIP = {"synced", "learned", "codex-transfer"}
COPY_IGNORE = shutil.ignore_patterns("node_modules", ".git", ".DS_Store", "__pycache__", "*.pyc")
SECRET = re.compile(r"(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_\w{20,}|xox[abprs]-[\w-]{10,}|AKIA[0-9A-Z]{16}"
                    r"|-----BEGIN [A-Z ]*PRIVATE KEY-----|(?i:api[_-]?key|secret|token|password)\s*[=:]\s*[\"']?[A-Za-z0-9_\-]{24,})")


def clean(text: str) -> str:
    return text.replace(str(HOME), "__HOME__")


def put(rel: str, text: str, mode: int | None = None) -> None:
    p = OUT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(clean(text))
    if mode:
        p.chmod(mode)


def copy_text(src: Path, rel: str, mode: int | None = None) -> None:
    if src.exists():
        put(rel, src.read_text(), mode)


def run(*cmd: str) -> str:
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main() -> None:
    for d in ("claude", "bin", "mcptoon", "launchd", "tools", "skills"):
        shutil.rmtree(OUT / d, ignore_errors=True)

    # Claude Code user config
    for name in ("CLAUDE.md", "RTK.md"):
        copy_text(CLAUDE / name, f"claude/{name}")
    copy_text(CLAUDE / "settings.json", "claude/settings.json")
    for d in ("commands", "hooks"):
        for f in sorted((CLAUDE / d).glob("*")):
            copy_text(f, f"claude/{d}/{f.name}", 0o755 if f.suffix in (".sh", ".mjs") else None)
    mcp = json.load((HOME / ".claude.json").open()).get("mcpServers", {})
    put("claude/mcpServers.json", json.dumps(mcp, indent=2) + "\n")

    # Plugins: marketplaces + which are enabled (installed from source by install.sh)
    s = json.load((CLAUDE / "settings.json").open())
    known = json.load((CLAUDE / "plugins" / "known_marketplaces.json").open())
    plugins = {"marketplaces": {n: v.get("source") for n, v in known.items() if n != "claude-plugins-official"},
               "enabled": sorted(k for k, v in s.get("enabledPlugins", {}).items() if v)}
    put("claude/plugins.json", json.dumps(plugins, indent=2) + "\n")

    # Skills (user level)
    for d in sorted((CLAUDE / "skills").iterdir()):
        if d.is_dir() and d.name not in SKILL_SKIP:
            shutil.copytree(d, OUT / "skills" / d.name, ignore=COPY_IGNORE)

    # mcptoon, helper scripts, launchd
    copy_text(HOME / ".mcptoon" / "config.json", "mcptoon/config.json")
    for n in BIN_SCRIPTS:
        copy_text(TOOLS / "bin" / n, f"bin/{n}", 0o755)
    copy_text(HOME / "Library/LaunchAgents/com.caveman.proxy.plist", "launchd/com.caveman.proxy.plist")

    # Tool manifests
    put("tools/brew.txt", "".join(f"{l}\n" for l in run("brew", "list", "--versions", "rtk", "openjdk@21", "ollama", "node", "pnpm", "gh").splitlines()))
    put("tools/uv-tools.txt", "".join(l + "\n" for l in run("uv", "tool", "list").splitlines() if l and not l.startswith("-")))
    deps = json.loads(run("npm", "ls", "-g", "--depth=0", "--json") or "{}").get("dependencies", {})
    put("tools/npm-global.txt", "".join(f"{n}@{v.get('version')}\n" for n, v in sorted(deps.items())))
    put("tools/ollama-models.txt", "".join(f"{m}\n" for m in ("nomic-embed-text", "ordis/jina-embeddings-v2-base-code", "qwen3-coder:30b-a3b-q4_K_M")))

    # Secret scan over everything written
    hits = []
    for p in OUT.rglob("*"):
        if p.is_file() and ".git" not in p.parts and p.name != "export.py" and p.suffix != ".csv" and p.stat().st_size < 2_000_000:
            try:
                for m in SECRET.finditer(p.read_text(errors="ignore")):
                    hits.append(f"{p.relative_to(OUT)}: {m.group(0)[:40]}")
            except OSError:
                pass
    if hits:
        print("SECRET-LIKE STRINGS FOUND, review before committing:", *hits[:25], sep="\n  ")
        sys.exit(1)
    print("export ok, no secret-like strings")


if __name__ == "__main__":
    main()
