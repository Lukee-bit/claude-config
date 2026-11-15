"use strict";
/**
 * claude-config adapter for OpenCode V2 (template; install-opencode.sh / .ps1 place
 * it at ~/.config/opencode/plugins/claude-config.js, where OpenCode auto-discovers
 * loose .js files). Same file on macOS and Windows: every OS-specific path is
 * resolved at runtime, so no install-time rendering is needed.
 *
 * Bridges this repo's Claude Code hook automation into OpenCode using the same
 * pattern as the other generated plugins (gsd-core.js, caveman-native.js):
 * spawn the existing scripts, translate payloads between the Claude hook
 * contract and the OpenCode V2 plugin API, and fail open — a missing script or
 * any error changes nothing.
 *
 *   tool.execute.before   → node guard-pack.js (Claude PreToolUse contract):
 *                            deny → throw (OpenCode surfaces it to the model);
 *                            ask  → stderr advisory only (V2 has no ask here).
 *   tool.execute.after    → agent-handoff tool (edit log, sync 5s) +
 *                            jcodemunch hook-posttooluse (background reindex)
 *                            on file-editing tools.
 *   session "prompt"      → agent-handoff prompt nudge → injected with the next
 *                            context event (caveman-native pending pattern).
 *   session "context"      → inject .agent/handoff.md + memory index excerpt
 *                            (Claude SessionStart context parity).
 *   session "compaction"  → jcodemunch hook-precompact (background).
 *   session.created       → agent-handoff init + vault/spec/index bootstrap,
 *                            fire-and-forget (each script is idempotent and
 *                            filters non-project dirs itself).
 *   session.deleted       → agent-handoff end (snapshot + detached summary).
 *
 * Global instructions live in ~/.config/opencode/AGENTS.md, which OpenCode V2
 * loads natively; this plugin does not inject them. Opt out of the session-start
 * bootstraps with CLAUDE_CONFIG_OC_BOOTSTRAP=0.
 */
const { spawn, spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");

const HOME = os.homedir();
const BIN = path.join(HOME, ".claude-tools", "bin");
const IS_WIN = process.platform === "win32";
// Git Bash runs the repo's bash helpers on Windows; macOS has bash natively.
const BASH = IS_WIN ? "C:\\Program Files\\Git\\bin\\bash.exe" : "/bin/bash";
const PY = IS_WIN ? "python" : "python3";
// uv installs the jCodeMunch entry point as a home-local shim (.exe on Windows).
const JCODEMUNCH = path.join(HOME, ".local", "bin", "jcodemunch-mcp" + (IS_WIN ? ".exe" : ""));

// Claude plugin cache path drifts with the installed guard-pack version; resolve it.
function resolveGuardPack() {
  const base = path.join(HOME, ".claude", "plugins", "cache", "claude-code-hooks", "guard-pack");
  try {
    const versions = fs
      .readdirSync(base, { withFileTypes: true })
      .filter((d) => d.isDirectory() && /^\d+(?:\.\d+)+$/.test(d.name))
      .map((d) => d.name)
      .sort((a, b) => {
        const ka = a.split(".").map(Number);
        const kb = b.split(".").map(Number);
        for (let i = 0; i < Math.max(ka.length, kb.length); i++) {
          const d = (ka[i] || 0) - (kb[i] || 0);
          if (d) return d;
        }
        return 0;
      });
    if (!versions.length) return null;
    return path.join(base, versions[versions.length - 1], "guard-pack.js");
  } catch {
    return null;
  }
}
const GUARD_PACK = resolveGuardPack();

// OpenCode tool id → Claude tool name. V2 renamed bash→shell and
// apply_patch→patch; accept both so either host works (gsd-core ADR-5331 E4).
const TOOL_MAP = {
  bash: "Bash", shell: "Bash",
  read: "Read", grep: "Grep", glob: "Glob",
  write: "Write", edit: "Edit",
  apply_patch: "MultiEdit", patch: "MultiEdit", multi_edit: "MultiEdit",
  webfetch: "WebFetch", web_search: "WebSearch", websearch: "WebSearch",
  task: "Task", subagent: "Task",
};
// guard-pack PACK_TOOLS (Bash, Read, Edit, MultiEdit, Write, Agent, Task, Grep).
const GUARDED = new Set(["Bash", "Read", "Edit", "MultiEdit", "Write", "Grep", "Task"]);
const EDIT_TOOLS = new Set(["write", "edit", "apply_patch", "patch", "multi_edit"]);

// OpenCode args → Claude tool_input (gsd-core mapToolInput contract).
function mapInput(input) {
  const out = {};
  if (!input || typeof input !== "object") return out;
  const filePath = input.filePath || input.file_path || input.path || input.fileName;
  if (filePath) out.file_path = filePath;
  if (input.content !== undefined) out.content = input.content;
  if (input.new_string !== undefined) out.new_string = input.new_string;
  if (input.newString !== undefined) out.new_string = input.newString;
  if (input.old_string !== undefined) out.old_string = input.old_string;
  if (input.oldString !== undefined) out.old_string = input.oldString;
  if (input.command !== undefined) out.command = input.command;
  if (input.pattern !== undefined) out.pattern = input.pattern;
  if (input.prompt !== undefined) out.prompt = input.prompt;
  if (input.description !== undefined) out.description = input.description;
  if (input.url !== undefined) out.url = input.url;
  if (input.query !== undefined) out.query = input.query;
  return out;
}

// A JS runtime we can spawn: inside OpenCode's bundled binary, process.execPath
// boots the app instead of node (gsd-core #4849), so fall back to PATH.
function nodeBin() {
  const exe = path.basename(process.execPath || "").toLowerCase();
  return /node|bun/.test(exe) ? process.execPath : "node";
}

function feed(child, payload) {
  child.on("error", () => {});
  if (child.stdin) {
    child.stdin.on("error", () => {});
    child.stdin.write(JSON.stringify(payload ?? {}));
    child.stdin.end();
  }
}

function childEnv(cwd) {
  return { ...process.env, CLAUDE_PROJECT_DIR: cwd || "" };
}

// Background, best-effort: bootstraps, reindexing, snapshots.
function bashBg(script, args, cwd) {
  try {
    const file = path.join(BIN, script);
    if (!fs.existsSync(file)) return;
    feed(
      spawn(BASH, [file.replace(/\\/g, "/"), ...args], {
        stdio: ["pipe", "ignore", "ignore"],
        cwd,
        windowsHide: true,
        env: childEnv(cwd),
      }),
      {}
    );
  } catch {}
}

function pyBg(script, args, payload, cwd) {
  try {
    const file = path.join(BIN, script);
    if (!fs.existsSync(file)) return;
    feed(
      spawn(PY, [file, ...args], {
        stdio: ["pipe", "ignore", "ignore"],
        cwd,
        windowsHide: true,
        env: childEnv(cwd),
      }),
      payload
    );
  } catch {}
}

// Blocking: cheap hooks and the guard gate. Empty string = no output or error.
function py(script, args, payload, cwd, timeout = 10000) {
  try {
    const file = path.join(BIN, script);
    if (!fs.existsSync(file)) return "";
    const r = spawnSync(PY, [file, ...args], {
      input: JSON.stringify(payload ?? {}),
      encoding: "utf8",
      cwd,
      timeout,
      windowsHide: true,
      maxBuffer: 1024 * 1024,
      env: childEnv(cwd),
    });
    return r.stdout || "";
  } catch {
    return "";
  }
}

function exeBg(file, args, payload, cwd) {
  try {
    if (!fs.existsSync(file)) return;
    feed(
      spawn(file, args, {
        stdio: ["pipe", "ignore", "ignore"],
        cwd,
        windowsHide: true,
      }),
      payload
    );
  } catch {}
}

// Session-start scaffolds only for real project dirs. HOME and the config dir
// are not projects; the scripts filter further themselves.
function projectish(dir) {
  if (!dir || typeof dir !== "string") return false;
  if (process.env.CLAUDE_CONFIG_OC_BOOTSTRAP === "0") return false;
  const p = dir.replace(/\\/g, "/").replace(/\/+$/, "").toLowerCase();
  const home = HOME.replace(/\\/g, "/").toLowerCase();
  if (p === home || p === home + "/.config/opencode") return false;
  if (/^[a-z]:$/.test(p)) return false; // bare drive root
  return true;
}

// .agent/handoff.md + memory index excerpt (Claude SessionStart context parity).
function handoffContext(dir) {
  if (!dir) return "";
  try {
    const agentDir = path.join(dir, ".agent");
    if (!fs.existsSync(agentDir)) return "";
    const parts = [];
    const read = (rel, cap) => {
      const file = path.join(agentDir, rel);
      if (!fs.existsSync(file)) return;
      const text = fs.readFileSync(file, "utf8");
      parts.push(
        text.length > cap
          ? `### ${rel} (truncated — read the full file)\n${text.slice(0, cap)}\n…`
          : `### ${rel}\n${text}`
      );
    };
    read(path.join("handoff.md"), 6000);
    read(path.join("memory", "MEMORY.md"), 2500);
    if (!parts.length) return "";
    return [
      "Project handoff/memory excerpt follows. Read the full `.agent/handoff.md` and `.agent/memory/` before changing anything.",
      "",
      parts.join("\n\n"),
    ].join("\n");
  } catch {
    return "";
  }
}

async function setup(ctx) {
  // One setup() per location (caveman-native #1443): ctx.location.directory is
  // the project dir this plugin instance serves.
  const dir =
    typeof ctx.location?.directory === "string" && ctx.location.directory
      ? ctx.location.directory
      : undefined;
  const project = dir && projectish(dir) ? dir : undefined;
  const pending = new Map(); // sessionID → prompt-time context, injected next request
  const ended = new Set();

  function emitEnd(sessionID) {
    if (!project || ended.has(sessionID)) return;
    ended.add(sessionID);
    pyBg("agent-handoff", ["end", project], { session_id: sessionID, reason: "clear" }, project);
  }

  function sameLocation(event) {
    if (!event.location) return true; // already routed to us (#1444)
    return (
      event.location.directory === ctx.location.directory &&
      event.location.workspaceID === ctx.location.workspaceID
    );
  }

  const controller = new AbortController();
  (async () => {
    try {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        try {
          if (!sameLocation(event)) continue;
          const sessionID = event.data?.sessionID;
          if (typeof sessionID !== "string" || !sessionID) continue;
          if (event.type === "session.created" && project) {
            pyBg("agent-handoff", ["init", project], {}, project);
            bashBg("vault-bootstrap", [project], project);
            bashBg("spec-bootstrap", [project], project);
            bashBg("index-bootstrap", [project], project);
          }
          if (event.type === "session.deleted") {
            emitEnd(sessionID);
            pending.delete(sessionID);
          }
        } catch {}
      }
    } catch {}
  })();

  // UserPromptSubmit parity: silent nudge unless many unsaved edits.
  await ctx.session.hook("prompt", (event) => {
    if (!project) return;
    const out = py(
      "agent-handoff", ["prompt", project],
      { session_id: event.sessionID }, project, 5000
    );
    if (out.trim()) pending.set(event.sessionID, out.trim().slice(0, 2000));
  });

  // Inject the handoff/memory excerpt with every model request.
  await ctx.session.hook("context", (event) => {
    const text = handoffContext(project);
    if (text) event.system.push({ type: "text", text });
    const hint = pending.get(event.sessionID);
    if (hint) {
      event.system.push({ type: "text", text: hint });
      pending.delete(event.sessionID);
    }
  });

  // PreCompact parity: keep index/context warm before compaction.
  await ctx.session.hook("compaction", (event) => {
    if (!project) return;
    exeBg(JCODEMUNCH, ["hook-precompact"], { session_id: event.sessionID }, project);
  });

  // PreToolUse parity: guard-pack safety gate — config guard, dangerous
  // commands, secrets, tests, git safety, case collisions, spawn caps.
  await ctx.tool.hook("execute.before", (event) => {
    if (!GUARD_PACK || !fs.existsSync(GUARD_PACK)) return;
    const claudeName = TOOL_MAP[String(event.tool || "").toLowerCase()];
    if (!claudeName || !GUARDED.has(claudeName)) return;
    const payload = {
      tool_name: claudeName,
      tool_input: mapInput(event.input),
      session_id: event.sessionID,
      cwd: project || undefined,
    };
    let decision = null;
    try {
      const r = spawnSync(nodeBin(), [GUARD_PACK], {
        input: JSON.stringify(payload),
        encoding: "utf8",
        cwd: project || undefined,
        timeout: 20000, // git-probing guards probe serially; fail open past this
        windowsHide: true,
        maxBuffer: 1024 * 1024,
      });
      decision =
        r.status === 0 && r.stdout && r.stdout.trim() ? JSON.parse(r.stdout) : null;
    } catch {
      decision = null;
    }
    const d = decision?.hookSpecificOutput;
    if (d?.hookEventName === "PreToolUse" && d.permissionDecision === "deny") {
      throw new Error(d.permissionDecisionReason || `[guard-pack] blocked ${claudeName} call`);
    }
    if (d?.permissionDecision === "ask") {
      console.error(
        `[claude-config] guard-pack review advised: ${d.permissionDecisionReason || claudeName}`
      );
    }
  });

  // PostToolUse parity: handoff edit log + jCodeMunch reindex on file edits.
  await ctx.tool.hook("execute.after", (event) => {
    if (event.status !== "completed") return;
    const tool = String(event.tool || "").toLowerCase();
    if (!EDIT_TOOLS.has(tool)) return;
    const payload = {
      session_id: event.sessionID,
      tool_name: TOOL_MAP[tool],
      tool_input: mapInput(event.input),
    };
    if (project) {
      py("agent-handoff", ["tool", project], payload, project, 5000); // edit log
      exeBg(JCODEMUNCH, ["hook-posttooluse"], payload, project); // reindex (bg)
    }
  });

  return () => {
    controller.abort();
    for (const sessionID of pending.keys()) emitEnd(sessionID);
    pending.clear();
  };
}

module.exports = { id: "claude-config", setup };