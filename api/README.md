# Zambia Mineral Origin Gate API

Resolves a Zambian mineral licence code to a **binary** verified / not-verified verdict, with four checks that each trace to a published government register.

Base URL: `https://danielpatelzamb.github.io/zambia-legibility-map/api/v1`

No key, no rate limit, no server. It is a set of static JSON files on GitHub Pages, served with `Access-Control-Allow-Origin: *`, so a browser or an off-chain worker can call it directly.

## Try it

```bash
curl -s https://danielpatelzamb.github.io/zambia-legibility-map/api/v1/licence/40199-HQ-AMR.json
```

```bash
curl -s https://danielpatelzamb.github.io/zambia-legibility-map/api/v1/index.json
```

## Endpoints

| Endpoint | Returns |
|---|---|
| `GET /index.json` | Service metadata, check definitions, counts, source provenance |
| `GET /licence/{CODE}.json` | The gate verdict for one licence code. Codes are upper case, e.g. `40199-HQ-AMR` |
| `GET /bulk/gate.json` | Every known code with its verdict, for bulk consumers |
| `GET /openapi.json` | OpenAPI 3.1 description of the contract |

## The one field that matters

```json
"verified": false
```

`verified` is true **only when all four checks pass.** It is deliberately a single boolean rather than a rich provenance document, and that is a design decision rather than a shortcut.

Rich per-lot provenance fragments a fungible commodity into thousands of non-interchangeable lots, which destroys the depth you need for price discovery. A binary gate does the opposite: it concentrates supply into one pool of "passes" and one pool of "does not". This is how LME brand approval has worked for a century. A warrant is fungible precisely because the provenance reached the market as a yes, not as a data payload.

Check detail is still returned in full, for audit. It is not meant to be traded on.

## The four checks

| id | Requirement | Source |
|---|---|---|
| `licence_permits_production` | The licence class must permit minerals to be produced for sale | NGDR register |
| `no_adverse_notice` | The licence must not appear in a cancellation or default notice | MMMD notices |
| `beneficial_ownership_declared` | The holder must have declared its beneficial owners | PACRA |
| `annual_returns_filed` | The holder must be current on statutory annual returns | PACRA |

The first check is the one nobody asks and the cheapest fraud to catch. Most licences on the Zambian register are exploration or bidding-area rights that **cannot lawfully produce minerals for sale**. A seller quoting one as the origin of a cargo is making a claim the register itself contradicts, and that takes one HTTP call to test.

## Revoked is not the same as unknown

A code that has been cancelled is absent from the active register **by definition**. A plain `404` would conflate "we have never heard of this" with "this was revoked", which are completely different risks.

So cancelled and lapsed codes get their own file:

```json
{
  "licence_code": "23189-HQ-LEL",
  "found": true,
  "on_active_register": false,
  "status": "revoked_or_lapsed",
  "verified": false,
  "adverse_notices": [
    { "notice": "Cancelled at MLC 78th meeting (Apr 2024)", "holder_as_listed": "Helmet Metal Limited" }
  ]
}
```

A genuine `404` therefore means only one thing: not in this snapshot.

## Example response

```json
{
  "schema": "zm-origin-gate/v1",
  "generated": "2026-08-12",
  "licence_code": "40199-HQ-AMR",
  "found": true,
  "on_active_register": true,
  "status": "active",
  "verified": false,
  "origin_eligible": true,
  "grade": "C",
  "checks_passed": 2,
  "checks_total": 4,
  "checks": [
    {
      "id": "licence_permits_production",
      "pass": true,
      "requirement": "The licence class must permit minerals to be produced for sale",
      "detail": "Artisanal mining right permits production",
      "source": "ngdr"
    }
  ],
  "licence": { "code": "40199-HQ-AMR", "type": "AMR", "commodities": ["Gold"], "hectares": 6 },
  "holder": { "name": "...", "beneficial_ownership_declared": false, "annual_returns_filed": false },
  "sources": [ { "id": "ngdr", "publisher": "Geological Survey Department, Zambia", "snapshot": "2025-06-18" } ]
}
```

## Calling it from a contract or worker

The gate is deliberately cheap to consume off-chain. A worker fetches the file, checks one boolean, and signs an attestation:

```js
const r = await fetch(`${BASE}/licence/${code}.json`);
if (!r.ok) throw new Error("unknown licence code");
const gate = await r.json();
if (!gate.verified) throw new Error(`gate failed: ${gate.checks_passed}/4`);
// gate.verified === true, so attest
```

Do not put the check detail on chain. Put the boolean and the `generated` date on chain, and keep the detail retrievable for audit.

## What this does not do

It does not prove that any material was produced, that a cargo came off the licence someone names, or that the holder is solvent or honest. It proves that on the snapshot date, four published government records agreed.

The physical link between a cargo and a piece of ground is not covered by any public Zambian record. Closing that gap needs an assay-based fingerprint keyed to the licence area, not another API.

## Provenance and terms

Sources, publishers and snapshot dates are in every response and in `index.json`. Derived from Zambian public registers. Reuse freely with attribution to this project and to the underlying government sources.

Regenerate with `pipeline/build_origin_gate_api.ps1`. Output is deterministic, so rebuilding unchanged data produces an empty diff.
