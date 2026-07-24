# The Zambian Copper Legibility Map & Bankability Scorecard

A static, single-page MVP that maps where the Zambian critical-minerals supply chain is
**legible to capital** — and deliberately shows the **verification void** where trusted-warehouse
and independent-verification infrastructure is absent upstream.

Built per the "Legibility Map + Bankability Scorecard" build spec:

- **Legibility Map** — Leaflet map with schematic export corridors (Lobito, TAZARA/Dar,
  North–South/Durban, Beira, Walvis Bay), illustrative mining/processing operation markers,
  ZRA clearing-agent hubs, LME warehouse endpoints (all downstream, none in Zambia), and the
  annotated verification-void overlay.
- **Trade Analysis** — mirror-trade gap (Zambia-reported exports vs. partner-reported imports)
  and unit-value spread analysis (cathode 7403.11 vs. concentrate 2603) from free UN Comtrade data.
- **KYC Check** — search any holder or license code across six sources: the NGDR register (5,000
  records), the MLC-78 cancellation list, the 2023/2025 default notices (10,306 adverse rows),
  ZambiaLII court judgments (2,789 holder names checked as exact phrases; 158 with judgments —
  `pipeline/scrape_court_records.ps1`, resumable), EITI company production, and the disputes index.
  Returns a risk badge (HIGH RISK / CAUTION / NO ADVERSE FINDINGS) with reasons, license/adverse/court
  tables, external registry links, and a show-on-map highlight. Status semantics are time-aware: an
  MLC-78 (Apr 2024) cancellation on a license still in the Jun-2025 active register is shown as
  "reinstated on appeal" (adverse history), never as a current cancellation. Runs entirely client-side.
- **Production data** — EITI Fusion portal + ZEITI XLSX extracts: copper production by company
  2018–2023 (chart on the Trade tab, joined into operation popups and KYC), national 2023/24 totals,
  2023 exports by commodity (`pipeline/build_production_layer.ps1`).
- **Bankability Scorecard & financing cost model** — deterministic 0–100 rubric (option-card
  pillars, SVG gauge), a financing ladder showing which instruments each band can access with
  indicative rates, and a cost-of-illegibility calculator: product + volume in, indicative revenue
  (benchmarked to live Comtrade medians), working capital, financing cost, savings from reaching the
  next band, and the documentation-linked price-realization gap computed from the observed
  concentrate P10-vs-median spread. Optional Claude-generated lender memo (bring your own key).
  License layer renders **real license parcels** (NGDR polygons via `pipeline/build_license_polygons.ps1`),
  not centroid dots.
- **Methodology & Caveats** — causal DAG for the certification-spread claim, GFI mirror-trade
  method, and the honest-limitations list (formal-economy bias front and center).

## Run it

No build step, no Node, no Python. Either:

```bash
powershell -ExecutionPolicy Bypass -File serve.ps1
```

then open http://localhost:8090/ — or simply double-click `index.html`
(data ships as `.js` globals, so `file://` works too; only the map tiles and CDN libs need internet).

## Refresh the trade data

```bash
powershell -ExecutionPolicy Bypass -File pipeline/fetch_trade_data.ps1
```

Pulls ~120 queries from the UN Comtrade **public preview API** (no key required; one period per
call; 500-row cap per query; aggressive rate limits — the script spaces calls ~6s apart and resumes
from `data/raw/` if interrupted). Emits `data/trade_data.js`.

Coverage: annual 2019–2024 exports + mirror imports for HS 740311, 2603, 7402, 7404, 7408, 8105;
monthly 2023–2024 exports for 740311 and 2603.

## Files

| Path | What |
|---|---|
| `index.html`, `app.js`, `styles.css` | The app |
| `data/trade_data.js` | Generated Comtrade rows (+ metadata incl. truncation flags) |
| `data/geo_layers.js` | Hand-authored corridors, markers, void polygon — **illustrative** |
| `data/legal_layers.js` | 20 sourced disputes/fraud cases + verified dataset index |
| `data/licenses_points.js` | Generated: 5,000 real license centroids (NGDR open WFS) joined with MMMD revocation lists |
| `data/zambia_adm0.js` | Zambia boundary (geoBoundaries, CC BY 4.0) |
| `data/gov/` | Downloaded official data: NGDR GeoServer license polygons, cadastre proxy snapshots, MMMD cancellation/default lists (see `findings.json`) |
| `data/raw/*.json` | Raw Comtrade responses (resume cache) |
| `pipeline/fetch_trade_data.ps1` | Comtrade data pipeline |
| `pipeline/build_license_layer.ps1` | Joins NGDR license polygons with MMMD revocation lists → web layer |
| `serve.ps1` | Tiny PowerShell static server |

## Official license & revocation data

The Geological Survey's **NGDR GeoServer** (`geoserverprd.gsb.gov.zm`, open WFS) serves actual
active-license polygons — holder, type, status, dates, commodities. The Ministry of Mines publishes
**cancellation lists** (MLC-78, Apr 2024: 2,604 records) and **default notices** (Jun 2025: 3,429 rights)
as code+holder tables with no coordinates. `build_license_layer.ps1` joins the two by license code:
45% of mapped active licenses appear in an official cancellation or default list. The Landfolio
cadastre snapshots in `data/gov/cadastre/` were fetched via the portal's own session proxy — use for
research, do not republish wholesale.

## Data licensing

UN Comtrade: redistributable with attribution. OSM tiles: © OpenStreetMap contributors (ODbL).
Geo layers here are hand-authored from public sources and clearly labeled illustrative — no
cadastre records or commercial BoL data are included, per the spec's redistribution constraints.
