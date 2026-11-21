#!/usr/bin/env bash
# One-click setup for macOS: installs the prerequisites, detects Claude Code / Cursor / OpenCode,
# lets you pick which to configure (default: all detected), runs the installers and checks the result.
# Double-click Install.command (it launches this). Agents and scripts can skip every prompt:
#   ./setup/setup.sh --all --yes                  every harness already installed, no questions
#   ./setup/setup.sh --only claude,cursor,opencode --yes   exactly these; installs any that is missing
#   ./setup/setup.sh --dry-run                    print what would happen, change nothing
#   --no-tools                                    config only (skip brew/uv/npm/ollama package installs)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"
ALL=0; YES=0; ONLY=""; DRY=0; NOTOOLS=0; PENDING=0
while [ $# -gt 0 ]; do case "$1" in
  --all) ALL=1;; --yes|-y) YES=1;; --dry-run) DRY=1;; --no-tools) NOTOOLS=1;;
  --only) ONLY="${2:?--only needs a list}"; shift;; --only=*) ONLY="${1#*=}";;
  *) echo "unknown flag $1"; exit 2;; esac; shift; done

LOGDIR="$HOME/.claude-tools"; mkdir -p "$LOGDIR"; LOG="$LOGDIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
say() { printf '\n== %s\n' "$*"; }
note() { printf '  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(uname -s)" = Darwin ] || { echo "This setup is for macOS. On Windows double-click Install.cmd."; exit 1; }
printf '\n  claude-config one-click setup  (macOS)\n  Log: %s\n' "$LOG"
[ $DRY -eq 1 ] && echo "  DRY RUN: nothing will be changed."
export PATH="$HOME/.local/bin:$HOME/.caveman/bin:$PATH"
brew_env() { for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && { eval "$("$b" shellenv)"; return; }; done; }
brew_env

# ---- 1. prerequisites
say "Prerequisites"
if ! have brew; then
  if [ $DRY -eq 1 ]; then note "would: install Homebrew"; PENDING=1; else
    note "installing Homebrew (it may ask for your password) ..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "Homebrew install failed."; exit 1; }
    brew_env
  fi
fi
for pair in git:git node:node uv:uv python3:python@3.13 curl:curl; do
  cmd="${pair%%:*}"; pkg="${pair#*:}"
  if have "$cmd" && { [ "$cmd" != git ] || xcode-select -p >/dev/null 2>&1; }; then note "ok: $cmd"; continue; fi
  if [ $DRY -eq 1 ]; then note "would: brew install $pkg"; PENDING=1; continue; fi
  note "installing $pkg ..."; brew install "$pkg" || { echo "brew install $pkg failed."; exit 1; }
done
hash -r

# ---- 2. repo state (a ZIP download has no .git; config-sync needs one)
say "Repository"
BRANCH=main; [ -f .config-branch ] && BRANCH="$(tr -d '[:space:]' < .config-branch)"
if [ ! -d .git ]; then
  if [ $DRY -eq 1 ]; then note "would: turn this folder into a git checkout of branch '$BRANCH' so updates keep working"; else
    if git init -q && git remote add origin https://github.com/Lukee-bit/claude-config && git fetch -q --depth 100 origin "$BRANCH" \
       && git checkout -q -f -B "$BRANCH" "origin/$BRANCH" && git branch -q --set-upstream-to "origin/$BRANCH" "$BRANCH"; then note "git checkout of '$BRANCH' created"
    else echo "  note: could not create a git checkout. Install works; updates need a git clone."; fi
  fi
else note "git checkout present ($(git rev-parse --abbrev-ref HEAD 2>/dev/null))"; fi

# ---- 3. detect harnesses
say "Detecting harnesses"
KEYS="claude cursor opencode"
label() { case "$1" in claude) echo "Claude Code";; cursor) echo "Cursor";; opencode) echo "OpenCode";; esac; }
detect() { case "$1" in
  claude) have claude || [ -x "$HOME/.local/bin/claude" ];;
  cursor) [ -d /Applications/Cursor.app ] || have cursor || have agent || have cursor-agent;;
  opencode) have opencode;; esac; }
FOUND=""; MISSING=""
for k in $KEYS; do if detect $k; then FOUND="$FOUND $k"; note "$(printf '%-12s found' "$(label $k)")"; else MISSING="$MISSING $k"; note "$(printf '%-12s not installed' "$(label $k)")"; fi; done
list_labels() { local o=""; for k in $*; do o="${o:+$o, }$(label $k)"; done; echo "$o"; }

# ---- 4. choose
CHOSEN=""
if [ -n "$ONLY" ]; then
  CHOSEN="$(echo "$ONLY" | tr ',' ' ')"; for c in $CHOSEN; do case " $KEYS " in *" $c "*) ;; *) echo "unknown harness '$c' (use: claude, cursor, opencode)"; exit 2;; esac; done
elif [ $ALL -eq 1 ] || [ $YES -eq 1 ]; then CHOSEN="$FOUND"
else
  i=0; SETS=()
  if [ -n "$FOUND" ]; then i=$((i+1)); SETS[$i]="$FOUND"; echo; echo "What do you want to set up?  (several numbers allowed, e.g. 3,4;  Enter = 1)"; printf '  [%d] All detected: %s  (recommended)\n' $i "$(list_labels $FOUND)"
  else echo; echo "What do you want to set up?  (several numbers allowed, e.g. 3,4;  Enter = 1)"; fi
  if [ -n "$MISSING" ]; then i=$((i+1)); SETS[$i]="$FOUND $MISSING"; printf '  [%d] Everything, and install what is missing: %s\n' $i "$(list_labels $MISSING)"; fi
  for k in $KEYS; do i=$((i+1)); SETS[$i]="$k"; extra=""; detect $k || extra="  (will be installed first)"; printf '  [%d] %s only%s\n' $i "$(label $k)" "$extra"; done
  read -r -p "Choice: " ans; ans="${ans:-1}"
  for n in $(echo "$ans" | tr ',' ' '); do
    case "$n" in ''|*[!0-9]*) echo "'$n' is not a choice"; exit 2;; esac
    [ "$n" -ge 1 ] && [ "$n" -le $i ] || { echo "'$n' is not a choice"; exit 2; }
    CHOSEN="$CHOSEN ${SETS[$n]}"
  done
fi
CHOSEN="$(printf '%s\n' $CHOSEN | awk '!s[$0]++' | tr '\n' ' ' | sed 's/ *$//')"
[ -n "$CHOSEN" ] || { echo; echo "Nothing to set up: no supported harness found. Re-run and choose to install one."; exit 1; }
printf '\nSetting up: %s\n' "$(list_labels $CHOSEN)"

# ---- 5. install missing harnesses
TO_INSTALL=""; for k in $CHOSEN; do detect $k || TO_INSTALL="$TO_INSTALL $k"; done
[ -n "$TO_INSTALL" ] && say "Installing harnesses"
for k in $TO_INSTALL; do
  if [ $DRY -eq 1 ]; then note "would install $(label $k)"; continue; fi
  note "installing $(label $k) ..."
  case "$k" in
    claude) curl -fsSL https://claude.ai/install.sh | bash;;
    opencode) npm install -g @opencode/cli;;
    cursor) brew install --cask cursor; curl -fsS https://cursor.com/install | bash || note "Cursor CLI install skipped";;
  esac
  export PATH="$HOME/.local/bin:$PATH"; hash -r
  detect $k || { echo "  could not detect $(label $k) after installing it; continuing without it."; CHOSEN="$(echo " $CHOSEN " | sed "s/ $k / /" | xargs)"; }
done

# ---- 6. run the installers
[ $DRY -eq 1 ] && [ $PENDING -eq 1 ] && { echo; echo "Dry run: the installers need the prerequisites above first, so they are not previewed. Nothing was changed."; exit 0; }
CSV="$(echo $CHOSEN | tr ' ' ',')"
FLAGS=(); [ $DRY -eq 1 ] && FLAGS+=(--dry-run); [ $NOTOOLS -eq 1 ] && FLAGS+=(--no-tools)
say "Base install (tools, MCP gateway, skills, plugins, services)"
bash ./install.sh --harnesses "$CSV" ${FLAGS[@]+"${FLAGS[@]}"} || { echo "install.sh failed. The log is $LOG"; exit 1; }
hash -r; export PATH="$HOME/.local/bin:$HOME/.caveman/bin:$PATH"
case " $CHOSEN " in *" cursor "*) say "Cursor"; bash ./install-cursor.sh ${FLAGS[@]+"${FLAGS[@]}"} || { echo "install-cursor.sh failed"; exit 1; };; esac
case " $CHOSEN " in *" opencode "*) say "OpenCode"; bash ./install-opencode.sh ${FLAGS[@]+"${FLAGS[@]}"} || { echo "install-opencode.sh failed"; exit 1; };; esac
[ $DRY -eq 1 ] && { echo; echo "Dry run finished. Nothing was changed."; exit 0; }

# ---- 7. verify
say "Verifying"
FAILS=0
row() { if [ "$2" = 1 ]; then printf '  PASS  %s\n' "$1"; else printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS+1)); fi; }
if have mcptoon; then mcptoon doctor 2>&1 | grep -q ', 0 issue' && row "mcptoon gateway (doctor)" 1 || row "mcptoon gateway (doctor)" 0; else row "mcptoon gateway (doctor)" 0; fi
case " $CHOSEN " in *" claude "*)
  O="$(claude mcp list 2>&1)"
  echo "$O" | grep -q 'mcptoon:.*Connected' && echo "$O" | grep -q 'caveman:.*Connected' && ! echo "$O" | grep -q 'Conflicting scopes' && row "Claude Code: mcptoon + caveman connected" 1 || row "Claude Code: mcptoon + caveman connected" 0
  ! grep -q '__HOME__' "$HOME/.claude/settings.json" && row "Claude Code: settings hold no leftover placeholder" 1 || row "Claude Code: settings hold no leftover placeholder" 0;; esac
case " $CHOSEN " in *" opencode "*)
  for s in caveman gsd mcptoon; do opencode api POST "/api/experimental/mcp/$s/connect" >/dev/null 2>&1 || true; done
  O="$(opencode mcp list 2>&1)"
  echo "$O" | grep -Eq 'caveman +connected' && echo "$O" | grep -Eq 'gsd +connected' && echo "$O" | grep -Eq 'mcptoon +connected' && row "OpenCode: caveman, gsd, mcptoon connected" 1 || row "OpenCode: caveman, gsd, mcptoon connected" 0;; esac
case " $CHOSEN " in *" cursor "*)
  AG="$(command -v agent || command -v cursor-agent || true)"
  [ -n "$AG" ] && { "$AG" mcp list 2>&1 | grep -q 'mcptoon: ready' && row "Cursor Code CLI: mcptoon ready" 1 || row "Cursor Code CLI: mcptoon ready" 0; }
  grep -q mcptoon "$HOME/.cursor/mcp.json" 2>/dev/null && row "Cursor: ~/.cursor/mcp.json has mcptoon" 1 || row "Cursor: ~/.cursor/mcp.json has mcptoon" 0;; esac
(echo > /dev/tcp/127.0.0.1/9222) >/dev/null 2>&1 && row "Services: Lightpanda browser (port 9222)" 1 || row "Services: Lightpanda browser (port 9222)" 0

say "Almost done"
printf '  Restart: %s  (fully quit and reopen).\n  Sign in once in each harness. Open Obsidian once if you use the vault features.\n  Update later with:  ~/.claude-tools/bin/config-sync status\n  Full log: %s\n' "$(list_labels $CHOSEN)" "$LOG"
[ $FAILS -eq 0 ] && { echo "All checks passed."; exit 0; }
echo "$FAILS check(s) failed - see above and the log."; exit 1
