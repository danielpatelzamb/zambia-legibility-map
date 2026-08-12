# Data map. Zambia minerals analysis dataset

Everything in `dataset/` as of 2026-07-28, how the tables join, and what each is good for.
Rebuild: `pipeline/build_analysis_dataset.ps1` then `pipeline/merge_research_outputs.ps1`.
Provenance of the research inputs: `RECOVERY_LOG.md`.

## The join model

```
                          entities.csv  (16 major entities, canonical crosswalk)
                                 │ entity_id
        ┌────────────────┬───────┴────────┬─────────────────┬──────────────────┐
        │                │                │                 │                  │
entity_production  entity_values   entity_contacts    facilities        supply_chain_links
 (entity×yr×comm)  (entity×yr×metric) (1 per entity)  (operator_entity_id)  (entity_id)
        │                │
        └──────┬─────────┘
               ▼
       entity_year_panel.csv  ← THE ANALYSIS PANEL (entity × year)
               ▲
        ┌──────┴───────┐
   adverse_actions  court_cases     (counts folded in via holder_entity_id)

licenses.csv (7,468)  ──holder──►  holder_contacts.csv (400 researched)
       │ license_code                      ▲
       ├──► adverse_actions.csv             │ holder (raw name)
       └──► court_cases.csv          holder_roster_all.csv (research/: all 3,622 holders)

Standalone / context tables:
  historical_production.csv + timeline_events.csv   → the 1964-2025 timelapse
  value_addition_efforts.csv                        → policy & initiative layer
  sector_directory.csv                              → segmented org directory
  price_series.csv                                  → deflators / implied-value math
  trade_flows.csv, exports_by_commodity.csv         → trade side
  bol_shipments.csv                                 → shipment-level evidence
  disputes.csv                                      → curated dispute narratives
```

**Key rule:** every table referencing a company carries `entity_id` where it maps to the
16-entity crosswalk. Long-tail license holders and court parties have `entity_id` empty: join those on the raw `holder` name instead (see `holder_contacts.csv`).

## Tables

### Core entity layer
| File | Rows | Grain | Notes |
|---|---|---|---|
| `entities.csv` | 16 | entity | canonical names, type, parent, `ownership_nationality`, name variants |
| `entity_contacts.csv` | 21 | entity/institution | website, HQ, phone, email, officers, **linkedin, whatsapp, other_channels, facility_contacts** |
| `entity_production.csv` | 72 | entity×year×commodity | EITI/ZEITI company copper tonnes 2018-2023 |
| `entity_values.csv` | 103 | entity×year×metric | **unified money table**: ZEITI + audited ARs + deal values + fabrication financials; every row has source_name/source_url |
| `entity_year_panel.csv` | 65 | entity×year | **the econ panel**: tonnes, reported values, WB price, implied gross value, adverse/court counts |

`entity_values.csv` metrics: revenue_usd (19), production_tonnes (16), capacity_tpa (16),
investment_committed_usd (15), capex_usd (12), transaction_value_usd (11),
production_value_usd (7), payments_to_govt_usd (4), construction_cost_usd (3).

### License / compliance layer
| File | Rows | Grain | Notes |
|---|---|---|---|
| `licenses.csv` | 7,468 | license | NGDR WFS: holder, type, dates, hectares, centroid, default/cancellation flags |
| `adverse_actions.csv` | 10,307 | license×list | MMMD default notices (2023-10, 2025-06) + MLC-78 cancellations (2024-04) |
| `court_cases.csv` | 373 | holder×judgment | ZambiaLII search over 2,789 holder names |
| `holder_contacts.csv` | 1,423 | holder | researched contacts. **`reachable`** = yes 203 / no 1,220. `match_confidence` high/medium/none. **`search_coverage`** distinguishes `searched` from `not_researched` (search blackout), an unsearched blank is NOT a verified absence. `holder_key` = normalized name for dedup grouping |
| `official_doc_mentions.csv` | 16,120 | holder × document | **6,446 distinct holders** mined from 60 official documents (MMMD Mining Licensing Committee meetings 70-91, 2023 + 2025 default notices, 2024 cancellation notice, ZEMA titles). Carries licence code, hectares, district (9,433), province (10,033) and `decision`: granted 6,343 / default 3,375 / cancelled 2,642 / deferred 1,814 / refused 1,366 |
| `pacra_registry.csv` | growing | holder × registry entity | Companies-registry status from PACRA's public API. **`beneficial_owner_declared`** (0 = statutory non-compliance), `annual_return_filed`, `nominal_capital_ok`, plus registration number, incorporation date, entity status, ISIC class. `exact_name_match` flags whether the registry name equals the register name |
| `disputes.csv` | 20 | dispute | curated public reporting, approx coords |

### Physical & supply-chain layer
| File | Rows | Grain | Notes |
|---|---|---|---|
| `facilities.csv` | 22 | facility | smelters/refineries/SX-EW/concentrators/fabricators; `coordinate_source` labels precision (OSM polygon vs town centroid vs estimate) |
| `supply_chain_links.csv` | 31 | entity×counterparty | offtakes, prepayments, streams, corridors, rail/port |
| `bol_shipments.csv` | 24 | shipment | US CBP manifests via ImportYeti; `value_usd` null (not on free manifests) |
| `trade_flows.csv` | 752 | reporter×partner×HS×period | UN Comtrade 2019-2024 + partner mirrors |
| `exports_by_commodity.csv` | 221 | HS×year | ZEITI customs aggregates (ZMW where USD unpublished) |

`supply_chain_links.csv` by type: financing_offtake 9, offtake 7, rail 5, corridor 3,
stream 2, trucking 2, port 1, marketing 1, auction_channel 1.

### Historical / policy layer
| File | Rows | Grain | Notes |
|---|---|---|---|
| `historical_production.csv` | 128 | commodity×year | **copper 1964-2025 (62), cobalt 1970-2024 (55), emerald 2007-2021 (11)**. USGS/BGS |
| `timeline_events.csv` | 46 | event | structural events w/ `entity_ids`: policy 11, acquisition 8, privatization 6, other 6, opening 5, nationalization 4, disaster 3, closure 3 |
| `value_addition_efforts.csv` | 28 | effort | policy 12, international_initiative 5, national_project 5, zone_incentive 3, state_vehicle 3 |
| `sector_directory.csv` | 37 | organization | manufacturer 10, services 7, institution 6, asm_association 4, gemstone_trade 4, trader_exporter 3, gemstone_producer 3 |
| `national_production.csv` | 24 | commodity×year | EITI national totals (base metals in thousand tonnes as published) |
| `price_series.csv` | 22 | commodity×year | WB Pink Sheet copper + USGS cobalt, USD/tonne, 2015-2025 |

## Analysis starting points

- **Value per entity**: `entity_year_panel.csv`: compare `reported_production_value_usd` against
  `implied_gross_value_usd` (tonnes × WB price). Divergence is the story.
- **Timelapse**: `historical_production.csv` (copper 1964-2025) as the spine, `timeline_events.csv`
  as annotations. Nationalization → decline → privatization → Chinese wave reads directly off it.
- **Legibility gap**: `licenses.csv` (7,468) vs `holder_contacts.csv` (400 researched, 129 reachable).
  The unreachable 271 + unswept ~2,300 orgs *are* a finding, not just a gap.
- **Compliance risk**: join `adverse_actions` + `court_cases` counts onto holders, cross-ref
  `holder_contacts.notes` (several holders carry documented cancellations, ZEMA shutdowns, tax probes).
- **Value-addition reality check**: `value_addition_efforts.csv` (what was promised) vs
  `facilities.csv` + fabrication rows in `entity_values.csv` (what actually got built).

## Caveats that must travel with any published analysis

- **Formal-economy bias**: this is the *legible* economy. Artisanal/informal flows are absent by construction.
- **BoL is US-slanted**: US CBP manifests miss China-bound blister/anode (most CNMC output) and
  air-freighted emeralds. `supply_chain_links.csv` covers those corridors instead.
- **ZMW/USD**: ZEITI 2023 export values are ZMW-only; ZAMEFA reports in kwacha. Conversions are
  flagged as estimates in-row: check `note` before using.
- **Coordinate precision** varies in `facilities.csv`; never present town-centroid points as plant locations.
- **`match_confidence`** in `holder_contacts.csv`: treat `medium` as a lead, not a fact. `none` rows
  have a sourced explanation in `notes`.
- **Exclude** the holder "Trimble Spatial Zen Ltd Test": cadastre test record, not a real company.
- Cobalt 2025 price is a USGS estimate; base-metal national totals are in thousand tonnes as published.
