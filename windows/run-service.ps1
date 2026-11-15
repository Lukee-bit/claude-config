# Keep-alive runner for one service spec (the Windows counterpart of a launchd KeepAlive job).
# Spec JSON comes from `windows/render.py service` (single source: launchd/*.plist).
param([Parameter(Mandatory)][string]$Spec)
$s = Get-Content $Spec -Raw | ConvertFrom-Json
foreach ($p in $s.env.PSObject.Properties) { Set-Item "env:$($p.Name)" $p.Value }
while ($true) {
  if ($s.log) { & $s.exe @($s.args) *>> $s.log } else { & $s.exe @($s.args) *> $null }
  Start-Sleep ([int]$s.throttle)
}
