param([string]$Date = (Get-Date -Format "yyyy-MM-dd"))

$root = Get-Location
$log  = Join-Path $root ("logs\engine-{0}.log" -f $Date)
if (-not (Test-Path $log)) { throw "No log for $Date at $log" }

$entry = Get-Content $log | Select-Object -Last 1 | ConvertFrom-Json
if (-not $entry) { throw "No entries in $log" }

function Normalize-Text([string]$text){
  if (-not $text) { return "" }
  $text = [regex]::Replace($text, '\p{Zs}', ' ')
  $pair = [regex]::Matches($text,'(?<=\p{L})\s(?=\p{L})').Count
  if($pair -ge 10){ $text = [regex]::Replace($text,'(?<=\p{L})\s(?=\p{L})','') }
  $text = $text -replace '\s{2,}',' '
  return $text.Trim()
}

$shift    = Normalize-Text $entry.shift
$note     = Normalize-Text $entry.note
$practice = Normalize-Text ($entry.sample ?? $entry.content_text)
$mood     = [int]$entry.mood
$energy   = [int]$entry.energy
$focus    = [int]$entry.focus
$chakras  = ($entry.chakra ?? "") -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }

$shiftNames = @{ grounded="Grounded"; compassion="Compassion"; clarity="Clarity"; courage="Courage"; release="Release" }
$shiftTitle = ($shiftNames[$shift] ?? ($shift.Substring(0,1).ToUpper()+$shift.Substring(1)))

$chakraLabels = @{
  root="Root (Muladhara)"; sacral="Sacral (Svadhisthana)"; solar_plexus="Solar Plexus (Manipura)";
  heart="Heart (Anahata)"; throat="Throat (Vishuddha)"; third_eye="Third Eye (Ajna)"; crown="Crown (Sahasrara)"
}
$chakraColors = @{
  root="#E53935"; sacral="#FB8C00"; solar_plexus="#FDD835";
  heart="#43A047"; throat="#1E88E5"; third_eye="#5E35B1"; crown="#8E24AA"
}

$theme = @{
  grounded   = @{ bg1="#b9f5d0"; bg2="#effdf5"; accent="#2e7d32" }
  compassion = @{ bg1="#ffddea"; bg2="#fff3f7"; accent="#ad1457" }
  clarity    = @{ bg1="#daeeff"; bg2="#f3f9ff"; accent="#1565c0" }
  courage    = @{ bg1="#fff1cc"; bg2="#fff8e1"; accent="#ef6c00" }
  release    = @{ bg1="#efefef"; bg2="#fafafa"; accent="#424242" }
}
$tk = ($theme.Keys -contains $shift) ? $shift : "clarity"
$bg1 = $theme[$tk].bg1; $bg2 = $theme[$tk].bg2; $accent = $theme[$tk].accent

$chips = ""
foreach($c in $chakras){
  $lab = ($chakraLabels[$c] ?? $c)
  $col = ($chakraColors[$c] ?? "#888")
  $chips += "<span class='chip' style='--chip:$col'><span class='dot'></span>$lab</span>"
}

$outDir  = Join-Path $root "cards"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$ts      = Get-Date -Format "yyyyMMdd-HHmmss"
$outFile = Join-Path $outDir ("auraflow-card-{0}.html" -f $ts)

@"
<!doctype html>
<html lang="en">
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AuraFlow  Morning Card</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
<style>
  :root{
    --bg1:$bg1; --bg2:$bg2; --accent:$accent;
    --ink:#0b1220; --muted:#6b7280; --panel:rgba(255,255,255,0.82); --stroke:rgba(255,255,255,0.50);
  }
  *{box-sizing:border-box}
  body{
    margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
    font-family:Inter, system-ui, -apple-system, Segoe UI, Roboto, Arial; color:var(--ink);
    background: radial-gradient(1200px 600px at 20% 10%, var(--bg1), transparent 60%),
                radial-gradient(1000px 600px at 80% 90%, var(--bg2), transparent 55%),
                linear-gradient(160deg, #f8fafc 0%, #eef2f7 100%);
    animation: floatBg 14s ease-in-out infinite alternate;
    padding: 28px;
  }
  @keyframes floatBg { from{background-position:0 0,0 0,0 0} to{background-position:20px -20px,-30px 15px,0 0} }

  .card{
    backdrop-filter: blur(10px);
    background: var(--panel);
    border:1px solid var(--stroke);
    border-radius: 20px;
    box-shadow: 0 20px 50px rgba(0,0,0,.12), 0 6px 18px rgba(0,0,0,.06);
    width:min(880px, 96vw); padding:28px;
    transform: perspective(1000px) translateZ(0);
    transition: transform .2s ease, box-shadow .2s ease;
  }
  .card:hover{ transform: perspective(1000px) translateZ(6px); box-shadow: 0 24px 60px rgba(0,0,0,.16), 0 8px 22px rgba(0,0,0,.08) }

  .header{ display:flex; align-items:center; justify-content:space-between; gap:16px; margin-bottom:8px }
  .title{ font-weight:800; font-size:28px; letter-spacing:.2px }
  .badge{ background:var(--accent); color:#fff; padding:6px 12px; border-radius:999px; font-weight:700; font-size:12px }
  .sub{ color:var(--muted); font-size:13px; margin-bottom:18px }

  .grid{ display:grid; grid-template-columns: 1.1fr .9fr; gap:18px }
  @media (max-width: 860px){ .grid{ grid-template-columns: 1fr } }

  .box{ background:rgba(255,255,255,.94); border:1px solid #e9edf2; border-radius:16px; padding:16px }

  .gauges{ display:flex; gap:18px; flex-wrap:wrap }
  .g{ display:grid; place-items:center; width:140px; aspect-ratio:1; position:relative }
  .ring{ width:100%; height:100%; border-radius:50%;
         background: conic-gradient(var(--accent) calc(var(--val)*1%), #e6edf5 0),
                     radial-gradient(circle 52% at 50% 50%, #fff 68%, transparent 69%);
         box-shadow: inset 0 2px 12px rgba(0,0,0,.08); }
  .label{ position:absolute; text-align:center }
  .label .k{ font-size:12px; color:var(--muted) }
  .label .v{ font-weight:800; font-size:22px }

  .chips{ display:flex; flex-wrap:wrap; gap:10px }
  .chip{ display:inline-flex; align-items:center; gap:8px; background:#fff; border:1px solid #eef1f5; padding:6px 12px; border-radius:999px; font-size:12px }
  .chip .dot{ width:8px; height:8px; border-radius:50%; background:var(--chip,#888) }

  .practice{ margin-top:12px; background:linear-gradient(180deg,#fafcfe 0%,#f6f8fb 100%); border:1px dashed #e3e7ee; border-radius:12px; padding:14px 16px; line-height:1.55; font-size:16px }
  .note{ background:#fafafa; border:1px solid #eee; border-radius:12px; padding:10px 12px; font-size:13px; color:#334155; margin-top:12px }

  .support{ margin-top:14px; display:grid; grid-template-columns:repeat(2,1fr); gap:10px }
  @media (max-width: 860px){ .support{ grid-template-columns:1fr } }
  .row{ display:flex; align-items:center; gap:10px }
  .row .k{ min-width:170px; color:#475569; font-size:12px }
  .bar{ flex:1; height:8px; background:#eef2f7; border-radius:999px; overflow:hidden }
  .fill{ height:100%; background:var(--accent); width:0% }

  .footer{ margin-top:16px; color:#9aa3ad; font-size:12px; text-align:right }
</style>

<div class="card" id="card">
  <div class="header">
    <div class="title">Morning State</div>
    <div class="badge">$shiftTitle</div>
  </div>
  <div class="sub">$([DateTime]::Parse($entry.ts).ToString("dddd, MMM d  h:mm tt"))</div>

  <div class="grid">
    <div class="box">
      <div class="gauges">
        <div class="g" style="--val:$([int]$mood*10)"><div class="ring"></div><div class="label"><div class="k">Mood</div><div class="v">$mood/10</div></div></div>
        <div class="g" style="--val:$([int]$energy*10)"><div class="ring"></div><div class="label"><div class="k">Energy</div><div class="v">$energy/10</div></div></div>
        <div class="g" style="--val:$([int]$focus*10)"><div class="ring"></div><div class="label"><div class="k">Focus</div><div class="v">$focus/10</div></div></div>
      </div>

      @(if ("$note" -ne "") { "<div class='note'><b>Note:</b> $note</div>" })
      <div class="practice">$practice</div>
    </div>

    <div class="box">
      <div style="font-weight:700; margin-bottom:8px">Chakra focus</div>
      <div class="chips">$chips</div>

      <div style="margin-top:16px; font-weight:700; margin-bottom:6px">Support areas</div>
      <div class="support" id="supportRows"></div>
    </div>
  </div>

  <div class="footer">AuraFlow  visual preview card</div>
</div>

<script>
  const support = {
    root:       $([math]::Round([double]($entry.support.root    ?? 0),3)),
    sacral:     $([math]::Round([double]($entry.support.sacral  ?? 0),3)),
    solar_plexus:$([math]::Round([double]($entry.support.solar_plexus ?? 0),3)),
    heart:      $([math]::Round([double]($entry.support.heart   ?? 0),3)),
    throat:     $([math]::Round([double]($entry.support.throat  ?? 0),3)),
    third_eye:  $([math]::Round([double]($entry.support.third_eye ?? 0),3)),
    crown:      $([math]::Round([double]($entry.support.crown   ?? 0),3))
  };
  const labels = {
    root:"Root (Muladhara)", sacral:"Sacral (Svadhisthana)", solar_plexus:"Solar Plexus (Manipura)",
    heart:"Heart (Anahata)", throat:"Throat (Vishuddha)", third_eye:"Third Eye (Ajna)", crown:"Crown (Sahasrara)"
  };
  const container = document.getElementById('supportRows');
  const order = ["root","sacral","solar_plexus","heart","throat","third_eye","crown"];
  order.forEach(k=>{
    const row = document.createElement('div'); row.className='row';
    const kdiv = document.createElement('div'); kdiv.className='k'; kdiv.textContent = labels[k] || k;
    const bar  = document.createElement('div'); bar.className='bar';
    const fill = document.createElement('div'); fill.className='fill';
    bar.appendChild(fill); row.append(kdiv,bar); container.appendChild(row);
    requestAnimationFrame(()=>{ fill.style.width = Math.min(100, Math.max(0, support[k]*100)) + "%"; });
  });
</script>
"@ | Set-Content -Path $outFile -Encoding UTF8

# Robust auto-open (PowerShell + cmd fallback)
if (Test-Path $outFile) {
  try { Start-Process $outFile } catch { cmd /c start "" "$outFile" }
}
Write-Host "Saved card  $outFile"
