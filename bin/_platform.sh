#!/usr/bin/env bash
# Sourced by the helper scripts in this directory. One place that knows how Windows (Git Bash) differs from macOS.
# On macOS/Linux every function below is a no-op or identity, so existing behaviour is unchanged.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) CC_OS=windows;;
  Darwin) CC_OS=macos;;
  *) CC_OS=linux;;
esac

if [ "$CC_OS" = windows ]; then
  # Claude Code hands us C:\Users\me\proj; scripts want /c/Users/me/proj so path hashes and `cd` agree.
  cc_path() { cygpath -u "$1" 2>/dev/null || printf '%s' "$1"; }
  cc_winpath() { cygpath -w "$1" 2>/dev/null || printf '%s' "$1"; }
  cc_add_path() { export PATH="$HOME/.local/bin:$HOME/AppData/Roaming/npm:$PATH"; }
  # Non-project locations to skip, on top of the macOS list in each script.
  cc_system_dir() {
    local d="${1,,}" h="${HOME,,}"
    case "$d" in
      "$h/projects"|"$h/appdata"*|"$h/scoop"*|/c|/c/windows*|"/c/program files"*|/c/programdata*) return 0;;
    esac
    return 1
  }
  CC_SLEEP=sleep
  CC_VENV_PY=Scripts/python.exe
else
  cc_path() { printf '%s' "$1"; }
  cc_winpath() { printf '%s' "$1"; }
  cc_add_path() { :; }
  cc_system_dir() { return 1; }
  CC_SLEEP=/bin/sleep
  CC_VENV_PY=bin/python
fi
