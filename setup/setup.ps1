# One-click setup for Windows: installs the prerequisites, detects Claude Code / Cursor / OpenCode,
# lets you pick which to configure (default: all detected), runs the installers and checks the result.
# Double-click Install.cmd (it launches this). Agents and scripts can skip every prompt:
#   pwsh ./setup/setup.ps1 -All -Yes           every harness already installed, no questions
#   pwsh ./setup/setup.ps1 -Only claude,cursor,opencode -Yes   exactly these; installs any that is missing
#   pwsh ./setup/setup.ps1 -DryRun             print what would happen, change nothing
#   -NoTools                                   config only (skip winget/uv/npm/ollama package installs)
param([switch]$All, [switch]$Yes, [string]$Only = '', [switch]$DryRun, [switch]$NoTools)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
$Stamp = Get-Date -Format yyyyMMdd-HHmmss
$LogDir = "$HOME/.claude-tools"; New-Item -ItemType Directory -Force $LogDir | Out-Null
$Log = "$LogDir/install-$Stamp.log"
try { Start-Transcript -Path $Log -Force | Out-Null } catch { }

function Say($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Note($m) { Write-Host "  $m" }
function Sync-Path {
  $env:Path = ([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User') | Where-Object { $_ }) -join ';'
  foreach ($d in "$HOME/.local/bin", "$HOME/AppData/Roaming/npm") { if ((Test-Path $d) -and ($env:Path -notlike "*$d*")) { $env:Path += ";$d" } }
}
function Have($c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function Real-Python { if (-not (Have python)) { return $false }; python -c "import sys" 2>$null; return ($LASTEXITCODE -eq 0) }

Write-Host @"

  claude-config one-click setup  (Windows)
  Log: $Log
"@
if ($DryRun) { Write-Host '  DRY RUN: nothing will be changed.' -ForegroundColor Yellow }
Sync-Path

# ---- 1. prerequisites --------------------------------------------------------------------------------------
Say 'Prerequisites'
$prereq = @(
  @{ cmd = 'git'; id = 'Git.Git' }, @{ cmd = 'node'; id = 'OpenJS.NodeJS' },
  @{ cmd = 'uv'; id = 'astral-sh.uv' }, @{ cmd = 'python'; id = 'Python.Python.3.13' })
foreach ($p in $prereq) {
  $ok = if ($p.cmd -eq 'python') { Real-Python } else { Have $p.cmd }
  if ($ok) { Note "ok: $($p.cmd)"; continue }
  if (-not (Have winget)) { throw "winget is missing. Install 'App Installer' from the Microsoft Store, then run this again." }
  if ($DryRun) { Note "would: winget install $($p.id)"; continue }
  Note "installing $($p.id) ..."
  winget install -e --id $p.id --accept-source-agreements --accept-package-agreements --silent | Out-Null
  Sync-Path
  $ok = if ($p.cmd -eq 'python') { Real-Python } else { Have $p.cmd }
  if (-not $ok) { throw "$($p.cmd) is still not usable after installing $($p.id). Close this window, open Install.cmd again." }
}

# ---- 2. repo state (a ZIP download has no .git; config-sync needs one) ---------------------------------------
Say 'Repository'
$Branch = if (Test-Path .config-branch) { (Get-Content .config-branch -Raw).Trim() } else { 'main' }
if (-not (Test-Path .git)) {
  if ($DryRun) { Note "would: turn this folder into a git checkout of branch '$Branch' so updates keep working" }
  else {
    try {
      git init -q 2>&1 | Out-Null
      git remote add origin https://github.com/Lukee-bit/claude-config 2>&1 | Out-Null
      git fetch -q --depth 100 origin $Branch 2>&1 | Out-Null
      if ($LASTEXITCODE) { throw 'fetch failed' }
      git checkout -q -f -B $Branch "origin/$Branch" 2>&1 | Out-Null
      git branch -q --set-upstream-to "origin/$Branch" $Branch 2>&1 | Out-Null
      Note "git checkout of '$Branch' created"
    } catch { Write-Host "  note: could not create a git checkout ($_). Install works; updates need a git clone." -ForegroundColor Yellow }
  }
} else { Note "git checkout present ($(git rev-parse --abbrev-ref HEAD 2>$null))" }

# ---- 3. detect harnesses ----------------------------------------------------------------------------------
Say 'Detecting harnesses'
$names = [ordered]@{ claude = 'Claude Code'; cursor = 'Cursor'; opencode = 'OpenCode' }
function Detect($k) {
  switch ($k) {
    'claude' { return ((Have claude) -or (Test-Path "$HOME/.local/bin/claude.exe")) }
    'cursor' { return ((Test-Path "$env:LOCALAPPDATA/Programs/cursor/Cursor.exe") -or (Have cursor) -or (Test-Path "$env:LOCALAPPDATA/cursor-agent/agent.cmd") -or (Have cursor-agent)) }
    'opencode' { return (Have opencode) }
  }
}
$present = @{}; foreach ($k in $names.Keys) { $present[$k] = [bool](Detect $k); Note ("{0,-12} {1}" -f $names[$k], $(if ($present[$k]) { 'found' } else { 'not installed' })) }
$missing = @($names.Keys | Where-Object { -not $present[$_] }); $found = @($names.Keys | Where-Object { $present[$_] })

# ---- 4. choose ---------------------------------------------------------------------------------------------
$chosen = @()
if ($Only) { $chosen = @($Only -split '[,\s]+' | Where-Object { $_ }); foreach ($c in $chosen) { if (-not $names.Contains($c)) { throw "unknown harness '$c' (use: $($names.Keys -join ', '))" } } }
elseif ($All -or $Yes) { $chosen = $found }
else {
  $opts = @()
  if ($found) { $opts += @{ label = "All detected: $(($found | ForEach-Object { $names[$_] }) -join ', ')  (recommended)"; set = $found } }
  if ($missing) { $opts += @{ label = "Everything, and install what is missing: $(($missing | ForEach-Object { $names[$_] }) -join ', ')"; set = ($found + $missing) } }
  foreach ($k in $names.Keys) { $opts += @{ label = "$($names[$k]) only$(if (-not $present[$k]) { '  (will be installed first)' })"; set = @($k) } }
  Write-Host "`nWhat do you want to set up?  (several numbers allowed, e.g. 3,4;  Enter = 1)"
  for ($i = 0; $i -lt $opts.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i + 1), $opts[$i].label) }
  $ans = Read-Host 'Choice'; if (-not $ans) { $ans = '1' }
  foreach ($n in ($ans -split '[,\s]+' | Where-Object { $_ })) {
    if ($n -notmatch '^\d+$' -or [int]$n -lt 1 -or [int]$n -gt $opts.Count) { throw "'$n' is not a choice" }
    $chosen += $opts[[int]$n - 1].set
  }
}
$chosen = @($chosen | Select-Object -Unique)
if (-not $chosen) { Write-Host "`nNothing to set up: no supported harness found. Re-run and choose to install one." -ForegroundColor Yellow; try { Stop-Transcript | Out-Null } catch { }; exit 1 }
Write-Host "`nSetting up: $(($chosen | ForEach-Object { $names[$_] }) -join ', ')" -ForegroundColor Green

# ---- 5. install missing harnesses ----------------------------------------------------------------------------
$toInstall = @($chosen | Where-Object { -not $present[$_] })
if ($toInstall) { Say 'Installing harnesses' }
foreach ($k in $toInstall) {
  if ($DryRun) { Note "would install $($names[$k])"; continue }
  Note "installing $($names[$k]) ..."
  switch ($k) {
    'claude' { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression }
    'opencode' { npm install -g '@opencode/cli' }
    'cursor' {
      winget install -e --id Anysphere.Cursor --accept-source-agreements --accept-package-agreements --silent | Out-Null
      try { Invoke-RestMethod 'https://cursor.com/install?win32=true' | Invoke-Expression } catch { Note "Cursor CLI install skipped: $_" }
    }
  }
  Sync-Path
  if (-not (Detect $k)) { Write-Host "  could not detect $($names[$k]) after installing it; continuing without it." -ForegroundColor Yellow; $chosen = @($chosen | Where-Object { $_ -ne $k }) }
}

# ---- 6. run the installers ---------------------------------------------------------------------------------
$csv = $chosen -join ','
$flags = @(); if ($DryRun) { $flags += '-DryRun' }; if ($NoTools) { $flags += '-NoTools' }
Say 'Base install (tools, MCP gateway, skills, plugins, services)'
& pwsh -NoProfile -ExecutionPolicy Bypass -File "$Root/install.ps1" -Harnesses $csv @flags
if ($LASTEXITCODE) { throw "install.ps1 failed (exit $LASTEXITCODE). The log is $Log" }
Sync-Path
if ($chosen -contains 'cursor') {
  Say 'Cursor'
  & pwsh -NoProfile -ExecutionPolicy Bypass -File "$Root/install-cursor.ps1" @flags
  if ($LASTEXITCODE) { throw "install-cursor.ps1 failed (exit $LASTEXITCODE)" }
}
if ($chosen -contains 'opencode') {
  Say 'OpenCode'
  & pwsh -NoProfile -ExecutionPolicy Bypass -File "$Root/install-opencode.ps1" @flags
  if ($LASTEXITCODE) { throw "install-opencode.ps1 failed (exit $LASTEXITCODE)" }
}

# ---- 7. verify ---------------------------------------------------------------------------------------------
$rows = @()
function Retry($attempts, [scriptblock]$test) { for ($i = 1; $i -le $attempts; $i++) { if (& $test) { return $true }; if ($i -lt $attempts) { Start-Sleep -Seconds 8 } }; return $false }
function Row($what, $ok, $detail = '') { $script:rows += [pscustomobject]@{ Check = $what; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Detail = $detail } }
if ($DryRun) { Write-Host "`nDry run finished. Nothing was changed." -ForegroundColor Yellow; try { Stop-Transcript | Out-Null } catch { }; exit 0 }
Say 'Verifying'
if (Have mcptoon) { $script:o = ''; Row 'mcptoon gateway (doctor)' (Retry 4 { $script:o = (mcptoon doctor 2>&1 | Out-String); $script:o -match ', 0 issue' }) ($script:o -split "`n" | Where-Object { $_ -match 'issue' } | Select-Object -First 1) } else { Row 'mcptoon gateway (doctor)' $false 'mcptoon not on PATH' }
if ($chosen -contains 'claude') {
  Row 'Claude Code: mcptoon + caveman connected' (Retry 3 { $o = (claude mcp list 2>&1 | Out-String); ($o -match 'mcptoon:.*Connected') -and ($o -match 'caveman:.*Connected') -and ($o -notmatch 'Conflicting scopes') }) ''
  Row 'Claude Code: settings hold no leftover placeholder' (-not (Select-String -Path "$HOME/.claude/settings.json" -Pattern '__HOME__' -Quiet)) ''
}
if ($chosen -contains 'opencode') {
  Row 'OpenCode: caveman, gsd, mcptoon connected' (Retry 4 {
    foreach ($s in 'caveman', 'gsd', 'mcptoon') { try { opencode api POST "/api/experimental/mcp/$s/connect" 2>&1 | Out-Null } catch { } }
    $o = (opencode mcp list 2>&1 | Out-String); ($o -match 'caveman\s+connected') -and ($o -match 'gsd\s+connected') -and ($o -match 'mcptoon\s+connected') }) ''
}
if ($chosen -contains 'cursor') {
  $ag = (Get-Command agent, cursor-agent -ErrorAction SilentlyContinue | Select-Object -First 1).Source
  if (-not $ag -and (Test-Path "$env:LOCALAPPDATA/cursor-agent/agent.cmd")) { $ag = "$env:LOCALAPPDATA/cursor-agent/agent.cmd" }
  if ($ag) { $o = (& $ag mcp list 2>&1 | Out-String); Row 'Cursor Code CLI: mcptoon ready' ($o -match 'mcptoon: ready') '' }
  Row 'Cursor: ~/.cursor/mcp.json has mcptoon' ((Test-Path "$HOME/.cursor/mcp.json") -and (Select-String -Path "$HOME/.cursor/mcp.json" -Pattern 'mcptoon' -Quiet)) ''
}
Row 'Services: Lightpanda browser (port 9222)' ([bool](Test-NetConnection 127.0.0.1 -Port 9222 -InformationLevel Quiet -WarningAction SilentlyContinue)) ''
$rows | Format-Table -AutoSize | Out-String | Write-Host
$bad = @($rows | Where-Object Result -eq 'FAIL')

Say 'Almost done'
Write-Host @"
  Restart: $(($chosen | ForEach-Object { $names[$_] }) -join ', ')  (fully quit and reopen).
  Sign in once in each harness. Open Obsidian once if you use the vault features.
  Update later with:  ~/.claude-tools/bin/config-sync status
  Full log: $Log
"@
try { Stop-Transcript | Out-Null } catch { }
if ($bad) { Write-Host "$($bad.Count) check(s) failed - see the table above and the log." -ForegroundColor Red; exit 1 }
Write-Host 'All checks passed.' -ForegroundColor Green
