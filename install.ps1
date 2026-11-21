# Restore this Claude Code stack on Windows 11. Safe to re-run: files it replaces are backed up (*.bak-YYYYMMDD).
# Counterpart of install.sh. The repo's templates stay the single source; windows/render.py maps them to Windows.
#   pwsh ./install.ps1 -DryRun     print what would happen
#   pwsh ./install.ps1             apply
#   pwsh ./install.ps1 -NoTools    config only (skip winget/uv/npm/ollama installs)
#   pwsh ./install.ps1 -Harnesses opencode,cursor   leave Claude Code's own config alone (setup/ passes the harnesses you chose)
# Most people should double-click Install.cmd instead: it installs the prerequisites and asks which harnesses to set up.
# Needs: PowerShell 7, Git for Windows (Git Bash runs the helper scripts and hooks), Node, uv, Python 3.
param([switch]$DryRun, [switch]$NoTools, [string]$Harnesses = 'claude,cursor,opencode')
$SkipClaudeConfig = $Harnesses -notmatch 'claude'
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$Stamp = Get-Date -Format yyyyMMdd
$Home_ = ($HOME -replace '\\', '/')
$Tmp = Join-Path ([IO.Path]::GetTempPath()) "claude-config-render"
New-Item -ItemType Directory -Force $Tmp | Out-Null

function Say($m) { Write-Host "`n== $m" }
function Run([scriptblock]$b, $what) { if ($DryRun) { Write-Host "  would: $what" } else { & $b } }
function Place($src, $dst) {
  if ($DryRun) { Write-Host "  would place $src -> $dst"; return }
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if (Test-Path $dst) { Copy-Item $dst "$dst.bak-$Stamp" -Force }
  (Get-Content $src -Raw) -replace '__HOME__', $Home_ | Set-Content $dst -NoNewline -Encoding utf8
}
function Render($what, $out, [string[]]$extra = @()) { python windows/render.py $what --home $Home_ --bash $Bash --out $out @extra; if ($LASTEXITCODE) { throw "render $what failed" } }
function Sync-Path { $env:Path = ([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User') | Where-Object { $_ }) -join ';'; foreach ($d in "$HOME/.local/bin", "$HOME/AppData/Roaming/npm") { if ((Test-Path $d) -and ($env:Path -notlike "*$d*")) { $env:Path += ";$d" } } }
# Plain HTTPS download: needs no gh login (a fresh machine has none).
function Fetch($url, $out) { New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null; Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out }
function Lines($f) { Get-Content $f | Where-Object { $_ -and $_ -notmatch '^\s*#' } }

Say 'Prerequisites'
Sync-Path
foreach ($c in 'git', 'node', 'npm', 'uv', 'python') { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { throw "missing: $c (install it first; see windows/tools/winget.txt)" } }
python -c "import sys" 2>$null; if ($LASTEXITCODE) { throw "'python' is the Microsoft Store stub, not Python: run  winget install -e --id Python.Python.3.13  and open a new window" }
$Bash = (Join-Path (Split-Path (Split-Path (git --exec-path) -Parent) -Parent) 'bin/bash.exe') -replace '\\', '/'
if (-not (Test-Path $Bash)) { $Bash = 'C:/Program Files/Git/bin/bash.exe' }
if (-not (Test-Path $Bash)) { throw 'Git Bash not found (install Git for Windows)' }
Write-Host "  git bash: $Bash"
$HaveClaude = [bool](Get-Command claude -ErrorAction SilentlyContinue)
if (-not $HaveClaude) { Write-Host "  note: 'claude' CLI not found; plugin steps will be skipped" }
$env:UV_LINK_MODE = 'copy'   # hardlinked venv files trip Kwipu's path-security check

if (-not $NoTools) {
  Say 'winget packages'
  foreach ($p in Lines windows/tools/winget.txt) { Run { winget install -e --id $p --accept-source-agreements --accept-package-agreements --silent } "winget install $p" }
  Sync-Path
  Say 'uv tools'
  foreach ($t in 'jcodemunch-mcp', 'mcp-obsidian', 'mcptoon', 'obsidian-wiki', 'specify-cli', 'semgrep') { Run { uv tool install $t } "uv tool install $t" }
  Run { uv tool install -p 3.13 serena-agent } 'uv tool install serena-agent'
  Sync-Path
  Say 'npm globals (tools/npm-global.txt, with windows/tools/npm-overrides.txt)'
  $ov = @{}; foreach ($l in Lines windows/tools/npm-overrides.txt) { $ov[$l.Substring(0, $l.LastIndexOf('@'))] = $l }
  foreach ($pkg in Lines tools/npm-global.txt) {
    $name = $pkg.Substring(0, $pkg.LastIndexOf('@'))
    if ($name -eq 'npm') { continue }
    $want = if ($ov.ContainsKey($name)) { $ov[$name] } else { $pkg }
    Run { npm install -g $want } "npm install -g $want"
  }
  Sync-Path
  Say 'Ollama models (tools/ollama-models.txt)'
  foreach ($m in Lines tools/ollama-models.txt) { Run { ollama pull $m } "ollama pull $m" }
  Say 'lumen, rtk (single binaries)'
  if (-not (Get-Command lumen -ErrorAction SilentlyContinue)) {
    Run { Fetch 'https://github.com/ory/lumen/releases/download/v0.0.42/lumen-0.0.42-windows-amd64.exe' "$HOME/.local/bin/lumen.exe" } 'download lumen 0.0.42'
  }
  if (-not (Get-Command rtk -ErrorAction SilentlyContinue)) {
    $rv = ((Lines tools/brew.txt) | Where-Object { $_ -match '^rtk\s+(\S+)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
    Run { $z = Join-Path $Tmp 'rtk.zip'; Fetch "https://github.com/rtk-ai/rtk/releases/download/v$rv/rtk-x86_64-pc-windows-msvc.zip" $z; Expand-Archive $z "$Tmp/rtk" -Force; New-Item -ItemType Directory -Force "$HOME/.local/bin" | Out-Null; Copy-Item (Get-ChildItem "$Tmp/rtk" -Recurse -Filter 'rtk.exe' | Select-Object -First 1).FullName "$HOME/.local/bin/rtk.exe" -Force } "download rtk $rv"
  }
  Sync-Path
}

Say 'Claude Code config'
if ($SkipClaudeConfig) { Write-Host '  skipped: Claude Code is not in -Harnesses' }
if (-not $SkipClaudeConfig) {
Place claude/CLAUDE.md "$HOME/.claude/CLAUDE.md"
Place claude/RTK.md "$HOME/.claude/RTK.md"
}
if (-not $DryRun -and -not $SkipClaudeConfig) {
  Render settings "$Tmp/settings.json"
  $dst = "$HOME/.claude/settings.json"
  if (Test-Path $dst) { Copy-Item $dst "$dst.bak-$Stamp" -Force }
  Copy-Item "$Tmp/settings.json" $dst -Force
} else { Write-Host '  would render claude/settings.json -> ~/.claude/settings.json (Caveman hooks come from `caveman setup`)' }
if (-not $SkipClaudeConfig) { foreach ($f in (Get-ChildItem claude/commands, claude/hooks -File)) { Place $f.FullName "$HOME/.claude/$($f.Directory.Name)/$($f.Name)" } }
Run { New-Item -ItemType Directory -Force "$HOME/.claude/skills" | Out-Null; Copy-Item skills/* "$HOME/.claude/skills/" -Recurse -Force } 'copy skills/ -> ~/.claude/skills'

Say 'GSD Core (full install is snapshotted into the mcptoon skill catalog, then trimmed to the core profile)'
Run { npx -y '@opengsd/gsd-core@latest' --claude --global --profile=full } 'npx @opengsd/gsd-core --claude --global --profile=full'
Run {
  $gc = "$HOME/.claude-tools/skill-catalog/gsd"; New-Item -ItemType Directory -Force $gc | Out-Null
  foreach ($d in (Get-ChildItem "$HOME/.claude/skills" -Directory -Filter 'gsd-*')) { Copy-Item $d.FullName "$gc/$($d.Name)" -Recurse -Force }
} 'snapshot ~/.claude/skills/gsd-* -> ~/.claude-tools/skill-catalog/gsd'
Run { npx -y '@opengsd/gsd-core@latest' --claude --global --profile=core } 'npx @opengsd/gsd-core --claude --global --profile=core'

Say 'Helper scripts and mcptoon'
foreach ($f in (Get-ChildItem bin -File)) { Place $f.FullName "$HOME/.claude-tools/bin/$($f.Name)" }
if (-not $DryRun) {
  Render mcptoon "$Tmp/mcptoon.json"
  New-Item -ItemType Directory -Force "$HOME/.mcptoon" | Out-Null
  if (Test-Path "$HOME/.mcptoon/config.json") { Copy-Item "$HOME/.mcptoon/config.json" "$HOME/.mcptoon/config.json.bak-$Stamp" -Force }
  Copy-Item "$Tmp/mcptoon.json" "$HOME/.mcptoon/config.json" -Force
}

Say 'MCP servers in ~/.claude.json (mcptoon, caveman)'
if ($SkipClaudeConfig) { Write-Host '  skipped: Claude Code is not in -Harnesses' }
elseif (-not $DryRun) {
  Render mcpservers "$Tmp/mcps.json"
  python -c "import json,os,sys; p=os.path.expanduser('~/.claude.json'); c=json.load(open(p,encoding='utf-8')) if os.path.exists(p) else {}; n=json.load(open(sys.argv[1],encoding='utf-8')); c.setdefault('mcpServers',{}).update(n); json.dump(c,open(p,'w',encoding='utf-8'),indent=2); print('  merged:',', '.join(n))" "$Tmp/mcps.json"
}

Say 'Third-party repos built from source (tools/git-sources.txt)'
foreach ($l in Lines tools/git-sources.txt) {
  $name, $url, $rev = $l -split '\s+'
  $dir = if ($name -eq 'Kwipu') { "$HOME/.claude-tools/Kwipu" } else { "$HOME/.claude-tools/src/$name" }
  if (Test-Path $dir) { Write-Host "  $name present"; continue }
  Run { New-Item -ItemType Directory -Force (Split-Path $dir) | Out-Null; git clone $url $dir; git -C $dir checkout $rev } "clone $name @ $rev"
}
if (-not $DryRun) {
  $kw = "$HOME/.claude-tools/Kwipu"
  if ((Test-Path $kw) -and -not (Test-Path "$kw/.venv/Scripts/python.exe")) { uv venv "$kw/.venv" --python 3.13; uv pip install --python "$kw/.venv/Scripts/python.exe" -r "$kw/requirements.txt" }
}

Say 'Obsidian Local REST API plugin (copied into each vault by bin/vault-bootstrap)'
$pl = "$HOME/.claude-tools/obsidian-plugins/obsidian-local-rest-api"
if (-not (Test-Path "$pl/main.js")) {
  Run { New-Item -ItemType Directory -Force $pl | Out-Null; foreach ($a in 'main.js', 'manifest.json', 'styles.css') { Fetch "https://github.com/coddingtonbear/obsidian-local-rest-api/releases/latest/download/$a" "$pl/$a" } } 'download obsidian-local-rest-api release assets'
}

Say 'Lightpanda (primary browser; unsigned community Windows port, Chrome is the fallback)'
if (-not (Test-Path "$HOME/.local/bin/lightpanda.exe")) {
  Run { $z = Join-Path $Tmp 'lp.zip'; Fetch 'https://github.com/qidiai/lightpanda-windows-port/releases/download/portable-v0.2.5/lightpanda-portable-windows-x64.zip' $z; Expand-Archive $z "$Tmp/lp" -Force; New-Item -ItemType Directory -Force "$HOME/.local/bin" | Out-Null; Copy-Item (Get-ChildItem "$Tmp/lp" -Recurse -Filter 'lightpanda*.exe' | Select-Object -First 1).FullName "$HOME/.local/bin/lightpanda.exe" -Force } 'download lightpanda portable-v0.2.5'
}

Say 'Plugins (claude/plugins.json)'
if ($HaveClaude) {
  $pj = Get-Content claude/plugins.json -Raw | ConvertFrom-Json
  foreach ($m in $pj.marketplaces.PSObject.Properties) { Run { claude plugin marketplace add $m.Value.repo } "claude plugin marketplace add $($m.Value.repo)" }
  foreach ($p in $pj.enabled) { Run { claude plugin install $p } "claude plugin install $p" }
}

Say 'Skill catalog (mcptoon) and project memory (obsidian-wiki)'
Run {
  $C = "$HOME/.claude-tools/skill-catalog"; New-Item -ItemType Directory -Force "$C/user" | Out-Null
  function Link($link, $target) { if ((Test-Path $target) -and -not (Test-Path $link)) { New-Item -ItemType Junction -Path $link -Target $target | Out-Null } }
  Link "$C/candor" "$HOME/.claude/plugins/marketplaces/candor/plugins/candor/skills"
  $os = "$HOME/.claude/plugins/marketplaces/obsidian-skills"; Link "$C/obsidian-skills" $(if (Test-Path "$os/plugins/obsidian/skills") { "$os/plugins/obsidian/skills" } else { "$os/skills" })
  $owDir = "$HOME/.local/share/uv/tools/obsidian-wiki/Lib/site-packages/obsidian_wiki/_data/skills"
  if (Test-Path $owDir) { Link "$C/obsidian-wiki" $owDir; foreach ($s in 'llm-wiki', 'wiki-capture', 'wiki-query') { Link "$HOME/.claude/skills/$s" "$owDir/$s" } }
  $root = "$HOME/.local/share/harness-master-controller/skills"
  foreach ($s in (Get-Content tools/folded-skills.txt | Where-Object { $_ })) { if (-not (Test-Path "$root/$s")) { Link "$C/user/$s" "$HOME/.claude/skills/$s" } }
  $roots = @($C); if (Test-Path $root) { $roots = @($root, $C) }
  if (Get-Command mcptoon -ErrorAction SilentlyContinue) { mcptoon skills index @roots }
  if (Get-Command obsidian-wiki -ErrorAction SilentlyContinue) { obsidian-wiki hooks install; obsidian-wiki hooks install --only UserPromptSubmit }
} 'link candor, obsidian-wiki and folded user skills into ~/.claude-tools/skill-catalog, index them, register the obsidian-wiki hooks'

Say 'Services (scheduled tasks, rendered from launchd/*.plist)'
function Register-Service($plist, $listen) {
  $spec = "$HOME/.claude-tools/services/$([IO.Path]::GetFileNameWithoutExtension($plist)).json"
  if ($DryRun) { Write-Host "  would register scheduled task from $plist"; return }
  New-Item -ItemType Directory -Force (Split-Path $spec) | Out-Null
  $x = @(); if ($listen) { $x = @('--listen', $listen) }
  Render service $spec (@('--plist', $plist) + $x)
  $name = (Get-Content $spec -Raw | ConvertFrom-Json).name
  $act = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$PSScriptRoot\windows\run-service.ps1`" -Spec `"$spec`""
  Register-ScheduledTask -TaskName $name -Action $act -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0) -Force | Out-Null
  Start-ScheduledTask -TaskName $name
  Write-Host "  registered and started: $name"
}
Register-Service launchd/io.lightpanda.serve.plist ''
# Caveman records the proxy route it wired into each agent; the proxy must listen on exactly that route.
$cmAgents = @('claude', 'opencode') | Where-Object { $Harnesses -match $_ }
if ((Get-Command caveman -ErrorAction SilentlyContinue) -and -not $DryRun -and $cmAgents) {
  caveman setup --yes --agents ($cmAgents -join ',')
  $route = $null
  foreach ($a in $cmAgents) {
    $f = "$HOME/.caveman/integrations/$a.json"
    if (-not $route -and (Test-Path $f)) { $route = (Get-Content $f -Raw | ConvertFrom-Json).operations | ForEach-Object { $_.owned.route } | Where-Object { $_ } | Select-Object -First 1 }
  }
  if ($route) {
    $listen = ([uri]$route).Authority
    if (-not $SkipClaudeConfig) { python -c "import json,os,sys; p=os.path.expanduser('~/.claude/settings.json'); s=json.load(open(p,encoding='utf-8')); s.setdefault('env',{})['ANTHROPIC_BASE_URL']=sys.argv[1]; json.dump(s,open(p,'w',encoding='utf-8'),indent=2)" $route }
    Register-Service launchd/com.caveman.proxy.plist $listen
    if (-not $SkipClaudeConfig) { caveman doctor claude --fix }
  }
} elseif (-not $cmAgents) { Write-Host '  caveman: neither Claude Code nor OpenCode selected, skipped' }
elseif ($DryRun) { Write-Host "  would: caveman setup --yes --agents $($cmAgents -join ',') and register the proxy on the route Caveman records" }
else { Write-Host '  @caveman-ai/cli is missing: re-run the installer once its npm install has succeeded' }

if (-not $DryRun) {
  New-Item -ItemType Directory -Force "$HOME/.claude-tools" | Out-Null
  (Get-Location).Path -replace '\\', '/' | Set-Content "$HOME/.claude-tools/config-repo" -Encoding ascii
  (git rev-parse HEAD 2>$null) | Set-Content "$HOME/.claude-tools/.config-rev" -Encoding ascii
}
Say 'Done. Remaining by hand: figcraft app, open Obsidian once per vault, restart Claude Code, run `mcptoon doctor`. See windows/README.md.'
