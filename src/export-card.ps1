param([string]$Date = (Get-Date -Format "yyyy-MM-dd"))

function Resolve-RepoPath([string]$rel){
  $root = (Get-Location)
  return Join-Path $root $rel
}

# --- Load today entries ---
$logPath = Resolve-RepoPath ("logs\engine-{0}.log" -f $Date)
if(-not (Test-Path $logPath)){ Write-Host "No log for $Date"; exit 0 }
$lines = Get-Content -Path $logPath -ErrorAction Stop
$entries = @()
foreach($ln in $lines){ try{ $entries += ($ln | ConvertFrom-Json) } catch{} }

# Pick latest engine entry, plus latest diary/journal if present
$engine  = ($entries | Where-Object { $_.mood -ne $null }) | Select-Object -Last 1
$diaryE  = ($entries | Where-Object { $_.diary  -ne $null -and $_.diary  -ne "" }) | Select-Object -Last 1
$journalE= ($entries | Where-Object { $_.journal -ne $null -and $_.journal -ne "" }) | Select-Object -Last 1

if(-not $engine){ Write-Host "No engine entry found for $Date"; exit 0 }

# ----- Helpers -----
function HtmlEncode([string]$s){
  if($null -eq $s){ return "" }
  return $s.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;")
}
function Normalize([string]$s){
  if($null -eq $s){ return "" }
  return ($s -replace '\s+',' ').Trim()
}

# Data
$mood  = [int]$engine.mood
$energy= [int]$engine.energy
$focus = [int]$engine.focus
$note  = Normalize $engine.note
$shift = ($engine.shift | Out-String).Trim()

# Chakra labels/colors (fallbacks if files absent)
$chakraLabels = @{
  root="Root (Muladhara)"; sacral="Sacral (Svadhisthana)"; solar_plexus="Solar Plexus (Manipura)";
  heart="Heart (Anahata)"; throat="Throat (Vishuddha)"; third_eye="Third Eye (Ajna)"; crown="Crown (Sahasrara)"
}
$chakraColors = @{
  root="#E53935"; sacral="#F57C00"; solar_plexus="#FBC02D";
  heart="#43A047"; throat="#1E88E5"; third_eye="#5E35B1"; crown="#8E24AA"
}

# Top focus chips from engine.tree / engine.chakra
$chakras = @()
if($engine.chakra){ $chakras = @($engine.chakra -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }) }

# Support scores if present
$support = @{
  root = 0; sacral=0; solar_plexus=0; heart=0; throat=0; third_eye=0; crown=0
}
if($engine.support){
  foreach($k in $support.Keys){
    $v = $engine.support.$k
    if($null -ne $v){ $support[$k] = [double]$v }
  }
}

# Compose reflections
$diaryText   = if($diaryE){ Normalize $diaryE.diary } else { "" }
$journalText = if($journalE){ Normalize $journalE.journal } else { "" }

# --- HTML ---
$ts = Get-Date
$outDir = Resolve-RepoPath "cards"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$fname = "auraflow-card-{0}.html" -f (Get-Date -Format "yyyyMMdd-HHmmss")
$out = Join-Path $outDir $fname

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>AuraFlow  $($Date)</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
<style>
  :root{ --bg1:#fff; --panel:rgba(255,255,255,0.55); --ring:#e9eef3; --ink:#0f172a; --sub:#475569; --chip:#eef2f6; --b:#d7dee7}
  *{box-sizing:border-box}
  body{margin:0; font-family:Inter,system-ui,Segoe UI,Arial; color:var(--ink); background: radial-gradient(1200px 600px at 10% 0%, #ffd1e1, transparent 60%), radial-gradient(1200px 600px at 90% 100%, #cbe7ff, transparent 60%), linear-gradient(180deg,#f7fbff,#f6f8fb); }
  .wrap{max-width:1000px; margin:48px auto; padding:0 18px}
  .card{background:var(--panel); backdrop-filter:saturate(160%) blur(16px); border:1px solid #e8eef6; border-radius:24px; box-shadow:0 10px 30px rgba(30,41,59,.08)}
  .head{display:flex; align-items:center; justify-content:space-between; padding:22px 26px 6px}
  h1{margin:0; font-size:32px}
  .pill{background:#bb1457;color:#fff;border-radius:999px;padding:8px 14px;font-weight:700}
  .body{display:grid; grid-template-columns:1fr 1fr; gap:22px; padding:18px 22px 26px}
  .panel{border:1px solid var(--b); border-radius:18px; padding:18px; background:rgba(255,255,255,.7)}
  .g{display:grid; grid-template-columns:repeat(3,1fr); gap:18px}
  .ring{aspect-ratio:1/1;border-radius:999px;display:grid;place-items:center;background:radial-gradient(circle at 50% 55%, #fff, #f5f6f8)}
  .ring h3{margin:0;font-size:14px;color:var(--sub);font-weight:600}
  .ring b{display:block;font-size:24px;margin-top:6px}
  .chips{display:flex; flex-wrap:wrap; gap:10px; margin:6px 0 14px}
  .chip{display:inline-flex;align-items:center;gap:8px;border-radius:999px;padding:8px 12px;background:var(--chip);border:1px solid var(--b);font-weight:600}
  .dot{width:10px;height:10px;border-radius:999px;display:inline-block}
  .cols{display:grid;grid-template-columns:1fr 1fr;gap:14px}
  .muted{color:var(--sub)}
  .k{border-top:1px dashed var(--b);margin-top:10px;padding-top:10px}
  .note{background:#f6f9fc;border:1px solid var(--b);border-radius:12px;padding:10px 12px}
  .footer{padding:0 26px 22px;color:#9aa6b2;font-size:12px;text-align:right}
</style>
</head>
<body>
<div class="wrap">
  <div class="card">
    <div class="head">
      <div>
        <h1>Morning State</h1>
        <div class="muted">$([System.DateTime]::Parse($ts.ToString()).ToString('dddd, MMM d h:mm tt'))</div>
      </div>
      <div class="pill">$($shift.Substring(0,1).ToUpper()+$shift.Substring(1))</div>
    </div>
    <div class="body">
      <div class="panel">
        <div class="g">
          <div class="ring"><div><h3>Mood</h3><b>$mood/10</b></div></div>
          <div class="ring"><div><h3>Energy</h3><b>$energy/10</b></div></div>
          <div class="ring"><div><h3>Focus</h3><b>$focus/10</b></div></div>
        </div>
        $(if($note -ne ""){ "<div class='k'><div class='note'><b>Note:</b> $(HtmlEncode $note)</div></div>" })
        $(if($diaryText -ne ""){ "<div class='k'><div class='note'><b>Dear Diary:</b> $(HtmlEncode $diaryText)</div></div>" })
        $(if($journalText -ne ""){ "<div class='k'><div class='note'><b>Journal:</b> $(HtmlEncode $journalText)</div></div>" })
      </div>
      <div class="panel">
        <div class="muted" style="font-weight:700;margin-bottom:8px">Chakra focus</div>
        <div class="chips">
          $(
            $chipHtml = ""
            foreach($c in $chakras){
              $lab = if($chakraLabels.ContainsKey($c)){$chakraLabels[$c]}else{$c}
              $col = if($chakraColors.ContainsKey($c)){$chakraColors[$c]}else{"#888"}
              $chipHtml += "<span class='chip'><span class='dot' style='background:$col'></span> $lab</span>"
            }
            $chipHtml
          )
        </div>
        <div class="muted" style="font-weight:700;margin:14px 0 6px">Support areas</div>
        <div class="cols">
          <div>
            <div>$($chakraLabels.root)</div>
            <div>$($chakraLabels.solar_plexus)</div>
            <div>$($chakraLabels.throat)</div>
            <div>$($chakraLabels.crown)</div>
          </div>
          <div>
            <div>$($chakraLabels.sacral)</div>
            <div>$($chakraLabels.heart)</div>
            <div>$($chakraLabels.third_eye)</div>
          </div>
        </div>
      </div>
    </div>
    <div class="footer">AuraFlow visual card</div>
  </div>
</div>
<script>
  // future: animate rings/bars if you like
</script>
</body>
</html>
"@

Set-Content -Path $out -Value $html -Encoding UTF8
Start-Process $out
