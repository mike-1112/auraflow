param(
    [int]$Mood,
    [int]$Energy,
    [int]$Focus,
    [string]$Note,
    [switch]$Chakra,  # user switch
    [switch]$Tree,    # user switch
    [switch]$Help
)

if ($Help) {
@"
Usage:
  Interactive:
    powershell -ExecutionPolicy Bypass -File src\run-engine.ps1

  With flags:
    powershell -ExecutionPolicy Bypass -File src\run-engine.ps1 -Mood 8 -Energy 8 -Focus 8 -Note ""feeling great"" -Chakra -Tree
"@
    exit 0
}

function Resolve-RepoPath([string]$relative) {
    Join-Path -Path (Get-Location) -ChildPath $relative
}

$rulesPath  = Resolve-RepoPath "data\engine\rules.json"
$chakCfgPath = Resolve-RepoPath "data\engine\chakra.json"
$treeCfgPath = Resolve-RepoPath "data\engine\tree.json"

if (-not (Test-Path $rulesPath)) { throw "Missing $rulesPath" }

$rulesObj   = Get-Content -Raw -Path $rulesPath | ConvertFrom-Json
$chakCfgObj = $null
$treeCfgObj = $null
if (Test-Path $chakCfgPath) { $chakCfgObj = Get-Content -Raw -Path $chakCfgPath | ConvertFrom-Json }
if (Test-Path $treeCfgPath) { $treeCfgObj = Get-Content -Raw -Path $treeCfgPath | ConvertFrom-Json }

function Read-Int([string]$label){
    while ($true) {
        $v = Read-Host "$label (0-10)"
        if ($v -match '^\d+$' -and [int]$v -ge 0 -and [int]$v -le 10) { return [int]$v }
        Write-Host "Please enter an integer 0..10." -ForegroundColor Yellow
    }
}

if ($PSBoundParameters.Keys -notcontains 'Mood')   { $Mood   = Read-Int "Mood" }
if ($PSBoundParameters.Keys -notcontains 'Energy') { $Energy = Read-Int "Energy" }
if ($PSBoundParameters.Keys -notcontains 'Focus')  { $Focus  = Read-Int "Focus" }
if ($null -eq $Note) { $Note = Read-Host "Optional Note (press Enter to skip)" }

# Buckets
$bMoodLow    = $rulesObj.buckets.mood.low
$bMoodHigh   = $rulesObj.buckets.mood.high
$bEnergyLow  = $rulesObj.buckets.energy.low
$bEnergyHigh = $rulesObj.buckets.energy.high
$bFocusLow   = $rulesObj.buckets.focus.low
$bFocusHigh  = $rulesObj.buckets.focus.high

function Get-Bucket([int]$v, $lowRange, $highRange){
    if ($v -ge $lowRange[0] -and $v -le $lowRange[1]) { return "low" }
    if ($v -ge $highRange[0] -and $v -le $highRange[1]) { return "high" }
    "mid"
}

$moodBucket   = Get-Bucket $Mood   $bMoodLow  $bMoodHigh
$energyBucket = Get-Bucket $Energy $bEnergyLow $bEnergyHigh
$focusBucket  = Get-Bucket $Focus  $bFocusLow $bFocusHigh

# Tags from note (simple)
$noteTag = $null
if ($Note) {
    $lower = $Note.ToLower()
    if ($lower -match 'anxious|anxiety|panic|overwhelm') { $noteTag = 'anxious' }
    elseif ($lower -match 'peace|calm|tranquil|serene')  { $noteTag = 'peace' }
}

# Rule resolution
$rules = $rulesObj.rules
$selectedRule = $null

if ($noteTag -eq 'anxious') {
    $selectedRule = ($rules | Where-Object { $_.id -eq 'anxious_any' })[0]
} elseif ($noteTag -eq 'peace') {
    $selectedRule = ($rules | Where-Object { $_.id -eq 'peace_any' })[0]
}

if (-not $selectedRule) {
    # exact
    $candidates = $rules | Where-Object { $_.when.mood -eq $moodBucket -and $_.when.energy -eq $energyBucket -and $_.when.focus -eq $focusBucket }
    if ($candidates.Count -gt 0) { $selectedRule = $candidates[0] }
}

# fallbacks for any 'mid'
if (-not $selectedRule) {
    $try = @()

    $mTry = @($moodBucket); if ($moodBucket -eq 'mid') { $mTry = @('low','high') }
    $eTry = @($energyBucket); if ($energyBucket -eq 'mid') { $eTry = @('low','high') }
    $fTry = @($focusBucket); if ($focusBucket -eq 'mid') { $fTry = @('low','high') }

    foreach ($m in $mTry) {
      foreach ($e in $eTry) {
        foreach ($f in $fTry) {
          $hit = $rules | Where-Object { $_.when.mood -eq $m -and $_.when.energy -eq $e -and $_.when.focus -eq $f }
          if ($hit.Count -gt 0) { $try += $hit[0] }
        }
      }
    }
    if ($try.Count -gt 0) { $selectedRule = $try[0] }
}

if (-not $selectedRule) {
    # final safety: pick the first rule in declared order that exists
    foreach ($rid in $rulesObj.order) {
        $r = ($rules | Where-Object { $_.id -eq $rid })[0]
        if ($r) { $selectedRule = $r; break }
    }
}

if (-not $selectedRule) { throw "No matching rule found. Check data\engine\rules.json." }

$shift  = $selectedRule.shift
$sample = $selectedRule.example

# Optional mappings (use *config* objects, not the -Chakra / -Tree switches)
$chakraNodes = @()
$treeNodes   = @()

if ($Chakra -and $chakCfgObj) {
    $names = $chakCfgObj.map.PSObject.Properties.Name
    if ($names -contains $shift) { $chakraNodes = @($chakCfgObj.map.$shift) }
}

if ($Tree -and $treeCfgObj) {
    $names = $treeCfgObj.map.PSObject.Properties.Name
    if ($names -contains $shift) { $treeNodes = @($treeCfgObj.map.$shift) }
}

# Output
Write-Host ""
Write-Host "AURAFLOW  Morning State-Shift Result" -ForegroundColor Cyan
Write-Host ("-"*48)
"{0,-12}: {1}" -f "Mood",   $Mood   | Write-Host
"{0,-12}: {1}" -f "Energy", $Energy | Write-Host
"{0,-12}: {1}" -f "Focus",  $Focus  | Write-Host
if ($Note) { "{0,-12}: {1}" -f "Note", $Note | Write-Host }
"{0,-12}: {1}" -f "Shift",   $shift  | Write-Host
"{0,-12}: {1}" -f "Example", $sample | Write-Host

if ($Chakra -and $chakraNodes.Count -gt 0) {
    Write-Host ""
    Write-Host "Chakra nodes:" -ForegroundColor Magenta
    foreach ($n in $chakraNodes) {
        $label = $chakCfgObj.labels.$n; if (-not $label) { $label = $n }
        Write-Host ("  - {0} [{1}]" -f $label, $n)
    }
}
if ($Tree -and $treeNodes.Count -gt 0) {
    Write-Host ""
    Write-Host "Tree of Life nodes:" -ForegroundColor Green
    foreach ($n in $treeNodes) {
        $label = $treeCfgObj.labels.$n; if (-not $label) { $label = $n }
        Write-Host ("  - {0} [{1}]" -f $label, $n)
    }
}

# Log
New-Item -ItemType Directory -Force -Path (Resolve-RepoPath "logs") | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd"
$log   = Resolve-RepoPath ("logs\engine-{0}.log" -f $stamp)
([pscustomobject]@{
    ts=(Get-Date).ToString("o"); mood=$Mood; energy=$Energy; focus=$Focus; note=$Note;
    shift=$shift; sample=$sample; chakra=($chakraNodes -join "," ); tree=($treeNodes -join ",")
} | ConvertTo-Json -Compress) | Add-Content -Path $log

exit 0
