# parse_zra_clearing_agents.ps1
# Parses the ZRA "Licensed Clearing Agents Schedule as at 31.05.2024" into two outputs:
#   private/dataset/clearing_agents.csv  - full record incl. phone, email, TPIN, address
#   dataset/clearing_agents_public.csv   - name, town, licence type, expiry ONLY
#
# Customs clearing is the single hardest link in a Zambian export chain to source, and this
# list is the authoritative register of who may lawfully do it. ZRA publishes it, so the
# contacts are public business details - but they still go to private/ under the project's
# standing rule that no contact value enters a tracked file, because the app is deployed
# publicly and view-source would expose anything shipped in data/.
#
# Extraction: pdftotext -table (NOT -layout). The 2024 schedule is one row per agent with
# clean column alignment; -layout interleaves the columns and mis-associates emails with the
# wrong company. Verified by checking how often the email's local part shares a token with
# the company name - reported at the end as an alignment score.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sc   = "C:\Users\-\AppData\Local\Temp\claude\C--Users---Downloads-Mining-project\e9498ec4-84af-4c22-b594-6598d752d74b\scratchpad\supply"
$src  = Join-Path $sc 'zra2024.txt'
$utf8 = New-Object System.Text.UTF8Encoding($false)
if (-not (Test-Path $src)) { throw "missing $src - run pdftotext -table on the ZRA schedule first" }

# Zambian towns, longest-first so "NAKONDE" doesn't win inside a longer name and
# so multi-word towns match before their first word does.
$TOWNS = @('KAPIRI MPOSHI','LIVINGSTONE','CHILILABOMBWE','CHINGOLA','CHAMBISHI','KALULUSHI',
  'MUFULIRA','LUANSHYA','SOLWEZI','KASUMBALESA','NAKONDE','CHIRUNDU','KAZUNGULA','KATIMA',
  'SESHEKE','MONGU','KAOMA','MUMBWA','KABWE','MPIKA','KASAMA','MBALA','MPULUNGU','MANSA',
  'SAMFYA','SERENJE','MKUSHI','CHIPATA','KATETE','PETAUKE','LUNDAZI','CHOMA','MAZABUKA',
  'MONZE','KALOMO','SIAVONGA','SINAZONGWE','KAFUE','CHONGWE','CHISAMBA','CHILANGA',
  'NDOLA','KITWE','LUSAKA') | Sort-Object { -$_.Length }

$rows = New-Object System.Collections.Generic.List[object]
$cur  = $null
foreach ($line in [System.IO.File]::ReadAllLines($src)) {
    if ($line -notmatch '\S') { continue }
    if ($line -match 'LICENSED\s+CLEARING|AS AT |^\s*S/N\b') { continue }

    # A new record starts with a serial number followed by a 10-digit TPIN.
    if ($line -match '^\s*(\d{1,5})\s+(\d{9,11})\s+(.+)$') {
        if ($cur) { $rows.Add($cur) }
        $sn = $Matches[1]; $tpin = $Matches[2]; $rest = $Matches[3]

        $email = ([regex]::Match($rest, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')).Value
        # Mobiles are 09x/07x/06x but plenty of agents list a LANDLINE (021x, 0212...), which a
        # mobile-only pattern silently drops - and a dropped phone then stayed inside the name.
        $phones = @([regex]::Matches($rest, '\b\+?260[0-9]{9}\b|\b0[0-9]{9}\b') |
                    ForEach-Object { $_.Value } | Select-Object -Unique)
        $expiry = ([regex]::Match($rest, '\b\d{2}\.\d{2}\.\d{4}\b')).Value

        # licence type is a controlled vocabulary in this schedule
        $lic = if ($rest -match 'FULL\s+LICEN[CS]E') { 'Full licence' }
               elseif ($rest -match 'FINAL\s+CLEARANCE\s*\+?\s*RIT') { 'Final clearance + RIT' }
               elseif ($rest -match 'REMOVAL\s+IN\s+TRANSIT|RIT\s+ONLY') { 'RIT only' }
               elseif ($rest -match 'FINAL\s+CLEARANCE') { 'Final clearance only' }
               else { $null }

        # Company name is everything before the licence-type/phone/email block. Cut at the
        # EARLIEST of every possible boundary, not the first pattern that happens to match:
        # the source contains typos ("CLEARNACE"), so anchoring on a single exact spelling let
        # one row absorb its own phone and email into the company name.
        $name = $rest
        $cutAt = $name.Length
        foreach ($cut in 'FULL\s+LICEN', 'FINAL\s+CLEAR', 'REMOVAL\s+IN\s+TRANSIT', '\bRIT\b',
                         '\bCLEAR(ANCE|NACE|ENCE)\b', '\b\+?260[0-9]{9}\b', '\b0[0-9]{9}\b',
                         '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}') {
            $m = [regex]::Match($name, $cut)
            if ($m.Success -and $m.Index -lt $cutAt) { $cutAt = $m.Index }
        }
        $name = $name.Substring(0, $cutAt)
        # The PDF hyphenates across its own line wraps ("LIMIT- ED"), and the licence-type
        # column bleeds its tail words into the name ("... LIMITED ONLY", "... RIT ONLY").
        # Both are cosmetic in the source but would corrupt any name-based join downstream.
        $name = ($name -replace '(?<=[A-Z])-\s+(?=[A-Z])', '')
        $name = ($name -replace '\s{2,}', ' ').Trim()
        $name = ($name -replace '\s+(RIT\s+)?ONLY$', '').Trim()
        $name = ($name -replace '\s+(FINAL|FULL|REMOVAL|CLEARANCE|LICENCE|LICENSE|RIT)$', '').Trim()

        # Address: the run of text after the email (or after the phone if no email),
        # up to the expiry date.
        $addr = $null
        $anchor = if ($email) { $email } elseif ($phones.Count) { $phones[0] } else { $null }
        if ($anchor) {
            $i = $rest.IndexOf($anchor)
            if ($i -ge 0) {
                $addr = $rest.Substring($i + $anchor.Length)
                if ($expiry) { $addr = ($addr -replace [regex]::Escape($expiry), '') }
                $addr = ($addr -replace '\s{2,}', ' ').Trim()
            }
        }

        $cur = [pscustomobject]@{
            sn = $sn; tpin = $tpin; name = $name; licence_type = $lic
            phone = ($phones -join ' / '); email = $email.ToLower()
            address = $addr; expiry = $expiry; town = $null
        }
        continue
    }

    # Continuation line: only the company name and address wrap. Anything with an @ or a
    # phone on a continuation line belongs to the record above.
    if ($cur) {
        $t = ($line -replace '\s{2,}', ' ').Trim()
        if ($t -match '^[A-Z0-9 &.,\-/()'']+$' -and $t.Length -lt 60 -and $t -notmatch '@') {
            # heuristically a name tail if the current name looks truncated (no legal suffix yet)
            if ($cur.name -notmatch '\b(LIMITED|LTD|PLC|COMPANY|ENTERPRISES|SERVICES|AGENCY|CORPORATION|ZONE)\b') {
                $n = ($cur.name + ' ' + $t)
                $n = ($n -replace '(?<=[A-Z])-\s+(?=[A-Z])', '') -replace '\s{2,}', ' '
                $cur.name = ($n -replace '\s+(RIT\s+)?ONLY$', '').Trim()
            } elseif ($cur.address) {
                $cur.address = ($cur.address + ' ' + $t).Trim()
            }
        }
    }
}
if ($cur) { $rows.Add($cur) }

# derive town from the address
foreach ($r in $rows) {
    if (-not $r.address) { continue }
    $a = $r.address.ToUpper()
    foreach ($t in $TOWNS) { if ($a -match [regex]::Escape($t)) { $r.town = $t; break } }
}

$rows = @($rows | Where-Object { $_.name -and $_.name.Length -ge 4 })
Write-Host ("parsed {0} licensed clearing agents" -f $rows.Count)
Write-Host ("  with phone: {0} | email: {1} | address: {2} | town resolved: {3} | licence type: {4}" -f `
    @($rows | Where-Object phone).Count, @($rows | Where-Object email).Count,
    @($rows | Where-Object address).Count, @($rows | Where-Object town).Count,
    @($rows | Where-Object licence_type).Count)

# ---- alignment check: does the email's local part share a token with the company name? ----
# This is the guard against silently mis-associating a contact with the wrong company, which
# is what -layout extraction does. A high score means the row assembly is trustworthy.
$checked = 0; $agree = 0
foreach ($r in $rows) {
    if (-not $r.email) { continue }
    $local = ($r.email -split '@')[0] -replace '[^a-z0-9]', ''
    if ($local.Length -lt 4) { continue }
    $checked++
    $toks = @($r.name.ToUpper() -split '[^A-Z0-9]+' |
              Where-Object { $_.Length -ge 4 -and $_ -notin 'LIMITED','ZAMBIA','COMPANY','SERVICES','GENERAL','TRADING' })
    foreach ($tk in $toks) { if ($local -like ('*' + $tk.ToLower() + '*')) { $agree++; break } }
}
$score = if ($checked) { [math]::Round(100 * $agree / $checked, 1) } else { 0 }
Write-Host ("`nALIGNMENT CHECK: {0}% of checkable emails share a distinctive token with their company name ({1}/{2})" -f $score, $agree, $checked)
Write-Host "  (generic mailboxes like firstname@gmail.com legitimately do not match, so this is a floor, not a ceiling)"

# ---- write private (full) ----
$privDir = Join-Path $root 'private\dataset'
New-Item -ItemType Directory -Force -Path $privDir | Out-Null
$rows | Select-Object name, licence_type, town, phone, email, address, tpin, expiry, sn |
    Sort-Object name | Export-Csv (Join-Path $privDir 'clearing_agents.csv') -NoTypeInformation -Encoding UTF8

# ---- write public (identity + location only, no contact value, no TPIN) ----
$rows | Select-Object name, licence_type, town, expiry |
    Sort-Object name | Export-Csv (Join-Path $root 'dataset\clearing_agents_public.csv') -NoTypeInformation -Encoding UTF8

Write-Host ("`nwrote private\dataset\clearing_agents.csv  ({0} rows, with contacts)" -f $rows.Count)
Write-Host ("wrote dataset\clearing_agents_public.csv   ({0} rows, no contact values)" -f $rows.Count)
Write-Host "`ntop towns:"
$rows | Where-Object town | Group-Object town | Sort-Object Count -Descending | Select-Object -First 12 |
    ForEach-Object { Write-Host ("  {0,5}  {1}" -f $_.Count, $_.Name) }
Write-Host "`nlicence types:"
$rows | Group-Object licence_type | Sort-Object Count -Descending |
    ForEach-Object { Write-Host ("  {0,5}  {1}" -f $_.Count, ($_.Name -replace '^$','(unparsed)')) }
