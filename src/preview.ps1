$root = Get-Location
$dir  = Join-Path $root 'logs'
if (-not (Test-Path $dir)) { throw "No logs directory at $dir." }

$days = 7
$records = @()
for ($i=0; $i -lt $days; $i++) {
  $d = (Get-Date).AddDays(-$i).ToString('yyyy-MM-dd')
  $path = Join-Path $dir ("engine-{0}.log" -f $d)
  if (Test-Path $path) {
    $line = Get-Content $path | Select-Object -Last 1 | ConvertFrom-Json
    if ($line) { $records += $line }
  }
}
$records = $records | Sort-Object { $_.ts }

if ($records.Count -eq 0) { throw "No recent records to preview." }

$m = ($records | ForEach-Object { $_.mood })   -join ','
$e = ($records | ForEach-Object { $_.energy }) -join ','
$f = ($records | ForEach-Object { $_.focus })  -join ','
$labels = ($records | ForEach-Object { (Get-Date $_.ts).ToString('MM-dd') }) -join '","'

$out = Join-Path $root "preview.html"
@"
<!doctype html><meta charset="utf-8"><title>AuraFlow Preview</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>body{font-family:Segoe UI,system-ui,Arial;padding:24px;color:#222} .wrap{max-width:900px;margin:0 auto}</style>
<div class="wrap">
<h1>AuraFlow  Last 7 Days</h1>
<canvas id="chart" height="120"></canvas>
<script>
const labels=["$labels"];
const mood=[$m], energy=[$e], focus=[$f];
new Chart(document.getElementById('chart'), {
  type:"line",
  data:{labels,
    datasets:[
      {label:"Mood", data:mood, tension:.3},
      {label:"Energy", data:energy, tension:.3},
      {label:"Focus", data:focus, tension:.3}
    ]
  },
  options:{responsive:true, scales:{y:{beginAtZero:true, max:10}}}
});
</script>
</div>
"@ | Set-Content -Path $out -Encoding UTF8

Write-Host "Saved preview  $out"
Start-Process $out
