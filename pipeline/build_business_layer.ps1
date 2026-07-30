# build_business_layer.ps1
# Builds dataset/mining_businesses.csv (public-safe) and data/business_data.js -> window.BIZ
# from the private business directories.
#
# PRIVACY: the private directories carry a `contact` object per company. NOTHING from that object
# is written here. The public artefacts get identity and business facts only - name, segment, what
# they do, town/province, ownership, scale, registry status. That is the publishable part; the
# phone numbers stay in private/.
#
# Towns are resolved to coordinates from a small hand-checked table of Zambian mining towns, so the
# map can plot a business at TOWN level. These are town centroids, NOT company addresses - the
# layer says so, and anything without a town simply is not plotted.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$pr   = Join-Path $root 'private\research'
$outCsv = Join-Path $root 'dataset\mining_businesses.csv'
$outJs  = Join-Path $root 'data\business_data.js'

# Town centroids (lat, lng). Hand-checked against the existing licence centroids in the register.
$TOWNS = @{
    'Lusaka'        = @(-15.4167, 28.2833); 'Kitwe'        = @(-12.8024, 28.2132)
    'Ndola'         = @(-12.9587, 28.6366); 'Chingola'     = @(-12.5288, 27.8492)
    'Mufulira'      = @(-12.5500, 28.2400); 'Kalulushi'    = @(-12.8333, 28.1000)
    'Luanshya'      = @(-13.1367, 28.4166); 'Chililabombwe'= @(-12.3667, 27.8333)
    'Chambishi'     = @(-12.6500, 28.0500); 'Kabwe'        = @(-14.4469, 28.4464)
    'Livingstone'   = @(-17.8419, 25.8543); 'Solwezi'      = @(-12.1688, 26.3894)
    'Kalumbila'     = @(-12.2500, 25.3500); 'Mumbwa'       = @(-14.9833, 27.0667)
    'Chipata'       = @(-13.6333, 32.6500); 'Kasama'       = @(-10.2129, 31.1808)
    'Mansa'         = @(-11.1996, 28.8940); 'Mongu'        = @(-15.2500, 23.1333)
    'Choma'         = @(-16.8000, 26.9833); 'Kafue'        = @(-15.7690, 28.1814)
    'Chibombo'      = @(-14.6572, 28.0705); 'Mazabuka'     = @(-15.8569, 27.7497)
    'Mpongwe'       = @(-13.5167, 28.1500); 'Mapatizya'    = @(-16.8667, 26.0833)
    'Sinazongwe'    = @(-17.2667, 27.4667); 'Serenje'      = @(-13.2333, 30.2333)
    'Mkushi'        = @(-13.6167, 29.4000); 'Petauke'      = @(-14.2500, 31.3167)
    'Kawambwa'      = @(-9.7833, 29.0833);  'Samfya'       = @(-11.3667, 29.5500)
    'Mpika'         = @(-11.8333, 31.4500); 'Chongwe'      = @(-15.3333, 28.6833)
    'Mwinilunga'    = @(-11.7333, 24.4333); 'Kalomo'       = @(-17.0333, 26.4833)
    'Kasempa'       = @(-13.4500, 25.8333); 'Lufwanyama'   = @(-13.0333, 27.6000)
    'Ndola Rural'   = @(-13.0000, 28.5000); 'Chinsali'     = @(-10.5500, 32.0667)
}

$rows = @()
foreach ($f in @('biz_traders_processors.json','biz_services_supply.json')) {
    $p = Join-Path $pr $f
    if (-not (Test-Path $p)) { Write-Warning "missing $f"; continue }
    foreach ($b in (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        $town = if ($b.town) { ($b.town -split ',')[0].Trim() } else { $null }
        $ll = if ($town -and $TOWNS.ContainsKey($town)) { $TOWNS[$town] } else { $null }
        $rows += [pscustomobject]@{
            name            = $b.name
            segment         = $b.segment
            what_they_do    = $b.what_they_do
            town            = $town
            district        = $b.district
            province        = $b.province
            ownership       = $b.ownership
            parent          = $b.parent
            scale           = $b.scale
            pacra_number    = $b.pacra_number
            pacra_status    = $b.pacra_status
            isic            = $b.isic
            ncc_grade       = $b.ncc_grade
            officeholder    = $b.officeholder      # name + title in official capacity only
            confidence      = $b.confidence
            evidence        = if ($b.confidence -eq 'high') { 'non-registry source evidences operations' }
                              else { 'registry record and/or indirect evidence only' }
            lat             = if ($ll) { $ll[0] } else { $null }
            lng             = if ($ll) { $ll[1] } else { $null }
            coord_basis     = if ($ll) { 'town centroid, not a company address' } else { $null }
            notes           = $b.notes
            sources         = if ($b.sources) { @($b.sources) -join ' | ' } else { $null }
        }
    }
}
# de-duplicate on name, keeping the better-evidenced record
$rows = @($rows | Group-Object { $_.name.ToUpper().Trim() } | ForEach-Object {
    ($_.Group | Sort-Object { if ($_.confidence -eq 'high') { 0 } else { 1 } } | Select-Object -First 1) })

$rows | Sort-Object segment, name | Export-Csv $outCsv -NoTypeInformation -Encoding UTF8

# browser layer: only the fields the app needs, no contact fields by construction
$mapped = @($rows | Where-Object { $_.lat } | ForEach-Object {
    [pscustomobject]@{ n=$_.name; s=$_.segment; w=$_.what_they_do; t=$_.town; pr=$_.province
                       o=$_.ownership; sc=$_.scale; pn=$_.pacra_number; ps=$_.pacra_status
                       c=$_.confidence; lat=$_.lat; lng=$_.lng } })
$bySeg = @(($rows | Group-Object segment) | ForEach-Object {
    [pscustomobject]@{ s=$_.Name; n=$_.Count
                       hi=@($_.Group | Where-Object confidence -eq 'high').Count
                       tw=@($_.Group | Where-Object { $_.town }).Count } } | Sort-Object { -$_.n })
$payload = [ordered]@{
    STATS = [ordered]@{
        total    = $rows.Count
        high     = @($rows | Where-Object confidence -eq 'high').Count
        located  = @($rows | Where-Object { $_.lat }).Count
        pacra    = @($rows | Where-Object { $_.pacra_number }).Count
        segments = $bySeg.Count
    }
    BY_SEGMENT = $bySeg
    MAPPED     = $mapped
    ALL        = @($rows | ForEach-Object {
        [pscustomobject]@{ n=$_.name; s=$_.segment; w=$_.what_they_do; t=$_.town; pr=$_.province
                           o=$_.ownership; sc=$_.scale; pn=$_.pacra_number; ps=$_.pacra_status
                           g=$_.ncc_grade; c=$_.confidence } })
}
$hdr = "/* business_data.js - generated by pipeline/build_business_layer.ps1. Do not hand-edit.`n" +
       "   Mining-adjacent businesses: traders, processors, services and supply. Identity and`n" +
       "   business facts only - contact details are held in private/ and never emitted here. */`n"
[System.IO.File]::WriteAllText($outJs, $hdr + "window.BIZ = " + ($payload | ConvertTo-Json -Depth 8 -Compress) + ";`n",
    (New-Object System.Text.UTF8Encoding($false)))

Write-Host ("wrote {0} ({1} rows)" -f $outCsv, $rows.Count)
Write-Host ("wrote {0} ({1:N0} KB)" -f $outJs, ((Get-Item $outJs).Length/1KB))
Write-Host ("  high confidence {0} | mappable {1} | PACRA-confirmed {2} | segments {3}" -f `
    $payload.STATS.high, $payload.STATS.located, $payload.STATS.pacra, $payload.STATS.segments)
$bySeg | ForEach-Object { Write-Host ("    {0,-22} {1,4}  (high {2,3}, located {3,3})" -f $_.s, $_.n, $_.hi, $_.tw) }
