# build_declared_business.ps1
# Builds dataset/declared_business_vs_licences.csv - the join between what the companies registry
# says a licence holder does for a living and what the licence register says it holds.
#
# Previously produced by an ad-hoc command, which meant it could not be regenerated. Now a
# first-class pipeline step. Run after fetch_pacra_registry.ps1.
#
# READ THIS BEFORE USING THE OUTPUT FOR A HEADLINE
# PACRA's ISIC line is a value captured on a registration form. It is NOT an audited statement of
# current activity, and for miners it is demonstrably unreliable:
#   Rio Tinto Exploration Zambia Limited -> "Construction of buildings"
#   Yetu Mining Limited                  -> "Radio broadcasting"
#   VS Construction & Mining Services    -> "Private security activities"
#   Willianda Investments Limited        -> "Processing and preserving of fruit and vegetables"
# The last one is the hard case: nothing in the name betrays the mismatch, so no automated test
# catches it. `name_contradicts_declaration` therefore measures a LOWER BOUND on the error rate.
# Any claim built on this table should be phrased as a statement about the REGISTRY
# ("the registry does not classify them as mining"), never about the company's own account of itself.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$ds   = Join-Path $root 'dataset'
$out  = Join-Path $ds 'declared_business_vs_licences.csv'

function Norm([string]$n) {
    if (-not $n) { return '' }
    $x = ($n.ToUpper() -replace '[^A-Z0-9 ]',' ') -replace '\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b',' '
    ($x -replace '\s+',' ').Trim()
}
# words that mean "this company describes itself as being in minerals"
$MINE_NAME = '\b(MINING|MINERAL|MINERALS|MINES|MINE|QUARR|QUARRY|GEMSTONE|GEMSTONES|EMERALD|EMERALDS|GOLD|COPPER|COBALT|MANGANESE|LITHIUM|GRAPHITE|SMELT|SMELTING|REFIN|REFINERY|EXPLORATION|GEOLOG|ORE|ORES|BULLION|LAPIDAR|AGGREGATE|AGGREGATES|LIMESTONE|CEMENT|STONE|METAL|METALS|ALLOY|ALLOYS)\b'
# ISIC text that counts as a mining-related declaration
$MINE_ISIC = 'mining|quarry|quarrying|mineral|ore|extraction|prospect|explor|metal|smelt|refin|gemstone|coal|petroleum'

$pac    = Import-Csv (Join-Path $ds 'pacra_registry.csv')
$roster = Import-Csv (Join-Path $root 'research\holder_roster_all.csv')
$rIdx = @{}; foreach ($r in $roster) { $rIdx[$r.holder] = $r }

$rows = foreach ($r in $pac) {
    if ($r.entity_status -eq 'NO_REGISTRY_MATCH' -or -not $r.nature_of_business) { continue }
    $nob = $r.nature_of_business
    $cls = if ($nob -like 'System.Object*') { 'UNRESOLVED_MULTI_MATCH' }
           elseif ($nob -match $MINE_ISIC)  { 'mining_related' }
           else                             { 'NOT_mining_related' }
    $x = $rIdx[$r.query_holder]
    [pscustomobject]@{
        holder            = $r.query_holder
        declared_business = if ($cls -eq 'UNRESOLVED_MULTI_MATCH') { $null } else { $nob }
        business_class    = $cls
        # lower bound on classification error - see the header note
        name_contradicts_declaration = if ($cls -eq 'NOT_mining_related' -and $r.query_holder -match $MINE_NAME) { 'yes' } else { 'no' }
        entity_number     = $r.entity_number
        registration_date = $r.registration_date
        hectares          = if ($x) { [int]$x.hectares } else { $null }
        licenses          = if ($x) { $x.licenses } else { $null }
        mining_lics       = if ($x) { $x.mining_lics } else { $null }
        main_commodities  = if ($x) { $x.main_commodities } else { $null }
        beneficial_owner_declared = $r.beneficial_owner_declared
        annual_return_filed       = $r.annual_return_filed
        lics_in_default_2025      = if ($x) { $x.lics_in_default_2025 } else { $null }
    }
}
$rows = @($rows)
$rows | Sort-Object business_class, { -[int]$_.hectares } | Export-Csv $out -NoTypeInformation -Encoding UTF8

$nm    = @($rows | Where-Object business_class -eq 'NOT_mining_related')
$mr    = @($rows | Where-Object business_class -eq 'mining_related')
$un    = @($rows | Where-Object business_class -eq 'UNRESOLVED_MULTI_MATCH')
$flag  = @($nm | Where-Object name_contradicts_declaration -eq 'yes')
$clean = @($nm | Where-Object name_contradicts_declaration -eq 'no')
$haAll   = ($nm + $mr | Measure-Object hectares -Sum).Sum
$haNM    = ($nm    | Measure-Object hectares -Sum).Sum
$haClean = ($clean | Measure-Object hectares -Sum).Sum

Write-Host ("wrote {0} ({1} rows)" -f $out, $rows.Count)
Write-Host ("  mining-related declaration      : {0}" -f $mr.Count)
Write-Host ("  NOT mining-related              : {0}" -f $nm.Count)
Write-Host ("  unresolved multi-match          : {0}  (excluded from every percentage)" -f $un.Count)
Write-Host ""
Write-Host ("  of the NOT-mining set, name contradicts the classification: {0} ({1}%)" -f `
    $flag.Count, [math]::Round(100*$flag.Count/$nm.Count,1))
Write-Host ("  -> that is the measurable floor on classification error; the true rate is higher")
Write-Host ""
Write-Host ("  ground on a non-mining classification            : {0:N0} ha ({1}% of licensed)" -f `
    $haNM, [math]::Round(100*$haNM/$haAll,1))
Write-Host ("  same, EXCLUDING self-contradicting names         : {0:N0} ha ({1}% of licensed)" -f `
    $haClean, [math]::Round(100*$haClean/$haAll,1))
Write-Host ("  -> quote the second figure; it is the defensible one")
