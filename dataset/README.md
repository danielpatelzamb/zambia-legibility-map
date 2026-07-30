# Zambia Minerals Analysis Dataset

Analysis-ready CSV package built from the Zambia Legibility Map data plus targeted web research.
Rebuild with `pipeline/build_analysis_dataset.ps1`, then `pipeline/merge_research_outputs.ps1`
(the latter folds in `research/*.json` produced by the research agents).

Entity keys: every table that references a company carries an `entity_id` joining to
`entities.csv`. License holders and court parties outside the major-entity crosswalk have
`entity_id` empty — join those on the raw name instead.

## Tables

| File | Grain | Source |
|---|---|---|
| `entities.csv` | one row per major entity | hand-curated crosswalk: canonical name, type, parent, **ownership_nationality**, name variants |
| `entity_contacts.csv` | entity | official business contacts only (website, HQ, phone, email, officers w/ titles, ownership %) — from corporate sites, filings, EITI; per-fact sources |
| `entity_production.csv` | entity x year x commodity | Zambia EITI Fusion portal + ZEITI XLSX (2018–2023 company copper tonnes) |
| `entity_values_zeiti.csv` | entity x 2023 | ZEITI production USD values |
| `entity_values.csv` | entity x year x metric | unified values: ZEITI + annual-report segment data, EITI payments, transaction values (each row has source_name/source_url) |
| `entity_year_panel.csv` | entity x year | **the econ-analysis panel**: production tonnes, reported values, World Bank price, implied gross value, adverse/court counts |
| `national_production.csv` | commodity x year | EITI national totals (NB: base metals in thousand tonnes as published) |
| `exports_by_commodity.csv` | HS code x year | ZEITI customs export aggregates (values in ZMW where USD unpublished) |
| `trade_flows.csv` | reporter x partner x HS x period | UN Comtrade (Zambia exports + partner mirror imports, 2019–2024; HS 740311, 2603, 7402, 7404, 7408, 8105) |
| `licenses.csv` | license (7,468 active) | NGDR GeoServer WFS: holder, type, dates, hectares, centroid lat/lng, MMMD default/cancellation flags |
| `adverse_actions.csv` | license x adverse list | MMMD default notices (2023-10, 2025-06) + MLC-78 cancellations (2024-04) |
| `court_cases.csv` | holder x judgment | ZambiaLII judgment search over 2,789 holder names (158 with hits) |
| `disputes.csv` | documented dispute (20) | curated public reporting: KCM liquidation, Mopani/IRH, FQM tax cases, illegal-mining incidents; approx coords |
| `facilities.csv` | facility | geolocated smelters/refineries/SX-EW/fabricators/MFEZ tenants (OSM + company + USGS sources; coordinate_source marks precision) |
| `bol_shipments.csv` | shipment | freely accessible bill-of-lading records (mostly US customs); see `research/bol_sources.md` for coverage limits |
| `price_series.csv` | commodity x year | World Bank Pink Sheet copper/cobalt annual averages |

## Caveats for analysis

- **Formal-economy bias**: everything here is the *legible* economy; artisanal/informal flows are absent.
- ZEITI export values for 2023 are ZMW-only in the source; deflate with care (2023 ZMW/USD moved a lot).
- Comtrade preview rows are TOTAL-mode only and capped at 500/query; `TRADE_META.truncated` was empty at fetch.
- Mirror-trade gaps (Zambia X vs partner M) include freight/insurance and re-routing (Switzerland "merchanting") — not all gap is misinvoicing.
- License centroids: `web_layer` = pipeline centroid; `first_ring_mean` = rough fallback, fine for district-level work.
- `implied_gross_value_usd` = tonnes x annual avg price; it is a gross-value proxy, **not** revenue (TC/RCs, payability, timing ignored).
- Nationality classification covers the major-entity crosswalk only; for the 7,468-license long tail use PACRA/ZEITI beneficial-ownership disclosures.
- Contacts were verified against official sources in Jul 2026; officers/ministers churn — recheck before relying on them.
