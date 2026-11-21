# Cursor / Cursor Code surface on top of the claude-config base install.
# Run pwsh ./install.ps1 first. Reuses ~/.claude/skills, the Claude plugin cache,
# ~/.claude-tools/bin helpers and ~/.mcptoon/config.json.
# Safe to re-run: replaced files are backed up (*.bak-YYYYMMDD).
# Never runs the OpenCode installer. Does not rewrite Claude plugins/skills.
# Windows: also wraps Claude .sh hooks that Cursor Code loads (Open-with fix).
#   pwsh ./install-cursor.ps1 -DryRun     print what would happen
#   pwsh ./install-cursor.ps1             apply
#   pwsh ./install-cursor.ps1 -NoTools    config only (skip GSD --cursor)
param([switch]$DryRun, [switch]$NoTools)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Say($m) { Write-Host "`n== $m" }
function Run([scriptblock]$b, $what) { if ($DryRun) { Write-Host "  would: $what" } else { & $b } }

if (-not (Test-Path "$HOME/.claude-tools/config-repo")) { throw 'base install missing (run pwsh ./install.ps1 first)' }
foreach ($c in 'python', 'node') {
  if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { throw "missing: $c (install it first; see windows/tools/winget.txt)" }
}
if (-not (Get-Command mcptoon -ErrorAction SilentlyContinue)) {
  Write-Host '  note: mcptoon not on PATH; base install tool step may still be needed'
}

Say 'Cursor config (~/.cursor)'
$renderArgs = @('cursor/render.py')
if ($DryRun) { $renderArgs += '--dry-run' }
python @renderArgs
if ($LASTEXITCODE) { throw 'cursor/render.py failed' }

if (-not $NoTools) {
  Say 'GSD Core (Cursor hooks / commands)'
  Run { npx -y '@opengsd/gsd-core@latest' --cursor --global --profile=core } 'npx @opengsd/gsd-core --cursor --global'
  if (-not $DryRun) {
    python cursor/render.py
    if ($LASTEXITCODE) { throw 'cursor/render.py (post-GSD) failed' }
  }
}

# Cursor Code CLI leaves a new MCP server at "needs approval" until it is enabled.
$agent = (Get-Command agent, cursor-agent -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $agent -and (Test-Path "$env:LOCALAPPDATA/cursor-agent/agent.cmd")) { $agent = "$env:LOCALAPPDATA/cursor-agent/agent.cmd" }
if ($agent -and -not $DryRun) { & $agent mcp enable mcptoon 2>&1 | Out-Null; Write-Host '  Cursor Code CLI: mcptoon approved' }

Say 'Done. Fully quit and restart Cursor IDE + Cursor Code CLI, then verify: mcptoon doctor; MCP list shows mcptoon; no .sh Open-with dialogs. See cursor/README.md.'
