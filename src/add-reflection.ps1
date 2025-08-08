param(
  [string]$Diary = "",
  [string]$Journal = "",
  [string]$Date = (Get-Date -Format "yyyy-MM-dd")
)

function Resolve-RepoPath([string]$rel){
  $root = (Get-Location)
  return Join-Path $root $rel
}

# Ensure logs folder
New-Item -ItemType Directory -Force -Path (Resolve-RepoPath "logs") | Out-Null
$logPath = Resolve-RepoPath ("logs\engine-{0}.log" -f $Date)

# Append a reflection line (JSON)
$payload = [pscustomobject]@{
  ts      = (Get-Date).ToString("o")
  diary   = $Diary
  journal = $Journal
}
($payload | ConvertTo-Json -Compress) | Add-Content -Path $logPath

# Rebuild card for this date (and auto-open)
powershell -ExecutionPolicy Bypass -File (Resolve-RepoPath "src\export-card.ps1") -Date $Date | Out-Null
