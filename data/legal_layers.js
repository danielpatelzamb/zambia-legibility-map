// legal_layers.js: documented disputes, fraud cases and license datasets.
// Compiled from public reporting (agents' web research, 2026-07-23).
// Coordinates are approximate, the mine/site or nearest town, not legal filings.
window.LEGAL = {

  cases: [
    {
      name: "Vedanta/KCM provisional liquidation & settlement",
      category: "tax-corporate-dispute", lat: -12.37, lng: 27.83, years: "2019-2024",
      summary: "In May 2019 state firm ZCCM-IH petitioned to wind up Konkola Copper Mines (Chililabombwe/Chingola), placing it under a provisional liquidator; Vedanta pursued arbitration in Johannesburg and injunctions against asset sell-offs. A Sept 2022 standstill led to settlement: in 2024 the Lusaka High Court lifted the liquidation, ZCCM-IH withdrew its petition, and Vedanta regained control, committing ~$250M to pay KCM creditors.",
      source: "Lusaka Times", sourceUrl: "https://www.lusakatimes.com/2024/07/26/vedanta-resources-takes-over-konkola-copper-mines/"
    },
    {
      name: "Glencore's Mopani exit and IRH takeover",
      category: "tax-corporate-dispute", lat: -12.82, lng: 28.21, years: "2021-2024",
      summary: "In 2021 Glencore sold Mopani (Kitwe/Mufulira) to ZCCM-IH for $1, leaving Mopani owing Glencore $1.5B in transaction debt that strained the state balance sheet. In 2023-24 Zambia selected Abu Dhabi's IRH as 51% strategic investor with a $1.1B injection; the Glencore debt was restructured with $300M repaid via an IRH shareholder loan plus a copper-price-linked royalty.",
      source: "Mining.com / Glencore", sourceUrl: "https://www.mining.com/web/zambia-seeks-to-restructure-glencore-debt-with-new-mopani-investor/"
    },
    {
      name: "First Quantum $7.9B ZRA tax assessment",
      category: "tax-corporate-dispute", lat: -12.08, lng: 26.43, years: "2018-2019",
      summary: "In March 2018 the Zambia Revenue Authority assessed First Quantum (Kansanshi, Solwezi) $7.9B for allegedly underpaid import duties on ~$540M of equipment: $150M duties plus $2.1B penalties and $5.7B interest. FQM 'unequivocally refuted' the assessment; no bill near that size was ever enforced, with analysts expecting settlement at a small fraction of the claim.",
      source: "Bloomberg", sourceUrl: "https://www.bloomberg.com/news/articles/2018-03-20/first-quantum-confirms-7-9-billion-zambian-tax-assessment"
    },
    {
      name: "ZCCM-IH vs First Quantum: Kansanshi $1.4B arbitration",
      category: "tax-corporate-dispute", lat: -12.10, lng: 26.40, years: "2016-2020",
      summary: "ZCCM-IH (20% Kansanshi shareholder) sued FQM in 2016 for $1.4B+, alleging Kansanshi lent ~$2.3B to FQM Finance at below-market interest without minority consent. A tribunal ruled in Feb 2018 that ZCCM failed to establish a prima facie case; a parallel Lusaka High Court claim went FQM's way in March 2020. The parties later reached commercial accommodation on Kansanshi dividends/royalties (2022).",
      source: "The Globe and Mail / ZCCM-IH", sourceUrl: "https://www.zccm-ih.com.zm/2020/03/30/zccm-ih-to-appeal-against-the-lusaka-high-court-judgment-delivered-in-favour-of-first-quantum-minerals/"
    },
    {
      name: "Kangaluwi mine in Lower Zambezi National Park",
      category: "environmental-litigation", lat: -15.35, lng: 29.65, years: "2013-2023",
      summary: "ZEMA rejected Mwembeshi Resources' EIA for the Kangaluwi open-pit copper mine inside Lower Zambezi National Park in 2012, but the minister overturned the rejection in 2014, triggering a decade of NGO litigation. The High Court (2019) and Court of Appeal (2021) dismissed appeals largely on procedural technicalities; in May 2023 ZEMA found Mwembeshi in breach of environmental conditions and ordered all mining and construction in the park to cease.",
      source: "Business & Human Rights Resource Centre", sourceUrl: "https://www.business-humanrights.org/en/latest-news/zambia-court-authorises-controversial-mining-to-proceed-on-a-technicality/"
    },
    {
      name: "Kasenseli gold mine suspension",
      category: "illegal-mining", lat: -11.74, lng: 24.43, years: "2020-2024",
      summary: "ZCCM-IH's Zambia Gold Company began mining at Kasenseli (Mwinilunga) in 2020, but the site was plagued by illegal-miner incursions, fatalities, and allegations of gold theft and smuggling. Government suspended operations in October 2021, citing among other things the absence of a legally appointed mine manager; after K42M in remedial works, the mine officially reopened in November 2024.",
      source: "Lusaka Times / ZCCM-IH", sourceUrl: "https://www.zccm-ih.com.zm/2024/11/17/kasenseli-gold-mine-re-opened/"
    },
    {
      name: "Luapula sugilite scandal ('SugiGate')",
      category: "illegal-mining", lat: -11.97, lng: 28.75, years: "2023-2024",
      summary: "Illegal mining and export of rare purple sugilite from the Muombe mine area (Chembe District, Luapula) implicated senior officials: the Provincial Minister was fired over alleged K2M kickbacks, and 19 people including the ex-minister and a police commissioner were arrested in July 2023. Later operations seized ~60 tonnes of sugilite and 20 more suspects in Mansa.",
      source: "Lusaka Times / News Diggers", sourceUrl: "https://www.lusakatimes.com/2023/07/08/former-minister-and-police-commissioner-amongst-19-arrested-sugigate/"
    },
    {
      name: "Black Mountain slag dump collapse, Kitwe",
      category: "illegal-mining", lat: -12.83, lng: 28.22, years: "2018",
      summary: "On 20 June 2018 part of Kitwe's 'Black Mountain', a cobalt/copper-rich slag dump worked by informal 'jerabo' miners after a portion was ceded to youth cooperatives: collapsed onto miners below, killing at least 10-11. The dump has seen recurring deaths, illegal blasting and gang-controlled extraction; government has repeatedly reallocated shares of the dump to small-scale groups.",
      source: "Lusaka Times", sourceUrl: "https://www.lusakatimes.com/2018/06/20/at-least-10-people-are-confirmed-dead-and-eight-injured-at-the-black-mountain-collapse/"
    },
    {
      name: "KKIA fake-gold jet seizure (Egypt-Zambia scandal)",
      category: "fraud-scam", lat: -15.33, lng: 28.45, years: "2023-2024",
      summary: "On 13 August 2023 authorities seized a private jet from Cairo at Kenneth Kaunda International Airport carrying $5.7M cash, 602 bars of fake gold (copper/zinc passed off as ~$7.6M in bullion), pistols and ammunition; 11 Egyptians and Zambians were detained. In a 2024 consent judgment ~$5M was forfeited to the state and the jet released; Zambian suspects faced espionage charges.",
      source: "BBC / OCCRP", sourceUrl: "https://www.occrp.org/en/news/egyptian-tycoon-revealed-as-owner-of-jet-in-zambian-gold-scam-case"
    },
    {
      name: "Lusaka fake-gold dealer scams",
      category: "fraud-scam", lat: -15.42, lng: 28.28, years: "2023-2025",
      summary: "Lusaka has seen recurring gold-plated/fake-bullion scams targeting foreign buyers: in October 2025 police re-arrested dealer Shadreck Kasanda in a fresh gold scandal, and the Drug Enforcement Commission arrested two Zambians over a $224,000 scam in which a buyer paid for a 30kg consignment later claimed 'lost in transit', with a linked case involving 72 fake gold bars.",
      source: "News Diggers / Zambia Monitor", sourceUrl: "https://diggers.news/local/2025/10/20/police-nab-kasanda-in-another-gold-scandal/"
    },
    {
      name: "Sino-Metals Leach tailings dam failure, Chambishi",
      category: "environmental-litigation", lat: -12.65, lng: 28.05, years: "2025-2026",
      summary: "On 18 February 2025 a tailings containment at Chinese state-owned Sino-Metals Leach Zambia (Chambishi) failed, releasing ~50 million litres of acidic, heavy-metal-laden waste into the Mwambashi/Kafue river system, killing fish up to 100 km downstream and forcing Kitwe to shut its water supply. Residents sued; compensation to 454 households was only paid mid-2025, with ~500 Kalusale residents still lacking farmland and clean water a year later.",
      source: "Human Rights Watch", sourceUrl: "https://www.hrw.org/news/2025/09/11/zambia-acid-spill-jeopardizes-residents-health"
    },
    {
      name: "Serenje-Mkushi manganese mining suspension",
      category: "environmental-litigation", lat: -13.23, lng: 30.24, years: "2019-2022",
      summary: "A manganese rush in Central Province brought unregulated pits and a ferroalloy plant to Serenje, leaving workers with manganism-type permanent disabilities and communities with pollution complaints. In July 2022 government suspended manganese mining in Serenje and Mkushi pending environmental and licensing compliance reviews; advocacy groups continue to press for worker compensation.",
      source: "News Diggers / Resource Justice Network", sourceUrl: "https://resourcejustice.org/serenjes-toxic-legacy-why-zambias-mineral-wealth-must-come-with-justice/"
    },
    {
      name: "Illegal manganese mining, Chifunabuli (Luapula)",
      category: "illegal-mining", lat: -11.80, lng: 29.55, years: "2019-2023",
      summary: "Small-scale licence holders in Luapula complained of widespread illegal manganese digging and buying, which continued in Chifunabuli District despite a court injunction obtained by Danley Mining restraining unlicensed miners. Local miners also protested that manganese licences over Luapula ground were being issued in Lusaka to outsiders, fuelling conflict.",
      source: "Phoenix FM", sourceUrl: "https://www.phoenixfm.co.zm/business/small-scale-miners-complain-of-widespread-illegal-manganese-mining-activities-in-luapula-province/"
    },
    {
      name: "Grizzly Mining vs Kagem/Gemfields (Kamakanga claim)",
      category: "license-dispute", lat: -13.04, lng: 28.10, years: "2024-2026",
      summary: "In December 2024 rival emerald producer Grizzly Mining, sister company Pridegems and owner Abdoulaye Ndiaye sued Kagem Mining (75% Gemfields, 25% IDC) over alleged unlawful occupation of the 'Kamakanga House' area in the Ndola Rural Emerald Restricted Area (Lufwanyama) and 'conspiracy to injure business reputation'. Gemfields calls the claims meritless; litigation ongoing as of 2025-26.",
      source: "IOL Business Report", sourceUrl: "https://iol.co.za/business-report/companies/gemfields-unscathed-by-mozambique-civil-unrest-readies-defence-against-zambian-claim-9831a4f7-7e2b-4f9f-8bd0-0521090e3e7f"
    },
    {
      name: "Gemfields vs 15% emerald export duty",
      category: "tax-corporate-dispute", lat: -13.00, lng: 28.14, years: "2024-2025",
      summary: "Zambia's reintroduction of a 15% export duty on precious gemstones from 1 January 2025 prompted Gemfields to pause emerald auctions and lobby for reversal, warning it made Kagem uneconomic on top of the 6% mineral royalty; combined with weak emerald prices, Gemfields temporarily suspended mining at Kagem in 2025. Government later moved to suspend the duty under industry pressure.",
      source: "Mining Weekly", sourceUrl: "https://www.miningweekly.com/article/gemfields-urges-zambia-to-reconsider-emerald-export-duty-2025-01-08"
    },
    {
      name: "Kikonge gold rush crackdown, Mufumbwe",
      category: "illegal-mining", lat: -13.68, lng: 24.80, years: "2025-2026",
      summary: "A gold rush at Kikonge in Mufumbwe District drew over 25,000 illegal miners, some armed and backed by undocumented foreigners; clashes killed two people and injured 11 police officers before mobile police dispersed the camp in 2025, seizing weapons, excavators and hundreds of gold detectors. In January 2026 Zambia Army commandos cleared remaining miners and shut down the illegal 'Swahiri' and 'Ukraine' markets.",
      source: "News Diggers / Zambian Eye", sourceUrl: "https://diggers.news/local/2026/01/25/zambia-army-disperses-mufumbwe-illegal-miners/"
    },
    {
      name: "CNMC Luanshya Baluba shutdown standoff",
      category: "license-dispute", lat: -13.08, lng: 28.35, years: "2015",
      summary: "In September 2015 CNMC Luanshya Copper Mines suspended its Baluba shaft and put ~1,600 workers on forced leave, citing low copper prices and the power crisis, without consulting the Mineworkers Union. Government publicly threatened to revoke CNMC Luanshya's mining licence unless workers were re-hired; Baluba went onto care and maintenance and was only revived years later.",
      source: "Reuters via BizNews / HRW", sourceUrl: "https://www.biznews.com/africa/2015/09/14/zambia-to-withdraw-copper-miners-licence-if-laid-off-workers-not-re-hired"
    },
    {
      name: "Chingola (Seseli pit) illegal-mining landslide",
      category: "illegal-mining", lat: -12.53, lng: 27.86, years: "2023",
      summary: "On the night of 30 November-1 December 2023, rain-triggered landslides buried informal miners digging unauthorized tunnels in waste dumps at the Seseli open-pit area in Chingola, killing at least seven with more than 20 missing and presumed drowned. The disaster highlighted endemic illegal artisanal mining around Chingola's KCM pits and dumps.",
      source: "AP / Al Jazeera", sourceUrl: "https://www.aljazeera.com/news/2023/12/5/zambia-digs-for-miners-buried-in-open-pit-mudslide"
    },
    {
      name: "Kalengwa mine ownership war (Moxico vs KPZ/Fawaz)",
      category: "license-dispute", lat: -13.47, lng: 25.02, years: "2016-2024",
      summary: "The dormant high-grade Kalengwa copper deposit (Mufumbwe District) has been fought over for years by Moxico Resources Zambia and the Fawaz-linked Kalengwa Processing Zone/Euro Africa entities. Supreme Court rulings, a September 2023 judgment upholding KPZ's processing licence, licence suspensions, and reciprocal contempt proceedings. The dispute remained unresolved into the mid-2020s, stalling redevelopment.",
      source: "Zambian Watchdog / Zambian Observer", sourceUrl: "https://zambianobserver.com/kalengwa-mines-licence-suspended-moxicos-davies-gets-cited-for-contempt/"
    },
    {
      name: "Arrest of 31 Chinese nationals for illegal copper mining",
      category: "illegal-mining", lat: -12.55, lng: 27.85, years: "2017",
      summary: "In June 2017 Zambian authorities arrested 31 Chinese nationals in a Copperbelt sweep (Chingola area) for allegedly running illegal copper mining operations, including claims some sites employed underage miners; Beijing formally protested. Most detainees were released and deported rather than prosecuted, a reference point in debates over foreign involvement in Zambia's informal mining economy.",
      source: "BBC / Mining Technology", sourceUrl: "https://www.mining-technology.com/news/newszambia-arrests-31-chinese-national-for-illegal-mining-5833483/"
    },
  ],

  // Verified by web research 2026-07-23. Verdict: NO freely redistributable,
  // current mining-license POLYGON dataset for Zambia exists, the Landfolio
  // ArcGIS services return error 499 "Token Required" on every query, and the
  // old FlexiCadastre scrapes are dead. Everything open is points, mine
  // footprints, or contract/company tabular data.
  datasets: [
    {
      name: "★ NGDR GeoServer open WFS (Geological Survey, gsb.gov.zm)",
      url: "https://geoserverprd.gsb.gov.zm/geoserver",
      contains: "THE find: actual active-license POLYGONS served openly: ~7,468 consolidated active licenses (holder, type, status incl. 'Non-Compliant', grant/expiry, commodities, area), plus applications, restricted areas and admin layers. Fresher than the Landfolio portal (includes Jun-2025 MRC-era grants). Supersedes the earlier 'no open polygons' verdict: snapshot in data/gov/ngdr/ and rendered on this map.",
      format: "WFS → GeoJSON/SHP", terms: "Open government service; no license text published: cite the Geological Survey",
    },
    {
      name: "MMMD revocation & default notices",
      url: "https://www.mmmd.gov.zm/?p=2787",
      contains: "Official cancellation/default lists: MLC-78 cancellations (Apr 2024, 2,604 records: code, holder, reason), Final Public Default Notice (18 Jun 2025, 3,429 rights), Oct-2023 default notice (2,812). License code + holder only, no coordinates; joinable to NGDR polygons by code (done on this map).",
      format: "HTML tables + PDF", terms: "Official public notices",
    },
    {
      name: "USGS Africa GIS compilation (2021/2024)",
      url: "https://www.sciencebase.gov/catalog/item/607611a9d34e018b3201cbbf",
      contains: "Mineral production/processing facilities, exploration & development sites, occurrences, ports and power infrastructure for all of Africa incl. Zambia. Facility/site points, the best-maintained open point layer.",
      format: "FileGDB + shapefiles", terms: "US public domain",
    },
    {
      name: "Jasansky et al. 2023 (FINEPRINT) global mine production DB",
      url: "https://doi.org/10.5281/zenodo.7369478",
      contains: "1,171 mines, 80 materials, 2000-2021: coordinates, ownership, reserves, production. Zambia's major copper mines (Kansanshi, Lumwana, Sentinel…) in scope. Points + ownership/production attributes.",
      format: "GeoPackage + CSV", terms: "CC BY 4.0",
    },
    {
      name: "Maus et al. global mining polygons v2",
      url: "https://doi.org/10.1594/PANGAEA.942325",
      contains: "44,929 visually-mapped mine-footprint polygons worldwide incl. the Copperbelt. Actual land-use polygons, the closest open substitute for license boundaries, but they are NOT license boundaries.",
      format: "GPKG + CSV", terms: "CC BY-SA 4.0",
    },
    {
      name: "ResourceContracts.org. Zambia",
      url: "https://www.resourcecontracts.org/countries/zm",
      contains: "73 documents (2000-2023): concessions, development agreements, license certificates (Mopani, Kagem, CMC Luanshya, EU-Zambia minerals MoU…). The best open source for Zambian license TERMS. No geometry.",
      format: "PDF/Word/XLSX + API", terms: "CC BY-SA 4.0 (NRGI/CCSI/World Bank)",
    },
    {
      name: "Zambia EITI summary data",
      url: "https://eiti.org/countries/zambia",
      contains: "Revenues by company/stream, production & exports (copper, cobalt, emeralds, gold, coal); latest report covers 2023-2024 (published Oct 2025). Tabular, no geometry.",
      format: "XLSX + API", terms: "EITI open data policy (attribution)",
    },
    {
      name: "energydata.info. Zambia mining reserves",
      url: "https://energydata.info/dataset/mining-reserves-zambia",
      contains: "43 mineral-facility points (USGS-style fields: operator, commodity, capacity, investors). Data year 2015: dated but clean. The historical cadastre extracts once on this portal are gone.",
      format: "GeoJSON + shapefile", terms: "CC BY 4.0",
    },
    {
      name: "USGS MRDS (archived)",
      url: "https://mrdata.usgs.gov/mrds/",
      contains: "Global mineral occurrence/deposit points incl. Zambia (commodity, production, references). Archived, not updated since ~2011.",
      format: "CSV/SHP/KML/WFS", terms: "US public domain",
    },
    {
      name: "PACRA beneficial-ownership search",
      url: "https://portal.pacra.org.zm/search",
      contains: "Company & beneficial-ownership lookups, search-only (~38% BO compliance). No bulk export; Zambia is NOT in the OpenOwnership bulk register.",
      format: "Web search only", terms: "Free search; extracts paid per document",
    },
    {
      name: "Zambia Mining Cadastre (Landfolio). GATED",
      url: "https://portals.landfolio.com/zambia/",
      contains: "The only real license polygons (active/application/petroleum/restricted areas). Every ArcGIS query endpoint verified returning error 499 'Token Required' (2026-07-23). View-only; request credentials from the Ministry of Mines / MRC for programmatic access.",
      format: "ArcGIS viewer only", terms: "Not redistributable",
    },
    {
      name: "Zambia Geoportal 'Mining licenses' record (znsdi.net). DEAD LEAD",
      url: "https://www.znsdi.net/srv/api/records/f9eaada6-39a6-4c37-a329-32fab8e3ec8c",
      contains: "A metadata record for an official open 'Mining licenses' layer exists, but the whole site returns 502 (demo instance, down). The only trace of an official open license layer: worth re-checking periodically.",
      format: "GeoNetwork (down)", terms: "Unknown",
    },
  ],
};
