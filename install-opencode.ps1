# OpenCode V2 surface on top of the claude-config base install. Run pwsh ./install.ps1 first:
# this reuses what the base install creates (~/.claude/skills, the Claude plugin cache,
# ~/.claude-tools/bin helpers, npm globals). Safe to re-run: replaced files are backed up
# (*.bak-YYYYMMDD) before opencode.json is merged. Never writes ~/.claude.
# Counterpart of install-opencode.sh. The repo's templates stay the single source;
# opencode/render.py maps them into ~/.config/opencode/opencode.json.
#   pwsh ./install-opencode.ps1 -DryRun     print what would happen
#   pwsh ./install-opencode.ps1             apply
#   pwsh ./install-opencode.ps1 -NoTools    config only (skip the GSD/RTK/Caveman OpenCode installers)
param([switch]$DryRun, [switch]$NoTools)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$Stamp = Get-Date -Format yyyyMMdd

function Say($m) { Write-Host "`n== $m" }
function Run([scriptblock]$b, $what) { if ($DryRun) { Write-Host "  would: $what" } else { & $b } }
function Place($src, $dst) {
  if ($DryRun) { Write-Host "  would place $src -> $dst"; return }
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if (Test-Path $dst) { Copy-Item $dst "$dst.bak-$Stamp" -Force }
  Copy-Item $src $dst -Force
}
$OC = "$HOME/.config/opencode"

if (-not (Test-Path "$HOME/.claude-tools/config-repo")) { throw 'base install missing (run pwsh ./install.ps1 first)' }
foreach ($c in 'python', 'node') { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { throw "missing: $c (install it first; see windows/tools/winget.txt)" } }
if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) { Write-Host '  note: opencode CLI not found; config is still rendered' }

Say 'OpenCode config (~/.config/opencode)'
# The templates hold no __HOME__ placeholders — every OS-specific path resolves
# at runtime (claude-config.js) or in render.py.
Place opencode/AGENTS.md "$OC/AGENTS.md"
foreach ($f in (Get-ChildItem opencode/commands -File)) { Place $f.FullName "$OC/commands/$($f.Name)" }
Place opencode/plugins/claude-config.js "$OC/plugins/claude-config.js"
if ($DryRun) { Write-Host '  would render opencode/render.py -> ~/.config/opencode/opencode.json (backup first)' }
else {
  python opencode/render.py
  if ($LASTEXITCODE) { throw 'render.py failed' }
}

if (-not $NoTools) {
  Say 'GSD Core (adds its OpenCode commands, agents and hooks)'
  Run { npx -y '@opengsd/gsd-core@latest' --opencode --global } 'npx @opengsd/gsd-core --opencode --global'
  Say 'RTK (OpenCode plugin)'
  Run { rtk init --global --opencode } 'rtk init --global --opencode'
  Say 'Caveman (OpenCode provider routes + MCP entry)'
  Run { caveman setup --yes --agents opencode } 'caveman setup --yes --agents opencode'
}

Say 'Done. Restart OpenCode (new plugin files need it), then verify: opencode mcp list (caveman, gsd, lightpanda, mcptoon); mcptoon doctor. See opencode/README.md.'