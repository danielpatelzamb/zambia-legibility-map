# watch_court_scrape.ps1 — follows the ZambiaLII scrape checkpoint, rebuilding
# data\kyc_court.js every ~10 minutes while it grows, and a final time once the
# checkpoint has been stable for 5 minutes. Exits after max 4 hours.
$ErrorActionPreference = 'Continue'
$root  = Split-Path -Parent $PSScriptRoot
$src   = Join-Path $root 'data\gov\court\court_hits.json'
$build = Join-Path $root 'pipeline\build_kyc_court.ps1'
$last = 0; $stable = 0
for ($i = 0; $i -lt 240; $i++) {
    Start-Sleep -Seconds 60
    try {
        $j = Get-Content $src -Raw | ConvertFrom-Json
        $n = @($j.names.PSObject.Properties).Count
    } catch { continue }
    if ($n -eq $last) { $stable++ } else { $stable = 0; $last = $n }
    if ($i % 10 -eq 9 -and $stable -lt 5) {
        & powershell -ExecutionPolicy Bypass -File $build | Out-Null
        Write-Host "interim rebuild at $n names (check $i)"
    }
    if ($stable -ge 5) { break }
}
& powershell -ExecutionPolicy Bypass -File $build
Write-Host "final rebuild done at $last names"
