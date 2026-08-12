# Zambia Mining Cadastre. Holder Contact Data Probe

Date: 2026-07-28. Method: public/unauthenticated endpoints only, a handful of test requests + a 20-record sample. No auth bypass, no CAPTCHA, no bulk pull.

## Bottom line

**Bulk holder CONTACT data (registered address / phone / email) is NOT publicly available** from the mining cadastre.

- The public Map Portal exposes, at scale, the license-**holder company NAME** (with ownership %) for every active license and application: nothing more identifying. This is genuinely richer than the NGDR mirror the repo already has (whose `respoffice`/party fields were empty), so it is worth pulling.
- There are **no address / phone / email / contact columns anywhere** in the cadastre's public feature layers. `RespOffice` is the *government* cadastre office (e.g. "MCU - Lusaka Central Office"), not the holder.
- Holder contact details live only in the **login-gated transactional portal** and in **PACRA** (company registry), where PACRA offers a per-company **search but no public bulk API/export**.

So: **holder company names = yes, bulk, legitimately. Holder contact details = no (not at scale, not publicly).**

---

## 1. Portals found

| System | URL | Access |
|---|---|---|
| Mining Cadastre **Map Portal** (Trimble Landfolio / FlexiCadastre) | https://portals.landfolio.com/zambia/ | Public, no login |
| Old FlexiCadastre host (redirects/dead) | http://portals.flexicadastre.com/zambia/ | Deprecated |
| **Transactional / eGov Portal** | https://portal.miningcadastre.com/site/Login.aspx | **Login required**: out of scope |
| MMMD (ministry) | https://www.mmmd.gov.zm/ | Public info only |
| NGDR GeoServer | https://ngdr.mmmd.gov.zm/geoserver/ows | **Did not resolve** from this environment (DNS ENOTFOUND): could not run GetCapabilities/DescribeFeatureType here; retry from a network that resolves it |

The Ministry confirms three integrated systems: Trimble Landfolio (back office), the online Transactional Portal, and the Map Portal. Only the Map Portal is open.

## 2. Map Portal architecture (how data is served)

- Viewer: ArcGIS JS API 3.21 over ArcGIS Server 10.91.
- Backend REST host: `https://ags1.landfolio.com/arcgis/rest/services/ZambiaMapPortal/…`
- **The ArcGIS services require a token**: hitting them directly returns `{"error":{"code":499,"message":"Token Required"}}`. The public page config (`MainPage.Init(...)`) has `ArcGISToken:null` / `Extras:null`, so the old ANCIR-scraper trick of lifting the token from the HTML no longer works.
- Instead the viewer routes every request through a server-side **ESRI resource proxy** on the portal that injects the token:
  - `esriConfig.defaults.io.proxyUrl = "proxy.ashx"; alwaysUseProxy = true` (from `zambia/javascript/map.js`).
  - Proxy endpoint: **`https://portals.landfolio.com/zambia/proxy.ashx?<full ArcGIS REST URL>`**
  - This proxy is **open to unauthenticated GET** (it is what the public map itself uses). A browser `User-Agent`, a `Referer: https://portals.landfolio.com/zambia/` header, and the session cookies set by loading the landing page are needed; then GET requests succeed. (POST triggered 411/Content-Length issues: use GET.)

## 3. Layers available (all via the proxy)

Service `ZambiaMapPortal/Active/MapServer`:

| id | layer | sample count |
|---|---|---|
| 0 | Small Scale Exploration Licences | 1,750 |
| 1 | Large Scale Exploration Licences |: |
| 2 | Large Scale Mining Licences | 213 |
| 3 | Small Scale Mining Licences |: |
| 4 | Artisanal Mining Rights |: |
| 5 | Mineral Processing Licences |: |
| 6 | Prospecting Permits (2008) |: |
| 7 | Prospecting Licences (2008) |: |
| 8 | Large Scale Gemstone Licences (2008) |: |
| 9 | Small Scale Gemstone Licences (2008) |: |
| 10 | ActiveLicenses (aggregate; not directly queryable: returns error 400) |: |

Other services: `ZambiaMapPortal/Applications/MapServer/0` (Applications), `ZambiaMapPortal/PetroleumLicences/MapServer/0` (Petroleum Licenses). Also non-license: `Geology`, `Admin`, `RestrictedAreas`.

## 4. Field schema (identical across all license/application layers)

`guidLicense, guidLicenseType, Code, TypeGroup, Type, TypeCode, StatusGrp, Status, Jurisdic, Region, RespOffice, Parties, ApplNo, Interest, Renewal, OldCode, AccCode, Group1..5, Comments, Archived, DteApplied, DtePegged, DteExpires, DteGranted, DteRenewal, Name, Identifier, guidStatus, AreaValue, AreaUnit, CalculatedAreaValue, CalculatedAreaUnit, Commodities, CommoditiesCd, MapRef, guidShape, guidPart, Part, ExteriorShapePartCount, geomShape, strResourceContractsJSON, ESRI_OID`

Holder-relevant fields:
- **`Parties`**: holder company name(s) + ownership share, e.g. `"Jin Ding Mining Limited (100%)"`. This is the only holder identifier.
- `RespOffice`: government cadastre office (e.g. "MCU - Lusaka Central Office"), NOT the holder.
- `strResourceContractsJSON`: **null** in all sampled records.
- **No** address / phone / email / postal / registration-number / director fields exist. Confirmed on both the Active and Applications layers.

## 5. Bulk query pattern (viable for holder NAMES + license attributes)

Prime a session cookie once (GET `https://portals.landfolio.com/zambia/` with a browser UA), then per layer:

```
GET https://portals.landfolio.com/zambia/proxy.ashx?https://ags1.landfolio.com/arcgis/rest/services/ZambiaMapPortal/Active/MapServer/{id}/query?where=1=1&outFields=Code,Type,TypeGroup,Status,Region,RespOffice,Parties,Name,Commodities,DteGranted,DteExpires,ApplNo&returnGeometry=false&resultRecordCount=1000&resultOffset=0&f=json
```

Headers: `User-Agent: <browser>`, `Referer: https://portals.landfolio.com/zambia/`, plus the cookie jar from the landing page.

- Page with `resultOffset` / `resultRecordCount` (server honors `exceededTransferLimit`; the ANCIR crawler alternatively quad-splits the bbox envelope).
- Get totals with `&returnCountOnly=true`.
- Loop layer ids 0-9 on `Active` + `Applications/0` + `PetroleumLicences/0` to cover the whole active estate.
- Join to the repo's existing 7,468 NGDR polygons on the license `Code` to attach holder company names.

This is the same traffic the public map viewer generates. Keep volume modest / add delays; it is one shared government server.

## 6. Sample records

20 real records saved to `research/cadastre_parties_sample.json` (12 Small Scale Exploration + 8 Large Scale Mining). Examples of the `Parties` values returned:
`Kalukana Investments Limited (100%)`, `Zimba Mining Co-operative Society Ltd (100%)`, `Jin Ding Mining Limited (100%)`, `Chirundu Joint Venture Zambia Limited (100%)`, `Goviex Uranium Zambia Limited`, `Zhonghui Mining Industry Zambia Limited (100%)`.

## 7. PACRA (company registry): where holder contact detail actually lives

- Public per-company **Business Search**: https://search.pacra.org.zm/: "search and preview details of any registered business" (min 4 characters; search by name/number). Registration portal: https://portal.pacra.org.zm; movable-property registry: https://mprs.pacra.org.zm/.
- The search is an **interactive, per-lookup** tool (JS SPA). No public API, JSON endpoint, or bulk export is documented or advertised. Full extracts / certified company profiles (which carry registered office address and directors) are generally **paid** services per PACRA's Forms & Fees.
- Practical implication: registered-office address / directors for each holder company could be obtained by **per-name lookups against PACRA** using the `Parties` names harvested from the Map Portal, but that is per-record, likely rate-limited and/or paid, and is *not* a legitimate bulk feed. Contact PACRA (`pro@pacra.org.zm`) about bulk/API access if scale is needed. Note: `search.pacra.org.zm` uses `search.pacra` (Zambia); do not confuse with same-named registries elsewhere.

## 8. Open items / caveats

- NGDR GeoServer WFS could not be tested here (DNS did not resolve). Worth retrying `https://ngdr.mmmd.gov.zm/geoserver/ows?service=WFS&request=GetCapabilities` and `DescribeFeatureType` from a resolving network to confirm it carries no richer party/contact layer than the Landfolio portal (expected: it does not: same underlying data, contact fields empty).
- Token/proxy behavior can change if the Ministry reconfigures the portal (it was recently re-contracted with Spatial Dimension). Re-verify the `proxy.ashx` path before any pull.
- Verified counts: Active/0 = 1,750; Active/2 = 213. Full-estate totals not enumerated (kept requests minimal).
