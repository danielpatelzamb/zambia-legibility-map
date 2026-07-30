# Session recovery log

Purpose: on-disk trail of in-flight work so any session (or human) can resume after a crash
without digging through transcripts. Newest entries at the bottom. Keep this updated whenever
a research file lands or a pipeline step runs.

## How to resume from this file
1. Check the checklist below — anything unchecked is pending.
2. Research agents write JSONs into `research/`; the merge step is
   `pipeline/build_analysis_dataset.ps1` (if entities/licenses changed) then
   `pipeline/merge_research_outputs.ps1` (always, after research JSONs change).
3. Expected research files: entity_contacts.json, facilities.json, bol_shipments.json,
   price_series.json, entity_values.json, valuations.json.
4. Nothing is committed to git yet — user asked to wait until all of this is done.

## State checklist (2026-07-28)

- [x] dataset/ CSVs built (build_analysis_dataset.ps1 ran 03:01)
- [x] research/entity_contacts.json — 21 entities (03:59 session; enrichment pass IN FLIGHT, see below)
- [x] research/bol_shipments.json — 10 shipments, valid
- [x] research/entity_values.json — 29 records, RECOVERED from crashed session transcript
      (Chinese-owned entities: CCS, Chambishi Metals, CNMC Luanshya, NFCA, Sino-Metals,
      Lubambe, Chibuluma, Mimbula, UMCIL). Source: subagent a77777586916a6550 of crashed
      session 69626af4, extracted and validated ~2026-07-28 10:3x UTC.
- [x] research/facilities.json — DONE 22 facilities (smelters/refineries/SX-EW/concentrators/
      fabricators; OSM polygon coords where available, precision labeled in coordinate_source)
- [x] research/price_series.json — DONE 22 rows (Copper: WB Pink Sheet 2015-2025 USD/t;
      Cobalt: USGS MCS USD/lb converted to USD/t; 2025 cobalt is USGS estimate)
- [x] research/valuations.json — DONE 40 records (FQM Kansanshi/Trident segment revenue+
      production 2022-2025 from audited ARs; Barrick Lumwana from SEC 40-F; KCM/Vedanta deal
      history; Mopani Glencore-exit + IRH $1.1bn; ZCCM-IH; ZAMEFA). No dupes vs entity_values.json.
- [x] research/entity_contacts.json ENRICHMENT — DONE. 21 records enriched with linkedin/
      whatsapp/other_channels/facility_contacts. Only ZRA (+260 96 0081111) and PACRA
      (+260 953 748701) publish WhatsApp lines. China-linked operators (CCS, Chambishi Metals,
      CNMC Luanshya, NFCA, Sino-Metals) are thinnest — their Facebook pages flagged
      "official status unverified". Official channels only, no personal data.
- [x] research/sector_directory.json — DONE 37 orgs across segments (gemstone_producer,
      gemstone_trade, asm_association, manufacturer, trader_exporter, services, institution).
      Landed just before the second interruption; validated as JSON.

## SECOND INTERRUPTION (2026-07-28 ~03:40): session hit usage limit ("resets 4:40am NY"),
## process exited with 11 agents in flight. All 11 resumed from transcripts after restart
## (user switched model to Opus). Each resumed agent was instructed to write partial results
## to disk FIRST, then continue — so a third interruption loses at most a few lookups.
## DONE post-resume: holder_contacts_batch1.json (50 objects, rows 1-50: high 16 / medium 8 /
## none 26; Kagem researched fully — was NOT in entity_contacts.json; KYC red flags noted for
## Zambian Anglo Mining, San He, Brigade Construction, Sezic, Kamdec, Katiso).
## DONE post-resume: holder_contacts_batch6.json (50 objects, SME rows 101-150: high 6 /
## medium 2 / none 42; "Trimble Spatial Zen Ltd Test" flagged as cadastre TEST record —
## exclude from published dataset; deepest-tier co-ops reachable only via Registrar of
## Cooperatives / district offices).
## DONE post-resume: holder_contacts_batch2.json (50 objects, rows 51-100: high 16 / medium 14 /
## none 20; Grizzly Copper, Ever Great Energy/Sino Great Group, GoviEx Uranium, Arc Minerals'
## Zaco; KYC flags: Avocado Mining ZEMA shutdown + arrests, Momentsky labour fine, Tubombeshe
## tax probe; Maamba commodity field flagged misattributed in source CSV).
## DONE post-resume: holder_contacts_batch5.json (50 objects, SME rows 51-100: high 8 /
## medium 4 / none 38; Advantex copper plant Kalulushi, Jewel of Africa, Consolidated Gold
## ZCCM-IH/Karma JV, Atomic Eagle uranium subsidiaries, Oval/Xtract Silverking JV).
## NEW AGENT launched: value_addition_efforts.json (policy/zones/international initiatives/
## national projects/state vehicles layer; merge block + DATA_MAP.md still to add).
## DONE post-resume: holder_contacts_batch4.json (50 objects, SME rows 1-50: high 3 /
## medium 16 / none 31; Lafarge = Chilanga Cement/Huaxin with full contacts; Copper Tree
## = ZCCM-IH investee; KCM Smelterco = liquidation-era split entity; Sensele = 2025
## amaBhungane illegal-mining exposé subject; 2 official sites DNS-dead, recorded URL-only).
## DONE post-resume: BoL/supply-chain sweep. bol_shipments.json now 24 records (14 new:
## CNMC Luanshya→Gerald Metals cathodes, Chambishi Metals→Shepherd Chemical cobalt, FQM
## intra-group + KCM inbound reagent chain). supply_chain_links.json NEW, 31 records:
## Jiangxi 2x$500m prepayments, Royal Gold $1bn Kansanshi stream, Glencore $1.5bn Mopani
## financing-offtake, Mercuria $200m, Trafigura KCM $100m (in arbitration), Lobito corridor
## stack (DFC $553m, AFC >$4bn, KoBold anchor cargo), TAZARA $1.4bn CCECC, North-West Rail.
## Gaps: no US BoL for Chinese-group/emerald/regional flows (expected); BoL value_usd null
## (free manifests carry no declared values).
## DONE post-resume: holder_contacts_batch8.json (50 objects, SME rows 201-250: high 5 /
## medium 2 / none 43; Copperzone Resources ~3,000 km2 Canadian explorer, Antler Gold REE,
## Velos construction/limestone; exposé color: Jingneng via Chifupu Minerals on Kenlen's
## license, Cibakent gold mine chiefs' complaints).
## DONE post-resume: holder_contacts_batch7.json (50 objects, SME rows 151-200: high 3 /
## medium 9 / none 38; Limeco quicklime + Firering stake, African Pioneer plc/FQM option JV,
## Mulonga co-op pinned via Chirundu council EPB). ALL 8 CONTACT BATCHES NOW COMPLETE:
## 400 holders swept — high 63 / medium 66 / none 271.
## THIRD INTERRUPTION (2026-07-28, session limit resets 4:30pm America/New_York): three
## agents killed mid-run — value-addition, historical/timeline, BoL-sources guide. Incremental
## checkpointing WORKED: value_addition_efforts.json (28), historical_production.json (128),
## timeline_events.json (46) all landed VALID. Only research/bol_data_sources.md was lost
## (never written) — needs a re-run when the limit resets.
## MERGE RUN + VERIFIED: dataset/ now 22 CSVs. DATA_MAP.md written (join model, per-table
## notes, analysis starting points, caveats).

## PDF EXTRACTOR VERIFIED WORKING (tested by main session, not just claimed):
##   & scratchpad\pdftext.ps1 -Path <pdf> -Out <txt>     (BOTH params required)
##   On data\gov\Final-Public-Default-Notice_18062025.pdf: 321,199 chars, 5,257 licence codes.
##   Unlocks the MMMD/NCC PDFs WebFetch can't read. Batch9 wrongly believed local PDF
##   extraction was impossible (looked for poppler) — it isn't; use this script.

## !! METHOD LANDMINE (batch13) — affects trust in some "none" results !!
## DuckDuckGo's OR operator behaves as AND in this environment: a query like
## `"Changfa Resources" OR "Fankel Mineral"` returns ZERO results even though Changfa
## demonstrably has pages. Any agent that OR-batched names to save search calls produced FALSE
## negatives. batch13 caught it and re-ran its 9 affected holders individually. batch18 observed
## a sibling's OR-batched query in the shared browser pane, so at least one other batch may be
## affected. Warning pushed to all 9 value-chain agents. RULE: one holder name per query.
## ALSO (batch18): the browser pane is SHARED across sibling agents — a get_page_text call
## returned another agent's results. Parallel slices can corrupt each other's reads there;
## prefer WebFetch, or give each agent its own tab.

## COORDINATION MISTAKE (mine, flagged by batch14): I rewrote holders_remaining_target.csv
## while wave-1 agents were reading it BY LINE NUMBER — it shrank 2318 -> 1718 rows mid-run.
## batch14's slice was verified unique against all other batches so no work was lost, but the
## rule is: NEVER rewrite a target CSV that live agents are indexing into. The currently-running
## value-chain agents read holders_stratified_target.csv, confirmed untouched since 23:19:47
## (before they launched).
## BETTER PDF TOOL FOUND (batch14): pdftotext ships with Git for Windows —
## "C:\Program Files\Git\mingw64\bin\pdftotext.exe" (verified present). Prefer it over the
## PowerShell inflate hack. Agents kept concluding "no PDF extraction on this machine" because
## they only checked for poppler on PATH.

## WAVE 1 COMPLETE (batches 9-20, 600 records) + MERGED. dataset/holder_contacts.csv now:
##   1,253 holders | high 128 / medium 231 / none 894
##   REACHABLE (phone|email|website|social present): 189
##   search_coverage: searched 1,127 / not_researched 116 / partial_search_only 10
##   New columns added: holder_key (normalized, for dedup grouping), segment, facebook,
##   district, contact_person, reachable, search_coverage.
##   NOTE 1,253 rows vs 1,237 distinct holder_key = 16 name-variant/overlap pairs to reconcile.

## *** CORRECTION APPLIED — the "not in the company registry" number was mostly MY BUG ***
## PACRA's search endpoint cannot handle ampersands (and to a lesser degree dots, brackets,
## apostrophes, double spaces). Proof: "VS Construction & Mining Services Limited" -> 0 hits, but
## "VS Construction" -> VS CONSTRUCTION & MINING SERVICES LIMITED (120080075175, Active, 2008).
## 141 of the 559 no-match holders carried such artefacts. pipeline/pacra_requery_normalised.ps1
## retried them with progressively simplified names, accepting a hit ONLY if it shared >=60% of
## distinctive tokens with the original (so "Anzan" can never silently become "Anzanu Wholesalers").
## RESULT: 116 of 141 were registered all along. Folded back into dataset/pacra_registry.csv
## (exact_name_match = 'resolved_via_normalised_query') and registry_discrepancies.csv
## (registry_discrepancy = 'RESOLVED_ON_RETRY').
##
## HEADLINE ARITHMETIC, corrected — use these numbers, not the earlier ones:
##   559 raw no-match
##   -229 cooperatives (register with the Registrar of Cooperatives, absence EXPECTED)
##   -116 punctuation-bug false negatives
##   = 214 genuinely unexplained companies holding mineral rights with no company-registry record
## CORRECTED PACRA TOTALS: 2,273 of 2,716 matched | 746 have NOT declared beneficial owners
##   | 1,428 have NOT filed annual returns | 934 below minimum nominal capital.
## Note also: where several entities matched one query the API returns arrays; the fold-in
## flattens to the first match. Re-check any row you intend to quote individually.
## LESSON: a punctuation quirk in one API turned into a false 559-company claim. Verify a
## surprising count against the source before it becomes a finding.

## FLAG-BUG RESIDUE CLEARED: holders_remaining_target.csv had been generated BEFORE the
## in_default flag fix, so every row showed in_default_2025 = 0. batch19 spotted the
## inconsistency (Hao Ming Investment is entry 553 in the 18 June 2025 notice, licence
## 33921-HQ-LEL, yet the CSV said 0) — batch12 had flagged the same symptom earlier.
## Regenerated from the corrected roster: 1,718 unswept organisations, of which 952 have
## >=1 licence in the 2025 default notice. Column renamed lics_in_default_2025 to match roster.
## Progress: 998 unique holders swept so far.

## HOLDER-NAME DUPLICATES IN THE REGISTER (checked by main session):
## 26 normalized-name collision groups covering 52 holder rows — same company recorded under
## name variants, each variant holding DIFFERENT licences (so they must be merged, not dropped).
## Examples: "China Copper Mines Limited"/"...Ltd"; "Chilanga Cement  Plc"/"Chilanga Cement Plc";
## "Chibaris International (Zambia) Limited"/"Chibaris International(Zambia)Limited";
## "EKS Mining International Limited"/"...Ltd"; "Jewel Of africa"/"Jewel of Africa Limited";
## "BASEMETALLIC ZAMBIA LIMITED"/"Base Metalic Zambia Limited" (flagged by batch18).
## Many others are double-space variants of person names (register data-entry artifacts).
## So "3,622 distinct holders" is really ~3,596. Fix: group on a normalized key
## (uppercase, strip punctuation and LIMITED|LTD|PLC|COMPANY|CO, collapse whitespace)
## before any per-holder counting or article claim.

## OPEN QA ITEM — NOW RESOLVED (verified by main session against the extracted notice):
## A coop agent worried the CSV's default flags came from a different list. They do not.
##   - 40/40 sampled licences flagged in_default_notice_2025 appear verbatim in the notice text.
##   - The notice contains 3,402 distinct licence codes; 3,265 are present in licenses.csv and
##     137 are NOT — i.e. the notice covers rights no longer on the active register.
##   - That 137 explains most of the earlier count gap (notice text says 3,429 rights;
##     licenses.csv flags 3,155; adverse_actions has 4,891 rows for multi-part rights).
## The agent had only checked the 2023 notice and the cancellation notice, not the 2025 one.
## CONCLUSION: the default flags are sound. Safe to quote, provided you say "rights listed in
## the 18 June 2025 notice" rather than implying all of them are currently active licences.

## ARTISANAL HECTARES ARE A WEAK DISCRIMINATOR (coop batch3): the register's hectares field for
## artisanal rights looks like a nominal figure, not a measured one — BOMAS matched 3/3 minerals
## but its published area is 3.85 ha against the register's 7. Also a 36627-36635 block of Central
## Province societies all carry identical 6.5923 ha and identical Co/Cu/Au, which reads as a
## repeated cell in the notice. Do NOT use hectares alone to confirm artisanal identity.

## TWO OPERATIONAL GOTCHAS (coop batch3):
##   - mmmd.gov.zm serves an EXPIRED CERTIFICATE; the www. host has a valid one.
##     Always use https://www.mmmd.gov.zm/?p=NNNN. (Agent correctly refused to disable TLS checks.)
##   - The MLC notice archive IS enumerable: no sitemap and the WP REST API 404s, but
##     ?paged=N&s=MINING+LICENSING+COMMITTEE and ?cat=61 page cleanly and yield 26 post IDs
##     (70th/71st through 91st + Extra Ordinary + default + cancellation notices) — the complete
##     set. Parsed to 15,849 table rows at scratchpad\b3_mlc_rows.tsv.
##   - SHARED-SCRATCHPAD HAZARD: agents wrote overlapping p_*.html into the same mlc\ directory and
##     several sibling copies were TRUNCATED (one p_2794 was 29KB vs the real 187KB) or were Wayback
##     error pages. Never parse that directory with a wildcard; use an explicit verified file list.

## SUPERSEDED QA NOTE (kept for history):
##   The 18 June 2025 notice text states 3,429 rights defaulted (AMR 1,083, SSML 442, ...).
##   Our dataset has 4,891 rows in adverse_actions.csv for default_notice_2025-06-18 and
##   3,155 licences flagged in_default_notice_2025 in licenses.csv. Three different numbers.
##   Likely explanations: multi-part rights producing >1 row, or rights in the notice that are
##   absent from the active-licence WFS layer (already cancelled/expired). Reconcile before
##   quoting a default count in any article.

## *** THE SEARCH BLOCKER WAS SELF-INFLICTED — SOLVED 2026-07-29 ***
## Every "search is dead / CAPTCHA-walled" report came from WebFetch-based access. The in-app
## BROWSER PANE (mcp__Claude_Browser__*) is a real browser and search engines + Facebook serve it
## normally. Verified by main session:
##   - https://duckduckgo.com/?q=... via navigate + get_page_text: real results, NO CAPTCHA.
##   - https://www.facebook.com/<slug>: full public business page, NO LOGIN. One read gave
##     phone +260 776756333, email, street address and website for Kuma Investment.
## Facebook is where Zambian SMEs publish phone/WhatsApp, so this reopens the single richest
## channel for the SME tail. Agents MUST call tabs_create for their own tabId first — the pane is
## shared and sibling reads cross-contaminate otherwise.
## 3 browser-based agents launched over research/browser_sweep_target.csv (2,513 orgs with no
## channel, sorted by hectares desc).

## *** THE ROUTE TO THE COOPERATIVES (coop batch2) ***
## ZFCM — Zambia Federation of Cooperatives in Mining, zfcm.org
##   +260 952 496 469 | cooperativeminingfederation@gmail.com
##   Plot 25 Chila Road, Kabulonga, P.O. Box 38032, Lusaka
## The national federation for mining cooperatives = the single realistic channel to the 229
## cooperative licence holders. Also Registrar of Cooperatives / Department of Cooperatives,
## 9th Floor New Government Complex, Nasser Road, Lusaka, P.O. Box 31968, +260 211 226673
## (CAVEAT: sourced from secondary licensing guides that still place it under Ministry of
## Commerce — may predate the move to Ministry of SME Development; confirm before relying).
##
## STRUCTURAL FINDING, not a search failure: ZERO of 70 cooperatives surveyed has a published
## office phone, email or address. MLC notices publish only applicant/province/district/licence
## code/minerals. They are outside PACRA so no registry record exists, and none has ANY web
## presence. What IS obtainable is district+province (51 of 70 resolved). District clustering
## means provincial cooperative offices in Mansa, Solwezi, Mpika and Mumbwa would reach ~a third
## of a batch at once. Several societies are visibly co-filed (consecutive licence numbers, same
## district) suggesting organised group applications.
## MLC archive starts at the 70th meeting (Feb 2023) — earlier grants leave no trace, so
## "not found" for those is a dating artefact.
##
## OPERATIONAL LIMIT DISCOVERED: the browser pane caps at 9 tabs and IS shared — a coop agent had
## get_page_text return ANOTHER agent's search results twice. WebSearch/WebFetch are per-agent and
## race-free. CAP CONCURRENT BROWSER AGENTS AT ~4, or give non-browser agents the WebFetch path.

## NOTABLE SUBSTANTIVE FIND (browser batchC): **Eagles Holding Limited is the commercial holding
## company of the ZAMBIA NATIONAL SERVICE** (Zambia Defence Force / Ministry of Defence) — a
## state/military-owned mining licence holder. ZNS House, Plot 6452 Church Road, Lusaka,
## +260 211 524 488. Confirmed via its own subsidiary's page. Also: African Pearl Estates is
## controlled by the Mwila family (late Benjamin Mwila, defence minister 1991-97) with Makor
## Resources holding 51% of a JV over 418 km2 in Mumbwa since March 2025.
## Earlier a sibling had DELIBERATELY left Eagles unmatched despite the ZNS namesake because no
## source tied it to the licences — correct caution at the time, now resolved with a source.
## NEW TACTIC (batchC): **job boards are a top-yield contact source** for firms with no website
## (Great Zambia Jobs etc. publish HR email/phone/address). Propagated to running agents.
## DISAMBIGUATION RULE: Zambian company names are UNIQUE in the PACRA register, so an exact
## registered-name match to a Zambian-domiciled entity justifies "high" confidence.

## *** BIGGEST FIND OF THE SESSION (batchB, VERIFIED by main session) ***
## PACRA has an UNDOCUMENTED PUBLIC JSON API, no auth, bulk-queryable:
##   https://xatu.pacra.org.zm:8344/api/v1/Search/registrysearch?Searchtext=<name>&SortyBy=entity%20name&Direction=ASC
## Returns per matched entity: entityName, entityNumber (registration no.), registrationDate,
## natureofBusiness, entityStatus (Active/...), companyType, ISIC classification, AND the two
## fields that matter most for this project:
##   - beneficialOwnerStatus + beneficialOwnerReason  => whether the company has DECLARED ITS
##     BENEFICIAL OWNERS. Verified example, Limestone Resources: "has not complied with the
##     requirement to disclose information on the beneficial ownership of all the shares...".
##     This is a per-company, statutory, free measure of ownership opacity across the register.
##   - annualReturnStatus + annualReturnReason => filing compliance, with the last return date.
## Also nominalCapitalStatus (undercapitalised shells are visible: "below the required
## prescribed minimum nominal share of K20000").
## NO contact fields — so it does not solve outreach, but it makes the register LEGIBLE, which
## is the project's actual thesis. And it is FREE: this supersedes the K50/company PACRA
## printout plan entirely for everything except registered addresses/directors.
## => pipeline/fetch_pacra_registry.ps1 written (resumable, 250ms delay, saves every 25) and
##    RUNNING over all 2,716 organisations -> research/pacra_registry.json.
##    Re-run the same script to resume after any crash; it skips holders already present.

## AGENT CLAIM TESTED AND NOT REPRODUCED (main session, don't build on it):
## batchC reported zambiadirectory.com/search_results?q=<name> as a bulk-queryable contact
## source "exposing schema.org microdata (telephone, streetAddress...)". I tested it:
##   - the apex host returns a 170-byte JS redirect to www with an extra &google= param;
##   - the www URL returns 222KB for EVERY query, identical +/-40 chars regardless of the name;
##   - itemprops present are page-furniture only (headline, publisher, dateModified...) —
##     NO telephone / streetAddress / addressLocality anywhere, and no +260 phone patterns.
## Conclusion: results are rendered client-side, so it is NOT server-side bulk-queryable.
## Individual listing pages an agent cited may still be valid; the SCALE claim is not.
## Lesson: verify a "bulk source" before designing a wave around it.

## FACEBOOK BLANKS ARE INCONCLUSIVE, NOT NEGATIVE (batchC): facebook.com returns HTTP 400 to
## all automated requests in this environment. Any holder whose only likely channel is Facebook
## has an UNTESTED blank. batchC recorded this in notes correctly; treat those as leads.
## => NEXT-BEST ACTION for the ~1,000 unreachable holders. Facebook is where Zambian SMEs
##    actually publish phone/WhatsApp (confirmed hits already: Kuma Investment facebook.com/
##    kumagranite ~21k followers with a published business WhatsApp; Bekazulu Mining reachable
##    ONLY via Facebook; Hemings, Masob, MCK, Niang, Serenje Ferro, Chibaris all FB-only).
##    Requires a real browser session, NOT WebFetch. I attempted this via the in-app browser
##    pane but the tab cap was reached and every tab was in use by live sibling agents —
##    batch18 had already shown the pane is SHARED and cross-agent reads corrupt each other,
##    so I deliberately did not hijack their tabs mid-run. Do this AFTER all agents finish:
##    walk the FB-lead holders, read the About block, capture published phone/WhatsApp/email.

## FIFTH INTERRUPTION: batches A, G, H all hit "API Error: Connection closed mid-response".
## Checkpointing again limited the damage — A and G had already written all 47 records; only
## H (5/47) and I (14/47) were genuinely short and were resumed.
## VALUE-CHAIN WAVE YIELD (honest ceiling, consistent across independent slices):
##   batchA 11 reachable / 47 (best) | batchB 0 / 47 | batchC 2 / 47 | batchD 5 / 47
##   batchE 3 / 47 | batchF 2 / 47 | batchG 6 / 47 | batchH 5 / 5 so far | batchI 9 / 14 so far
## Each slice independently exhausted the SAME bulk sources: MMMD MLC minutes corpus, MMMD 2025
## default notice, NCC 2024+2026 registers, ZRA large-taxpayer register, ZRA licensed clearing
## agents (has phone/email/address — but zero matches to mineral holders), full 234-doc ZEMA
## repository, Chamber of Mines + Zambia Mining Website directories, and systematic
## name-stem x 3-TLD domain sweeps. Conclusion: for the deep register there is no published
## contact channel to find. Remaining routes are OFF-WEB: MMMD licence files, district council
## offices, Registrar of Cooperatives.
## WHAT THE WAVE DID DELIVER instead of contacts: official district/province + licence-number
## identity for the large majority (batchE 37/47, batchF 38/47, batchC 40/47), often confirmed
## by EXACT hectarage match to the register — a far stronger identity tie than name matching.
## That is real legibility value even where no phone exists.
## PDF EXTRACTION GOTCHA (batchF): re-extracting the NCC 2026 register truncated to 186KB vs the
## complete 1.17MB extract already in the scratchpad. Prefer existing extracts.

## SHARED SCRATCHPAD CORPORA (reuse instead of re-fetching — cheap local greps):
## ncc.txt, ncc2024.txt, ncc2025.txt, ncc2026.txt, mmmd.txt, mlc_posts.json, zema_eis.html
## in the session scratchpad. mlc_posts.json is a WordPress REST dump whose `id` fields yield
## citable https://www.mmmd.gov.zm/?p=<id> URLs. NCC 2024 has address columns; 2026 does not.

## DECISION 2026-07-28 — ZRA tax-portal FINANCIALS: NOT COLLECTED (user asked; I declined).
## The indexed portal.zra.org.zm PDFs are payment/registration receipts exposed by
## misconfiguration, not a published register. Registered ADDRESS is a registry-type fact that
## PACRA publishes anyway, so agents kept those. The tax LIABILITY/PAYMENT figures on the same
## page are confidential taxpayer data — republishing them in a public app is a different act
## from surfacing an address, and would expose the project legally without serving its purpose.
## Agents were already instructed to skip amounts and TPINs, and did.
## LEGITIMATE SUBSTITUTES for company-level tax/payment data, all published BY DESIGN:
##   - ZEITI/EITI reconciliation reports: per-company payments to government, consented and
##     audited. Already partly in dataset/entity_values.csv as metric payments_to_govt_usd
##     (4 rows) — the ZEITI annexes can extend this substantially and are free.
##   - LuSE-listed filers (ZAMEFA/Chilanga/ZCCM-IH) publish audited accounts incl. tax charges.
##   - Foreign parents' annual reports/40-F (FQM, Barrick, Vedanta, Jubilee, Shuka, GoviEx)
##     disclose Zambian segment taxes and royalties.
## NEXT ACTION IF USER WANTS DEPTH HERE: mine ZEITI annexes 2016-2024 for per-company
## payments-to-government and fold into entity_values.csv. That is the same analytical payload,
## from a source built for publication.

## JUDGEMENT CALL FLAGGED BY batch9 (user should decide):
##   Two registered addresses (Srinibash Resources, DAMATECH MINING) came from search-indexed
##   ZRA tax-payment-registration PDFs. Government records, and the agent took ADDRESSES ONLY
##   (no TPINs, amounts, or personal details). My view: acceptable for a transparency dataset
##   since they are business registered addresses, but they are incidentally-indexed tax
##   receipts, so flag them in the published caveats and drop them if you'd rather not rely on
##   that provenance. Both are marked in their notes fields.

## REMAINING WORK (blocked on session limit; resume after 4:30pm America/New_York NY)
- [x] research/bol_data_sources.md — DONE (61KB, all 6 sections). KEY FINDING: the 24 existing
      BoL records are not a small sample of Zambian exports — they are a near-complete sample of
      the only slice US manifests CAN see. No ocean B/L is issued in Zambia (landlocked); the
      shipper on Durban/Dar B/Ls is a forwarder or trading house; China-bound blister/anode never
      touches US data; emeralds fly on air waybills no B/L product carries. Buying more manifest
      data will NOT fix attribution.
      FREE ACTIONS RANKED: (1) check Harvard Library for Panjiva / S&P Capital IQ Pro — licensed
      by academic libraries, would be the premium US-manifest set at $0; (2) OpenCorporates free
      at-scale access for universities/anti-corruption researchers (else GBP 2,250-12,000/yr);
      (3) ZEITI report annexes XLS 2016-2024 — the only free COMPANY-LEVEL Zambian export figures,
      by project; (4) Comtrade + ITC Trade Map mirror-trade (Trade Map beta currently free, and
      permanently free for low-income-country users); (5) corridor layer — TPA transit cargo by
      destination (Zambia 3.5 Mt 2025), Namport cross-border, Transnet live vessel list (transient,
      needs scheduled capture), SARS Trade Stats free bulk monthly HS download; (6) Zauba free
      HS pages for emeralds = the only window on the gem corridor.
      BEST PAID: Sayari (attribution, not more manifests — 1.8B trade records + 500M registry-
      resolved companies + ownership traversal, real African coverage; pricing NOT published,
      ask for academic pricing + Zambia proof-of-value). Runner-up Kpler for dry-bulk cargo.
      CAVEATS: many vendor pricing pages 403 automated fetches — those figures labelled
      [third-party] vs [vendor page], with an appendix listing what needs a manual browser pass;
      ZRA contact details flagged for manual confirmation (zra.org.zm has a TLS chain error).
      NOTE: user asked me to sign up for trial accounts — DECLINED (account creation / accepting
      ToS on his behalf is out of bounds; trial ToS commonly forbid bulk export). No accounts
      were created. Original task framing:
      (free vs freemium sources, what each yields for Zambia, costed plan). Agent died before
      writing anything. NOTE: user asked me to sign up for trial accounts — declined (account
      creation / accepting ToS on his behalf is out of bounds, and trial ToS often forbid bulk
      export). Deliverable is a documented procurement guide he can act on himself.
## FOURTH INTERRUPTION (2026-07-28): process exited seconds after wave 1 launched — batches 9-20
## had written their empty-array files but only 1 record total. All 12 resumed from transcript;
## checkpoint interval tightened from every 10 holders to every 5. BoL guide agent also resumed
## to finish sections 2-6.

## WORKAROUND FOUND (batch15, confirmed useful): **Yahoo HTML search via WebFetch works** —
## https://search.yahoo.com/search?p=<query>. Best general fallback when WebSearch is capped and
## DDG/Mojeek/Brave/Ecosia are CAPTCHA-walled. Bing RSS returns junk. Propagated to all 9
## value-chain agents mid-run. Also working: ZEMA site search, domain guessing
## (<holder>.com/.co.zm), Facebook business page fetches, MMMD licensing-committee minutes.
## A prior crashed session left a working PowerShell PDF text extractor at
## scratchpad\pdftext.ps1 (inflates Flate streams) — use it for the image/compressed
## MMMD + NCC register PDFs that WebFetch cannot read. It also decodes Cloudflare-obfuscated
## emails.
## MORE WORKING TECHNIQUES (batch10):
##  - PowerShell Invoke-WebRequest reaches sites WebFetch 403s on (e.g. concorde.co.zm).
##  - **ZEMA's WordPress site search does NOT index PDFs** — searching a holder name returns
##    nothing even when an EIS exists. Use the repository LISTING instead:
##    zema.org.zm/docs-category/environmental-impact-statements/ (~369 doc titles) and sibling
##    categories, match titles to holder names, then fetch the PDF. ZEMA EIS documents DO carry
##    proponent contacts — this is how SINO XINYUAN MINING (previously unreachable) yielded
##    email + phone + street address. Correction was pushed to all 9 value-chain agents mid-run.
##  - NCC contractor registers 2024 + 2025 are minable with the PDF extractor and give
##    town/province/ownership (no phones).

## !! SEARCH INFRASTRUCTURE IS NOW THE BINDING CONSTRAINT (discovered during wave 1) !!
## batch11 reported: shared WebSearch 200-call session cap exhausted; DuckDuckGo HTML fallback
## now serving CAPTCHAs; Mojeek 403, Brave 429, Bing returning unrelated cached results. Agents
## fell back to ZEMA site search (works, but sparse for small holders). CAPTCHAs must NOT be
## circumvented, so this is a hard ceiling, not a workaround problem.
## CONSEQUENCE: "none" results produced under these conditions are UNTESTED, not verified-absent.
## batch11 flagged 10 such holders with "COVERAGE CAVEAT" in notes for re-sweep: Lxco Investment,
## Inspire Mineral Resources, Gramajo Mining, Faith Mountain Investments, Sedhost Minerals,
## Shineth Resource Mining, Irenka, Modibo Resources, Constantinou Menelaos Agathoklis Mining,
## Mavikem Resources.
## RECOMMENDATION (pending user decision): do NOT launch waves 2-5 into a CAPTCHA wall — it would
## generate ~1,700 unreliable nulls that look like verified absences. Better: finish wave 1, then
## use PACRA printouts (K50/company = registered office + directors) for holders that matter.
## Yield curve confirms diminishing returns: batch1 16/50 high -> batch11 2/50 high.
## batch20 CONFIRMED THE WALL: 20 of its 50 holders were NEVER LOOKED UP (budget died at
## holder ~29; DDG CAPTCHA then 403, Mojeek 403, searx/Anubis denials, Bing RSS unrelated,
## stract/zambiayp 404). Agent correctly labelled them "NOT RESEARCHED" rather than passing
## them off as negative evidence.
## MITIGATION APPLIED: merge_research_outputs.ps1 now derives a `search_coverage` column
## (searched / partial_search_only / not_researched) from the notes text, so holder_contacts.csv
## can never misrepresent an unsearched null as a verified absence. Re-queue targets are
## machine-filterable: Import-Csv dataset\holder_contacts.csv | ? search_coverage -ne 'searched'
## ALSO LEARNED (blockers for any future sweep): MMMD default notices and NCC gazetted contractor
## registers are image/compressed PDFs that WebFetch cannot text-extract — they need a LOCAL pdf
## text pass, and they are multi-holder sources (high value per extraction). zra.org.zm fails TLS
## verification, so ZRA registers are only reachable via search-engine extraction.

- [~] WAVE 1 OF FULL SWEEP RUNNING (12 agents on Opus, batches 9-20 = rows 1-600 of
      research/holders_remaining_target.csv). Target list = 2,318 unswept organizations,
      ordered by license weight. 47 batches needed in total; waves continue after this one.
      User authorized the commit once the sweep completes.
- [ ] holder contact sweep beyond the first 400. Full universe now mapped in
      research/holder_roster_all.csv: 3,622 distinct holders = 2,716 organizations +
      902 person/unclassified + 4 government. 400 orgs swept so far (batches 1-8).
      ~2,316 organizations remain unswept. Person-holders stay EXCLUDED (privacy line).
      Yield curve is steep: batch1 (biggest holders) 16/50 high-confidence; batch8 (deep tail)
      5/50. Expect <10% findable in the remaining tail. Options: (a) keep batching ~50/agent,
      (b) buy PACRA printouts (K50/local company = registered office + directors) for holders
      that matter, (c) both — web sweep first, PACRA for the "none" rows that matter.
- [ ] app feature: timelapse UI (data is READY — copper 1964-2025 + 46 annotated events)
- [ ] commit — STILL ON HOLD until user says go
## DONE post-resume: cadastre probe (see above); holder_contacts_batch3.json (50 objects,
## rows 101-150: high 6 / medium 11 / none 33 — Tawansangthong, Zambian Weiye, FACL, Grizzly,
## Aabrick with full contacts; ZEMA filings noted as upgrade path for some "none" results).
## PACRA pricing researched for user: K50/local printout (registered office + directors),
## K350/foreign, no public API, bulk via pro@pacra.org.zm. Suggested: buy printouts only for
## high-value holders that came back "none" after the web sweep.
- [x] research/fabrication_financials.json — DONE 27 rows (ZAMEFA/Reunert revenue FY21-25,
      Neelkanth/ZALCO/Uniflex cable makers, Chambishi MFEZ $2.5bn+ zone investment + CCS
      cumulative sales, battery-precursor estimates, KoBold Mingomba $2.3-2.5bn).
- [ ] research/holder_contacts_batch{1,2,3}.json — 3 agents running: official contacts for the
      top 150 organizational license holders (of 2,708 org holders / 3,622 distinct; the 914
      person-holders are excluded by the privacy line). Target list:
      research/top_holders_target.csv. Match-confidence field per row; no data-broker sources.
- [x] research/cadastre_contacts_probe.md — DONE. Verdict: bulk holder NAMES yes (Landfolio
      portal ESRI proxy, query pattern documented in the probe file; joinable on license Code),
      holder CONTACT details NO — schema has no address/phone/email columns; contacts live only
      in the login-gated portal and PACRA (per-lookup only, no public bulk/API; contact PACRA
      for bulk access). Sample: research/cadastre_parties_sample.json (20 records).
      So the web-research batches are the right/only route for contacts at scale.
- [ ] research/historical_production.json + timeline_events.json — agent running: national
      copper/cobalt production 1964-2025 (USGS/BGS) + structural-events timeline, for the
      planned independence-to-now TIMELAPSE feature in the app.
- [ ] contacts QA pass after enrichment lands (user wants contact quality "fantastic" —
      verify URLs/emails, fill gaps; datasets feed later analysis + articles)
- [ ] merge_research_outputs.ps1 re-run after all research files land
      (also add merge blocks for historical_production.json / timeline_events.json)
- [ ] verify dataset/ row counts; then user decides on commit (DO NOT COMMIT until user says)
- [ ] LATER (app feature, after datasets): timelapse UI from independence to now

## Notes
- Crashed session transcripts (for further forensics if needed):
  C:\Users\-\.claude\projects\C--Users--\69626af4-dbc2-4d49-a66c-9c73c5e56ede.jsonl and its
  subagents\ folder. Unrecoverable agents: facilities (a5a8cde), prices/valuations orchestrator
  (af697c2, partial: had WB copper series secured but unsaved), Barrick (a069b01), FQM (a084ade),
  BoL (a091b87 — but bol_shipments.json landed before crash).
- Machine has no Python/Node; all pipeline scripts are PowerShell 5.1.
- merge_research_outputs.ps1 updated this session to carry linkedin/whatsapp/other_channels/
  facility_contacts columns through to dataset/entity_contacts.csv.
