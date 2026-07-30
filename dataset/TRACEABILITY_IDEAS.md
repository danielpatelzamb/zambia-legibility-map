# Traceability and dashboard ideas — what this dataset can actually support

Everything below is buildable from tables already in `dataset/`. Each idea names the join, so you
can judge effort. Ordered by (my view of) impact per unit work.

---

## Tier 1 — build these first

### 1. The mirror-trade gap detector  ★ flagship
**Join:** `trade_flows.csv` self-join on `hs_code` + `period`, Zambia-as-reporter export rows
against partner-as-reporter import rows.

For each HS code, partner and year: what Zambia says it exported vs what the partner says it
imported from Zambia. The gap is the single most defensible under-invoicing signal available from
free data, and it is already loaded (752 rows, 2019–2024, HS 740311/2603/7402/7404/7408/8105).

Present as a diverging bar per partner-year, and let the user pick the commodity. Caveat to show
on the chart, not bury: gaps include freight and insurance (FOB vs CIF), and Zambian metal is
often invoiced through Swiss/UAE/Singapore desks while physically moving to China — so Comtrade
"partner" is a *financial* counterparty, not always a destination.

### 2. Legibility score per holder  ★ the project's own thesis, quantified
**Join:** `licenses.csv` → `holder_contacts.csv` + `pacra_registry.csv` + `official_doc_mentions.csv`
+ `court_cases.csv`, grouped on `holder_key`.

Score each holder 0–6 on how *knowable* they are:

| Signal | Source |
|---|---|
| Reachable by any channel | `holder_contacts.reachable` |
| Found in the companies registry | `pacra_registry.entity_status` ≠ NO_REGISTRY_MATCH |
| Beneficial owners declared | `pacra_registry.beneficial_owner_declared` = 1 |
| Annual returns filed | `pacra_registry.annual_return_filed` = 1 |
| Location known to district | `official_doc_mentions.district` present |
| Any published financial figure | `entity_values.csv` |

This turns "the register is illegible" from an assertion into a distribution you can chart.
It is also the honest frame for your own coverage: score 0 holders are where the data ends,
not where reality does.

### 3. Ownership-opacity map layer
**Join:** `licenses.csv` (has `centroid_lat/lng`) → `pacra_registry.csv` on holder.

Colour licence polygons by `beneficial_owner_declared`. **729 companies have never declared their
beneficial owners** — plot their ground. The visual claim is immediate: here is territory whose
ultimate owner is legally undisclosed. Cross-filter with the 2025 default notice (2,332 holders)
and you get "undisclosed owner AND in default", which is a short, very interesting list.

### 4. Timelapse 1964 → 2025
**Data:** `historical_production.csv` (copper 62 years, cobalt 55) + `timeline_events.csv` (46 events).

Scrub-bar animation of national output with events pinned to their years: 1969–70 Mulungushi/Matero
51% takeover, 1982 ZCCM consolidation, the 1970s–80s collapse, 1997–2000 privatisation unbundling,
the 2005+ Chinese wave, 2019 KCM liquidation, 2021 Glencore exit, 2024 Mopani–IRH and Lubambe–JCHX.
The nationalisation-to-privatisation-to-Chinese-wave arc reads straight off the curve, which is why
this is worth building even though it is "just" a line chart with annotations.

---

## Tier 2 — strong, slightly more work

### 5. Chain-of-custody path view (the actual "traceability" product)
**Join:** `licenses` → `facilities` (by operator + proximity) → `supply_chain_links` (offtake/corridor)
→ `trade_flows` (destination) → `bol_shipments` (where a manifest exists).

For a chosen entity, render the path: **licence → mine → processing facility → corridor → port →
destination → known offtaker**. Most paths will be partial; show the breaks explicitly. A path that
stops at "concentrate sold, buyer unpublished" is itself the finding — that is where traceability
fails in the real supply chain, not just in the dataset.

The 31 `supply_chain_links` rows carry the money: Jiangxi's two $500m prepayments, Royal Gold's
$1bn Kansanshi stream, Glencore's $1.5bn Mopani financing-offtake, Trafigura's KCM prepayment
(in arbitration), the Lobito consortium, TAZARA's $1.4bn CCECC concession.

### 6. Shell-signal composite
**Join:** `pacra_registry` + `holder_roster_all` + `official_doc_mentions`.

Flag holders scoring on several of: nominal capital below the statutory K20,000 minimum (**937**),
annual returns unfiled (**1,439**), beneficial owners undeclared (**729**), no web footprint at all,
yet holding large hectarage, and appearing in the default notice. None of these alone means much;
together they describe a licence-holding vehicle rather than an operator. Publish the *criteria and
the count*, and let readers judge individual names — do not label a company a shell in your UI.

### 7. Protected-area encroachment overlay
**Data:** you already have `data/gov/ngdr/ngdr_restricted_areas.geojson` and licence centroids/polygons.

Spatial intersect licences against restricted areas and national parks. There is precedent in the
research notes: a holder withdrew a 2024 application after Lower Zambezi encroachment. This is a
high-salience layer and the geometry is already in the repo.

### 8. Value-addition promised vs built
**Join:** `value_addition_efforts.csv` (28 policy instruments, zones, initiatives, with announced
values) against `facilities.csv` (22 built, geolocated) and the fabrication rows in `entity_values.csv`.

Announced battery-precursor SEZ and MFEZ investment versus plants that physically exist. The
Chambishi zone's claimed **$2.5bn cumulative** against a countable list of operating tenants is the
kind of comparison that writes its own headline.

### 9. Licence churn over time
**Data:** `official_doc_mentions.csv` — 16,120 mentions carrying `decision`: granted 6,343,
default 3,375, cancelled 2,642, deferred 1,814, refused 1,366, across Mining Licensing Committee
meetings 70–91 (2023-05 → 2025-10).

Chart decisions per meeting. This makes the *licensing system itself* legible — how much ground
churns, how often committees defer, whether enforcement is rising. Nobody has visualised this.

---

## Tier 3 — nice once the above exist

10. **Implied vs reported value per entity** — `entity_year_panel.csv` already has
    `implied_gross_value_usd` (tonnes × World Bank price) beside `reported_production_value_usd`.
    Scatter with the diagonal drawn; distance from the line is the question worth asking.
11. **Nationality of control** — `entities.csv` has `ownership_nationality`; aggregate hectares and
    production by country of ultimate owner. Simple, and the numbers are striking.
12. **Facility capacity vs national output** — sum `facilities.capacity` against
    `national_production.csv` to expose idle smelter/refinery capacity.
13. **Corridor Sankey** — mine → smelter → corridor → port → destination, weighted by
    `trade_flows.net_weight_kg`.
14. **Court-record layer** — `court_cases.csv` (373) joined to holders, mapped.

---

## Design rules I would hold to

- **Show absence as data.** `search_coverage` distinguishes "we looked and found nothing" from
  "we could not look". A dashboard that renders both as an empty cell destroys the distinction that
  makes the dataset trustworthy.
- **Every figure links to its source.** Nearly every row carries `source_url`. Make it clickable —
  that single feature is what separates this from a scraped aggregator.
- **Name the gaps in the UI.** US bill-of-lading data cannot see China-bound blister or air-freighted
  emeralds. Say so on the shipment view rather than letting 24 records imply completeness.
- **Never present inference as fact.** No inferred email addresses (I discarded 48 of those after
  verifying they matched unrelated global companies), no "probably owned by" without a source.
- **Individual holders: aggregate only.** 902 individuals, 886 with real mining licences. Map them by
  district and count, never as pinned identifiable dots with names.
