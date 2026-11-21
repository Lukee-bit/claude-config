#!/usr/bin/env bash
# Double-click on macOS: opens Terminal and runs the one-click setup.
cd "$(dirname "$0")" || exit 1
bash setup/setup.sh "$@"; rc=$?
[ $# -eq 0 ] && { echo; read -r -p "Press Enter to close. " _; }
exit $rc
