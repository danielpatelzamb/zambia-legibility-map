# Bill-of-Lading & Supply-Chain Data Sources for Zambian Mineral Entities

**Status:** Complete — researched and written 2026-07-28. All six sections filled. See the appendix
for the handful of vendor pages that block automated fetching and need a manual browser pass.

**Purpose:** practical procurement guide — where to get more shipment / supply-chain data for the
~7,000 Zambian licence holders (~3,600 distinct companies) in this project, and what each source
actually delivers.

**Current baseline in repo:** 24 BoL records (`research/bol_shipments.json`, US CBP-derived via
ImportYeti) + 31 supply-chain link records (`research/supply_chain_links.json`).

**Ground rule for this document:** every pricing / tier fact is taken from the vendor's own published
page, with the URL. Where a vendor does not publish a number, this document says
**"not published"** rather than guessing.

---

## Table of contents

1. [Free / open sources](#1-free--open-sources)
2. [Freemium & trial commercial sources](#2-freemium--trial-commercial-sources)
3. [Why Zambia is hard](#3-why-zambia-is-hard)
4. [Vessel tracking (AIS) as a BoL proxy](#4-vessel-tracking-ais-as-a-bol-proxy)
5. [Recommended plan, prioritised and costed](#5-recommended-plan)
6. [Direct-request / FOI route](#6-direct-request--foi-route)

---

## 1. Free / open sources

Ranked by usefulness to this project. "Granularity" is the key column: almost everything free is
**aggregate** (country x HS code x month). Only a handful of free sources give you anything that
names a **company**.

### 1.1 UN Comtrade — aggregate mirror trade (already in use)

- Portal: https://comtradeplus.un.org/ | Help centre: https://uncomtrade.org/docs/
- API keys: https://uncomtrade.org/docs/api-subscription-keys/
- **Granularity:** reporter x partner x HS (up to 6-digit) x year/month x flow. Quantity + value.
  **No company names, no shipments.** It is a customs *aggregate*, not a manifest.
- **Free tier limits (as documented / widely reported; UN does not publish a single tidy limits
  table — the developer portal requires login, so treat these as best-known rather than official):**
  - No key / anonymous: **500 records per call** cap.
  - Free registered key ("Free APIs" product on the developer portal): higher call allowance,
    still a per-call record cap in the 500–100,000 range depending on endpoint; documented daily
    call ceilings around 500 calls/day for the free key.
  - Premium/subscription: per-call cap raised to **250,000 records**. Prices are handled through
    https://shop.un.org/databases and are **not published as a simple list price** on the API docs.
  - Exact current numbers must be read off the developer portal after login
    (https://comtradedeveloper.un.org/products) — the public docs page does not state them.
- **What it is good for here:** the *mirror-trade* method. Compare Zambia-reported exports of
  HS 7402/7403/7404/8105 (blister, refined copper, cobalt) against what China / Switzerland / UAE /
  South Africa / India report importing *from Zambia*. Gaps = under-invoicing / transit
  mis-attribution. This is the single most defensible free analysis available for Zambia.
- **Caveat that matters for Zambia:** Zambia's reported exports include DRC-origin metal smelted or
  merely transiting Zambia, and a large share of Zambian metal is invoiced through Switzerland /
  Singapore / UAE trading desks while physically going to China. Comtrade "partner" is therefore a
  *financial* not a physical destination in many rows.

### 1.2 Zambia's own published data

| Source | What is published | Company-level? | Link |
|---|---|---|---|
| ZamStats Monthly Bulletin | 276 volumes, 2003 → 2026 (June 2026 latest), PDF. Contains International Merchandise Trade section: exports by commodity group, traditional vs non-traditional exports, major destinations. | **No** — aggregate | https://www.zamstats.gov.zm/monthly-bulletin/ |
| ZamStats External Trade Bulletin (older series) | Standalone annual/periodic trade bulletins; the 2004 edition is still online as PDF, showing the historical format | No | https://www.zamstats.gov.zm/wp-content/uploads/2023/12/External-Trade-Bulletin-2004.pdf |
| ZamStats "Copper Export Earnings" monthly releases | Month-on-month refined copper export earnings (Kwacha) and volumes; published as web posts with graphs | No | e.g. https://www.zamstats.gov.zm/copper-export-earnings-january-2025-2026/ |
| ZamStats Economic Statistics tables | Downloadable economic statistics tables incl. trade | No | https://www.zamstats.gov.zm/economic-statistics-tables/ |
| ZamStats Divisions / External Trade Branch | The External Trade Branch compiles merchandise trade statistics — **this is the office to send a microdata request to** (see §6) | n/a | https://www.zamstats.gov.zm/divisions/ |
| ZRA Customs downloads | Customs forms, tariff, publications; a "Statistics and Publications" area exists. NOTE: `zra.org.zm` presented a TLS chain error when fetched on 2026-07-28 — browse it manually. Zambia applies HS 2022 at **8 digits** under the Zambia Customs Tariff, so ZRA holds 8-digit declaration-level data. | Declaration-level data exists internally; **not published** | https://www.zra.org.zm/download-category/customs/ |
| Bank of Zambia | Annual Report + monthly/quarterly statistics: export earnings, metal export values, balance of payments | No | https://www.boz.zm/ |
| ZEITI (Zambia EITI) | **Best free company-level lead.** Reports 2009→2024, plus Excel annexes. The 2023/2024 report states reporting entities were asked to report production **and export by project**; export contribution 74% (2024) / 68% (2023); copper production 822,824 Mt (2024). Annexes published as XLS/XLSX include the reporting template, certifications, **beneficial ownership**, and company lists. | **Partially yes** — by company/project for reporting entities (the large mines), not for the SME/junior tail | https://zambiaeiti.org/zeiti-reports-annexes/ ; 2023+2024 report PDF: https://eiti.org/sites/default/files/Zambia%20EITI%202023%20%20and%202024%20report.pdf |
| ZEITI Exploration/Production/Exports page | Export quantities and values by commodity, sourced from BoZ Annual Report + MoF Economic Report. Explicitly warns exports include DRC-origin copper smelted in Zambia. | No — aggregate | https://zambiaeiti.org/exploration-production-and-exports/ |
| EITI global "Production and exports" data | Cross-country production/export dataset built from EITI reporting | Country/commodity level | https://eiti.org/production-and-exports |

**Verdict on Zambian official sources:** nobody in Zambia publishes shipment-level or
consignment-level export data. ZRA holds it (8-digit CD-form declarations) but does not publish it.
The only free company-linked export figures are in ZEITI report annexes, and they cover the
reporting entities (roughly the large/medium mines), not the ~3,600-company tail. Treat ZEITI as a
**validation set** for your top holders, and ZRA/ZamStats as a **direct-request target** (§6).

### 1.3 Regional trade portals

- **ITC Trade Map** — https://www.trademap.org/
  - Free registration required. **Users in low- and middle-income countries have full free access;
    developed-country users historically had restricted free access and needed a subscription.**
    Zambia is a low-income country, so a Zambian-affiliated researcher gets everything free.
    (https://www.intracen.org/resources/tools/trade-map ;
    https://intracen.org/news-and-events/news/trade-promotion-organizations-support-free-access-to-itcs-trade-map)
  - **Important current status:** ITC is mid-migration of its subscription model. New subscriptions
    are **temporarily suspended**, and *all* Trade Map features — including normally
    subscription-only ones — are free in the Trade Map **beta** until official launch (planned
    July 2026). **Price list: not published** during the transition.
    (registration: https://mas-admintools.intracen.org/accounts/registration.aspx ;
    subscription page: https://mas-admintools.intracen.org/accounts/subscription.aspx)
  - Granularity: HS 6-digit, reporter x partner x year (some monthly/quarterly). Mirror data built in
    — Trade Map automatically shows partner-reported figures where a country doesn't report. Very
    useful for Zambia, which reports late/patchily. **No company names.** (Trade Map does surface
    lists of *importing/exporting companies* for some markets, sourced from third-party directories,
    but this is a directory, not shipment data.)
  - User guide (free PDF): https://www.trademap.org/Docs/TradeMap-Userguide-EN.pdf
- **COMESA COMSTAT Data Hub** — https://comstat.comesa.int/ and
  https://comesa.opendataforafrica.org/gallery?tag=Foreign+Trade
  - Free, no account for browsing. "Merchandise Trade by Commodity, HS" datasets with
    reporter/partner/commodity selectors; SADC as an aggregate partner is available. Built on the
    Knoema/Open Data for Africa platform, so it has CSV/Excel export and an embedded API.
  - Granularity: HS commodity x reporter x partner x year. **No company names.**
- **COMESA Trade Information Portal** — https://tradeportal.comesa.int/ — gateway to member-state
  national trade information portals (tariffs, procedures, forms). Regulatory reference, not
  shipment data.
- **SADC** — trade statistics are published mainly through member NSOs and the SADC Statistics
  yearbook; there is no SADC shipment-level portal. COMSTAT is the better regional entry point.
- **Zambia Trade Information Portal** — the national TIP (procedures, permits, forms). Useful for
  understanding what documents an exporter must file (which tells you what data ZRA holds), not for
  shipment records.

### 1.4 Open corporate / ownership / sanctions registries (ownership, not shipments)

These do **not** give you shipments. They give you the *entity resolution layer* you need before
shipment data is worth anything — matching your 3,600 company names to real legal entities,
directors, and parents.

| Source | Zambia coverage | Cost | Link |
|---|---|---|---|
| **PACRA Business Search** (Zambia's own registry) | Authoritative: private/public companies, business names, partnerships, foreign branches. Search is public; **certified extracts require a portal account and a fee in ZMW (roughly USD 5–14 per document depending on type)**. No bulk download, no API. | Search free; per-document fees | https://search.pacra.org.zm/ ; fees: https://www.pacra.org.zm/fees-and-forms |
| **OpenCorporates** | Aggregates registries globally; Zambian coverage is thin because PACRA has no bulk feed. | API: **Essentials £2,250/yr (£225/mo, 500 calls/mo, 200/day); Starter £6,600/yr (£660/mo, 2,500/mo, 500/day); Basic £12,000/yr (£1,200/mo, 5,000/mo, 1,000/day); Enterprise custom.** **Free at-scale access is explicitly offered to investigative journalists, NGOs, universities and anti-corruption research groups — apply by contacting them.** This is the single best free-by-application asset here for a Harvard-affiliated project. | https://opencorporates.com/pricing/ |
| **OpenSanctions** | Global sanctions + PEP + some registry data, entity-resolved. Data is **CC-BY-NC 4.0 — free for non-commercial use**, which covers academic/NGO research. Bulk distributions downloadable. | Data non-commercial free; commercial: Screening API pay-as-you-go with **30-day free trial**, Screening License flat-rate, Reseller License — **actual prices not published, quote only**. | https://www.opensanctions.org/datasets/ ; https://www.opensanctions.org/docs/bulk/ ; https://www.opensanctions.org/licensing/ |
| **OpenOwnership** | Zambia has a **live beneficial ownership register at PACRA (launched 2019), 25% threshold, full-economy coverage** — but **structured data is not publicly available in bulk and is not published as BODS**. OpenOwnership is providing technical assistance to Zambia. Country CSV of the *assessment* is downloadable. | Free | https://www.openownership.org/en/map/country/zambia/ ; CSV: https://www.openownership.org/en/map/country/zambia.csv |
| **OCCRP Aleph** | Aggregates leaked/scraped registries, court records and some customs/trade leaks; African registry coverage is partial. Public search is free; **the deeper collections are restricted to vetted journalists/researchers on request** (the homepage did not render usable text on fetch — verify access terms directly). | Free public tier; vetted access by application | https://aleph.occrp.org/ |

### 1.5 Academic / NGO / civil-society datasets

- **Resource Projects** — https://resourceprojects.org/ — open data on oil, gas and mining
  **payments to governments**, project-level, built largely from EITI + EU/Canada/UK mandatory
  disclosure filings. Company x project x payment stream x year. Contact
  `admin@resourceprojects.org`. Bulk-download terms **not published on the homepage** — check the
  data page. Good for cross-checking who actually pays royalties in Zambia (i.e. who is really
  producing) against your licence roster.
- **Resource Contracts** — https://resourcecontracts.org/ — full text of published mining contracts
  and annotations. For Zambia this is patchy but non-zero. Free.
- **SwissAid African gold studies (2024, updated 2025)** — the reference work on undeclared African
  gold flows, built on **mirror-trade analysis of national customs statistics** across all 54
  African countries over 10+ years. Headline findings: ≥435 t smuggled out of Africa in 2022
  (~USD 31 bn); 2012–2022, 2,569 t entered the UAE from Africa without matching export
  declarations (~USD 115 bn); in 2022 ~80% of African gold exports went to UAE (47%), Switzerland
  (21%), India (12%). Methodologically this is the template to copy for Zambian copper/gems.
  https://www.swissaid.ch/en/media/press-release-gold-study-2024/ ;
  https://www.swissaid.ch/en/media/united-arab-emirates-more-than-ever-a-hub-for-conflict-gold/
- **EITI global production & exports dataset** — https://eiti.org/production-and-exports
- **Mirror-trade / trade-gap literature**: the standard approach (Comtrade reporter-vs-partner
  asymmetry) is free to replicate with §1.1 data. For Zambia specifically the well-known asymmetry
  is Zambia-reported copper exports vs Chinese/Swiss/Emirati imports from Zambia.
- **Panjiva/US-manifest-derived academic releases**: several published papers use licensed
  Panjiva/ImportGenius US AMS manifest extracts, but the underlying data is generally
  **not redistributable**, so replication files rarely contain raw shipment rows. Do not plan on
  obtaining a bulk US manifest set through an academic replication package; plan on either the free
  ImportYeti/Panjiva search tiers or a paid licence (§2).

## 2. Freemium & trial commercial sources

**How to read this section.** Figures marked **[vendor page]** were read off the vendor's own
published pricing page. Figures marked **[third-party]** come from software-review aggregators
(Capterra / G2 / SoftwareSuggest / SaaSworthy / TrustRadius / Vendr) because the vendor's own page
either does not publish a price or **returned HTTP 403 to automated fetching on 2026-07-28**.
Third-party figures are indicative only — **confirm on the vendor page in a browser before
budgeting.** Where nothing is published anywhere, the entry says **not published**.

Several of these sites (importyeti.com, volza.com, exportgenius.in, spglobal.com) block automated
fetches, so a manual browser pass is needed to finalise the numbers. That is flagged per vendor.

### 2.1 US-manifest (CBP AMS) specialists

**ImportYeti** — https://www.importyeti.com/ (pricing: https://www.importyeti.com/pricing ,
https://www.importyeti.com/pricing/supply-chain , https://www.importyeti.com/pricing/sales-prospecting)
- Data: US CBP AMS ocean import bills of lading. This is the source of your existing 24 records.
- **Free tier: yes, "free forever"** — free company/supplier search of US import B/L records with the
  core shipment view. Exact record caps and whether CSV export is included on the free tier are
  **not readable via automated fetch (403)** — verify in browser. **[third-party]** reviewers
  describe the free tier as unusually generous for browsing, with export/bulk features gated.
- Paid **[third-party]**: Supply Chain ≈ **USD 50/month**; Sales Pro ≈ **USD 130/month**;
  Enterprise from ≈ **USD 1,000/org/month**. The supply-chain pricing page is titled
  "Risk-Free Pricing with a 100% Money-Back Guarantee", so a money-back guarantee is advertised.
  Card requirement: **not published**.
- Zambia relevance: **low** (US-bound only) but it is free, so exhaust it first.

**ImportGenius** — https://www.importgenius.com/pricing **[vendor page — full detail published]**
- **No free trial on any plan** (stated explicitly on the pricing page).
- USA Essentials Flex: **USD 229/month**, cancel anytime, **25 searches/day**, **1,000 download
  rows/month**, US import data **most recent 12 months only**, US exports from Jan 2014.
- USA Pro Flex: **USD 449/month**, **50 searches/day**, 1,000 rows/month, US data **2006→present**,
  US exports from Jan 2014, plus AI Company Profiler and HS-code search.
- USA Essentials Annual: **USD 319/month billed annually** (page states 17% discount vs monthly),
  **10,000 rows/month**. USA Pro Annual: discounted annual pricing, **50,000 rows/month**.
  Annual plans require talking to sales.
- Enterprise: **USD 1,999+/month** custom — unlimited searches, custom download volumes,
  **shipment data from 21+ countries**, API access, custom reports.
- **Global Trade Data add-ons** for regional data (Asia, Europe, Latin America, **Africa**) with
  country-specific pricing **starting at USD 199**. → *This add-on line is the thing to ask about
  for Zambia/South Africa/Tanzania; the countries inside the Africa add-on are not enumerated on
  the pricing page.*
- Zambia relevance: **medium** if and only if the Africa add-on covers Zambian or South African
  customs. Ask sales for the country list before paying.

**Panjiva (S&P Global Market Intelligence)** — https://www.spglobal.com/marketintelligence/ (product
campaign page 403'd on fetch)
- Data: US Customs B/L records plus S&P's wider global trade panel; marketed as covering
  ~8 million businesses.
- **Pricing: not published.** S&P quotes only. **[third-party]** Datarade and G2 both record that
  Panjiva has not published pricing (https://datarade.ai/data-providers/panjiva-by-s-p/profile).
- **Free tier:** Panjiva historically allowed limited free keyword search with results teased and
  detail gated. Current free-tier terms: **not published**.
- **Best free route for you: university library access.** Panjiva Supply Chain Intelligence is
  licensed by academic libraries — Stanford, for example, announced it as a new library resource
  (https://libguides.stanford.edu/blogs/library/new/14145/new-resource-panjiva-supply-chain-intelligence).
  **Check Harvard Library's database A–Z for Panjiva / S&P Capital IQ Pro.** If Harvard has it, this
  is a USD 0 route to the best US-manifest dataset, and Capital IQ Pro also carries S&P's global
  trade module. This is the highest-value single action in this document.

### 2.2 India-centric consignment-data vendors (the emerald window)

These matter for Zambia because **Indian import customs records name the Indian importer and the
foreign supplier**, which is how you catch Zambian emerald/beryl and some metal flows that no
US-manifest product will ever see. Most of these vendors are Indian and resell Indian DGCI&S /
customs data plus other countries' manifests.

**Volza** — https://www.volza.com/pricing/ (403 to automated fetch; verify in browser)
- Coverage claim: **203 countries** of export-import data in a single subscription.
- **Free trial: 7-day full-featured trial, and [third-party] reports credit-card details are NOT
  required for the trial.** Also a 3-day 100% money-back guarantee applicable within the first 300
  points consumed. **[third-party]**
- Paid **[third-party]**: Startup **USD 1,500/yr**, SME **USD 4,500/yr**, Corporate
  **USD 9,600/yr**.
- **Pricing model is points-based**, which matters a lot for Zambia: points are deducted per
  shipment record downloaded, and the rate varies by country — **1 point for a US or India
  shipment, up to ~10 points for hard-to-source markets**. A re-download of the same shipment is
  not charged again. So "Zambia" records, if available at all, will burn points fast.
- Zambia relevance: **medium-high** for the India leg, unknown for Zambian customs itself. Use the
  free 7-day trial to test the exact query "supplier country = Zambia" against Indian imports
  before paying anything.

**Export Genius** — https://www.exportgenius.in/company/plan-and-pricing.php (403 to automated fetch)
- Coverage claim: **200+ countries**.
- **Free plan / free trial: yes — a free tier with limited search and download** for platform
  evaluation. Exact caps **not published** in fetchable form.
- Paid **[third-party]**: Starter ≈ **USD 250/month**, Essential ≈ **USD 500/month**, Expert ≈
  **USD 1,200/month**; another aggregator lists a start price of **USD 278/month**.
  Treat as indicative.
- **Zambia coverage: not published** — no source found enumerating Zambia. Must ask.

**Zauba** — https://www.zauba.com/ (search entry: https://www.zauba.com/shipment_search ; 403 to
automated fetch)
- Data: Indian import/export shipment records compiled from shipping manifests, bills of lading,
  bills of entry and shipping bills; the site claims data from 10,000+ ports. Bangalore-based.
- **Historically the most usable free window into Indian consignment data** — HS-code and product
  search pages are publicly indexed (e.g.
  https://www.zauba.com/import-shipment+data-hs-code.html ,
  https://www.zauba.com/export-search-hs-code.html) and show per-shipment date, HS code, product
  description, quantity, unit price and origin/destination port. Free access to *importer names* has
  been progressively restricted over the years.
- **Pricing: not published.** Datarade records that Zauba has not published pricing
  (https://datarade.ai/data-providers/zauba/profile).
- Note: **Zauba Corp** (https://www.zaubacorp.com/) is a *different* product — Indian company
  registry/filings, not shipments. Irrelevant to Zambia except for Indian counterparties (Jaipur
  emerald importers), where it is genuinely useful and largely free.
- Zambia relevance: **high for emeralds via the India leg**, at zero or low cost. Try
  `HS 710310 / 710391 / 711011` searches filtered to Zambia as origin.

**Seair Exim Solutions** — https://www.seair.co.in/ (pricing page 403 to automated fetch)
- Data: Indian customs import/export plus other countries; sells country data packs and a
  subscription platform.
- **Free tier / trial: a free sample-data request and demo are advertised on the site; specific
  record caps not published.**
- **Pricing: not published** in fetchable form. Historically Seair quotes per-country/per-year packs
  on request.
- Zambia relevance: same as Export Genius — useful only via the India leg unless they can prove
  Zambian coverage.

**52wmb** — https://www.52wmb.com/
- Chinese-operated global trade data aggregator (Qingdao). Markets "free" customs data search with a
  registration wall and heavy gating on record detail.
- **Free tier: registration-gated free searches advertised; exact caps not published.**
  **Pricing: not published.**
- Zambia relevance: **low-to-unknown**. Its value proposition is Chinese buyer discovery. Chinese
  *import* consignee-level data is not published by China Customs, so no vendor can legitimately
  give you Chinese consignee names for Zambian copper at scale — be sceptical of any that claims to.

### 2.3 Enterprise trade-data platforms

**Trademo (Trademo Intel)** — https://www.trademo.com/pricing **[vendor page]**
- Coverage claim: **3 billion+ shipment records, 10M+ companies, 190+ countries**, data from 2011
  onwards where applicable; US updated daily, international weekly/monthly.
- **Pricing: custom plan only, no published figures.** Published *allocations* for the custom plan:
  **up to 500,000 download credits/year, up to 10,000 value-add credits/year**, multiple user
  licences. "Talk to Sales" only.
- **Free trial: not specified on the pricing page.**
- Zambia relevance: worth one sales conversation specifically to ask "do you have Zambia, South
  Africa, Tanzania, Namibia or Mozambique customs records, and can I see a Zambia sample?"

**Tendata** — https://www.tendata.com/ (pricing pages 403 to automated fetch)
- Coverage claim (vendor blog): **228+ countries, 10 billion+ records**.
- **Pricing: not published** — quote-based. Vendor states packages include a master account plus two
  sub-accounts (all three can log in simultaneously) and **24 weeks of download credits per year per
  package**. Free demo offered; a free trial period "may" be offered.
  (https://www.tendata.com/news/4324.html , https://www.tendata.com/news/4849.html)
- Treat the "228 countries" claim with care: for most African countries these platforms hold
  *aggregate* HS statistics, not consignment records, and the marketing does not distinguish.

**TradeAtlas** — https://www.tradeatlas.com/en (prices page 403 to automated fetch;
data packages: https://www.tradeatlas.com/en/solutions-data-packages)
- Turkish-operated global importer/exporter search engine.
- **Free tier: yes — a free version with limited functionality, free sign-up. [third-party]**
- Paid **[third-party]**: freemium model, roughly **USD 100–500/month**; subscriptions are stated to
  run **365 days**. So ≈ USD 1,200–6,000/yr. Exact tier names/caps **not published**.
- Zambia relevance: unknown; ask for a Zambia sample.

**Descartes Datamyne** — https://www.datamyne.com/our-product/datamyne-pricing/ **[vendor page]**
- Coverage claim: **US trade data with unlimited searches, daily updates, history back to 2004**;
  global import/export covering "nearly every country" with multi-country search; plus a Market
  Insight tier with Power BI dashboards. Other Descartes materials cite **230 markets** (strong in
  Latin America, Russia, China, Southeast Asia) or 190+ countries.
- **Pricing: not published — "Contact Us For Pricing" on every tier.** Subscriptions are described
  as *unmetered annual* access to all or selected countries, including training and support.
- **Free trial: yes, a free-trial registration exists**
  (https://www.datamyne.com/global-trade-analytics-free-trial/). **[third-party]** reports credit
  card details are **not** required for the trial — verify.
- Zambia relevance: Datamyne's African consignment coverage is its weakest region. The unmetered
  annual model is attractive *if* they hold South African or Tanzanian records.

**Panjiva** — see §2.1 (pricing not published; pursue via Harvard Library).

### 2.4 Risk / entity-intelligence platforms (ownership + some trade)

**Sayari (Sayari Graph)** — https://sayari.com/platform/graph/
- Data: **500M+ resolved companies, 11.7B+ primary-source records, 1.8B+ trade records**, entity
  resolution across corporate registries, and network/ownership traversal with source-linked
  evidence. **Supply Chain Mapping is a premium add-on inside Graph.**
- **Pricing: not published.** Licensing is described as **per entity under management**; custom
  quotes only (https://www.vendr.com/marketplace/sayari records no public list price).
- **Free tier / trial: not published.** No public free search.
- Zambia relevance: **this is the strongest single paid product for your actual use case** — see §5.
  It is the only major platform that combines (a) African corporate registry coverage with entity
  resolution and (b) a large trade-record corpus, which is exactly the join you need to link a
  licence holder to a shipper. Confirm PACRA/Zambia registry coverage and ask for a Zambia sample
  before committing. Nonprofit/academic pricing is **not published** but is worth asking for.

**Kharon** — https://kharon.com/
- Data: sanctions/nexus risk research — deep human-analyst dossiers on sanctioned networks, their
  subsidiaries and counterparties. Not a bulk shipment database.
- **Pricing: not published. Free tier: none published.**
- Zambia relevance: **low** unless a specific Zambian entity has a sanctions/PEP nexus you are
  chasing. Not a coverage play.

**Windward (Maritime AI)** — https://windward.ai/
- Data: AIS-derived vessel behaviour and risk analytics; modular packages (compliance, risk, supply
  chain visibility).
- **Pricing: not published** — licensing with perpetual and subscription options, customised by
  scope/data volume/integration; demos on request.
  **No free trial and no freemium version.** **[third-party]**
  (https://datarade.ai/data-providers/windward/profile)
- Zambia relevance: low for cargo attribution; useful only for vessel-level compliance questions.

**MarineTraffic (Kpler)** — https://www.marinetraffic.com/ (plans page 403 to automated fetch)
- Free website: live AIS map, vessel search, port calls, basic vessel particulars. Historical track
  data and expiring/older port-call history are gated.
- Paid **[third-party]**: tiers reported as **Basic ~£10/month, Essential ~£100/month, Enterprise —
  contact Kpler**. Reported that MarineTraffic **discontinued credit-based API pricing and moved to
  enterprise subscriptions only**, so API access now requires a sales conversation
  (https://g2.com/products/kpler-marinetraffic/pricing ;
  https://datadocked.com/ais-api-providers). Confirm on the site — this changed recently.
- Zambia relevance: **medium** as a corridor proxy (see §4). Cheapest way to get port-call and
  vessel-movement evidence for Dar/Durban/Walvis/Beira.

**Kpler** — https://www.kpler.com/ (acquired MarineTraffic and FleetMon; acquisition closed
7 March 2023 — https://www.kpler.com/blog/kpler-acquires-marinetraffic-and-fleetmon-for-maritime-sector-expansion)
- **Does cover dry bulk and metals:** "Ags, Metals & Dry" solution
  (https://www.kpler.com/solution/ags-metals-dry) and dry-bulk flows product
  (https://www.kpler.com/product/commodities/dry-bulk-flows-and-insight). Tracks **16,500+ dry bulk
  carriers**, with commodity granularity down to grades/sub-grades and cargo quality; up to 15 days
  predictive cargo flows, up to 18 months market forecasts.
- **Pricing: not published** — enterprise quote only. **Free tier: none published.**
- Zambia relevance: **this is the best commercial proxy for the copper corridors**, because Kpler
  infers *cargo* (commodity, tonnage, origin/destination) rather than just vessel positions. What it
  will **not** give you is the Zambian shipper name — its granularity is vessel + commodity + port
  pair, so it tells you "X kt of refined copper left Dar for Shanghai" not "Mopani shipped it".
  Realistically an enterprise-priced product (tens of thousands USD/yr class, but **not published**).

**Lloyd's List Intelligence / Seasearcher** — https://www.lloydslistintelligence.com/
- Data: vessel ownership, movements, port calls, casualty and sanctions risk; the authoritative
  vessel-registry layer.
- **Pricing: not published** — quote only. Some editorial content is metered-free.
- Zambia relevance: low-medium; it identifies vessels and owners, not cargo owners.

**Other AIS options worth knowing (free / cheap):**
- **VesselFinder** — https://www.vesselfinder.com/ — free live map + free vessel search; paid API and
  satellite AIS. Published API price list: **not published** (quote/credit based).
- **Spire Maritime** — https://spire.com/maritime/ — satellite AIS provider; **pricing not
  published**, enterprise API.
- **AISHub** — https://www.aishub.net/ — **free AIS data exchange**: you get access to the shared
  feed *if you contribute your own AIS receiver station*. No receiver, no data. Not practical here.
- **Global Fishing Watch** — https://globalfishingwatch.org/ — free AIS-derived vessel data and API,
  but scoped to **fishing and carrier vessels**; bulk carriers are largely out of scope. Not useful
  for copper.
- **NOAA / national AIS archives** — free but coastal-US only. Not useful for African ports.

## 3. Why Zambia is hard

This section exists because the obvious plan — "buy a bill-of-lading database and look up my 3,600
companies" — will fail for Zambia, and it is worth knowing *why* before spending money.

### 3.1 The structural problem: no ocean bill of lading is issued in Zambia

A **bill of lading** is a maritime document. It is created when cargo is loaded onto a vessel, by the
ocean carrier, at a seaport. Zambia is landlocked and has no seaport. Therefore:

- Zambian cargo travels first under a **road consignment note (CMR-equivalent)** or a **rail
  waybill** to a coastal port, typically consolidated or handed to a freight forwarder en route.
- The ocean B/L is then issued at Durban, Dar es Salaam, Walvis Bay, Beira, Nacala, Maputo or Lobito
  — and the **shipper named on it is very often the freight forwarder, the trading house, or a
  South African/Tanzanian logistics entity, not the Zambian mine.**
- So even a perfect global B/L database frequently resolves to "SBS Transport", "Bolloré", "Grindrod",
  "Manica", "Mitchell Cotts", "CEVA", or a Swiss/Singapore trader — not "Chambishi Metals" or the
  junior licence holder you actually care about.

**Consequence:** B/L data for Zambia is best treated as *corridor and consignee intelligence*
(who receives Zambian metal abroad, through which port, at what cadence) rather than as a
company-level export ledger for Zambian licence holders.

### 3.2 The US-manifest problem: the data everyone can get is the data Zambia doesn't use

Free and cheap B/L data (ImportYeti, ImportGenius free previews, Panjiva free search) is
overwhelmingly **US CBP AMS import manifest** data — records created because cargo entered a US
port. Your 24 existing records are this.

But Zambia's copper does not go to the US in meaningful volume. The destinations are:

| Zambian export flow | Physical route | Appears in US CBP AMS? |
|---|---|---|
| Refined copper cathode → China | Rail/road to Dar es Salaam or Durban → vessel to Chinese ports | **No** |
| Blister / anode copper → China smelters | Road to Dar/Durban/Walvis → vessel to China | **No** |
| Copper cathode → Switzerland/Singapore/UAE (invoiced) | Physically often still to Asia; the Swiss/Singapore leg is a *trading* not a shipping leg | **No** |
| Cobalt hydroxide/concentrate → China | Same corridors | **No** |
| Manganese ore → China/India | Road to Dar/Beira | **No** |
| Emeralds / beryl → India (Jaipur), Thailand (Bangkok), Israel, Hong Kong | **Air freight from Lusaka/Ndola, or hand-carried to auction** | **No** |
| Gemstones, small parcels of specialty metal → US buyers | Air or container into US | **Yes — this is your 24 records** |
| Sugar, cotton, tobacco, some agri → US (AGOA) | Container via Durban/Beira | Yes, but not minerals |

So the free/cheap manifest universe captures perhaps a low single-digit percentage of Zambian
mineral export value, and it is **biased towards small US-bound gemstone and non-mineral
consignments**. That is a real finding worth stating in the project, not a defect to be fixed by
buying more of the same data.

### 3.3 The air-freight problem: emeralds

Zambian emerald and beryl (Kagem, Grizzly, Kariba amethyst, and dozens of small licence holders)
move by **air**, in low-weight/high-value parcels, to auction and cutting centres — Jaipur,
Bangkok, Hong Kong, Tel Aviv, and Kagem's own auctions (historically Singapore/Lusaka/Jaipur).
Air waybills are **not** in any of the commercial B/L products, which are ocean-manifest based.
Coverage options for gems are therefore:

- Indian **import** customs data (Zauba / Export Genius / Seair / Volza cover Indian imports at
  consignment level, including Indian importer name) — this is the single best window on Zambian
  emerald flows, because Jaipur importers must file Indian customs entries.
- ZEITI + Gemfields' own listed-company disclosures (Kagem auction results are published by
  Gemfields in London-listed RNS announcements — free, company-level, revenue and carat data).
- Comtrade HS 7103 mirror data (Zambia-reported vs India/Thailand-reported).

### 3.4 The transit-attribution problem: DRC metal in Zambian statistics

ZEITI itself warns that Zambian exports include copper concentrates produced in the DRC but smelted
in Zambia, plus straightforward DRC transit through Kasumbalesa. Any figure you derive from
"Zambia exports" — official or mirror — carries this contamination. Conversely some Zambian metal is
exported *through* the DRC/Lobito and may be attributed elsewhere.

### 3.5 Which source type actually covers which corridor

| Corridor / flow | Best source type | Specific sources |
|---|---|---|
| Zambia → Dar es Salaam → China (copper, cobalt) | Port transit statistics + AIS + Chinese import mirror data | TPA transit-cargo statistics (aggregate, by destination country); Comtrade/Trade Map China-reported imports from Zambia; AIS (§4) |
| Zambia → Durban/Richards Bay → Asia | South African port statistics + SARS trade data + AIS | Transnet port statistics; SARS monthly trade data; Ports & Ships line-ups |
| Zambia → Walvis Bay → Asia/Europe | Namport annual statistics (transit cargo by country) | Namport annual reports |
| Zambia → Beira/Nacala → Asia | Cornelder/CFM throughput reports (thin) | see §4 |
| Zambia → Lobito → Atlantic | Lobito Atlantic Railway / Angolan port reports (very thin, new) | see §4 |
| Zambia → India (emeralds, some metal) | **Indian import consignment data — the best company-level window available** | Zauba, Export Genius, Seair, Volza, Trademo |
| Zambia → US (gems, agri) | US CBP AMS manifests | ImportYeti, ImportGenius, Panjiva |
| Zambia → China (all) | Chinese customs *aggregate* only; China stopped publishing consignee-level detail | Comtrade, Trade Map, Chinese customs statistical yearbooks |
| Ownership / who is behind a licence | Corporate registries | PACRA, OpenCorporates, OpenSanctions, Sayari |
| Who actually produces and pays | EITI reconciliation | ZEITI report annexes |

## 4. Vessel tracking (AIS) as a BoL proxy, and what port authorities publish

### 4.1 What AIS can and cannot establish

AIS is a vessel-safety broadcast: MMSI/IMO, position, speed, course, draught, destination as typed by
the crew. It says nothing about cargo ownership. What you can and cannot derive:

| Question | Can AIS answer it? |
|---|---|
| Did a bulk carrier load at Dar es Salaam and discharge at Shanghai? | **Yes** — port calls + track |
| How much cargo did it carry? | **Approximately** — from draught change between load and discharge (this is the core of Kpler's method) |
| Was the cargo copper? | **Inferred only** — from berth/terminal identity, vessel type, and corroborating trade data |
| Who was the shipper? | **No** |
| Which Zambian licence holder produced it? | **No** |
| Did volumes shift from Durban to Dar after a rail disruption? | **Yes, well** — this is AIS's strongest use for you |

**So: AIS is a corridor-level proxy, not a BoL substitute.** It is excellent for (a) corroborating
official aggregate export figures against physical departures, (b) detecting corridor switching
(Durban ↔ Dar ↔ Walvis ↔ Beira ↔ Lobito), (c) timing — spotting export surges that precede or lag
reported figures, and (d) identifying the small set of specialist copper-carrying vessels and
operators on these routes, which then become searchable names in other datasets.

Practical recipe at low/zero cost: use the **free MarineTraffic or VesselFinder port pages** for
Dar es Salaam, Durban, Richards Bay, Walvis Bay, Beira, Nacala and Lobito to harvest arrivals /
departures / expected-vessel lists (e.g. https://www.vesselfinder.com/ports/ZADUR001 for Durban),
then join vessel names to Kpler/Lloyd's-style commodity attribution only if you later buy it.

Where AIS *does* substitute meaningfully for a B/L is the **Zambia→Asia leg**: since no US manifest
exists for that flow and China publishes no consignee data, a departure record + tonnage estimate is
often the only physical evidence available.

### 4.2 Do any port authorities publish berth or consignment lists?

**Short answer: berth/vessel line-ups yes (operationally, transiently); consignment lists naming
shippers, no. Nobody on these corridors publishes shipper- or consignee-level cargo data.**

| Port / authority | What is published | Company-level? | Link |
|---|---|---|---|
| **Tanzania Ports Authority (TPA)** | Annual Report & Accounts (latest listed: FY ended 30 June 2022, published Dec 2024 — the reports page is sparse and behind actual data collection). TPA does publish **transit cargo tonnage broken down by destination country**, which is the single most useful corridor figure for Zambia. Reported 2025 figures: total transit cargo **14,250,087 t** (up from 9,187,061 t in 2024); **DRC 7,239,741 t (51%)**, **Zambia 3.5 M t (second largest)**, Rwanda 2.2 M t, Malawi 719,838 t, Burundi 494,698 t, Uganda ~47,605 t. | **No** — country-level, not company | https://ports.go.tz/index.php/en/publications/reports-annual-reports-and-accounting ; FY2022 report: https://www.ports.go.tz/images/documents/reports/TPA_Annual_Report_LW_FOR_WEBSITE.pdf ; 2025 figures reported via https://thechanzo.com/2026/07/04/drc-emerges-as-largest-transit-cargo-market-for-tanzania-ports |
| **Transnet (South Africa)** | A live **"Vessel Updates List"** covering Durban (Gateway, Container Terminal Pier 1, RoRo), Cape Town (Combi, Container), Ngqura Container Terminal, Port Elizabeth (Container, MPT RoRo), timestamped and refreshed continuously (e.g. "27 Jul 2026 07:02"). These are operational terminal updates / line-ups. **No cargo owner names visible.** Also TNPA port brochures with capacity data. Note these files are transient — if you want a time series you must harvest them on a schedule. | **No** | https://www.transnet.net/SubsiteRender.aspx?id=8185344 ; TNPA: https://www.transnet.net/TNPA ; Durban brochure: https://www.transnetnationalportsauthority.net/OurPorts/Durban/Documents/(TNPA)%20Durban%20Brochure.pdf |
| **Namport (Namibia)** | **Integrated Annual Report** (latest FY ended March 2025), PDF. Publishes cargo volumes by type (TEUs, general cargo tonnes), **cross-border cargo volumes by country including Zambia**, vessel calls and gross tonnage. Annual only — no monthly, no detailed commodity split. Walvis Bay is explicitly growing Zambian/DRC copper volumes; DRC alone was ~10% of cross-border cargo in 2025. | **No** — country-level | https://www.namport.com.na/about-namport/statistics/490 ; example report: https://www.namport.com.na/files/documents/af7_Annual%20Report%2012%20months%20ended%2031%20March%202020.pdf |
| **Mozambique — Cornelder de Moçambique (Beira)** | CdM is a JV of CFM and Cornelder Holdings (Rotterdam), operating Beira's container and general cargo terminals since Oct 1998. Throughput figures appear in press releases and trade press rather than a statistics portal; **no systematic public statistics series found**. Zambian copper is a known significant flow through Beira. | **No** | https://africaports.co.za/beira/ |
| **Mozambique — CFM / Nacala corridor** | Nacala handles ~3.5 M t/yr against 10 M t capacity. Figures come from press and consultancy reports, not a published statistics series. | **No** | https://www.reloadlogistics.com/news/mozambique-infrastructure-upgrades-beira-and-nacala-corridors |
| **Lobito / Angola** | Lobito Atlantic Railway is new; volumes appear in press releases and corridor-investor material. **No public statistics series found.** | **No** | — |
| **Africa Ports (africaports.co.za)** | News/reference portal with port profiles. Checked directly: **it does not publish an ongoing statistical series** — only occasional historical aggregates (e.g. TNPA handled 236 Mt and 13,000 vessel calls Apr 2010–Mar 2011). Do not rely on it as a data source. | No | https://africaports.co.za/transnet-national/ |
| **Regional / multilateral** | UNCTAD port-call and liner-connectivity statistics (free, vessel-call derived, country-level); World Bank Container Port Performance Index; PMAESA. All aggregate. | No | https://unctadstat.unctad.org/ |
| **Tanzania sector statistics** | Tanzania Ministry of Works & Transport publishes a Transport & Meteorology Sector Statistics volume with port and rail throughput | No | https://mow.go.tz/uploads/documents/sw-1689069736-TRANSPORT%20AND%20METEOROLOGY%20SECTOR%20STATISTICS%20-%202021%20FINAL.pdf |
| **TAZARA (rail)** | Publishes tonnage moved on the Tanzania–Zambia railway in annual/press reporting; corridor volume only | No | — |

**Implication for the project:** the corridor layer of your dataset can be built entirely free
(TPA transit-by-country + Namport cross-border-by-country + Transnet line-ups + AIS port calls), and
it will let you say authoritative things about *where Zambian minerals physically exit and in what
volume*. It will never let you attribute a shipment to a licence holder. Company-level attribution
has to come from ZEITI (top of the market), Indian import records (gems), US manifests (the thin US
slice), or a paid entity-resolution platform (§2.4).

## 5. Recommended plan

Ordered by **coverage gained per dollar**. Do all of Tier 0 before spending anything.

### Tier 0 — free, do these first (total cost: USD 0)

| # | Action | What it buys you | Effort |
|---|---|---|---|
| 1 | **Check Harvard Library for Panjiva / S&P Capital IQ Pro** (and for Sayari, Kpler, Lloyd's List — some universities license these) | Potentially the entire premium US-manifest + global trade panel at zero cost. **Highest expected value of any single action in this document.** | 30 min |
| 2 | **Apply to OpenCorporates for free at-scale academic/NGO access** (https://opencorporates.com/pricing/) — they explicitly offer this to universities and anti-corruption researchers | Entity resolution layer for your 3,600 companies; otherwise £2,250–12,000/yr | 1 hr application |
| 3 | **Build the Comtrade mirror-trade table** for HS 2603, 7402, 7403, 7404, 7407, 8105, 2602, 7103, 7113, 7108: Zambia-reported exports vs China / Switzerland / UAE / India / South Africa / Singapore-reported imports from Zambia, 2010→latest | The defensible headline analysis: the size and direction of Zambia's reporting gap. Free-tier 500-record cap is fine if you loop by year/HS | 1–2 days |
| 4 | **Register for ITC Trade Map** and pull the same series — *all features are free in the beta until launch (planned July 2026)*, and low/middle-income-country users are free permanently | Better mirror-data handling than raw Comtrade; monthly series | 3 hrs |
| 5 | **Extract every ZEITI report annex (XLS/XLSX) 2016→2024** and parse company/project-level production and export rows | The **only free company-level Zambian export figures that exist**. Validation set for your top ~50 holders | 1 day |
| 6 | **Harvest the corridor layer**: TPA transit cargo by destination country, Namport cross-border cargo by country, Transnet Vessel Updates List (schedule a weekly capture — the files are transient), Tanzania MoWT sector statistics | Physical export volume by corridor, free, defensible | 1 day + ongoing cron |
| 7 | **Free Indian-import searches for emeralds/beryl** on Zauba HS-code pages (710310, 710391, 711011, 710391) filtered to Zambian origin; cross-check Gemfields/Kagem auction RNS disclosures | The gem corridor, which no B/L product covers | 1 day |
| 8 | **Exhaust the ImportYeti free tier** on all 3,600 company names + known aliases and trading-house names (not just the mines) | Extends your 24 records; will still be a small absolute number | 1–2 days (scripted, respect their ToS and rate limits) |
| 9 | **Download SARS Trade Stats Portal data** (free bulk download, monthly, HS-level) for South Africa's recorded imports from and exports to Zambia | The Durban corridor's customs-side mirror; genuinely free and detailed | 3 hrs |
| 10 | **Download OpenSanctions bulk** (CC-BY-NC — free for your non-commercial research) and screen all 3,600 names | Sanctions/PEP flags on licence holders | 3 hrs |
| 11 | **Free AIS port-call harvesting** from MarineTraffic/VesselFinder port pages for Dar, Durban, Richards Bay, Walvis Bay, Beira, Nacala, Lobito | Vessel-level corroboration of corridor volumes | 1 day + cron |
| 12 | **Pull Resource Projects payment data** for Zambia (`admin@resourceprojects.org`) and Resource Contracts documents | Who actually pays royalties = who actually produces | 3 hrs |

**Realistic outcome of Tier 0:** a complete corridor-and-aggregate picture, company-level coverage of
the top of the market (via ZEITI + Resource Projects), a defensible mirror-trade gap estimate, gem-flow
evidence via India, and full entity resolution — for **USD 0**. Your BoL count will go from 24 to
maybe a few hundred, and that is a ceiling imposed by reality, not by budget.

### Tier 1 — free trials, exhausted deliberately (cost: USD 0, plus your time)

| Action | Terms |
|---|---|
| **Volza 7-day full-featured trial** — reportedly **no credit card required** | Use it to run exactly one test: does Volza hold *consignment-level* records where origin/supplier country = Zambia, and where destination = India/China/South Africa? Download the maximum permitted sample before it expires. Also test their points cost per Zambian record. |
| **Descartes Datamyne free trial** (https://www.datamyne.com/global-trade-analytics-free-trial/) — reportedly no card required | Same test. Datamyne's unmetered annual model is the best structure *if* African coverage exists. |
| **Export Genius free plan** | Limited search/download; test Zambia and India-import queries. |
| **TradeAtlas free version** | Free sign-up, limited functionality; test Zambia. |
| **Tendata free demo** | Demand a live Zambia query during the demo; do not accept a country-count claim. |

**The one question to ask every vendor:** *"Show me, live, ten consignment-level records where the
exporter country is Zambia, with the exporter name visible, in the last 12 months."* If they can't,
their "228 countries" is aggregate statistics you can get free from Comtrade. This single question
will eliminate most of §2.

### Tier 2 — small paid spends, only if Tier 1 proves coverage (USD 200–2,000)

| Spend | Price | Buy it if |
|---|---|---|
| **ImportGenius Africa add-on** | from **USD 199** (country-specific, on top of a base plan) | Their Africa pack demonstrably includes Zambia or South Africa consignment records |
| **ImportGenius USA Pro Flex, 1–2 months** | **USD 449/month**, 50 searches/day, 1,000 rows/month, US history 2006→present | You want the full US-manifest history on your 3,600 names in one burst, then cancel (no annual lock on Flex) |
| **Volza Startup** | **USD 1,500/yr** (points-based; ~1 point per US/India record, up to ~10 for hard markets) | The trial showed real Zambian or Indian-import records. Budget points carefully |
| **MarineTraffic Essential** | ~**£100/month** *[third-party — confirm]* | You need historical vessel tracks/port-call history rather than just live positions, for a few months of corridor analysis |

### Tier 3 — the enterprise option (pricing not published; expect five figures USD/yr)

**Single best paid option for Zambia specifically: Sayari.** Reasoning:

- It is the only major platform that puts **1.8B+ trade records** and **500M+ resolved companies from
  primary-source corporate registries** in the same graph, with **automated ownership traversal** —
  which is precisely the join your project needs (licence holder → legal entity → parent → shipper /
  counterparty).
- Your bottleneck is **not** more US manifests; it is **attribution** — connecting a shipment or a
  foreign counterparty back to one of your 3,600 licence holders. Sayari is built for that; Panjiva,
  ImportGenius and Volza are built for sales prospecting.
- African registry and PEP coverage is a Sayari selling point in a way it is not for the
  India-centric vendors.
- **Caveats:** pricing is **not published** (licensed per entity under management), Supply Chain
  Mapping is a **paid add-on**, and there is **no published free tier or trial**. Before signing:
  demand a Zambia proof-of-value — "resolve these 50 PACRA-registered licence holders and show me
  their trade counterparties" — and ask explicitly for academic/nonprofit pricing.

**Runner-up, different job: Kpler.** If your question becomes "how much copper physically left each
corridor each month, and where did it go", Kpler's dry-bulk cargo attribution (16,500+ bulkers,
commodity granularity to grade level) is the best product on the market. It will not name Zambian
shippers. Buy Sayari for *who*, Kpler for *how much and where*. Do not buy both.

**Do not prioritise:** Kharon (sanctions dossiers, wrong tool), Windward (no freemium, vessel-risk
focus), Lloyd's List Intelligence (vessel registry, not cargo owners), 52wmb (unverifiable Chinese
consignee claims), Panjiva at list price (get it via the library instead).

### Cost summary

| Scenario | Annual cost | Coverage gained |
|---|---|---|
| Tier 0 only | **USD 0** | Corridors, aggregates, mirror-trade gap, ZEITI company-level top-of-market, gems via India, entity resolution, sanctions screening |
| Tier 0 + 1 + targeted Tier 2 | **USD 200–2,000** | Above, plus whatever consignment-level Zambian/Indian/South African records actually exist, plus full US-manifest history |
| Tier 0 + 1 + Sayari | **USD 0 + Sayari quote (not published)** | Above, plus systematic attribution of foreign counterparties to Zambian licence holders — the thing you actually can't build yourself |

---

## 6. Direct-request / FOI route

This route is under-used and, for Zambia, potentially higher-yield than anything purchasable. ZRA holds
**8-digit, declaration-level export data** (Zambia applies HS 2022 at 8 digits under the Zambia Customs
Tariff). It does not publish it. Asking is free.

**Legal hook:** Zambia enacted an **Access to Information Act (Act No. 20 of 2023)**. *Verify its
commencement status and the designated information officer for each agency before citing it* — the
implementation timetable and designated officers should be confirmed on each agency's website. Even
without the Act, statistics offices in the region routinely fulfil academic microdata requests under a
data-use agreement, especially with a university affiliation and a stated non-commercial purpose.

### What to ask for (in descending order of ambition)

1. **Anonymised transaction-level export records**: date, 8-digit HS, quantity, unit, FOB value,
   destination country, exit border post/port, mode of transport — *with the exporter name replaced by a
   stable pseudonymous ID*. This is the ask most likely to succeed, because it removes the
   commercial-confidentiality objection while preserving everything you need for structure.
2. **Exporter-named records for mineral HS chapters only** (26, 71, 74, 75, 78, 79, 81), on the argument
   that mineral exporters' identities are already public via ZEITI and the mining cadastre.
3. **Aggregated exporter counts and volumes by HS x destination x month** — the fallback that almost
   always gets granted.
4. **The ZEITI reporting templates as submitted** (Excel), rather than the reconciled PDF summary.

### Published contact points

| Body | Contact | Notes |
|---|---|---|
| **ZamStats (Zambia Statistics Agency)** — External Trade Branch is the compiling unit | **info@zamstats.gov.zm**, **dissemination.office@gmail.com**; [office line redacted - see private/], [office line redacted - see private/], [office line redacted - see private/]; Nationalist Road, P.O. Box 31908, Lusaka | Also runs a Zambia Data Portal, National Data Archive and National Summary Data page. **Copperbelt provincial office, Ndola: 0212 621583** — useful for mine-region queries. Divisions page: https://www.zamstats.gov.zm/divisions/ ; contacts: https://www.zamstats.gov.zm/contact-us/ |
| **ZRA (Zambia Revenue Authority)** — Customs Services Division; Research & Policy | **Contacts not captured: `zra.org.zm` returned a TLS certificate-chain error to automated fetching on 2026-07-28.** Take the call-centre number, `advice@`-style mailbox and the designated information officer from https://www.zra.org.zm/contact-us/ in a browser and record them here. | ZRA is the *only* holder of declaration-level Zambian export data. This is the single most valuable request to get right. Customs downloads: https://www.zra.org.zm/download-category/customs/ |
| **ZEITI Secretariat** | Via https://zambiaeiti.org/ (contact page); international EITI: https://eiti.org/countries/zambia | Ask for the underlying reporting templates and any unpublished annexes |
| **Ministry of Mines and Minerals Development / Mining Cadastre** | See `research/cadastre_contacts_probe.md` in this repo | Already probed for this project |
| **Tanzania Ports Authority** | **dg@ports.go.tz**; toll-free **0800-110032** | Ask for the transit-cargo-by-destination-country and by-commodity series (they clearly compile it — 2025 figures were released to press). Request the time series as Excel |
| **Namport (Namibia)** | **customercare@namport.com.na**; +264 64 208 2111; Nr 17 Rikumbi Kandanga Rd, P.O. Box 361, Walvis Bay | Ask Corporate Communications for the cross-border-cargo-by-country series beyond what the Integrated Annual Report shows |
| **Transnet / TNPA (South Africa)** | Via https://www.transnet.net/TNPA | Ask for historical cargo statistics by port and cargo category; also ask whether archived Vessel Updates files are retained |
| **SARS (South Africa)** | Trade Stats Portal: https://tools.sars.gov.za/tradestatsportal/data_download.aspx (free bulk download); query address published on https://www.sars.gov.za/customs-and-excise/trade-statistics/ (email is obfuscated on the page — read it in a browser) | **Already free and detailed — download before requesting anything** |
| **PACRA (Zambia company registry)** | https://search.pacra.org.zm/ ; fees: https://www.pacra.org.zm/fees-and-forms | No bulk feed or API. Per-document fees ~USD 5–14 equivalent in ZMW. Worth asking whether a research bulk extract is possible; OpenOwnership is already providing them technical assistance and may broker an introduction |
| **OpenOwnership** | https://www.openownership.org/en/map/country/zambia/ | They work directly with PACRA on the beneficial ownership register — a good intermediary for a bulk-data conversation |
| **Cornelder de Moçambique (Beira)** / **CFM** | Via https://africaports.co.za/beira/ for corporate details | Long shot; no statistics series published |
| **UN Comtrade support** | **comtrade@un.org** | For API key/limit questions and bulk-data quotes (https://shop.un.org/databases) |
| **Resource Projects** | **admin@resourceprojects.org** | For bulk payment data |

### Practical notes on making the request

- Lead with the **university affiliation and a non-commercial, published-research purpose**, and offer a
  **data-use agreement plus a commitment not to republish record-level data**. Agencies refuse
  "give me your database"; they often grant "anonymised microdata for academic analysis under DUA".
- Ask for the **series they already compile** rather than a custom extract wherever possible — TPA
  clearly compiles transit cargo by country because it briefs the press on it; asking for "the table you
  gave the press, as Excel, for 2015–2025" has a much higher hit rate than a novel query.
- Expect 4–12 weeks. Send all requests in parallel in week 1 of the project, not sequentially.
- Log every request and response in this repo so the *absence* of data becomes a documented finding —
  for a legibility project, "ZRA declined to release aggregate exporter counts" is itself a result.

---

## Appendix: fetch-blocked sources needing a manual browser pass

These pages returned HTTP 403 or TLS errors to automated fetching on 2026-07-28. Their numbers in this
document are either marked **[third-party]** or missing, and should be confirmed by hand:

- importyeti.com/pricing and /pricing/supply-chain and /pricing/sales-prospecting (403)
- volza.com/pricing (403)
- exportgenius.in pricing (403)
- seair.co.in/pricing.aspx (403)
- tendata.com/price (403)
- tradeatlas.com/en/prices (403)
- zauba.com (403)
- marinetraffic.com/en/online-services/plans (403)
- spglobal.com Panjiva campaign page (403)
- trademap.org/Index.aspx (403 — registration/login gated)
- zra.org.zm (TLS certificate-chain verification failure)
- resourceprojects.org data/download terms (homepage fetched, download terms not published there)
- aleph.occrp.org (page did not render text to the fetcher; access terms unconfirmed)
- UN Comtrade developer portal products/limits pages (login-gated)
