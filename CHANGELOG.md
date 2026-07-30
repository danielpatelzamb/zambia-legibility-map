# Build log — dataset, registry and terminal work

This is the commit narrative from the original working branch, preserved because that branch
was rebuilt to keep contact data out of git history. Nothing here is a contact detail; the
corrections and caveats are the point.

Working notes and per-agent provenance live in `RECOVERY_LOG.md`. Contact data itself is in
`private/`, which is gitignored and never published.

---
## Add analysis dataset: contacts, registry compliance, supply chain, 1964-2025 history

Builds an analysis-ready CSV package in dataset/ from the licence register plus
targeted research. 29 tables, all rows carrying source URLs.

Register legibility
- official_doc_mentions.csv: 16,120 holder mentions mined from 60 official
  documents (MMMD Mining Licensing Committee meetings 70-91, the 2023 and 2025
  default notices, the 2024 cancellation notice, ZEMA titles). Resolves district,
  province, licence area and decision for 6,446 distinct holders.
- pacra_registry.csv: all 2,716 organisational holders queried against PACRA's
  public registry API. 2,157 matched. Carries beneficial-ownership and annual-return
  compliance: 729 have not declared beneficial owners, 1,439 have not filed returns,
  937 sit below minimum nominal capital.
- registry_discrepancies.csv: the 559 with no registry match, classified by likely
  cause. 229 are cooperatives that register elsewhere, so their absence is expected;
  spot-checking the rest showed name-variance failures (Lumwana Mining Co. Limited is
  registered as LUMWANA MINING COMPANY LIMITED), not absence. Do not read this table
  as evidence of shells without re-querying.

Contacts
- holder_contacts.csv: 1,423 holders researched, 203 reachable. search_coverage
  distinguishes 'searched' from 'not_researched' so blanks from the search blackout
  are never mistaken for verified absences; holder_key normalises name variants.
- outreach_targets.csv + OUTREACH_PLAN.md: 224 reachable organisations tiered by
  materiality, and the conveners (Chamber of Mines, ZEITI, conferences) that reach
  the rest.
- asm_outreach_channels.csv: 76 institutional gatekeepers, 62 with a phone or email.
- individual_holders.csv: 902 individual holders with the register's public facts and
  district, for outreach via district offices and associations rather than personally.

Value and supply chain
- entity_values.csv: 103 sourced financial facts from audited filings (FQM and Barrick
  segment data, SEC 40-F, LuSE) and deal reporting.
- supply_chain_links.csv: 31 offtakes, prepayments, streams and corridors with values.
- bol_shipments.csv: 24 US CBP manifest records. bol_data_sources.md explains why this
  is near-complete for what US manifests can see and why more manifest data will not
  help a landlocked exporter.

History and policy
- historical_production.csv: copper 1964-2025, cobalt 1970-2024 (USGS/BGS).
- timeline_events.csv: 46 sourced structural events, independence to now.
- value_addition_efforts.csv: 28 policy instruments, zones and initiatives.

Pipeline is reproducible: build_analysis_dataset.ps1, then merge_research_outputs.ps1.
fetch_pacra_registry.ps1 and probe_holder_web.ps1 are resumable.
probe_novel_methods.ps1 output is deliberately NOT merged: its MX-inferred addresses
were verified as false positives matching unrelated global companies.

Caveats travel with the data in DATA_MAP.md. RECOVERY_LOG.md records provenance,
five session interruptions, and the verification of every method used.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---

## Untrack generated dataset bundle

The zip is a build artifact regenerated from dataset/; keep it out of history.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---

## Correct registry-absence count, add browser-sourced contacts and declared-business analysis

CORRECTION (important): the earlier "559 companies absent from the company registry"
figure was largely an artefact of my own query. PACRA's search endpoint cannot handle
ampersands, and to a lesser extent dots, brackets and apostrophes: "VS Construction &
Mining Services Limited" returns nothing, while "VS Construction" returns it (entity
120080075175, Active, registered 2008). 141 of the 559 carried such characters and 116
of those were registered all along.

  559 raw no-match
  -229 cooperatives, which register with the Registrar of Cooperatives (absence expected)
  -116 punctuation-bug false negatives
  = 214 genuinely unexplained

pacra_requery_normalised.ps1 performs the retry, accepting a hit only when it shares 60%
or more of the original name's distinctive tokens so a shortened query cannot silently
attach an unrelated company. Corrections are folded into pacra_registry.csv
(exact_name_match = resolved_via_normalised_query) and registry_discrepancies.csv
(registry_discrepancy = RESOLVED_ON_RETRY). Corrected totals: 2,273 of 2,716 matched,
746 with beneficial ownership undeclared, 1,428 with annual returns unfiled, 934 below
minimum nominal capital.

New: declared_business_vs_licences.csv
732 of 2,128 licence holders (34%) declare a non-mining line of business to the companies
registry while holding 10.9M hectares, about 30% of all licensed ground - 134 wholesale
traders, 104 building contractors, 66 road freight firms, 29 mixed farmers. Largest are
Hongbin Investments (384,010 ha, "mixed farming") and Willianda Investments (177,581 ha,
"processing and preserving of fruit and vegetables"). 121 rows are marked
UNRESOLVED_MULTI_MATCH and excluded from those percentages rather than guessed.

New: holder_contacts_v2.csv - 1,501 holders, 240 reachable (up from 203)
The search blackout that limited earlier passes was self-inflicted: WebFetch is
CAPTCHA-walled but the browser pane is a real browser, and both search engines and public
Facebook business pages serve it normally. Six browser-based agents swept 360 previously
unreachable holders and found 37 channels, adding 78 holders not previously researched.
Facebook business pages were the top source; job-board postings second, though yield
varies sharply by slice.
(holder_contacts.csv was locked by another process during the merge, hence v2.)

New: cooperative_holders.csv - 140 societies, 109 located to district, 0 reachable.
Verified independently by two agents: no cooperative in this population publishes an
office phone, email or address. They sit outside PACRA, their artisanal rights fall below
ZEMA's EIA threshold so they never file an EIS, and most have no web presence. The route
to them is ZFCM, the Zambia Federation of Cooperatives in Mining, recorded in
asm_outreach_channels.csv.

Also new: asm_outreach_channels.csv (76 institutional gatekeepers, 62 reachable),
novel_source_contacts.csv, individual_holders.csv, outreach_targets.csv,
OUTREACH_PLAN.md and TRACEABILITY_IDEAS.md.

Notable identifications: Eagles Holding Limited is the commercial holding company of the
Zambia National Service (Ministry of Defence). Handa Resources has been in receivership
since July 2025. Central Africa Renewable Energy Corporation (34,181 ha) and Bangweulu
Batteries cannot be confirmed to exist in any register.

Not merged, deliberately: probe_novel_methods.ps1 MX output (inferred addresses matched
unrelated global companies) and a proposed crawl of ZRA payment-printout identifiers.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---

## Complete cooperative coverage: all 229 societies, 186 located to district

Finishes the cooperative population. 229 of 229 societies researched across four
batches; 186 located to district and province, 83 with a resolved licence code,
and zero with any published contact channel.

That zero is now confirmed four times independently. It is structural, not a search
failure: these societies register with the Registrar of Cooperatives rather than PACRA
so no company-registry record exists; their artisanal rights (roughly 2-33 ha) fall
below ZEMA's EIA threshold so they never file the environmental documents that carry
proponent contacts; and most have no web footprint at all. The route to this population
is ZFCM, the Zambia Federation of Cooperatives in Mining, in asm_outreach_channels.csv.
Geographically they concentrate in Central (53), Southern (30), North Western (28),
Northern (19), Luapula (18) and Eastern (16), so provincial cooperative offices reach
most of them.

Verified separately: the default-notice flags are sound. All 40 sampled licences flagged
in_default_notice_2025 appear verbatim in the extracted notice. The notice holds 3,402
distinct licence codes of which 137 are absent from the active register, which explains
the earlier count gap - it covers rights that have since lapsed. Describe them as
"rights listed in the 18 June 2025 notice" rather than as active licences.

Caveats found and recorded in RECOVERY_LOG.md:
- Artisanal hectares are a weak identity discriminator. The register's figure looks
  nominal rather than measured (one society's published area is 3.85 ha against the
  register's 7), and a block of nine Central Province societies carry identical area and
  commodities, which reads as a repeated cell in the source notice.
- Five societies cannot be placed because the source notices themselves have blank or
  malformed location cells (the 74th left LOCATION empty for nine AMR rows; the 75th
  printed the literal string "AMR" in the location column). Defects in the government
  data, not parsing failures.
- One licence code appears in two different provinces across two notices; commodity
  matching resolved it. A name sweep stopping at the earlier notice would have misplaced
  it by two provinces.
- mmmd.gov.zm is fronted by a FortiGate appliance whose self-signed certificate expired
  29 Sep 2025, so HTTPS fails for WebFetch, curl and Invoke-WebRequest. The www. host has
  a valid certificate; otherwise the Wayback CDX index carries 82 archived notice pages.
  No agent disabled certificate verification to work around it.
- The 82nd, 86th and 89th-91st licensing notices were never archived and cannot be
  reached live, which accounts for most remaining negatives.
- Shared-scratchpad hazard: concurrent agents wrote overlapping notice HTML into one
  directory and several copies were truncated. Never parse it with a wildcard.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---

## Add the institutional layer: 111 outreach channels, 82 reachable

The 229 cooperatives and 902 individual holders publish no contacts of their own, so
the only route to them is institutional. asm_outreach_channels.csv now carries 111
records, 82 with a working phone or email, across national, provincial and district
levels.

Resolved: the Registrar of Cooperatives sits under the Ministry of Small and Medium
Enterprise Development, not Commerce, Trade and Industry. Three independent lines of
evidence: msme.gov.zm publishes the Department of Registration and Regulation with the
cooperative registration mandate; "cooperative" appears zero times across mcti.gov.zm;
and MCTI's own P.O. Box 31968 is the box the stale businesslicenses.gov.zm listing
attributes to the Registrar, which explains that entry as a pre-2021 leftover. No named
Registrar is published anywhere. Corrects the caveat recorded with the earlier figure.

New: the six MMMD Regional Mining Bureaux, which the file previously referenced but did
not contain - Solwezi, Kitwe, Mansa (Luapula and Northern), Mkushi (Central), Chipata
(Eastern and Muchinga), Choma (Southern and Western). None publishes a direct contact;
all route via the Mines Development Department. Mkushi matters most: the bureau and the
district council share a town, and Central Province holds 53 of the 229 cooperatives.

Also new: four provincial administrations, eight provincial cooperative unions, fifteen
district councils in the districts where the cooperatives actually are, and the ministry
Permanent Secretary's office.

ZFCM verified against the live site and unchanged, but enrichment came back negative on
every axis: no provincial chapters, no named office bearers, no social presence, no
additional lines. It is a four-page funnel site and /about-us/ 404s.

Data-quality flags recorded rather than smoothed over:
- Luapula provincial site returns a WordPress database error with no archived interior
  page; a P.O. Box appears only in search-index summaries and was left null rather than
  recorded unverified. Fall back to Mansa, Samfya and Kawambwa councils.
- North-Western provincial site refuses connections and its snapshots carry no contacts.
- Central's published provincial phone has six digits where Kabwe's code needs nine, so
  it is almost certainly mistyped at source.
- mkushicouncil.gov.zm serves Itezhi-Tezhi's body text, a template copy-paste error;
  only its contact block is Mkushi-specific.
- Chongwe's published number is a digit short; both forms recorded.
- The Zambia Co-operative Federation's entire web presence is dead across three domains,
  and the provincial unions never published per-union contacts even when it was live.
- Several provincial sites share a SMART Zambia hosting outage that looks transient.

Excluded on the rules: a commercial directory listing for a provincial cooperative union,
and Solwezi's only published number, which is a funeral-services WhatsApp line.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---

## Enrich the terminal: Register & Ownership tab, and PACRA standing inside KYC

Additive only - no existing tab, layer, style or data file was replaced. The new
work follows the app's own conventions: a window global loaded from data/, an IIFE
module appended to app.js, Chart.js charts and table.data tables, the existing CSS
custom properties, no new CDN dependencies.

data/register_data.js (620 KB, generated by pipeline/build_register_layer.ps1)
carries companies-registry standing keyed by normalised holder name, published
contacts, the cooperative population, the 1964-2025 production series, licensing
decisions, supply-chain arrangements, value-addition efforts and institutional
channels. Counters are computed from dataset/, not hardcoded.

New tab "Register & Ownership":
- companies-registry standing across 2,273 matched holders, with the ampersand
  correction stated on the page (214 genuinely unexplained, not 559)
- declared business vs mineral rights: 732 holders on a non-mining declaration
  holding ~30% of licensed ground, plus the largest such holdings
- copper 1964-2025 with cobalt on a switch, events in the tooltip and a sourced
  events table
- what the Licensing Committee decided across 16,120 mentions
- 31 supply-chain arrangements with disclosed value, filterable by type
- 28 value-addition initiatives with announced value
- 82 reachable institutional offices, filterable by province and type
- cooperatives by province, with the reason the contact column is zero

KYC enrichment - the more useful half. The report now gains two cards under the
licence table: companies-registry standing (registered name, number, date, status,
declared business, and beneficial-ownership / annual-return / share-capital flags)
and any published contact channel with its match confidence. This closes the old
caveat that told the user to go verify beneficial ownership at PACRA themselves.
Cooperatives get their own card explaining that no company record exists by design.
Blanks distinguish "searched, nothing published" from "not researched".

Verified against the running app on serve.ps1: the new tab activates, all five
charts instantiate, all five tables populate (12/46/31/28/82 rows), both filter
pairs work, and the KYC cards fire correctly for Kansanshi (registry + contacts),
Hongbin Investments (registry + honest no-channel message) and Mimbula. The map,
KYC, trade and methodology tabs all still work.

Also: a resize hook on tab activation, because Chart.js measures a hidden panel at
0x0 and does not recover - the same shape as the map's invalidateSize() hook.
.claude/launch.json added so the terminal can be previewed directly.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---

## Scrub contact data from everything publishable

Contact details are now held locally and excluded from the repository. Nothing had
been pushed - the branch has no upstream and origin/main still points at the
pre-existing commit - so no contact data ever reached the public repo.

What moved to private/ (gitignored, untracked):
- company and holder contacts: holder_contacts.csv, holder_contacts_v2.csv,
  entity_contacts.csv, novel_source_contacts.csv, outreach_targets.csv,
  sector_directory.csv
- individual_holders.csv - 902 named individuals with districts. Names are public
  register facts, but a compiled per-person table is not something to publish.
- asm_outreach_channels.csv - institutional offices. These are government-published
  numbers and would be the safest to restore if wanted; erring private for now.
- every research/*contact*.json batch, the web and novel probe results, the cadastre
  party sample and contacts_notes.md

The browser payload is now contact-free by construction. build_register_layer.ps1
no longer emits a CONTACTS key at all, and reads its private inputs from private/.
Audited the generated data/register_data.js: no CONTACTS key, zero email addresses,
zero +260 phone patterns, 526 KB down from 620 KB. The 102 remaining URLs are source
citations and are meant to stay.

App changes:
- the KYC "Published contact channels" card is replaced by a note explaining that
  contact details are held privately and naming the institutional route instead.
  The companies-registry standing card stays: registration number, status and the
  beneficial-ownership / annual-return / share-capital flags are official register
  facts, not contact details.
- the institutional-routes table keeps office, type, level and province and drops
  the phone and email columns, so the app still tells you which door to knock on.

One government mailbox is deliberately retained in research/cadastre_contacts_probe.md:
[contact redacted], PACRA's own published address for bulk data requests.

NOTE ON HISTORY: earlier commits on this branch still contain the contact files.
The branch is unpushed, so nothing is exposed, but merging it to main as-is would
publish those blobs. Squash or rewrite before pushing - see the next commit message
or ask me to do it.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---

## Add economic linkage: minerals under non-mining declarations, tier legibility, gemstone gap

Four new cards on the Register & Ownership tab plus a new map overlay, all built from the
join between the two state registers rather than from new research.

Minerals under a non-mining declaration. A holder's line of business comes from the
companies registry; the minerals come from the licence register. 1,015 copper and 911
gold licence-commodity entries are held by companies that told the state they are in
wholesale trade, construction, freight or farming. Sortable by count or by share of that
mineral's entries - by share the leaders are clay 32.7%, dolomite and feldspar 28.6%,
rare earths 28.0% and limestone 27.7%. Framed on the page as a flag, not a finding: a
construction firm can legitimately hold a limestone right.

Legibility by licence tier. Reach rate is 19.6% for processing and 19.2% for mining, 7.8%
for exploration and 0% for artisanal. The Bidding area row is the tell - 1,442 licences
held by 4 holders, because gazetted blocks sit with the state until allocated.

The gemstone gap, which corrects a natural misreading of the register. Only 28 licences
were ever issued under a dedicated Gemstone Licence type, a 2008-era category that has
lapsed. But 2,056 licences list a gem commodity, held by 1,459 distinct holders - 668
under large-scale exploration, 609 small-scale exploration, 506 artisanal rights. Counting
the licence type understates the sector roughly seventy-fold.

The processing cohort. 195 Mineral Processing Licences across 189 holders, filterable by
default-notice status or non-mining declaration; 149 holders appear in the 18 June 2025
notice and 54 declare a non-mining business. Clicking a row flies the map to the plant.

Map: a new "Holder declared non-mining (1,286)" overlay shades those licence points, and
L.control.layers is now exposed on window so later modules can register overlays. Note
the map already had a purple Processing (MPL) filter, so processors were always mappable;
traders are not yet, because the trader directory has no coordinates until the enrichment
pass lands towns.

Privacy holds: re-audited the generated payload and the rendered DOM - no CONTACTS key,
zero email addresses, zero phone patterns.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>


---
