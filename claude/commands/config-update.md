---
description: Update this machine to the latest claude-config (reads CHANGELOG, applies, verifies)
---
Bring this machine up to date with its Luke's claude-config repo.

1. Run `~/.claude-tools/bin/config-sync status`. If it says up to date, stop and say so.
2. Show the user the pending CHANGELOG lines and wait for their OK. Anything marked as manual or destructive needs an explicit yes.
3. Run `~/.claude-tools/bin/config-sync apply` (pulls, re-runs the installer for this OS, keeps `*.bak-*` backups).
4. Do every manual action the CHANGELOG entries list (for example restarting a server or re-running a tool's own setup). Do not guess: if an entry is unclear, ask.
5. Verify: `mcptoon doctor` (all servers OK) and anything the entries name. Report what changed, what you verified, and what still needs the user.
Never edit the repo's templates as part of an update; report problems instead.
