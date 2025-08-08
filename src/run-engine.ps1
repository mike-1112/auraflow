param(
    [int]$Mood,[int]$Energy,[int]$Focus,[string]$Note,
    [switch]$Chakra,[switch]$Tree,[switch]$UseWeights,
    [ValidateSet("better","same","worse")] [string]$After,
    [switch]$DebugKw,[switch]$Help
)


if ($Help) {
    Write-Host "Usage:`n  powershell -ExecutionPolicy Bypass -File src\run-engine.ps1 -Mood 6 -Energy 7 -Focus 5 -Note ""arousal + desire"" -Chakra -UseWeights -DebugKw"
    exit 0
}

function Resolve-RepoPath([string]$p){ Join-Path (Get-Location) $p }

# Paths
$rulesPath=Resolve-RepoPath "data\engine\rules.json"
$chakCfgPath=Resolve-RepoPath "data\engine\chakra.json"
$treeCfgPath=Resolve-RepoPath "data\engine\tree.json"
$chakWeightPath=Resolve-RepoPath "data\engine\chakra_weights.json"
$chakraKwPath=Resolve-RepoPath "data\engine\chakra_keywords.json"
$contentPath=Resolve-RepoPath "data\engine\content_packs.json"
$userBiasPath = Resolve-RepoPath "data\engine\user_bias.json"
if(-not (Test-Path $rulesPath)){ throw "Missing $rulesPath" }

# Load
$rulesObj=Get-Content -Raw $rulesPath|ConvertFrom-Json
$chakCfgObj= if(Test-Path $chakCfgPath){Get-Content -Raw $chakCfgPath|ConvertFrom-Json} else {$null}
$treeCfgObj= if(Test-Path $treeCfgPath){Get-Content -Raw $treeCfgPath|ConvertFrom-Json} else {$null}
$chakWeights= if(Test-Path $chakWeightPath){Get-Content -Raw $chakWeightPath|ConvertFrom-Json} else {$null}
$chakraKw= if(Test-Path $chakraKwPath){Get-Content -Raw $chakraKwPath|ConvertFrom-Json} else {$null}
$contentPacks= if(Test-Path $contentPath){Get-Content -Raw $contentPath|ConvertFrom-Json} else {$null}

$userBias = if (Test-Path $userBiasPath) {
    Get-Content -Raw $userBiasPath | ConvertFrom-Json
} else {
    # default zero bias object
    [pscustomobject]@{
        chakra = [pscustomobject]@{
            root=0.0; sacral=0.0; solar_plexus=0.0; heart=0.0; throat=0.0; third_eye=0.0; crown=0.0
        }
        last_update = ""
    }
}

# Emojis
$emojiMap=@{
  "mood"=@("","","","","","","","","","","");
  "energy"=@("","","","","","","","","","","");
  "focus"=@("","","","","","","","","","","")
}

function Read-Int([string]$label,[string]$key){
  while($true){
    $v=Read-Host "$label (0-10)"
    if($v -match '^\d+$' -and [int]$v -ge 0 -and [int]$v -le 10){
      $i=[int]$v; Write-Host "   $i $($emojiMap[$key][$i])"; return $i
    } else { Write-Host "Enter 0..10" -ForegroundColor Yellow }
  }
}

function Tokenize-Note([string]$t){
  if(-not $t){ return @() }
  (($t.ToLower() -replace "[^a-z0-9\s]"," ") -split "\s+") | Where-Object { $_ -ne "" }
}

# Inputs
if($PSBoundParameters.Keys -notcontains 'Mood'){ $Mood=Read-Int "Mood" "mood" }
if($PSBoundParameters.Keys -notcontains 'Energy'){ $Energy=Read-Int "Energy" "energy" }
if($PSBoundParameters.Keys -notcontains 'Focus'){ $Focus=Read-Int "Focus" "focus" }
if($null -eq $Note){ $Note=Read-Host "Optional Note (Enter to skip)" }

# Buckets
function Get-Bucket([int]$v,$low,$high){
  if($v -ge $low[0] -and $v -le $low[1]){"low"}
  elseif($v -ge $high[0] -and $v -le $high[1]){"high"}
  else {"mid"}
}
$bMoodLow=$rulesObj.buckets.mood.low; $bMoodHigh=$rulesObj.buckets.mood.high
$bEnergyLow=$rulesObj.buckets.energy.low; $bEnergyHigh=$rulesObj.buckets.energy.high
$bFocusLow=$rulesObj.buckets.focus.low; $bFocusHigh=$rulesObj.buckets.focus.high
$moodBucket=Get-Bucket $Mood $bMoodLow $bMoodHigh
$energyBucket=Get-Bucket $Energy $bEnergyLow $bEnergyHigh
$focusBucket=Get-Bucket $Focus $bFocusLow $bFocusHigh

# Quick tags
$noteTag=$null; $tags=@{}
if($Note){
  $l=$Note.ToLower()
  if($l -match 'anxious|anxiety|panic|overwhelm'){$noteTag='anxious';$tags.tag_anxious=1}
  if($l -match 'peace|calm|tranquil|serene'){ if(-not $noteTag){$noteTag='peace'}; $tags.tag_peace=1 }
  if($l -match 'gratitude|grateful|thank'){$tags.tag_gratitude=1}
  if($l -match 'love|care|compassion'){$tags.tag_love=1}
  if($l -match 'stress|stressed|tense'){$tags.tag_stress=1}
}

# Refined keyword mapping
$noteTokens=Tokenize-Note $Note
$chakraOrder=@("root","sacral","solar_plexus","heart","throat","third_eye","crown")
$kwCounts=@{}
if($chakraKw -and $noteTokens.Count -gt 0){
  foreach($ck in $chakraOrder){
    $kwCounts[$ck]=0
    if($chakraKw.$ck.keywords){ foreach($kw in $chakraKw.$ck.keywords){ if($noteTokens -contains ($kw.ToLower())){ $kwCounts[$ck]++ } } }
    if($chakraKw.$ck.somatic){
      foreach($kw in $chakraKw.$ck.somatic){
        $needle=$kw.ToLower()
        foreach($tok in $noteTokens){
          if($tok -eq $needle){ $kwCounts[$ck]++ }
          elseif($needle.Length -ge 5 -and $tok.StartsWith($needle.Substring(0,5))){ $kwCounts[$ck]++ }
        }
      }
    }
  }
}
if($DebugKw){
  Write-Host "`nDEBUG  Keywords" -ForegroundColor Yellow
  Write-Host ("  chakra_keywords.json loaded: {0}" -f ([bool]$chakraKw))
  Write-Host ("  tokens: {0}" -f ($noteTokens -join ", "))
  foreach($k in $chakraOrder){ "{0,-12}: {1}" -f $k,$kwCounts[$k] | Write-Host }
}

# Rule resolution
$rules=$rulesObj.rules; $selectedRule=$null
if($noteTag -eq 'anxious'){ $selectedRule=($rules|Where-Object{ $_.id -eq 'anxious_any'})[0] }
elseif($noteTag -eq 'peace'){ $selectedRule=($rules|Where-Object{ $_.id -eq 'peace_any'})[0] }
if(-not $selectedRule){
  $cand=$rules|Where-Object{ $_.when.mood -eq $moodBucket -and $_.when.energy -eq $energyBucket -and $_.when.focus -eq $focusBucket }
  if($cand.Count -gt 0){ $selectedRule=$cand[0] }
}
if(-not $selectedRule){
  $mTry=@($moodBucket); if($moodBucket -eq 'mid'){$mTry=@('low','high')}
  $eTry=@($energyBucket); if($energyBucket -eq 'mid'){$eTry=@('low','high')}
  $fTry=@($focusBucket); if($focusBucket -eq 'mid'){$fTry=@('low','high')}
  foreach($m in $mTry){ foreach($e in $eTry){ foreach($f in $fTry){
    $hit=$rules|Where-Object{ $_.when.mood -eq $m -and $_.when.energy -eq $e -and $_.when.focus -eq $f }
    if($hit.Count -gt 0){ $selectedRule=$hit[0]; break }
  } } }
}
if(-not $selectedRule){ foreach($rid in $rulesObj.order){ $r=($rules|Where-Object{ $_.id -eq $rid})[0]; if($r){ $selectedRule=$r; break } } }
if(-not $selectedRule){ throw "No matching rule found. Check data\engine\rules.json." }
$shift=$selectedRule.shift; $sample=$selectedRule.example

# Chakra selection
$chakraNodes=@(); $chakraScoresOut=@()
if($Chakra){
  if($UseWeights -and $chakWeights){
    $nm=[double]$Mood/10; $ne=[double]$Energy/10; $nf=[double]$Focus/10
    $feat=@{"mood"=$nm;"energy"=$ne;"focus"=$nf;"tag_anxious"=([int]$tags.tag_anxious);"tag_peace"=([int]$tags.tag_peace);"tag_gratitude"=([int]$tags.tag_gratitude);"tag_love"=([int]$tags.tag_love);"tag_stress"=([int]$tags.tag_stress)}
    foreach($ck in $chakWeights.weights.PSObject.Properties.Name){
      $w=$chakWeights.weights.$ck; $score=0.0
      foreach($k in $chakWeights.features){
        $fv=0.0; if($feat.ContainsKey($k)){$fv=[double]$feat[$k]}
        $wv=0.0; if($w.PSObject.Properties.Name -contains $k){$wv=[double]$w.$k}
        $score += ($fv*$wv)
      }
      $label=$chakWeights.labels.$ck; if(-not $label){$label=$ck}
      $chakraScoresOut += [pscustomobject]@{ key=$ck; label=$label; score=[math]::Round($score,3) }
    }

    # Keyword bumps + disambiguation
    if($chakraKw -and $noteTokens -and $chakraScoresOut.Count -gt 0){
      $kwWeight=[double]$chakraKw.weights.keyword_hit
      $rootMoney=[double]$chakraKw.weights.money_root_bonus
      $thirdeyeCl=[double]$chakraKw.weights.clarity_thirdeye_bonus

      $moneyList=@("rent","mortgage","bills","debt","income","money","cash","paycheck","job","security")
      $clarList=@("clarity","vision","insight","intuition","confused","foggy","idea")
      $moneyHits=($noteTokens|Where-Object{ $moneyList -contains $_ }).Count
      $clarityHits=($noteTokens|Where-Object{ $clarList -contains $_ }).Count
      if ($moneyHits -gt 0) {
          $targets = $chakraScoresOut | Where-Object key -eq "root"
          foreach ($t in $targets) { $t.score += ($rootMoney * $moneyHits) }
      }
      if ($clarityHits -gt 0) {
          $targets = $chakraScoresOut | Where-Object key -eq "third_eye"
          foreach ($t in $targets) { $t.score += ($thirdeyeCl * $clarityHits) }
      }

      foreach($c in $chakraScoresOut){ $k=$c.key; if($kwCounts.ContainsKey($k)){ $c.score += ($kwCounts[$k]*$kwWeight) } }

      $physTerms=@(); $emoTerms=@()
      if($chakraKw.disambiguation){
        $physTerms=@($chakraKw.disambiguation.physical_arousal_terms|ForEach-Object{ $_.ToLower() })
        $emoTerms=@($chakraKw.disambiguation.emotional_warmth_terms|ForEach-Object{ $_.ToLower() })
      }
      $physHits=($noteTokens|Where-Object{ $physTerms -contains $_ }).Count
      $emoHits=($noteTokens|Where-Object{ $emoTerms  -contains $_ }).Count
      if ($physHits -gt 0 -and $emoHits -eq 0 -and $chakraKw.weights.physical_overrides_heart) {
          $sacralTargets = $chakraScoresOut | Where-Object key -eq "sacral"
          foreach ($t in $sacralTargets) { $t.score += 0.6 }

          $heartTargets = $chakraScoresOut | Where-Object key -eq "heart"
          foreach ($t in $heartTargets) { $t.score -= 0.3 }
      }
    }

    $chakraScoresOut = $chakraScoresOut | Sort-Object -Property score -Descending
    $chakraNodes = ($chakraScoresOut | Select-Object -First 2).key
  } elseif($chakCfgObj){
    $names=$chakCfgObj.map.PSObject.Properties.Name
    if($names -contains $shift){ $chakraNodes=@($chakCfgObj.map.$shift) }
  }
}

# Practice selection
$contentId=$null; $contentText=$sample
if($contentPacks){
  $pack=$contentPacks.$shift
  if($pack){
    $picked=$null
    if($Chakra -and $chakraNodes.Count -gt 0 -and $pack.chakra){
      foreach($n in $chakraNodes){
        if($pack.chakra.PSObject.Properties.Name -contains $n){
          $list=$pack.chakra.$n; if($list.Count -gt 0){ $picked = $list | Get-Random; break }
        }
      }
    }
    if(-not $picked -and $pack.general){ $picked=$pack.general | Get-Random }
    if($picked){ $contentId=$picked.id; $contentText=$picked.text }
  }
}

# Tree
$treeNodes=@()
if($Tree -and $treeCfgObj){
  $names=$treeCfgObj.map.PSObject.Properties.Name
  if($names -contains $shift){ $treeNodes=@($treeCfgObj.map.$shift) }
}

# Output
$emoji=@{mood=$emojiMap.mood[$Mood];energy=$emojiMap.energy[$Energy];focus=$emojiMap.focus[$Focus]}
Write-Host "`nAURAFLOW  Morning State-Shift Result"
Write-Host ("-"*48)
("{0,-14}: {1} {2}" -f "Mood",$Mood,$emoji.mood)   | Write-Host
("{0,-14}: {1} {2}" -f "Energy",$Energy,$emoji.energy) | Write-Host
("{0,-14}: {1} {2}" -f "Focus",$Focus,$emoji.focus)   | Write-Host
if ($Note) { ("{0,-14}: {1}" -f "Note",$Note) | Write-Host }


("{0,-14}: {1}" -f "Shift",$shift) | Write-Host

# --- Normalize & fix letter-by-letter spacing ---
# 1) Normalize ANY Unicode space separator to regular space
#    (\p{Zs} catches NBSP, thin spaces, en spaces, etc.)
$contentText = [regex]::Replace($contentText, '\p{Zs}', ' ')

# 2) If the string looks like it's letter-by-letter spaced,
#    remove single spaces that sit BETWEEN letters only.
$pairCount = ([regex]::Matches($contentText, '(?<=\p{L})\s(?=\p{L})')).Count
if ($pairCount -ge 10) {
    $contentText = [regex]::Replace($contentText, '(?<=\p{L})\s(?=\p{L})', '')
}

# 3) Normal tidy
$contentText = [regex]::Replace($contentText, '\s{2,}', ' ')         # collapse doubles
$contentText = [regex]::Replace($contentText, '(hips)\s*softness', '$1 — softness')
$contentText = [regex]::Replace($contentText, '([a-z])([A-Z])', '$1 $2')  # add space before Uppercase after lowercase
$contentText = $contentText.Trim()

("{0,-14}: {1}" -f "Practice", $contentText) | Write-Host





if($Chakra -and ($chakraNodes.Count -gt 0 -or $chakraScoresOut.Count -gt 0)){
  Write-Host ""
  if($UseWeights -and $chakraScoresOut.Count -gt 0){
    Write-Host "Support areas today (not a diagnosis):" -ForegroundColor Magenta
    $display=$chakraScoresOut | Sort-Object { [array]::IndexOf(@("root","sacral","solar_plexus","heart","throat","third_eye","crown"), $_.key) }
    foreach($c in $display){ Write-Host ("  - {0}: {1}" -f $c.label,[math]::Round($c.score,3)) }
    Write-Host "Focus gently on:" -ForegroundColor Magenta
  } else {
    Write-Host "Support areas today:" -ForegroundColor Magenta
  }
  $orderedTop=@()
  foreach($k in @("root","sacral","solar_plexus","heart","throat","third_eye","crown")){ if($chakraNodes -contains $k){ $orderedTop+=$k } }
  foreach($n in $orderedTop){
    $lab=$n
    if($chakWeights -and $chakWeights.labels.$n){$lab=$chakWeights.labels.$n}
    elseif($chakCfgObj -and $chakCfgObj.labels.$n){$lab=$chakCfgObj.labels.$n}
    Write-Host ("  - {0} [{1}]" -f $lab,$n)
  }
}

# Log
New-Item -ItemType Directory -Force -Path (Resolve-RepoPath "logs")|Out-Null
$stamp=Get-Date -Format "yyyy-MM-dd"
$log=Resolve-RepoPath ("logs\engine-{0}.log" -f $stamp)
([pscustomobject]@{ts=(Get-Date).ToString("o");mood=$Mood;energy=$Energy;focus=$Focus;note=$Note;shift=$shift;content_id=$contentId;after=$After;chakra=($chakraNodes -join ",");tree=($treeNodes -join ",");usedWeights=([bool]$UseWeights)}|ConvertTo-Json -Compress)|Add-Content -Path $log
# Auto-export Share Card for today (best-effort, non-blocking)
try {
  powershell -ExecutionPolicy Bypass -File (Join-Path (Get-Location) 'src\export-card.ps1') -Date (Get-Date -Format 'yyyy-MM-dd') | Out-Null
} catch { }

# Auto-export Share Card for today (best-effort)
try {
  powershell -ExecutionPolicy Bypass -File (Join-Path (Get-Location) 'src\export-card.ps1') -Date (Get-Date -Format 'yyyy-MM-dd') | Out-Null
} catch { }
# Auto-export Share Card for today (best-effort)
try {
  powershell -ExecutionPolicy Bypass -File (Join-Path (Get-Location) 'src\export-card.ps1') -Date (Get-Date -Format 'yyyy-MM-dd') | Out-Null
} catch { }
exit 0
