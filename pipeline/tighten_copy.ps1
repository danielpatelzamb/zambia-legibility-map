# tighten_copy.ps1
# Removes em/en dashes from user-facing copy and reports paragraphs that are still too long.
#
# A blind replace to ", " reads badly, so the rules are contextual: an em dash followed by a
# capital becomes a full stop (the aside was really a new sentence), one followed by lowercase
# becomes a comma or colon depending on what follows. En dashes inside numeric ranges become
# plain hyphens, which is what they should have been.
#
# Run with -WhatIf to see counts without writing.
param([switch]$WhatIf)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$u = New-Object System.Text.UTF8Encoding($false)
$EM = [char]0x2014
$EN = [char]0x2013

# Markup and app logic, plus the generated data layer and the CSVs the builders read from.
# Sweeping only the source files is not enough: most of the dashes that reach the screen come
# from descriptions inside data/*.js, and those are regenerated from dataset/*.csv, so both
# have to be cleaned or the dashes return on the next build.
$files = @(
    (Join-Path $root 'index.html'),
    (Join-Path $root 'app.js')
) + @(Get-ChildItem (Join-Path $root 'data') -Filter *.js | ForEach-Object { $_.FullName }) +
  @(Get-ChildItem (Join-Path $root 'dataset') -Filter *.csv | ForEach-Object { $_.FullName }) +
  @(Get-ChildItem (Join-Path $root 'research') -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
$report = @()

foreach ($f in $files) {
    $t = [IO.File]::ReadAllText($f, $u)
    $before = ([regex]::Matches($t, "$EM|$EN|&mdash;|&ndash;")).Count

    # normalise the HTML entities first so one set of rules covers both spellings
    $t = $t -replace '&mdash;', $EM
    $t = $t -replace '&ndash;', $EN

    # 1. numeric and date ranges: en dash (and em dash between digits) becomes a hyphen
    $t = [regex]::Replace($t, "(?<=\d)\s?[$EM$EN]\s?(?=\d)", '-')
    # 2. a bare en dash used as a placeholder in a table cell becomes a simple dash
    $t = [regex]::Replace($t, ">\s*$EN\s*<", '>-<')

    # 3. em dash before a capital letter or a digit: the clause stands alone, so end the sentence
    $t = [regex]::Replace($t, "\s*$EM\s+(?=[A-Z0-9])", '. ')
    # 4. em dash before "the/a/an/which/and/but/so/because/not/no": reads as a comma
    $t = [regex]::Replace($t, "\s*$EM\s+(?=(the|a|an|which|and|but|so|because|not|no|it|they|you|that|most|every|all|one|two|three|four|five|six|seven|eight|nine|ten)\b)", ', ')
    # 5. anything else: a colon, which is what an explanatory em dash usually means
    $t = [regex]::Replace($t, "\s*$EM\s*", ': ')
    # 6. any remaining en dash between words becomes a comma
    $t = [regex]::Replace($t, "\s*$EN\s+", ', ')
    $t = [regex]::Replace($t, "\s*$EN\s*", '-')

    # tidy artefacts the rules can create
    $t = $t -replace '\.\s*\.\s', '. '
    $t = $t -replace ',\s*,', ','
    $t = $t -replace ':\s*:', ':'
    $t = $t -replace '\s+([.,:;])', '$1'
    $t = $t -replace '([(\[])\s*:\s*', '$1'

    $after = ([regex]::Matches($t, "$EM|$EN|&mdash;|&ndash;")).Count
    if ($before -gt 0) {
        $report += [pscustomobject]@{ file = (Split-Path $f -Leaf); before = $before; after = $after }
    }
    if (-not $WhatIf -and $before -gt 0) { [IO.File]::WriteAllText($f, $t, $u) }
}

$report | Format-Table -AutoSize | Out-String -Width 80 | Write-Host
Write-Host ("files changed: {0} | dashes removed: {1}" -f @($report).Count,
    (($report | Measure-Object before -Sum).Sum - ($report | Measure-Object after -Sum).Sum))

# ---- report long paragraphs so they can be rewritten by hand ----
# There is no automatic fix for a 700-character paragraph; it has to be cut. This just lists them.
$html = [IO.File]::ReadAllText((Join-Path $root 'index.html'), $u)
$long = [regex]::Matches($html, '(?s)<p class="note"[^>]*>(.*?)</p>') |
    ForEach-Object {
        $txt = (($_.Groups[1].Value -replace '<[^>]+>', '') -replace '\s+', ' ').Trim()
        [pscustomobject]@{ chars = $txt.Length; text = $txt }
    } | Where-Object { $_.chars -gt 260 } | Sort-Object chars -Descending

Write-Host ("paragraphs still over 260 characters: {0}" -f @($long).Count)
$long | Select-Object -First 20 | ForEach-Object {
    Write-Host ("  {0,4}  {1}" -f $_.chars, $_.text.Substring(0, [Math]::Min(88, $_.text.Length)))
}
