/* Zambian Copper Legibility Map & Bankability Scorecard — app logic */
"use strict";

const HS_LABELS = {
  "740311": "7403.11 — Refined copper cathodes",
  "2603": "2603 — Copper ores & concentrates",
  "7402": "7402 — Unrefined / blister copper",
  "7404": "7404 — Copper waste & scrap",
  "7408": "7408 — Copper wire",
  "8105": "8105 — Cobalt (mattes, unwrought, powders)",
};
const PALETTE = ["#3987e5", "#e06a3a", "#22b381", "#eda100", "#d55181"];

/* ---------- tabs ---------- */
document.querySelectorAll("nav.tabs button").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("nav.tabs button").forEach((b) => b.classList.remove("active"));
    document.querySelectorAll(".tab-panel").forEach((p) => p.classList.remove("active"));
    btn.classList.add("active");
    document.getElementById("tab-" + btn.dataset.tab).classList.add("active");
    if (btn.dataset.tab === "map" && window._leafletMap) window._leafletMap.invalidateSize();
    if (btn.dataset.tab === "corridors") initCorridors3D();
    if (window._deckSetRunning) window._deckSetRunning(btn.dataset.tab === "corridors");
  });
});

/* ================================================================
   MAP
================================================================ */
(function buildMap() {
  const map = L.map("map", { worldCopyJump: true, zoomControl: true }).setView([-13.2, 27.8], 5);
  window._leafletMap = map;
  L.tileLayer("https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png", {
    maxZoom: 19, subdomains: "abcd",
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
  }).addTo(map);
  L.control.scale({ imperial: false, position: "bottomleft" }).addTo(map);

  // Zambia in focus: dim outside the border + a crisp light outline.
  if (window.ZMB_ADM0) {
    const geom = ZMB_ADM0.features[0].geometry;
    const polys = geom.type === "MultiPolygon" ? geom.coordinates : [geom.coordinates];
    const holes = polys.map((rings) => rings[0].map(([lng, lat]) => [lat, lng]));
    const world = [[-89, -180], [-89, 180], [89, 180], [89, -180]];
    L.polygon([world, ...holes], {
      stroke: false, fillColor: "#000000", fillOpacity: 0.32, interactive: false,
    }).addTo(map);
    L.geoJSON(ZMB_ADM0, {
      style: { color: "#8b98a5", weight: 1.6, fill: false, opacity: 0.85 },
      interactive: false,
    }).addTo(map);
  }

  const overlays = {};

  // Corridors — white casing under the colored line for legibility on any tile
  const corridorLayer = L.layerGroup();
  GEO.corridors.forEach((c) => {
    L.polyline(c.waypoints, { color: "#ffffff", weight: 6, opacity: 0.85, interactive: false })
      .addTo(corridorLayer);
    L.polyline(c.waypoints, {
      color: c.color, weight: 3, opacity: 0.95,
      dashArray: c.mode === "rail" ? null : "9 6",
    })
      .bindPopup(`<b>${c.name}</b><br><i>${c.mode} → ${c.port}</i><br>${c.status}`)
      .bindTooltip(c.name, { sticky: true })
      .addTo(corridorLayer);
  });
  overlays["Export corridors (schematic)"] = corridorLayer.addTo(map);

  // Ports — labeled anchors at the corridor endpoints
  const portLayer = L.layerGroup();
  GEO.ports.forEach((p) => {
    L.circleMarker(p.latlng, { radius: 6.5, color: "#0b0b0b", weight: 2, fillColor: "#ffffff", fillOpacity: 1 })
      .bindPopup(`<b>Port of ${p.name}</b>`)
      .bindTooltip(p.name, {
        permanent: true, direction: "bottom", offset: [0, 6], className: "port-label",
      })
      .addTo(portLayer);
  });
  overlays["Seaports"] = portLayer.addTo(map);

  // Named operations — badge symbology, not dots: M = mine, R = refiner/smelter,
  // D = development project. Distinct shapes + letters read at a glance.
  const OP_BADGE = {
    mining:      { letter: "M", color: "#e06a3a", shape: "border-radius:4px" },
    processing:  { letter: "R", color: "#9a7fd1", shape: "border-radius:50%" },
    development: { letter: "D", color: "#22b381", shape: "border-radius:4px;border-style:dashed" },
  };
  const opLayer = L.layerGroup();
  GEO.licenses.forEach((s) => {
    const b = OP_BADGE[s.type] || OP_BADGE.mining;
    L.marker(s.latlng, {
      icon: L.divIcon({
        className: "",
        html: `<div style="width:19px;height:19px;${b.shape};background:${b.color};border:1.5px solid #0d1117;
          box-shadow:0 0 0 1.5px rgba(255,255,255,0.75),0 2px 6px rgba(0,0,0,0.5);
          display:flex;align-items:center;justify-content:center;
          font:700 10.5px system-ui,sans-serif;color:#0d1117;">${b.letter}</div>`,
        iconSize: [22, 22], iconAnchor: [11, 11],
      }),
    })
      .bindTooltip(s.name.split("(")[0].trim(), { direction: "top", offset: [0, -10] })
      .bindPopup(() => {
        // production join is lazy — PRODUCTION and productionFor load after buildMap
        let prod = "";
        if (typeof productionFor === "function") {
          const c = productionFor(s.name.toUpperCase());
          if (c) {
            const years = Object.keys(c.series).sort();
            const latest = years[years.length - 1];
            prod = `<br><b style="color:#e06a3a">${Number(c.series[latest]).toLocaleString()} t Cu (${latest})</b>` +
              (years.length > 1 ? ` · ${years[0]}: ${Number(c.series[years[0]]).toLocaleString()} t` : "") +
              (c.usd2023 ? ` · $${(c.usd2023 / 1e6).toFixed(0)}M value (2023)` : "") +
              ` <span style="color:#8b98a5">— EITI</span>`;
          }
        }
        return `<b>${s.name}</b><br><i>${s.type === "processing" ? "Refiner / smelter" : s.type === "development" ? "Development project" : "Mine (large-scale)"}</i><br>${s.note}${prod}<br><span style="color:#8b98a5">Named-operation marker — approximate site location.</span>`;
      })
      .addTo(opLayer);
  });
  overlays["Named operations: mines · refiners · projects"] = opLayer.addTo(map);

  // Clearing hubs
  const clearLayer = L.layerGroup();
  GEO.clearingHubs.forEach((h) => {
    L.circleMarker(h.latlng, {
      radius: 4 + h.weight * 1.6, color: "#22b381", weight: 2,
      fillColor: "#22b381", fillOpacity: 0.25,
    }).bindPopup(`<b>${h.name}</b><br>Licensed clearing agents: ${"●".repeat(h.weight)}<br>${h.note}<br><span style="color:#8b98a5">City-level cluster from the ZRA licensed-agents list.</span>`)
      .addTo(clearLayer);
  });
  overlays["Customs clearing hubs (ZRA)"] = clearLayer.addTo(map);

  // Real license layer — NGDR open-WFS centroids joined with MMMD revocation lists
  const LIC_GROUPS = {
    LEL: ["Exploration", "#3987e5"], SEL: ["Exploration", "#3987e5"], PL: ["Exploration", "#3987e5"], P_LEL: ["Exploration", "#3987e5"],
    SML: ["Mining", "#e06a3a"], LML: ["Mining", "#e06a3a"], P_SML: ["Mining", "#e06a3a"], P_LML: ["Mining", "#e06a3a"],
    MPL: ["Processing", "#9a7fd1"],
    AMR: ["Artisanal", "#22b381"],
    SGL: ["Gemstone", "#d55181"], LGL: ["Gemstone", "#d55181"], LPL: ["Gemstone", "#d55181"],
    BA: ["Bidding area", "#8b98a5"],
  };
  // IMPORTANT: every license shown is ON the Jun-2025 ACTIVE register, so none is
  // currently cancelled. The flags are point-in-time official NOTICES about
  // curable or historical matters — not proof of current bad standing:
  //  - The "Final Public Default Notice" (18 Jun 2025) is a Section-72 SHOW-CAUSE
  //    notice: it lists curable breaches (unpaid area charges, unsubmitted
  //    quarterly/annual reports, unregistered pegging certificate) with a 30-DAY
  //    remedy window. A holder still on the active register most likely cured it.
  //  - An MLC-78 (Apr 2024) cancellation on an active-register license did NOT
  //    stick (~1,200 appealed; many reinstated) — adverse history, not status.
  // Amber = single flag (verify). Red = BOTH (repeat non-compliance).
  const FLAG_TEXT = {
    1: "◉ Listed in the 18 Jun 2025 default (show-cause) notice — a curable compliance breach with a 30-day remedy window. Still on the active register: verify, not proof of current default.",
    2: "◉ Cancelled at MLC-78 (Apr 2024) but on the Jun-2025 active register — reinstated. Adverse history, not current status.",
    3: "⚠ Repeat non-compliance: an MLC-78 (Apr 2024) cancellation AND the Jun-2025 show-cause notice. Still on the active register — verify.",
  };
  const isRed = (f) => f === 3; // red only for repeat non-compliance
  if (window.LICENSES_GEO && LICENSES_GEO.features.length) {
    const licCanvas = L.canvas({ padding: 0.4 });
    const GROUP_META = {
      "Mining": { color: "#e06a3a", desc: "production licenses (SML/LML)" },
      "Processing": { color: "#9a7fd1", desc: "smelters/refineries (MPL)" },
      "Artisanal": { color: "#22b381", desc: "artisanal rights (AMR)" },
      "Gemstone": { color: "#d55181", desc: "gemstone licenses" },
      "Exploration": { color: "#3987e5", desc: "exploration only — no production" },
      "Bidding area": { color: "#8b98a5", desc: "gazetted for bidding" },
    };
    const DEFAULT_ON = new Set(["Mining", "Processing", "Artisanal", "Gemstone"]);
    const BUCKETS = [
      { min: 0, label: "All sizes" },
      { min: 100, label: "≥100 ha" },
      { min: 1000, label: "≥1,000 ha" },
      { min: 10000, label: "≥10,000 ha" },
    ];
    const bucketOf = (ha) => (ha >= 10000 ? 3 : ha >= 1000 ? 2 : ha >= 100 ? 1 : 0);

    const polyPopup = (p) => {
      const g = LIC_GROUPS[p.t] || [p.t, "#9aa7b6"];
      return `<b>${p.c}</b><br><i style="color:${g[1]}">${g[0]} (${p.t})</i>` +
        (p.h ? `<br>${p.h}` : "") +
        (p.m ? `<br><span style="color:#9aa7b6">${p.m}</span>` : "") +
        (p.e ? `<br>Expires: ${p.e}` : "") + (p.a ? ` · ${Number(p.a).toLocaleString()} ha` : "") +
        (p.f ? `<br><b style="color:${isRed(p.f) ? "#f85149" : "#f5a623"}">${FLAG_TEXT[p.f]}</b>` : "") +
        `<br><span style="color:#8b98a5">License parcel — NGDR GeoServer snapshot (active register, Jun 2025).</span>`;
    };

    // Partition features by group × size bucket. SHADED PARCELS ONLY — no dot mode.
    const featsBy = {};
    const groups = {};
    Object.keys(GROUP_META).forEach((g) => {
      featsBy[g] = [[], [], [], []];
      groups[g] = { n: 0, nFlag: 0 };
    });
    LICENSES_GEO.features.forEach((feat) => {
      const p = feat.properties;
      const gName = (LIC_GROUPS[p.t] || [p.t, "#9aa7b6"])[0];
      if (!featsBy[gName]) return;
      featsBy[gName][bucketOf(p.a || 0)].push(feat);
      groups[gName].n++;
      if (p.f) groups[gName].nFlag++;
    });

    // One batched GeoJSON layer per group × bucket (clean licenses) and the same
    // for flagged: red = in the current (Jun-2025) default notice; amber = only a
    // historical MLC-78 cancellation — the license is on the active register, so
    // the cancellation didn't stick (likely reinstated on appeal). Never label
    // an active-register license "cancelled".
    const polyLayer = {}, flagPolyLayer = {};
    Object.keys(GROUP_META).forEach((g) => {
      polyLayer[g] = []; flagPolyLayer[g] = [];
      const color = GROUP_META[g].color;
      for (let b = 0; b < 4; b++) {
        const feats = featsBy[g][b];
        polyLayer[g][b] = feats.length
          ? L.geoJSON({ type: "FeatureCollection", features: feats }, {
              renderer: licCanvas, smoothFactor: 1.1,
              style: { color, weight: 1.2, opacity: 0.9, fillColor: color, fillOpacity: 0.3 },
              onEachFeature: (f, layer) => layer.bindPopup(() => polyPopup(f.properties)),
            })
          : null;
        const flagged = feats.filter((f) => f.properties.f > 0);
        flagPolyLayer[g][b] = flagged.length
          ? L.geoJSON({ type: "FeatureCollection", features: flagged }, {
              renderer: licCanvas, smoothFactor: 1.1,
              style: (f) => isRed(f.properties.f)
                ? { color: "#f85149", weight: 1.3, opacity: 0.95, fillColor: "#f85149", fillOpacity: 0.35 }
                : { color: "#f5a623", weight: 1.3, opacity: 0.95, fillColor: "#f5a623", fillOpacity: 0.3 },
              onEachFeature: (f, layer) => layer.bindPopup(() => polyPopup(f.properties)),
            })
          : null;
      }
    });

    // Commodity index for the mineral filter (top minerals by parcel count)
    const mineralCounts = {};
    LICENSES_GEO.features.forEach((f) => {
      (f.properties.m || "").split(",").forEach((tok) => {
        const t = tok.trim();
        if (t.length > 2) mineralCounts[t] = (mineralCounts[t] || 0) + 1;
      });
    });
    const topMinerals = Object.entries(mineralCounts).sort((a, b) => b[1] - a[1]).slice(0, 14);

    const state = { groups: new Set(DEFAULT_ON), minBucket: 0, mineral: "" };
    const licContainer = L.layerGroup(), flagContainer = L.layerGroup();

    // Scale-dependent parcel styling: zoomed out, thick strokes + heavy fill make
    // license clusters read as FILLED REGIONS (not specks); zoomed in, thin crisp
    // parcel borders like the cadastre portal.
    const zoomBand = () => { const z = map.getZoom(); return z >= 9 ? 2 : z >= 7 ? 1 : 0; };
    const BAND_STYLE = [
      { w: 4.5, fo: 0.55 },  // national view — solid filled coverage
      { w: 2.6, fo: 0.45 },  // regional view
      { w: 1.2, fo: 0.30 },  // parcel view — crisp borders
    ];
    let lastBand = -1;
    function applyZoomStyle() {
      const band = zoomBand();
      if (band === lastBand) return;
      lastBand = band;
      const { w, fo } = BAND_STYLE[band];
      Object.entries(polyLayer).forEach(([g, arr]) => {
        const color = GROUP_META[g].color;
        arr.forEach((l) => l && l.setStyle({ color, weight: w, opacity: 0.95, fillColor: color, fillOpacity: fo }));
      });
      const flagStyle = (f) => isRed(f.properties.f)
        ? { color: "#f85149", weight: w, opacity: 0.95, fillColor: "#f85149", fillOpacity: Math.min(0.65, fo + 0.05) }
        : { color: "#f5a623", weight: w, opacity: 0.95, fillColor: "#f5a623", fillOpacity: fo };
      Object.values(flagPolyLayer).forEach((arr) => arr.forEach((l) => l && l.setStyle(flagStyle)));
      Object.values(mineralCache).forEach((entry) => {
        if (entry.lic) entry.lic.setStyle({ color: entry.color, weight: w, opacity: 0.95, fillColor: entry.color, fillOpacity: fo });
        if (entry.flag) entry.flag.setStyle(flagStyle);
      });
    }
    map.on("zoomend", applyZoomStyle);

    const mineralCache = {}; // mineral -> per-group filtered layers, built on demand
    function filteredLayers(g) {
      const key = g + "|" + state.mineral + "|" + state.minBucket;
      if (!mineralCache[key]) {
        const feats = [];
        for (let b = state.minBucket; b < 4; b++) {
          featsBy[g][b].forEach((f) => {
            if ((f.properties.m || "").includes(state.mineral)) feats.push(f);
          });
        }
        const color = GROUP_META[g].color;
        const flagged = feats.filter((f) => f.properties.f > 0);
        const { w, fo } = BAND_STYLE[zoomBand()]; // build with the current zoom band's style
        mineralCache[key] = {
          color,
          lic: feats.length ? L.geoJSON({ type: "FeatureCollection", features: feats }, {
            renderer: licCanvas, smoothFactor: 1.1,
            style: { color, weight: w, opacity: 0.95, fillColor: color, fillOpacity: fo },
            onEachFeature: (f, layer) => layer.bindPopup(() => polyPopup(f.properties)),
          }) : null,
          flag: flagged.length ? L.geoJSON({ type: "FeatureCollection", features: flagged }, {
            renderer: licCanvas, smoothFactor: 1.1,
            style: (f) => isRed(f.properties.f)
              ? { color: "#f85149", weight: w, opacity: 0.95, fillColor: "#f85149", fillOpacity: Math.min(0.65, fo + 0.05) }
              : { color: "#f5a623", weight: w, opacity: 0.95, fillColor: "#f5a623", fillOpacity: fo },
            onEachFeature: (f, layer) => layer.bindPopup(() => polyPopup(f.properties)),
          }) : null,
        };
      }
      return mineralCache[key];
    }
    function refreshLicenses() {
      licContainer.clearLayers(); flagContainer.clearLayers();
      state.groups.forEach((g) => {
        if (state.mineral) {
          const fl = filteredLayers(g);
          if (fl.lic) licContainer.addLayer(fl.lic);
          if (fl.flag) flagContainer.addLayer(fl.flag);
        } else {
          for (let b = state.minBucket; b < 4; b++) {
            if (polyLayer[g][b]) licContainer.addLayer(polyLayer[g][b]);
            if (flagPolyLayer[g][b]) flagContainer.addLayer(flagPolyLayer[g][b]);
          }
        }
      });
    }
    refreshLicenses();
    applyZoomStyle(); // apply the current zoom band's style at load, not just on first zoom

    overlays["Active license areas (filters below)"] = licContainer.addTo(map);
    overlays["⚑ Flagged in an official notice (verify — not current cancellation)"] = flagContainer.addTo(map);
    window._licLayers = { licContainer, flagContainer, groups, state, refreshLicenses, polyLayer };

    // Filter bar: type pills + size pills
    const bar = document.getElementById("lic-filter");
    if (bar) {
      bar.innerHTML = '<span class="flt-label">Types:</span>' +
        Object.entries(GROUP_META).map(([g, meta]) => {
          const grp = groups[g];
          if (!grp.n) return "";
          return `<button class="lic-pill" data-group="${g}" aria-pressed="${DEFAULT_ON.has(g)}"
            style="--pill-color:${meta.color}" title="${meta.desc}">
            <span class="dot"></span>${g} <span class="n">${grp.n.toLocaleString()}${grp.nFlag ? " · " + grp.nFlag.toLocaleString() + "⚑" : ""}</span>
          </button>`;
        }).join("") +
        '<span class="flt-label" style="margin-left:12px">Min size:</span>' +
        BUCKETS.map((bk, i) => `<button class="lic-pill lic-size" data-bucket="${i}" aria-pressed="${i === 0}"
          style="--pill-color:#f5a623">${bk.label}</button>`).join("") +
        '<span class="flt-label" style="margin-left:12px">Mineral:</span>' +
        `<select id="lic-mineral" style="padding:4px 9px;font-size:12px">
          <option value="">Any mineral</option>
          ${topMinerals.map(([m, c]) => `<option value="${m}">${m} (${c.toLocaleString()})</option>`).join("")}
        </select>`;

      bar.querySelectorAll(".lic-pill[data-group]").forEach((pill) => {
        pill.addEventListener("click", () => {
          const g = pill.dataset.group;
          const on = pill.getAttribute("aria-pressed") !== "true";
          pill.setAttribute("aria-pressed", String(on));
          if (on) state.groups.add(g); else state.groups.delete(g);
          refreshLicenses();
        });
      });
      bar.querySelectorAll(".lic-size").forEach((pill) => {
        pill.addEventListener("click", () => {
          bar.querySelectorAll(".lic-size").forEach((p) => p.setAttribute("aria-pressed", "false"));
          pill.setAttribute("aria-pressed", "true");
          state.minBucket = Number(pill.dataset.bucket);
          refreshLicenses();
        });
      });
      const minSel = document.getElementById("lic-mineral");
      if (minSel) minSel.addEventListener("change", () => {
        state.mineral = minSel.value;
        refreshLicenses();
      });
    }
  }

  // Disputes / fraud / enforcement layer (from data/legal_layers.js)
  const CAT_STYLE = {
    "license-dispute":        { color: "#9a7fd1", glyph: "◆", label: "License dispute" },
    "tax-corporate-dispute":  { color: "#4d9fec", glyph: "◆", label: "Corporate / tax dispute" },
    "fraud-scam":             { color: "#f85149", glyph: "▲", label: "Fraud / scam" },
    "illegal-mining":         { color: "#e08a2e", glyph: "▲", label: "Illegal mining" },
    "environmental-litigation": { color: "#31c48d", glyph: "◆", label: "Environmental litigation" },
  };
  window._CAT_STYLE = CAT_STYLE;
  const CASES = (window.LEGAL && LEGAL.cases) || [];
  if (CASES.length) {
    const dispLayer = L.layerGroup();
    window._disputeMarkers = [];
    CASES.forEach((c, i) => {
      const st = CAT_STYLE[c.category] || { color: "#9aa7b6", glyph: "●", label: c.category };
      const m = L.marker([c.lat, c.lng], {
        icon: L.divIcon({
          className: "",
          html: `<div style="font-size:17px;line-height:1;color:${st.color};text-shadow:0 0 3px #fff,0 0 3px #fff,0 0 3px #fff;">${st.glyph}</div>`,
          iconSize: [18, 18], iconAnchor: [9, 9],
        }),
      }).bindPopup(
        `<b>${c.name}</b><br><i style="color:${st.color}">${st.label} · ${c.years}</i><br>${c.summary}` +
        (c.source ? `<br><a href="${c.sourceUrl || "#"}" target="_blank" rel="noopener">${c.source}</a>` : "") +
        `<br><span style="color:#8b98a5">Location approximate.</span>`
      );
      m._case = c; m._idx = i;
      m.addTo(dispLayer);
      window._disputeMarkers.push(m);
    });
    overlays["Disputes & fraud cases"] = dispLayer.addTo(map);
    window._disputeLayer = dispLayer;
  }

  // exposed so later modules can register overlays (see ECONOMIC LINKAGE)
  window._leafletLayerControl = L.control.layers(null, overlays, { collapsed: false }).addTo(map);

  // Legend
  const legend = document.getElementById("map-legend");
  const badge = (letter, color, extra = "") =>
    `<span class="swatch" style="background:${color};border:1.5px solid #0d1117;box-shadow:0 0 0 1.5px rgba(255,255,255,0.6);${extra}
      display:inline-flex;align-items:center;justify-content:center;width:15px;height:15px;
      font:700 9px system-ui,sans-serif;color:#0d1117;">${letter}</span>`;
  legend.innerHTML = [
    [badge("M", "#e06a3a", "border-radius:3px;"), "Mine (named operation)"],
    [badge("R", "#9a7fd1", "border-radius:50%;"), "Refiner / smelter"],
    [badge("D", "#22b381", "border-radius:3px;border-style:dashed;"), "Development project"],
    ['<span class="swatch" style="background:rgba(224,106,58,0.45);border:1.5px solid #e06a3a"></span>', "License area (shaded by type; filled at low zoom)"],
    ['<span class="swatch" style="background:rgba(248,81,73,0.5);border:1.5px solid #f85149"></span>', "Repeat non-compliance (2024 cancellation + 2025 notice)"],
    ['<span class="swatch" style="background:rgba(245,166,35,0.45);border:1.5px solid #f5a623"></span>', "Flagged in an official notice — show-cause default or reinstated cancellation (verify)"],
    ['<span class="swatch dot" style="background:rgba(34,179,129,0.25);border:2px solid #22b381"></span>', "Clearing-agent hub (size = concentration)"],
    ['<span class="swatch dot" style="background:#fcfcfb;border:2px solid #0b0b0b"></span>', "Seaport"],
    ['<span class="swatch line" style="background:#e4572e"></span>', "Lobito (rail)"],
    ['<span class="swatch line" style="background:#2e9db5"></span>', "TAZARA / Dar (rail)"],
    ['<span class="swatch line" style="background:#8d76c9"></span>', "North–South / Durban"],
    ['<span class="swatch line" style="background:#2fb59f"></span>', "Beira"],
    ['<span class="swatch line" style="background:#bc6c25"></span>', "Walvis Bay"],
  ].map(([sw, label]) => `<span class="item">${sw}${label}</span>`).join("");
})();

/* ================================================================
   CORRIDORS 3D (deck.gl + MapLibre dark basemap)
================================================================ */
const CORRIDOR_HUB = [28.21, -12.8]; // Kitwe — the Copperbelt origin for arcs

function haversineKm(a, b) {
  const R = 6371, toR = Math.PI / 180;
  const dLat = (b[0] - a[0]) * toR, dLng = (b[1] - a[1]) * toR;
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(a[0] * toR) * Math.cos(b[0] * toR) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}
function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

// Precompute per-corridor: [lng,lat] path, cumulative-distance timestamps, total km
const CORRIDOR_3D = GEO.corridors.map((c) => {
  const path = c.waypoints.map(([lat, lng]) => [lng, lat]);
  let km = 0;
  const timestamps = c.waypoints.map((wp, i) => {
    if (i > 0) km += haversineKm(c.waypoints[i - 1], wp);
    return km;
  });
  const total = km || 1;
  return {
    ...c, path, km: Math.round(km),
    timestamps: timestamps.map((t) => (t / total) * 100), // normalize to 0–100 loop
    rgb: hexToRgb(c.color),
    endpoint: path[path.length - 1],
  };
});

let _deck = null, _deckAnim = null;

function corridorLayers(time) {
  return [
    // soft glow under each route
    new deck.PathLayer({
      id: "glow", data: CORRIDOR_3D,
      getPath: (d) => d.path,
      getColor: (d) => [...d.rgb, 60],
      getWidth: 7, widthUnits: "pixels",
      jointRounded: true, capRounded: true,
    }),
    // crisp route line
    new deck.PathLayer({
      id: "routes", data: CORRIDOR_3D,
      getPath: (d) => d.path,
      getColor: (d) => [...d.rgb, 210],
      getWidth: 2.2, widthUnits: "pixels",
      jointRounded: true, capRounded: true,
      pickable: true,
    }),
    // animated flow pulses
    new deck.TripsLayer({
      id: "pulses", data: CORRIDOR_3D,
      getPath: (d) => d.path,
      getTimestamps: (d) => d.timestamps,
      getColor: (d) => [255, 255, 255, 255],
      getWidth: 4, widthUnits: "pixels",
      capRounded: true, jointRounded: true,
      trailLength: 14,
      currentTime: time,
      shadowEnabled: false,
    }),
    // 3D arcs from the Copperbelt hub to each port
    new deck.ArcLayer({
      id: "arcs", data: CORRIDOR_3D,
      getSourcePosition: () => CORRIDOR_HUB,
      getTargetPosition: (d) => d.endpoint,
      getSourceColor: (d) => [...d.rgb, 190],
      getTargetColor: (d) => [...d.rgb, 40],
      getWidth: 2.4, getHeight: 0.55,
      greatCircle: false, pickable: true,
    }),
    // hub + port dots
    new deck.ScatterplotLayer({
      id: "nodes",
      data: [
        { pos: CORRIDOR_HUB, r: 9, color: [237, 161, 0], name: "Copperbelt (Kitwe hub)" },
        ...CORRIDOR_3D.map((d) => ({ pos: d.endpoint, r: 6, color: d.rgb, name: d.port })),
      ],
      getPosition: (d) => d.pos,
      getRadius: (d) => d.r, radiusUnits: "pixels",
      getFillColor: (d) => [...d.color, 235],
      getLineColor: [255, 255, 255, 220], getLineWidth: 1.5, lineWidthUnits: "pixels",
      stroked: true, pickable: true,
    }),
    // labels
    new deck.TextLayer({
      id: "labels",
      data: [
        { pos: CORRIDOR_HUB, text: "COPPERBELT", size: 13 },
        ...GEO.ports.map((p) => ({ pos: [p.latlng[1], p.latlng[0]], text: p.name.toUpperCase(), size: 11 })),
      ],
      getPosition: (d) => d.pos,
      getText: (d) => d.text,
      getSize: (d) => d.size,
      getColor: [235, 235, 225, 235],
      getPixelOffset: [0, -16],
      fontFamily: "system-ui, sans-serif", fontWeight: 700,
      outlineWidth: 3, outlineColor: [13, 15, 20, 255],
      fontSettings: { sdf: true },
    }),
  ];
}

function initCorridors3D() {
  if (_deck || typeof deck === "undefined") return;
  _deck = new deck.DeckGL({
    container: "deck-container",
    map: typeof maplibregl !== "undefined" ? maplibregl : undefined,
    mapStyle: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
    initialViewState: { longitude: 27.5, latitude: -16.5, zoom: 4.05, pitch: 52, bearing: -12 },
    controller: true,
    layers: corridorLayers(0),
    getTooltip: ({ object }) =>
      object && (object.name || object.port) && {
        html: `<div style="font-family:system-ui;font-size:12px;max-width:240px">
                 <b>${object.name || object.port}</b>${object.status ? "<br>" + object.status : ""}</div>`,
        style: { background: "#16181d", color: "#eceade", borderRadius: "8px", padding: "8px 10px" },
      },
  });
  // Animation runs ONLY while the corridors tab is visible — a permanent RAF loop
  // re-rendering a hidden WebGL scene was janking the whole app.
  const LOOP = 114; // 100 route + trail
  const start = performance.now();
  let running = false;
  const tick = () => {
    if (!running) { _deckAnim = null; return; }
    const t = ((performance.now() - start) / 40) % LOOP;
    _deck.setProps({ layers: corridorLayers(t) });
    _deckAnim = requestAnimationFrame(tick);
  };
  window._deckSetRunning = (on) => {
    if (on === running) return;
    running = on;
    if (on && !_deckAnim) tick();
  };
  document.addEventListener("visibilitychange", () => {
    const tabActive = document.querySelector(".tab-panel.active")?.id === "tab-corridors";
    window._deckSetRunning(!document.hidden && tabActive);
  });
  window._deckSetRunning(true);

  // infographic cards
  document.getElementById("corridor-cards").innerHTML = CORRIDOR_3D.map((c, i) => `
    <div class="corridor-card" style="border-top-color:${c.color}" data-i="${i}">
      <div class="meta">${c.mode === "rail" ? "🚂 rail" : c.mode === "road" ? "🚛 road" : "🚛/🚂 road + rail"} → ${c.port.split(",")[0].replace("Port of ", "")}</div>
      <h4>${c.name}</h4>
      <div class="dist">~${c.km.toLocaleString()} <small>km (schematic)</small></div>
      <p class="status">${c.status}</p>
    </div>`).join("");
  document.querySelectorAll(".corridor-card").forEach((card) => {
    card.addEventListener("click", () => {
      const c = CORRIDOR_3D[Number(card.dataset.i)];
      const [lng, lat] = c.endpoint;
      _deck.setProps({
        initialViewState: {
          longitude: (lng + CORRIDOR_HUB[0]) / 2, latitude: (lat + CORRIDOR_HUB[1]) / 2,
          zoom: 4.6, pitch: 55, bearing: -12,
          transitionDuration: 900,
        },
      });
    });
  });
}

/* ================================================================
   HERO STATS
================================================================ */
(function buildHeroStats() {
  const el = document.getElementById("hero-stats");
  if (!el) return;
  const nLic = window.LICENSES ? LICENSES.points.length : 0;
  const nFlag = window.LICENSES ? LICENSES.points.filter((p) => p[8] > 0).length : 0;
  const nCases = (window.LEGAL && LEGAL.cases.length) || 0;
  const nAdverse = window.KYC ? Object.values(KYC.lists).reduce((s, l) => s + l.rows.length, 0) : 0;
  el.innerHTML = [
    [nLic.toLocaleString(), "active licenses mapped", "var(--s1)"],
    [nLic ? Math.round((100 * nFlag) / nLic) + "%" : "–", "flagged in official notices", "var(--critical)"],
    [nAdverse.toLocaleString(), "adverse-list records", "var(--serious)"],
    [nCases, "documented disputes & scams", "#9a7fd1"],
    ["5", "export corridors to tidewater", "var(--s3)"],
  ].map(([num, lbl, color]) =>
    `<div class="hero-stat"><div class="num" style="color:${color}">${num}</div><div class="lbl">${lbl}</div></div>`
  ).join("");
})();

/* ================================================================
   KYC / COUNTERPARTY CHECK
================================================================ */
const KYC_ENGINE = (() => {
  const GENERIC = new Set(["MINING", "MINERALS", "MINERAL", "LIMITED", "LTD", "COMPANY", "RESOURCES",
    "ZAMBIA", "ZAMBIAN", "ENTERPRISES", "ENTERPRISE", "INVESTMENTS", "INVESTMENT", "GROUP", "HOLDINGS",
    "GENERAL", "DEALERS", "SUPPLIERS", "AND", "THE", "CORPORATION", "INTERNATIONAL", "GLOBAL",
    // domain words that appear in case narratives — too generic to identify an entity
    "METAL", "METALS", "COPPER", "COBALT", "GOLD", "GEMSTONE", "GEMSTONES", "STONE", "STONES",
    "QUARRY", "QUARRYING", "EXPLORATION", "DEVELOPMENT", "CONSTRUCTION", "TRADING", "SERVICES",
    "LOGISTICS", "VENTURES", "INDUSTRIES", "COMMODITIES", "AGGREGATES", "CONCRETE", "MINES", "MINE"]);
  let index = null; // normName -> entity

  function splitParties(s) {
    if (!s) return [];
    return s.replace(/\(\s*[\d.]+\s*%\s*\)/g, "|").split(/[|;]+/)
      .map((x) => x.replace(/^[,\s]+|[,\s]+$/g, "")).filter((x) => x.length > 2);
  }
  const norm = (s) => s.toUpperCase().replace(/[^A-Z0-9 ]/g, " ").replace(/\s+/g, " ").trim();

  function build() {
    if (index) return index;
    index = new Map();
    const ent = (raw) => {
      const key = norm(raw);
      if (!key) return null;
      if (!index.has(key)) index.set(key, { name: raw.trim(), key, licenses: [], adverse: [] });
      return index.get(key);
    };
    if (window.LICENSES) {
      LICENSES.points.forEach((pt, i) => {
        splitParties(pt[4]).forEach((p) => { const e = ent(p); if (e) e.licenses.push(i); });
      });
    }
    if (window.KYC) {
      Object.entries(KYC.lists).forEach(([listId, list]) => {
        list.rows.forEach((row) => {
          // Adverse-list holders carry the same "(100%)" suffixes as register parties
          const names = splitParties(row[1] || "");
          names.forEach((nm) => {
            const e = ent(nm);
            if (e) e.adverse.push({ listId, label: list.label, code: row[0], detail: row[2] });
          });
        });
      });
    }
    // ZambiaLII judgment hits (scraped, exact-phrase) — keyed by uppercase holder name
    if (window.KYC_COURT) {
      Object.entries(KYC_COURT.names).forEach(([nm, rec]) => {
        const e = ent(nm);
        if (e) e.court = rec;
      });
    }
    // Commodity index — every mineral named on any license → the point rows that list it
    window._mineralIndex = new Map();
    if (window.LICENSES) {
      LICENSES.points.forEach((pt, i) => {
        (pt[5] || "").split(",").forEach((tok) => {
          const m = tok.trim();
          if (m.length < 2) return;
          const key = m.toUpperCase();
          if (!window._mineralIndex.has(key)) window._mineralIndex.set(key, { name: m, rows: [] });
          window._mineralIndex.get(key).rows.push(i);
        });
      });
    }
    return index;
  }

  // Mineral / commodity search — matches the query against commodity names on the
  // register (Beryllium, Neodymium, Cobalt, …), returns matching minerals with
  // holder/parcel counts.
  function mineralSearch(q) {
    build();
    const nq = norm(q);
    if (nq.length < 3 || !window._mineralIndex) return [];
    const out = [];
    for (const [key, rec] of window._mineralIndex) {
      if (key.includes(nq)) {
        const holders = new Set();
        rec.rows.forEach((i) => splitParties(LICENSES.points[i][4]).forEach((h) => holders.add(norm(h))));
        out.push({ mineral: rec.name, parcels: rec.rows.length, holders: holders.size, rows: rec.rows });
      }
    }
    return out.sort((a, b) => b.parcels - a.parcels).slice(0, 8);
  }

  function search(q) {
    build();
    const nq = norm(q);
    if (nq.length < 2) return [];
    const codeQ = /\d{3,5}-?HQ/.test(nq.replace(/\s/g, ""));
    const out = [];
    if (codeQ) {
      const code = nq.replace(/\s/g, "");
      for (const e of index.values()) {
        const licHit = e.licenses.some((i) => LICENSES.points[i][2].replace(/-/g, "").includes(code.replace(/-/g, "")));
        const advHit = e.adverse.some((a) => a.code.replace(/-/g, "").includes(code.replace(/-/g, "")));
        if (licHit || advHit) out.push(e);
        if (out.length >= 30) break;
      }
    } else {
      for (const e of index.values()) {
        if (e.key.includes(nq)) out.push(e);
        if (out.length >= 30) break;
      }
    }
    return out.sort((a, b) => (b.licenses.length + b.adverse.length) - (a.licenses.length + a.adverse.length));
  }

  // Near-name lookup for the no-exact-match case — "Metalex" vs "Metalix" style
  // confusions are a classic KYC trap, deliberate or accidental.
  function lev(a, b) {
    if (Math.abs(a.length - b.length) > 2) return 99;
    const m = a.length, n = b.length;
    let prev = Array.from({ length: n + 1 }, (_, j) => j);
    for (let i = 1; i <= m; i++) {
      const cur = [i];
      for (let j = 1; j <= n; j++) {
        cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      }
      prev = cur;
    }
    return prev[n];
  }
  function similarNames(q) {
    build();
    const qTokens = norm(q).split(" ").filter((t) => t.length >= 5 && !GENERIC.has(t));
    if (!qTokens.length) return [];
    const out = [];
    for (const e of index.values()) {
      const eTokens = e.key.split(" ").filter((t) => t.length >= 5 && !GENERIC.has(t));
      const close = qTokens.some((qt) => eTokens.some((et) => {
        const d = lev(qt, et);
        return d > 0 && d <= (qt.length >= 8 ? 2 : 1);
      }));
      if (close) out.push(e);
      if (out.length >= 5) break;
    }
    return out;
  }

  function disputeMatches(entity) {
    if (!window.LEGAL) return [];
    const tokens = entity.key.split(" ").filter((t) => t.length >= 4 && !GENERIC.has(t));
    if (!tokens.length) return [];
    return LEGAL.cases.filter((c) => {
      // exact word match, not substring — "METAL" must not hit "METALS"
      const words = new Set(norm(c.name + " " + c.summary).split(" "));
      return tokens.some((t) => words.has(t));
    });
  }

  function assess(entity) {
    const reasons = [];
    const cancelled = entity.adverse.filter((a) => a.listId === "mlc78");
    const defaults = entity.adverse.filter((a) => a.listId !== "mlc78");
    const disputes = disputeMatches(entity);
    const fraudDisputes = disputes.filter((c) => c.category === "fraud-scam");
    const now = "2026-07";
    const lics = entity.licenses.map((i) => LICENSES.points[i]);
    const expired = lics.filter((p) => p[6] && p[6] < now);

    // MLC-78 (Apr 2024) cancellations vs the Jun-2025 ACTIVE register: a code still
    // on the register means the cancellation didn't stick (reinstated on appeal).
    // Absence from the register is only "not currently active", never proof the
    // cancellation was executed — statuses change and the snapshot is one date.
    if (!window._activeCodeSet && window.LICENSES) {
      window._activeCodeSet = new Set(LICENSES.points.map((pt) => pt[2]));
    }
    const codeSet = window._activeCodeSet || new Set();
    const reinstated = cancelled.filter((a) => codeSet.has(a.code.trim().toUpperCase()));
    const unresolved = cancelled.filter((a) => !codeSet.has(a.code.trim().toUpperCase()));

    let level = "green";
    if (unresolved.length) {
      // still-operating entities (active licenses on the register) get CAUTION, not HIGH RISK
      level = entity.licenses.length ? "amber" : "red";
      reasons.push(`${entity.licenses.length ? "⚠" : "✖"} ${unresolved.length} license(s) cancelled at MLC-78 (Apr 2024) and not on the Jun-2025 active register — the cancellation appears to have stuck (verify current status on the cadastre portal).`);
    }
    if (reinstated.length) {
      if (level === "green") level = "amber";
      reasons.push(`◉ ${reinstated.length} license(s) were cancelled at MLC-78 (Apr 2024) but appear on the Jun-2025 active register — likely reinstated on appeal. Adverse history, not current status.`);
    }
    if (fraudDisputes.length) { level = "red"; reasons.push(`✖ Possible mention in fraud/scam case(s): ${fraudDisputes.map((c) => c.name).join("; ")} — verify identity match.`); }
    if (defaults.length) {
      // Show-cause default notices list CURABLE breaches (unpaid area charges,
      // unsubmitted reports) with a 30-day remedy window. A holder still on the
      // active register most likely cured it — a note to verify, not proof of
      // bad standing, and NOT a reason to raise the risk level on its own.
      const reportOnly = defaults.every((d) => /report|submission|pegging|program/i.test(d.detail || ""));
      const breachKind = reportOnly ? "unsubmitted reports / paperwork" : "unpaid area charges or compliance breaches";
      reasons.push(`◉ ${defaults.length} license(s) listed in an official show-cause default notice (${breachKind}) — curable, 30-day remedy window; the license(s) remain on the active register. Verify current standing; not proof of default.`);
    }
    if (expired.length) {
      if (level === "green") level = "amber";
      reasons.push(`⚠ ${expired.length} of ${lics.length} register license(s) show expiry dates in the past.`);
    }
    const otherDisputes = disputes.filter((c) => c.category !== "fraud-scam");
    if (otherDisputes.length) reasons.push(`◆ Possible dispute-index mention(s): ${otherDisputes.map((c) => c.name).join("; ")} — verify identity match.`);
    // EITI-verified producer — a strong positive signal for the smell test
    const prod = typeof productionFor === "function" ? productionFor(entity.key) : null;
    if (prod) {
      const years = Object.keys(prod.series).sort();
      const latest = years[years.length - 1];
      reasons.push(`✓ EITI-verified producer: ${Number(prod.series[latest]).toLocaleString()} t copper in ${latest}` +
        (prod.usd2023 ? ` ($${(prod.usd2023 / 1e6).toFixed(0)}M value, 2023)` : "") +
        ` — company-level production published via the EITI Fusion portal.`);
    }
    const court = entity.court || null;
    if (court && court.n > 0) {
      if (level === "green") level = "amber";
      reasons.push(`⚖ ${court.n} published judgment(s) on ZambiaLII match this name exactly — review the cases below (party role not determined automatically).`);
    }
    if (!reasons.length) reasons.push("No adverse findings in the sources checked (register snapshot, MLC-78 list, 2023/2025 default notices, disputes index, ZambiaLII judgments). Absence of findings is not proof of good standing.");
    return { level, reasons, disputes, lics, cancelled, defaults, court };
  }

  return { search, assess, build, similarNames, mineralSearch };
})();

(function buildKycUI() {
  const input = document.getElementById("kyc-query");
  if (!input || !window.KYC) return;
  const suggest = document.getElementById("kyc-suggest");
  const countEl = document.getElementById("kyc-count");
  let debounce = null;

  input.addEventListener("input", () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      const q = input.value.trim();
      if (q.length < 2) { suggest.innerHTML = ""; countEl.textContent = ""; return; }
      const hits = KYC_ENGINE.search(q);
      // Mineral / commodity matches (Beryllium, Neodymium, any listed mineral)
      const minerals = KYC_ENGINE.mineralSearch(q);
      // Also offer dispute-index cases whose text mentions the query (e.g. "Vedanta"
      // appears in cases but holds no Zambian license under that name).
      const nq = q.toUpperCase();
      const caseHits = (window.LEGAL ? LEGAL.cases : [])
        .map((c, i) => ({ c, i }))
        .filter(({ c }) => (c.name + " " + c.summary).toUpperCase().includes(nq))
        .slice(0, 6);
      // No exact match → surface near-spellings we DO know. "Metalex" vs
      // "Metalix" style confusion is a classic KYC trap — make it visible.
      const similar = (!hits.length && !minerals.length && q.length >= 5) ? KYC_ENGINE.similarNames(q) : [];
      const bits = [];
      if (hits.length) bits.push(`${hits.length}${hits.length >= 30 ? "+" : ""} entities`);
      if (minerals.length) bits.push(`${minerals.length} mineral(s)`);
      if (caseHits.length) bits.push(`${caseHits.length} dispute case(s)`);
      countEl.textContent = bits.length ? bits.join(" · ")
        : similar.length ? "no exact match — similar names below (verify: these may be DIFFERENT entities)"
        : "no matches in holders, license codes, minerals, disputes, or similar spellings";
      suggest.innerHTML =
        minerals.map((m) => `
        <div class="kyc-suggestion kyc-mineral" data-mineral="${encodeURIComponent(m.mineral.toUpperCase())}" style="border-color:var(--s3)">
          <span>⬡ ${m.mineral} <span style="color:var(--muted);font-weight:400">— show all licenses listing this mineral</span></span>
          <span class="tags">${m.parcels.toLocaleString()} parcel(s) · ${m.holders.toLocaleString()} holder(s)</span>
        </div>`).join("") +
        (similar.length ? `
        <div style="font-size:11.5px;color:var(--warning);margin:2px 0 6px">⚠ No exact match for “${q.replace(/</g, "&lt;")}”.
        Similar names in the official data — a close spelling can be a different company entirely:</div>` : "") +
        similar.map((e) => `
        <div class="kyc-suggestion" data-key="${encodeURIComponent(e.key)}" style="border-color:var(--warning)">
          <span>≈ ${e.name}</span>
          <span class="tags">${e.licenses.length} license(s)${e.adverse.length ? ` · <span class="hit">${e.adverse.length} adverse</span>` : ""}</span>
        </div>`).join("") +
        hits.map((e) => `
        <div class="kyc-suggestion" data-key="${encodeURIComponent(e.key)}">
          <span>${e.name}</span>
          <span class="tags">${e.licenses.length} license(s)${e.adverse.length ? ` · <span class="hit">${e.adverse.length} adverse</span>` : ""}${e.court && e.court.n ? ` · ⚖ ${e.court.n}` : ""}</span>
        </div>`).join("") +
        caseHits.map(({ c, i }) => `
        <div class="kyc-suggestion kyc-case" data-case="${i}">
          <span>◆ ${c.name}</span>
          <span class="tags">dispute case · ${c.years}</span>
        </div>`).join("");
      suggest.querySelectorAll(".kyc-case").forEach((div) => {
        div.addEventListener("click", () => {
          const marker = (window._disputeMarkers || [])[Number(div.dataset.case)];
          if (!marker) return;
          document.querySelector('nav.tabs button[data-tab="map"]').click();
          window._leafletMap.invalidateSize();
          window._leafletMap.setView(marker.getLatLng(), 8);
          marker.openPopup();
          document.getElementById("map").scrollIntoView({ behavior: "smooth" });
        });
      });
      suggest.querySelectorAll(".kyc-mineral").forEach((div) => {
        div.addEventListener("click", () => {
          const key = decodeURIComponent(div.dataset.mineral);
          showMineralOnMap(key);
        });
      });
      suggest.querySelectorAll(".kyc-suggestion[data-key]").forEach((div) => {
        div.addEventListener("click", () => {
          const key = decodeURIComponent(div.dataset.key);
          const e = [...KYC_ENGINE.build().values()].find((x) => x.key === key);
          if (e) renderReport(e);
        });
      });
    }, 180);
  });

  // Highlight every license parcel listing a given mineral, on the map tab.
  function showMineralOnMap(mineralKey) {
    const rec = window._mineralIndex && window._mineralIndex.get(mineralKey);
    if (!rec) return;
    document.querySelector('nav.tabs button[data-tab="map"]').click();
    if (window._kycHighlight) window._leafletMap.removeLayer(window._kycHighlight);
    const grp = L.layerGroup();
    const bounds = [];
    rec.rows.forEach((i) => {
      const p = LICENSES.points[i];
      bounds.push([p[1], p[0]]);
      L.circleMarker([p[1], p[0]], {
        radius: 5, color: "#22b381", weight: 1.5, fillColor: "#22b381", fillOpacity: 0.5,
      }).bindPopup(`<b>${p[2]}</b><br>${p[4]}<br><span style="color:#9aa7b6">${p[5]}</span>`).addTo(grp);
    });
    grp.addTo(window._leafletMap);
    window._kycHighlight = grp;
    window._leafletMap.invalidateSize();
    if (bounds.length) window._leafletMap.fitBounds(L.latLngBounds(bounds).pad(0.3), { maxZoom: 8 });
    document.getElementById("map").scrollIntoView({ behavior: "smooth" });
  }

  function renderReport(entity) {
    const a = KYC_ENGINE.assess(entity);
    document.getElementById("kyc-report").hidden = false;
    document.getElementById("kyc-name").textContent = entity.name;
    document.getElementById("kyc-sub").textContent =
      `${entity.licenses.length} register license(s) · ${entity.adverse.length} adverse-list entr(ies)`;
    const badge = document.getElementById("kyc-badge");
    badge.className = "risk-badge " + a.level;
    badge.textContent = a.level === "red" ? "HIGH RISK" : a.level === "amber" ? "CAUTION" : "NO ADVERSE FINDINGS";
    document.getElementById("kyc-reasons").innerHTML = a.reasons.map((r) => `<li>${r}</li>`).join("");

    const q = encodeURIComponent(entity.name);
    document.getElementById("kyc-external").innerHTML =
      `<a href="https://search.pacra.org.zm" target="_blank" rel="noopener">PACRA registry ↗</a>` +
      `<a href="https://www.resourcecontracts.org/search?q=${q}" target="_blank" rel="noopener">ResourceContracts ↗</a>` +
      `<a href="https://opencorporates.com/companies?q=${q}&jurisdiction_code=zm" target="_blank" rel="noopener">OpenCorporates ↗</a>` +
      `<a href="https://www.google.com/search?q=${q}+Zambia+mining" target="_blank" rel="noopener">News search ↗</a>`;

    const licCard = document.getElementById("kyc-lic-card");
    if (a.lics.length) {
      licCard.hidden = false;
      document.getElementById("kyc-lic-table").innerHTML =
        "<thead><tr><th>Code</th><th>Type</th><th>Commodities</th><th>Hectares</th><th>Expires</th><th>Status</th></tr></thead><tbody>" +
        a.lics.map((p) => `<tr>
          <td style="text-align:left;font-weight:600">${p[2]}</td><td style="text-align:left">${p[3]}</td>
          <td style="text-align:left;max-width:280px">${p[5]}</td>
          <td>${Number(p[7]).toLocaleString()}</td><td>${p[6]}${p[6] && p[6] < "2026-07" ? " ⚠" : ""}</td>
          <td style="text-align:left;color:${p[8] === 3 ? "var(--critical)" : p[8] ? "var(--warning)" : "var(--good)"}">${
            p[8] === 3 ? "Active — repeat non-compliance (MLC-78 + Jun-2025 notice)"
            : (p[8] & 1) ? "Active — in Jun-2025 show-cause notice (verify)"
            : (p[8] & 2) ? "Active — reinstated after MLC-78"
            : "Active"}</td>
        </tr>`).join("") + "</tbody>";
    } else licCard.hidden = true;

    const advCard = document.getElementById("kyc-adverse-card");
    if (entity.adverse.length) {
      advCard.hidden = false;
      document.getElementById("kyc-adverse-table").innerHTML =
        "<thead><tr><th>List</th><th>License code</th><th>Detail</th></tr></thead><tbody>" +
        entity.adverse.map((h) => `<tr>
          <td style="text-align:left">${h.label}</td>
          <td style="text-align:left;font-weight:600">${h.code}</td>
          <td style="text-align:left;max-width:380px">${h.detail || "—"}</td>
        </tr>`).join("") + "</tbody>";
    } else advCard.hidden = true;

    const courtCard = document.getElementById("kyc-court-card");
    if (a.court && a.court.hits && a.court.hits.length) {
      courtCard.hidden = false;
      document.getElementById("kyc-court-table").innerHTML =
        "<thead><tr><th>Judgment</th><th>Date</th><th>Court</th></tr></thead><tbody>" +
        a.court.hits.map((h) => `<tr>
          <td style="text-align:left;font-weight:600"><a href="${h.u}" target="_blank" rel="noopener">${h.t}</a></td>
          <td style="white-space:nowrap">${h.d || "—"}</td>
          <td style="text-align:left">${h.c || "—"}</td>
        </tr>`).join("") +
        (a.court.n > a.court.hits.length
          ? `<tr><td colspan="3" style="text-align:left;color:var(--muted)">…and ${a.court.n - a.court.hits.length} more — <a href="https://zambialii.org/search/?q=%22${encodeURIComponent(entity.name)}%22" target="_blank" rel="noopener">see all on ZambiaLII ↗</a></td></tr>`
          : "") + "</tbody>";
    } else courtCard.hidden = true;

    const dispCard = document.getElementById("kyc-dispute-card");
    if (a.disputes.length) {
      dispCard.hidden = false;
      document.getElementById("kyc-dispute-table").innerHTML =
        "<thead><tr><th>Case</th><th>Category</th><th>Years</th></tr></thead><tbody>" +
        a.disputes.map((c) => `<tr>
          <td style="text-align:left;font-weight:600">${c.name}</td>
          <td style="text-align:left">${c.category}</td><td>${c.years}</td>
        </tr>`).join("") + "</tbody>";
    } else dispCard.hidden = true;

    const mapBtn = document.getElementById("kyc-map-btn");
    mapBtn.disabled = !a.lics.length;
    mapBtn.onclick = () => {
      if (!a.lics.length) return;
      document.querySelector('nav.tabs button[data-tab="map"]').click();
      if (window._kycHighlight) { window._leafletMap.removeLayer(window._kycHighlight); }
      const grp = L.layerGroup();
      const bounds = [];
      a.lics.forEach((p) => {
        bounds.push([p[1], p[0]]);
        L.circleMarker([p[1], p[0]], {
          radius: 11, color: "#0b0b0b", weight: 2.5, fillColor: "#eda100", fillOpacity: 0.35, dashArray: "4 3",
        }).bindPopup(`<b>${p[2]}</b><br>${entity.name}`).addTo(grp);
      });
      grp.addTo(window._leafletMap);
      window._kycHighlight = grp;
      window._leafletMap.invalidateSize();
      window._leafletMap.fitBounds(L.latLngBounds(bounds).pad(0.6), { maxZoom: 9 });
      document.getElementById("map").scrollIntoView({ behavior: "smooth" });
    };

    document.getElementById("kyc-report").scrollIntoView({ behavior: "smooth", block: "start" });
  }
})();

/* ================================================================
   LICENSE STATS CARD
================================================================ */
(function buildLicenseStats() {
  if (!window.LICENSES || !LICENSES.points.length) return;
  document.getElementById("licenses-card").hidden = false;
  const n = LICENSES.points.length;
  const nDefault = LICENSES.points.filter((p) => p[8] & 1).length;
  const nRepeat = LICENSES.points.filter((p) => p[8] === 3).length; // both notices
  const nFlag = LICENSES.points.filter((p) => p[8] > 0).length;
  document.getElementById("licenses-note").innerHTML =
    `<strong>${n.toLocaleString()} active license records mapped</strong> from the Geological Survey's open ` +
    `GeoServer (snapshot ${LICENSES.meta.snapshot}). Every record shown is on the <em>active</em> register, so none is ` +
    `currently cancelled — the flags are point-in-time official notices, not current status. ` +
    `<strong style="color:var(--amber)">${nDefault.toLocaleString()} (${Math.round((100 * nDefault) / n)}%) are listed in the ` +
    `18 Jun 2025 Final Public Default Notice</strong> — a Section-72 <em>show-cause</em> notice for curable breaches ` +
    `(unpaid area charges, unsubmitted reports) with a 30-day remedy window; a holder still on the active register most ` +
    `likely cured it. <strong style="color:var(--critical)">${nRepeat.toLocaleString()}</strong> carry <em>both</em> that notice ` +
    `and an Apr-2024 MLC-78 cancellation (repeat non-compliance, drawn red). Treat flags as "verify," not "in default." ` +
    `Click any shaded parcel for code, holder, commodities and expiry.`;
  const groups = {};
  LICENSES.points.forEach((p) => {
    const g = ({ LEL: "Exploration", SEL: "Exploration", PL: "Exploration", P_LEL: "Exploration",
      SML: "Mining", LML: "Mining", P_SML: "Mining", P_LML: "Mining", MPL: "Processing",
      AMR: "Artisanal", SGL: "Gemstone", LGL: "Gemstone", LPL: "Gemstone", BA: "Bidding area" })[p[3]] || p[3];
    groups[g] = (groups[g] || 0) + 1;
  });
  const colors = { Exploration: "#3987e5", Mining: "#e06a3a", Processing: "#9a7fd1", Artisanal: "#22b381", Gemstone: "#d55181", "Bidding area": "#8b98a5" };
  document.getElementById("licenses-stats").innerHTML =
    Object.entries(groups).sort((a, b) => b[1] - a[1]).map(([g, c]) =>
      `<span class="item"><span class="swatch dot" style="background:${colors[g] || "#9aa7b6"}"></span><strong>${c.toLocaleString()}</strong>&nbsp;${g}</span>`
    ).join("") +
    `<span class="item"><span class="swatch dot" style="background:#f85149"></span><strong>${nFlag.toLocaleString()}</strong>&nbsp;cancelled / in default</span>`;
})();

/* ================================================================
   PRODUCTION BY COMPANY (EITI Fusion portal + ZEITI XLSX)
================================================================ */
// canonical-key → term to find in normalized entity/marker names
const PROD_MATCH = { KCM: "KONKOLA", CCS: "CHAMBISHI COPPER SMELTER", NFCA: "NFC AFRICA", "SINO-METALS": "SINO METALS" };
function productionFor(normName) {
  if (!window.PRODUCTION) return null;
  return PRODUCTION.companies.find((c) => {
    const term = PROD_MATCH[c.key] || c.key;
    return normName.includes(term);
  }) || null;
}

(function buildProductionChart() {
  if (!window.PRODUCTION || !document.getElementById("production-card") || typeof Chart === "undefined") return;
  document.getElementById("production-card").hidden = false;
  const ysel = document.getElementById("prod-year");
  ["2023", "2022", "2021", "2020", "2019", "2018"].forEach((y) => {
    const o = document.createElement("option"); o.value = y; o.textContent = y; ysel.appendChild(o);
  });
  let prodChart = null;
  const draw = (year) => {
    const rows = PRODUCTION.companies
      .map((c) => ({ name: c.display, t: c.series[year] || 0 }))
      .filter((r) => r.t > 0)
      .sort((a, b) => b.t - a.t);
    const total = rows.reduce((s, r) => s + r.t, 0);
    document.getElementById("prod-total").textContent =
      `${rows.length} companies reporting · ${Math.round(total).toLocaleString()} t combined`;
    if (prodChart) prodChart.destroy();
    prodChart = new Chart(document.getElementById("prod-chart"), {
      type: "bar",
      data: {
        labels: rows.map((r) => r.name),
        datasets: [{
          label: `Copper production ${year} (t)`,
          data: rows.map((r) => r.t),
          backgroundColor: "rgba(224,106,58,0.7)", borderColor: "#e06a3a", borderWidth: 1,
        }],
      },
      options: {
        indexAxis: "y", responsive: true, maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: { label: (c) => ` ${Math.round(c.parsed.x).toLocaleString()} t` } },
        },
        scales: {
          x: { ticks: { callback: (v) => (v / 1000) + "k t" }, grid: { color: "#1b2330" } },
          y: { grid: { display: false }, ticks: { font: { size: 11 } } },
        },
      },
    });
  };
  ysel.addEventListener("change", () => draw(ysel.value));
  draw("2023");
})();

/* ================================================================
   DISPUTES INDEX + DATASETS TABLES
================================================================ */
(function buildLegalTables() {
  const cases = (window.LEGAL && LEGAL.cases) || [];
  const datasets = (window.LEGAL && LEGAL.datasets) || [];
  const CAT = window._CAT_STYLE || {};

  if (cases.length) {
    document.getElementById("disputes-card").hidden = false;
    const filterSel = document.getElementById("dispute-filter");
    [...new Set(cases.map((c) => c.category))].forEach((cat) => {
      const o = document.createElement("option");
      o.value = cat;
      o.textContent = (CAT[cat] && CAT[cat].label) || cat;
      filterSel.appendChild(o);
    });

    const render = () => {
      const f = filterSel.value;
      const rows = cases
        .map((c, i) => ({ ...c, i }))
        .filter((c) => f === "all" || c.category === f)
        .sort((a, b) => (b.years || "").localeCompare(a.years || ""));
      document.getElementById("disputes-table").innerHTML =
        "<thead><tr><th>Case</th><th>Category</th><th>Years</th><th>Summary</th><th>Source</th></tr></thead><tbody>" +
        rows.map((c) => {
          const st = CAT[c.category] || { color: "#9aa7b6", label: c.category, glyph: "●" };
          return `<tr style="cursor:pointer" data-idx="${c.i}">
            <td style="font-weight:600;white-space:nowrap"><span style="color:${st.color}">${st.glyph}</span> ${c.name}</td>
            <td style="text-align:left;white-space:nowrap;color:${st.color}">${st.label}</td>
            <td style="white-space:nowrap">${c.years}</td>
            <td style="text-align:left;max-width:480px">${c.summary}</td>
            <td style="text-align:left;white-space:nowrap">${c.sourceUrl ? `<a href="${c.sourceUrl}" target="_blank" rel="noopener">${c.source}</a>` : (c.source || "")}</td>
          </tr>`;
        }).join("") + "</tbody>";

      // clicking a row flies to the marker on the map tab
      document.querySelectorAll("#disputes-table tbody tr").forEach((tr) => {
        tr.addEventListener("click", () => {
          const idx = Number(tr.dataset.idx);
          const marker = (window._disputeMarkers || [])[idx];
          if (!marker) return;
          window._leafletMap.invalidateSize();
          window._leafletMap.setView(marker.getLatLng(), 8);
          marker.openPopup();
          document.getElementById("map").scrollIntoView({ behavior: "smooth" });
        });
      });
    };
    filterSel.addEventListener("change", render);
    render();
  }

  if (datasets.length) {
    document.getElementById("datasets-card").hidden = false;
    document.getElementById("datasets-table").innerHTML =
      "<thead><tr><th>Dataset</th><th>Contains</th><th>Format</th><th>Terms</th></tr></thead><tbody>" +
      datasets.map((d) => `<tr>
        <td style="font-weight:600;white-space:nowrap"><a href="${d.url}" target="_blank" rel="noopener">${d.name}</a></td>
        <td style="text-align:left;max-width:460px">${d.contains}</td>
        <td style="text-align:left;white-space:nowrap">${d.format}</td>
        <td style="text-align:left;max-width:260px">${d.terms}</td>
      </tr>`).join("") + "</tbody>";
  }
})();

/* ================================================================
   TRADE ANALYSIS
================================================================ */
const ROWS = (window.TRADE_ROWS || []).map((r) => ({ ...r, period: String(r.period) }));
const HAS_DATA = ROWS.length > 0;

function fmtUsd(v) {
  if (v >= 1e9) return "$" + (v / 1e9).toFixed(2) + "B";
  if (v >= 1e6) return "$" + (v / 1e6).toFixed(1) + "M";
  return "$" + Math.round(v).toLocaleString();
}
function quantile(sorted, q) {
  if (!sorted.length) return NaN;
  const pos = (sorted.length - 1) * q;
  const lo = Math.floor(pos), hi = Math.ceil(pos);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

Chart.defaults.font.family = 'system-ui, -apple-system, "Segoe UI", sans-serif';
Chart.defaults.color = "#9aa7b6";
Chart.defaults.borderColor = "#1b2330";

/* ----- Mirror gap chart ----- */
let mirrorChart = null;
function drawMirror(code) {
  const years = ["2019", "2020", "2021", "2022", "2023", "2024"];
  // Zambia-reported exports to World (annual, flow X, reporter 894, partner 0)
  const zmbX = years.map((y) => {
    const r = ROWS.find((r) => r.freq === "A" && r.flow === "X" && r.rep === 894 && r.par === 0 && r.code === code && r.period === y);
    return r ? r.usd : null;
  });
  // Mirror: sum of all reporters' imports FROM Zambia (flow M, partner 894)
  const mirror = years.map((y) => {
    const rs = ROWS.filter((r) => r.freq === "A" && r.flow === "M" && r.par === 894 && r.code === code && r.period === y && r.rep !== 0);
    return rs.length ? rs.reduce((s, r) => s + r.usd, 0) : null;
  });

  const ctx = document.getElementById("mirror-chart");
  if (mirrorChart) mirrorChart.destroy();
  mirrorChart = new Chart(ctx, {
    type: "line",
    data: {
      labels: years,
      datasets: [
        { label: "Zambia-reported exports (FOB)", data: zmbX, borderColor: PALETTE[0], backgroundColor: PALETTE[0], borderWidth: 2, pointRadius: 4, tension: 0.15 },
        { label: "Partner-reported imports from Zambia (mirror, mostly CIF)", data: mirror, borderColor: PALETTE[1], backgroundColor: PALETTE[1], borderWidth: 2, pointRadius: 4, tension: 0.15 },
      ],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      plugins: {
        legend: { position: "bottom" },
        tooltip: { callbacks: { label: (c) => ` ${c.dataset.label}: ${c.parsed.y == null ? "n/a" : fmtUsd(c.parsed.y)}` } },
      },
      scales: {
        y: { ticks: { callback: (v) => fmtUsd(v) }, grid: { color: "#1b2330" } },
        x: { grid: { display: false } },
      },
    },
  });

  // summary line: latest year with both values
  const summary = document.getElementById("mirror-summary");
  for (let i = years.length - 1; i >= 0; i--) {
    if (zmbX[i] != null && mirror[i] != null && zmbX[i] > 0) {
      const gap = mirror[i] - zmbX[i];
      if (zmbX[i] < 1e6) {
        summary.textContent = `${years[i]}: Zambia reports almost none of this flow (${fmtUsd(zmbX[i])}) while partners report ${fmtUsd(mirror[i])} — the gap IS the finding.`;
      } else {
        const pct = (gap / zmbX[i]) * 100;
        summary.textContent = `${years[i]}: mirror ${gap >= 0 ? "exceeds" : "falls short of"} Zambia-reported by ${fmtUsd(Math.abs(gap))} (${pct.toFixed(0)}%).`;
      }
      return;
    }
  }
  summary.textContent = "No overlapping year with both sides reported.";
}

/* ----- Unit value distribution (monthly, partner-level) ----- */
function monthlyUnitValues(code) {
  return ROWS
    .filter((r) => r.freq === "M" && r.flow === "X" && r.code === code && r.par !== 0 && r.kg >= 20000 && r.usd > 0)
    .map((r) => (r.usd / r.kg) * 1000); // USD per tonne
}
function drawDistribution() {
  const cat = monthlyUnitValues("740311");
  const con = monthlyUnitValues("2603");
  if (!cat.length && !con.length) return;
  // Clamp the domain to the 2nd–98th percentile so a single misreported
  // partner-month doesn't stretch the axis; edge bins absorb the tails.
  const all = cat.concat(con).sort((a, b) => a - b);
  const min = quantile(all, 0.02), max = quantile(all, 0.98);
  const nb = 24, w = (max - min) / nb || 1;
  const bins = Array.from({ length: nb }, (_, i) => min + i * w);
  const count = (vals) => {
    const c = new Array(nb).fill(0);
    vals.forEach((v) => c[Math.max(0, Math.min(nb - 1, Math.floor((v - min) / w)))]++);
    return c.map((n) => (100 * n) / (vals.length || 1)); // % of observations
  };
  new Chart(document.getElementById("dist-chart"), {
    type: "bar",
    data: {
      labels: bins.map((b) => "$" + Math.round(b / 100) * 100 / 1000 + "k"),
      datasets: [
        { label: `Cathode 7403.11 (n=${cat.length})`, data: count(cat), backgroundColor: "rgba(42,120,214,0.75)", borderColor: "#3987e5", borderWidth: 1 },
        { label: `Concentrate 2603 (n=${con.length})`, data: count(con), backgroundColor: "rgba(235,104,52,0.65)", borderColor: "#e06a3a", borderWidth: 1 },
      ],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { position: "bottom" },
        tooltip: { callbacks: { label: (c) => ` ${c.dataset.label}: ${c.parsed.y.toFixed(1)}% of partner-months` } },
      },
      scales: {
        x: { stacked: false, grid: { display: false }, title: { display: true, text: "Unit value (USD/tonne)" } },
        y: { title: { display: true, text: "% of partner-month observations" }, grid: { color: "#1b2330" } },
      },
    },
  });
}

/* ----- Spread table ----- */
function drawSpreadTable(year) {
  const tbl = document.getElementById("spread-table");
  const codes = Object.keys(HS_LABELS);
  let html = "<thead><tr><th>HS code</th><th>Partners</th><th>P10 USD/t</th><th>Median USD/t</th><th>P90 USD/t</th><th>P90 / P10</th></tr></thead><tbody>";
  codes.forEach((code) => {
    const uvs = ROWS
      .filter((r) => r.freq === "A" && r.flow === "X" && r.rep === 894 && r.par !== 0 && r.code === code && r.period === year && r.kg >= 20000 && r.usd > 0)
      .map((r) => (r.usd / r.kg) * 1000)
      .sort((a, b) => a - b);
    if (uvs.length < 3) {
      html += `<tr><td>${HS_LABELS[code]}</td><td>${uvs.length}</td><td colspan="4" style="color:var(--muted)">insufficient partner coverage</td></tr>`;
      return;
    }
    const p10 = quantile(uvs, 0.1), p50 = quantile(uvs, 0.5), p90 = quantile(uvs, 0.9);
    const ratio = p90 / p10;
    html += `<tr><td>${HS_LABELS[code]}</td><td>${uvs.length}</td>
      <td>${Math.round(p10).toLocaleString()}</td>
      <td>${Math.round(p50).toLocaleString()}</td>
      <td>${Math.round(p90).toLocaleString()}</td>
      <td style="font-weight:600;color:${ratio > 1.8 ? "var(--critical)" : "var(--ink)"}">${ratio.toFixed(2)}×</td></tr>`;
  });
  tbl.innerHTML = html + "</tbody>";
}

if (HAS_DATA) {
  const sel = document.getElementById("mirror-code");
  Object.entries(HS_LABELS).forEach(([code, label]) => {
    const o = document.createElement("option");
    o.value = code; o.textContent = label;
    sel.appendChild(o);
  });
  sel.addEventListener("change", () => drawMirror(sel.value));
  drawMirror("740311");
  drawDistribution();

  const ysel = document.getElementById("spread-year");
  ["2024", "2023", "2022", "2021", "2020", "2019"].forEach((y) => {
    const o = document.createElement("option");
    o.value = y; o.textContent = y;
    ysel.appendChild(o);
  });
  ysel.value = "2023";
  ysel.addEventListener("change", () => drawSpreadTable(ysel.value));
  drawSpreadTable("2023");

  // ---- Financial benchmarks (computed from the fetched Comtrade rows) ----
  const medOf = (arr) => { const s = [...arr].sort((a, b) => a - b); return s.length ? quantile(s, 0.5) : null; };
  const annualUV = (code) => {
    for (const y of ["2024", "2023", "2022"]) {
      const r = ROWS.find((r) => r.freq === "A" && r.flow === "X" && r.rep === 894 && r.par === 0 && r.code === code && r.period === y && r.kg > 0);
      if (r) return { uv: (r.usd / r.kg) * 1000, year: y };
    }
    return null;
  };
  const catM = monthlyUnitValues("740311");
  const conM = monthlyUnitValues("2603");
  const conSorted = [...conM].sort((a, b) => a - b);
  window.BENCH = {
    cathodeUV: medOf(catM),
    concUV: medOf(conM),
    concP10: conSorted.length ? quantile(conSorted, 0.1) : null,
    blister: annualUV("7402"),
    cobalt: annualUV("8105"),
    uvFor(code) {
      if (code === "740311") return this.cathodeUV;
      if (code === "2603") return this.concUV;
      if (code === "7402") return this.blister && this.blister.uv;
      if (code === "8105") return this.cobalt && this.cobalt.uv;
      return null;
    },
  };

  // KPI strip at the top of the trade tab
  const kpiCodes = ["740311", "2603", "7402", "7404", "7408"];
  const exp24 = kpiCodes.reduce((s, c) => {
    const r = ROWS.find((r) => r.freq === "A" && r.flow === "X" && r.rep === 894 && r.par === 0 && r.code === c && r.period === "2024");
    return s + (r ? r.usd : 0);
  }, 0);
  const zx = ROWS.find((r) => r.freq === "A" && r.flow === "X" && r.rep === 894 && r.par === 0 && r.code === "2603" && r.period === "2024");
  const mir = ROWS.filter((r) => r.freq === "A" && r.flow === "M" && r.par === 894 && r.code === "2603" && r.period === "2024" && r.rep !== 0)
    .reduce((s, r) => s + r.usd, 0);
  const payability = BENCH.cathodeUV && BENCH.concUV ? Math.round((100 * BENCH.concUV) / BENCH.cathodeUV) : null;
  const kpi = document.createElement("div");
  kpi.className = "hero-stats";
  kpi.innerHTML = [
    [fmtUsd(exp24), "2024 copper-group exports (Zambia-reported)", "var(--s1)"],
    [BENCH.cathodeUV ? "$" + Math.round(BENCH.cathodeUV).toLocaleString() + "/t" : "–", "cathode median unit value (partner-months '23–24)", "var(--ink)"],
    [BENCH.concUV ? "$" + Math.round(BENCH.concUV).toLocaleString() + "/t" : "–", `concentrate median${payability ? " · ≈" + payability + "% of cathode" : ""}`, "var(--s2)"],
    [zx && mir ? "+" + fmtUsd(mir - zx.usd) : "–", "2024 concentrate mirror gap (partners vs Zambia)", "var(--critical)"],
  ].map(([num, lbl, color]) =>
    `<div class="hero-stat"><div class="num" style="color:${color}">${num}</div><div class="lbl">${lbl}</div></div>`
  ).join("");
  document.getElementById("tab-trade").insertBefore(kpi, document.getElementById("tab-trade").firstChild);
} else {
  document.getElementById("tab-trade").insertAdjacentHTML("afterbegin",
    '<div class="card"><div class="callout void"><strong>No trade data loaded.</strong> Run <code>pipeline/fetch_trade_data.ps1</code> to generate <code>data/trade_data.js</code>.</div></div>');
}

/* ================================================================
   SCORECARD — bankability rubric + financing cost model
================================================================ */
const PILLARS = [
  {
    id: "resource", name: "Resource / product verification", max: 25,
    options: [
      { pts: 25, label: "Independent & certified — JORC / NI 43-101 resource, or LME brand / accredited assay" },
      { pts: 12, label: "Partial — internal estimate or non-accredited assay" },
      { pts: 0, label: "None — no verifiable resource statement or assay ('no paperwork')" },
    ],
    fix: "Commission a JORC/NI 43-101 compliant resource statement or an ISO 17025-accredited assay chain",
  },
  {
    id: "recovery", name: "Recovery & metallurgical certainty", max: 15,
    options: [
      { pts: 15, label: "Demonstrated — operating plant or completed DFS metallurgy" },
      { pts: 8, label: "Intermediate — PFS or pilot-scale testwork" },
      { pts: 0, label: "Untested — no metallurgical testwork" },
    ],
    fix: "Complete pilot-scale metallurgical testwork on representative samples",
  },
  {
    id: "offtake", name: "Offtake & market access", max: 20,
    options: [
      { pts: 20, label: "Signed offtake with a creditworthy counterparty" },
      { pts: 12, label: "LOI / term sheet under negotiation" },
      { pts: 5, label: "Spot sales only" },
      { pts: 0, label: "No identified buyer" },
    ],
    fix: "Convert spot relationships into a term offtake with a rated trader or smelter",
  },
  {
    id: "counterparty", name: "Counterparty legibility", max: 20,
    options: [
      { pts: 20, label: "Registered, licensed, beneficial ownership disclosed (PACRA / EITI verifiable)" },
      { pts: 10, label: "Registered but beneficial ownership opaque" },
      { pts: 0, label: "Unregistered / informal operator" },
    ],
    fix: "File beneficial-ownership disclosure with PACRA and appear in EITI reporting; clear any MMMD default-notice entries",
  },
  {
    id: "logistics", name: "Jurisdiction & logistics", max: 20,
    options: [
      { pts: 20, label: "Established corridor, bonded logistics, licensed clearing agent engaged" },
      { pts: 12, label: "Functional but congested corridor; standard road freight" },
      { pts: 4, label: "Informal or high-risk cross-border transit" },
    ],
    fix: "Contract a ZRA-licensed clearing agent and route via a bonded corridor (Dar, Durban, or Lobito)",
  },
];
const PRESET_A = { resource: 25, recovery: 15, offtake: 20, counterparty: 20, logistics: 12 };
const PRESET_B = { resource: 0, recovery: 8, offtake: 5, counterparty: 10, logistics: 4 };

// Financing ladder — instruments and INDICATIVE effective annual rates by band.
// Rates are directional market ranges for African commodity trade finance, not quotes.
const FIN_BANDS = [
  { min: 80, name: "Bankable — structured trade finance grade", color: "#0ca30c", rate: 0.08,
    inst: "Pre-export finance, borrowing-base revolvers, receivables discounting", rateLabel: "SOFR + 250–450 bps (≈8% eff.)" },
  { min: 60, name: "Financeable with enhancements", color: "#eda100", rate: 0.105,
    inst: "Structured trade finance + credit insurance, collateral management (CMA)", rateLabel: "SOFR + 450–700 bps (≈10–11% eff.)" },
  { min: 40, name: "High-cost capital only", color: "#ec835a", rate: 0.15,
    inst: "Offtaker prepayment, streaming / royalty structures", rateLabel: "≈12–18% eff." },
  { min: 0, name: "Informal only — inside the void", color: "#f85149", rate: 0.25,
    inst: "No formal lenders. Farm-gate sale at deep discount, or equity", rateLabel: "20%+ eff. — or paid via price discount" },
];
const PRODUCT_LABELS = { "740311": "copper cathode", "7402": "blister copper", "2603": "copper concentrate", "8105": "cobalt intermediates" };

const scoreState = { ...PRESET_A };

(function buildScorecard() {
  const wrap = document.getElementById("pillars");
  if (!wrap) return;
  wrap.innerHTML = PILLARS.map((p) => `
    <div class="pillar-card" id="pc-${p.id}">
      <div class="p-head"><h4>${p.name}</h4><span class="p-pts" id="pp-${p.id}"></span></div>
      <div class="opts">
        ${p.options.map((o) => `
          <button class="opt" data-pillar="${p.id}" data-pts="${o.pts}" aria-pressed="false">
            <span>${o.label}</span><span class="opt-pts">${o.pts} pts</span>
          </button>`).join("")}
      </div>
    </div>`).join("");
  wrap.querySelectorAll(".opt").forEach((btn) => {
    btn.addEventListener("click", () => {
      scoreState[btn.dataset.pillar] = Number(btn.dataset.pts);
      renderScore();
    });
  });
  document.getElementById("preset-a").addEventListener("click", () => { Object.assign(scoreState, PRESET_A); document.getElementById("calc-product").value = "740311"; renderScore(); });
  document.getElementById("preset-b").addEventListener("click", () => { Object.assign(scoreState, PRESET_B); document.getElementById("calc-product").value = "2603"; renderScore(); });
  document.getElementById("calc-product").addEventListener("change", renderScore);
  document.getElementById("calc-volume").addEventListener("input", renderScore);
  renderScore();
})();

function bandFor(total) { return FIN_BANDS.find((b) => total >= b.min); }

function renderScore() {
  const scores = PILLARS.map((p) => ({ ...p, pts: scoreState[p.id],
    chosen: (p.options.find((o) => o.pts === scoreState[p.id]) || {}).label || "" }));
  const total = scores.reduce((s, p) => s + p.pts, 0);
  const band = bandFor(total);

  // option highlighting + per-pillar points
  document.querySelectorAll(".opt").forEach((btn) => {
    btn.setAttribute("aria-pressed", String(Number(btn.dataset.pts) === scoreState[btn.dataset.pillar]));
  });
  scores.forEach((p) => { document.getElementById("pp-" + p.id).textContent = `${p.pts}/${p.max}`; });

  // gauge
  const CIRC = 2 * Math.PI * 50;
  document.getElementById("gauge-arc").setAttribute("stroke-dasharray", `${(total / 100) * CIRC} ${CIRC}`);
  document.getElementById("gauge-arc").setAttribute("stroke", band.color);
  document.getElementById("gauge-num").textContent = total;
  const gEl = document.getElementById("score-grade");
  gEl.textContent = band.name;
  gEl.style.color = band.color;

  // pillar bars
  document.getElementById("pillar-bars").innerHTML = scores.map((p) => `
    <div class="pillar-bar-row" style="grid-template-columns:150px 1fr 44px">
      <span style="font-size:11.5px">${p.name.split(" ")[0]} ${p.name.split(" ")[1] || ""}</span>
      <span class="track"><div style="width:${(100 * p.pts) / p.max}%;background:${band.color}"></div></span>
      <span class="val">${p.pts}/${p.max}</span>
    </div>`).join("");

  // financing ladder
  document.getElementById("finance-ladder").innerHTML = FIN_BANDS.map((b) => `
    <div class="fin-band ${b === band ? "current" : ""}">
      <span class="bar" style="background:${b.color}"></span>
      <span class="inst"><b>${b.min}–${b.min === 80 ? 100 : FIN_BANDS[FIN_BANDS.indexOf(b) - 1].min - 1}</b> · ${b.inst}</span>
      <span class="rate">${b.rateLabel}</span>
    </div>`).join("");

  // cost-of-illegibility calculator
  const product = document.getElementById("calc-product").value;
  const volume = Math.max(0, Number(document.getElementById("calc-volume").value) || 0);
  const out = document.getElementById("calc-out");
  const uv = window.BENCH ? BENCH.uvFor(product) : null;
  if (!uv || !volume) {
    out.innerHTML = `<p class="note">Benchmark unit values need the Comtrade data (Trade tab) — or enter a volume above.</p>`;
  } else {
    const revenue = uv * volume;
    const wc = revenue * (60 / 365); // 60-day sell-and-collect cycle in transit
    const finCost = wc * band.rate;
    const idx = FIN_BANDS.indexOf(band);
    const nextBand = idx > 0 ? FIN_BANDS[idx - 1] : null;
    const saving = nextBand ? wc * (band.rate - nextBand.rate) : 0;
    // documentation-linked price gap — observed concentrate P10 vs median (correlational)
    let docGap = 0;
    if (product === "2603" && BENCH.concP10 && scoreState.resource < 25) {
      const fullGap = (BENCH.concUV - BENCH.concP10) * volume;
      docGap = scoreState.resource === 0 ? fullGap : fullGap / 2;
    }
    const L = (label, v, cls = "") => `<div class="calc-line ${cls}"><span>${label}</span><span class="v">${v}</span></div>`;
    out.innerHTML =
      L(`Indicative revenue — ${volume.toLocaleString()} t of ${PRODUCT_LABELS[product]} @ $${Math.round(uv).toLocaleString()}/t`, fmtUsd(revenue) + "/yr") +
      L("Working capital in transit (60-day cycle)", fmtUsd(wc)) +
      L(`Financing cost at this band (${Math.round(band.rate * 1000) / 10}% eff.)`, fmtUsd(finCost) + "/yr") +
      (nextBand ? L(`Reaching "${nextBand.name.split("—")[0].trim()}" saves`, fmtUsd(saving) + "/yr", "gain") : "") +
      (docGap > 0 ? L("Documentation-linked price-realization gap (observed P10 vs median — correlational)", "up to " + fmtUsd(docGap) + "/yr", "hl") : "") +
      `<p class="note" style="margin-top:8px">Unit values are medians computed from the UN Comtrade pulls on the Trade tab.
        Rates are indicative market ranges for African commodity trade finance, not quotes. The price-gap line is
        correlational — see Methodology.</p>`;
    window._calcSnapshot = { product: PRODUCT_LABELS[product], volume, uv, revenue, wc, band: band.name, rate: band.rate, saving, docGap };
  }

  // improvements
  const gaps = scores.map((p) => ({ ...p, forgone: p.max - p.pts })).filter((p) => p.forgone > 0)
    .sort((a, b) => b.forgone - a.forgone);
  document.getElementById("improvements").innerHTML = gaps.length
    ? gaps.map((p) => `<li><strong>+${p.forgone} pts</strong> — ${p.fix}.</li>`).join("")
    : "<li>Maximum score — nothing left on the table.</li>";
}

/* ----- Optional AI lender memo (raw HTTP; static site, no SDK) ----- */
if (document.getElementById("gen-narrative")) document.getElementById("gen-narrative").addEventListener("click", async () => {
  const key = document.getElementById("api-key").value.trim();
  const out = document.getElementById("narrative-out");
  out.hidden = false;
  if (!key) { out.textContent = "Enter an Anthropic API key first."; return; }
  const scores = PILLARS.map((p) => ({ name: p.name, max: p.max, pts: scoreState[p.id],
    chosen: (p.options.find((o) => o.pts === scoreState[p.id]) || {}).label || "" }));
  const total = scores.reduce((s, p) => s + p.pts, 0);
  const band = bandFor(total);
  const c = window._calcSnapshot;
  out.textContent = "Generating…";

  const prompt = `You are a commodity trade-finance credit analyst writing a short internal memo about a Zambian copper/cobalt stream.

Deterministic scorecard result (do NOT change or invent any numbers — explain them):
Total: ${total}/100 — ${band.name}
${scores.map((p) => `- ${p.name}: ${p.pts}/${p.max} — "${p.chosen}"`).join("\n")}
${c ? `
Financial model (computed from UN Comtrade benchmark unit values; rates indicative):
- Stream: ${c.volume.toLocaleString()} t/yr of ${c.product} @ $${Math.round(c.uv).toLocaleString()}/t → revenue ≈ ${Math.round(c.revenue / 1e6)}M USD/yr
- Working capital in transit (60d): ≈ ${Math.round(c.wc / 1e6)}M USD
- Current band effective rate: ${Math.round(c.rate * 1000) / 10}%
- Annual saving from reaching the next band: ≈ ${Math.round(c.saving / 1e6 * 10) / 10}M USD/yr
${c.docGap > 0 ? `- Documentation-linked price-realization gap (correlational): up to ${Math.round(c.docGap / 1e6 * 10) / 10}M USD/yr` : ""}` : ""}

Write a ~220-word memo: (1) one-sentence credit verdict, (2) what makes this stream legible or illegible to capital, (3) the single highest-value fix and roughly what it is worth per the figures above. Plain prose, no headers.`;

  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "anthropic-dangerous-direct-browser-access": "true",
      },
      body: JSON.stringify({
        model: "claude-opus-4-8",
        max_tokens: 1024,
        messages: [{ role: "user", content: prompt }],
      }),
    });
    if (!resp.ok) {
      const err = await resp.text();
      out.textContent = `API error ${resp.status}: ${err.slice(0, 400)}`;
      return;
    }
    const data = await resp.json();
    if (data.stop_reason === "refusal") { out.textContent = "The model declined this request."; return; }
    const text = (data.content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n");
    out.textContent = text || "(empty response)";
  } catch (e) {
    out.textContent = "Request failed: " + e.message;
  }
});


/* ================================================================
   GLOBAL COMMAND-BAR SEARCH (header) + KYC example chips
================================================================ */
(function wireGlobalSearch() {
  const gs = document.getElementById("global-search");
  const kq = document.getElementById("kyc-query");
  if (!gs || !kq) return;
  const pipe = () => {
    const kycBtn = document.querySelector('nav.tabs button[data-tab="kyc"]');
    if (!document.getElementById("tab-kyc").classList.contains("active")) kycBtn.click();
    kq.value = gs.value;
    kq.dispatchEvent(new Event("input"));
  };
  gs.addEventListener("input", pipe);
  gs.addEventListener("keydown", (e) => { if (e.key === "Enter") { pipe(); kq.focus(); } });
  document.addEventListener("keydown", (e) => {
    const tag = document.activeElement && document.activeElement.tagName;
    if (e.key === "/" && !/INPUT|TEXTAREA|SELECT/.test(tag || "")) { e.preventDefault(); gs.focus(); }
  });
  document.querySelectorAll(".kyc-example").forEach((chip) => {
    chip.addEventListener("click", () => {
      kq.value = chip.dataset.q;
      kq.dispatchEvent(new Event("input"));
    });
  });
})();

/* ================================================================
   REGISTER & OWNERSHIP
   Companies-registry standing, declared business vs mineral rights,
   the 1964-2025 production arc, licensing decisions, supply-chain
   arrangements, value addition, and the institutional routes to the
   holders who publish nothing. Data: data/register_data.js.
================================================================ */
(function registerTab() {
  const R = window.REGISTER;
  if (!R) return;
  const S = R.STATS;
  const fmt = (n) => Number(n).toLocaleString("en-US");
  const fmtHa = (n) => n >= 1e6 ? (n / 1e6).toFixed(2) + "M ha" : n >= 1e3 ? Math.round(n / 1e3) + "k ha" : n + " ha";
  const usd = (v) => v == null ? "" :
    v >= 1e9 ? "$" + (v / 1e9).toFixed(v / 1e9 >= 10 ? 1 : 2) + "bn" :
    v >= 1e6 ? "$" + Math.round(v / 1e6) + "m" : "$" + fmt(v);
  const tc = (s) => String(s || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
  const esc = (s) => String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const link = (u, t) => u ? '<a href="' + esc(u) + '" target="_blank" rel="noopener">' + esc(t || "source") + '</a>' : "";

  /* ----- hero counters ----- */
  const pctGround = Math.round((100 * S.nonMiningHa) / S.allHa);
  document.getElementById("reg-hero").innerHTML = [
    [fmt(S.pacraMatched), "holders matched to the companies registry", "var(--s1)"],
    [fmt(S.boUndeclared), "have never declared beneficial owners", "var(--critical)"],
    [pctGround + "%", "of licensed ground on a non-mining declaration", "var(--serious)"],
    [fmt(S.noRegistry), "companies with no registry record at all", "var(--warning)"],
    [fmt(S.reachable), "organisations reachable by any channel", "var(--s3)"],
    ["0", "of " + fmt(S.coops) + " cooperatives with a contact", "var(--critical)"],
  ].map(([num, lbl, color]) =>
    '<div class="hero-stat"><div class="num" style="color:' + color + '">' + num + '</div><div class="lbl">' + lbl + '</div></div>'
  ).join("");

  /* ----- companies-registry standing ----- */
  new Chart(document.getElementById("reg-compliance-chart"), {
    type: "bar",
    data: {
      labels: ["Beneficial owners undeclared", "Annual returns unfiled", "Below minimum share capital",
               "Declared a non-mining trade", "No registry record at all"],
      datasets: [{
        label: "Companies",
        data: [S.boUndeclared, S.returnsUnfiled, S.belowCapital, S.nonMining, S.noRegistry],
        backgroundColor: ["#f85149", "#ec835a", "#d29922", "#d55181", "#64718a"],
        borderRadius: 4, borderSkipped: false,
      }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: {
          label: (c) => fmt(c.parsed.y) + " of " + fmt(S.pacraMatched) + " matched companies",
        } },
      },
      scales: {
        x: { grid: { display: false }, ticks: { font: { size: 11 }, maxRotation: 22, minRotation: 0 } },
        y: { beginAtZero: true, grid: { color: "#1b2330" }, ticks: { callback: (v) => fmt(v) } },
      },
    },
  });

  /* ----- declared business vs rights ----- */
  const mis = R.MISMATCH.filter((m) => m.b && !/^System/.test(m.b)).slice(0, 10);
  new Chart(document.getElementById("reg-mismatch-chart"), {
    type: "bar",
    data: {
      labels: mis.map((m) => m.b.length > 42 ? m.b.slice(0, 40) + "..." : m.b),
      datasets: [{
        label: "Companies holding mineral rights",
        data: mis.map((m) => m.n),
        backgroundColor: "#3987e5", borderRadius: 4, borderSkipped: false,
      }],
    },
    options: {
      indexAxis: "y", responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: {
          title: (it) => mis[it[0].dataIndex].b,
          label: (c) => fmt(c.parsed.x) + " companies, holding " + fmtHa(mis[c.dataIndex].ha),
        } },
      },
      scales: {
        x: { beginAtZero: true, grid: { color: "#1b2330" } },
        y: { grid: { display: false }, ticks: { font: { size: 11 } } },
      },
    },
  });

  document.getElementById("reg-mismatch-table").innerHTML =
    "<thead><tr><th>Holder</th><th>Licensed ground</th><th>Declared line of business</th>" +
    "<th>Beneficial owners</th><th>In 2025 default notice</th></tr></thead><tbody>" +
    R.MISMATCH_BIG.map((m) => {
      const boCell = m.bo === "0" ? '<span style="color:var(--critical)">undeclared</span>'
                   : m.bo === "1" ? '<span style="color:var(--good)">declared</span>'
                   : '<span style="color:var(--muted)">unresolved</span>';
      const dfn = Number(m.df) || 0;
      return '<tr>' +
        '<td style="font-weight:600">' + esc(m.h) + '</td>' +
        '<td style="white-space:nowrap;font-family:var(--mono)">' + fmt(m.ha) + '</td>' +
        '<td style="text-align:left">' + esc(m.b) + '</td>' +
        '<td style="white-space:nowrap">' + boCell + '</td>' +
        '<td style="white-space:nowrap">' + (dfn > 0
          ? '<span style="color:var(--serious)">' + dfn + ' licence' + (dfn > 1 ? "s" : "") + '</span>'
          : "&ndash;") + '</td>' +
      '</tr>';
    }).join("") + "</tbody>";

  /* ----- the production arc ----- */
  const evByYear = {};
  R.EVENTS.forEach((e) => { (evByYear[e.y] = evByYear[e.y] || []).push(e); });
  let spineChart = null;
  function drawSpine(which) {
    const series = which === "co" ? R.CO : R.CU;
    const unit = which === "co" ? "t cobalt" : "t copper";
    const colour = which === "co" ? "#22b381" : "#3987e5";
    const peak = series.reduce((a, b) => (b.v > a.v ? b : a));
    const trough = series.reduce((a, b) => (b.v < a.v ? b : a));
    const last = series[series.length - 1];
    document.getElementById("reg-spine-summary").textContent =
      "peak " + fmt(peak.v) + " (" + peak.y + ") · trough " + fmt(trough.v) + " (" + trough.y +
      ") · latest " + fmt(last.v) + " (" + last.y + ")";
    if (spineChart) spineChart.destroy();
    spineChart = new Chart(document.getElementById("reg-spine-chart"), {
      type: "line",
      data: {
        labels: series.map((p) => p.y),
        datasets: [{
          label: unit, data: series.map((p) => p.v),
          borderColor: colour, backgroundColor: colour + "22",
          borderWidth: 2, fill: true, tension: 0.15,
          pointRadius: (c) => (series[c.dataIndex] && evByYear[series[c.dataIndex].y]) ? 4 : 0,
          pointBackgroundColor: colour, pointBorderColor: "#0a0e14", pointBorderWidth: 1.5,
          pointHoverRadius: 6,
        }],
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (c) => fmt(c.parsed.y) + " " + unit,
              afterBody: (it) => {
                const yr = series[it[0].dataIndex].y;
                return (evByYear[yr] || []).slice(0, 3).map((e) => "• " + e.e);
              },
            },
          },
        },
        scales: {
          x: { grid: { display: false }, ticks: { maxTicksLimit: 14, font: { size: 11 } } },
          y: { beginAtZero: true, grid: { color: "#1b2330" },
               ticks: { callback: (v) => v >= 1000 ? (v / 1000) + "k" : v } },
        },
      },
    });
  }
  document.getElementById("reg-commodity").addEventListener("change", (e) => drawSpine(e.target.value));
  drawSpine("cu");

  const CATCOL = {
    nationalization: "var(--critical)", privatization: "var(--s2)", acquisition: "var(--s1)",
    policy: "var(--s4)", opening: "var(--good)", closure: "var(--serious)",
    disaster: "var(--critical)", other: "var(--muted)",
  };
  document.getElementById("reg-events-table").innerHTML =
    "<thead><tr><th>Year</th><th>Category</th><th>Structural event</th><th>Source</th></tr></thead><tbody>" +
    R.EVENTS.map((e) => '<tr>' +
      '<td style="white-space:nowrap;font-family:var(--mono)">' + e.y + '</td>' +
      '<td style="white-space:nowrap;color:' + (CATCOL[e.c] || "var(--muted)") + '">' + tc(e.c) + '</td>' +
      '<td style="text-align:left">' + esc(e.e) + '</td>' +
      '<td style="text-align:left;white-space:nowrap">' + link(e.u) + '</td>' +
    '</tr>').join("") + "</tbody>";

  /* ----- licensing decisions ----- */
  const DECCOL = { granted: "#3fb950", default: "#ec835a", cancelled: "#f85149", deferred: "#d29922", refused: "#d55181" };
  new Chart(document.getElementById("reg-decisions-chart"), {
    type: "bar",
    data: {
      labels: R.DECISIONS.map((d) => tc(d.d)),
      datasets: [{
        label: "Holder mentions", data: R.DECISIONS.map((d) => d.n),
        backgroundColor: R.DECISIONS.map((d) => DECCOL[d.d] || "#64718a"),
        borderRadius: 4, borderSkipped: false,
      }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: (c) => fmt(c.parsed.y) + " of " + fmt(S.docMentions) + " mentions" } },
      },
      scales: {
        x: { grid: { display: false } },
        y: { beginAtZero: true, grid: { color: "#1b2330" }, ticks: { callback: (v) => fmt(v) } },
      },
    },
  });

  /* ----- supply-chain arrangements ----- */
  (function chain() {
    const sel = document.getElementById("reg-chain-filter");
    Array.from(new Set(R.CHAIN.map((c) => c.t))).sort().forEach((t) => {
      const o = document.createElement("option"); o.value = t; o.textContent = tc(t); sel.appendChild(o);
    });
    const render = () => {
      const f = sel.value;
      const rows = R.CHAIN.filter((c) => f === "all" || c.t === f).sort((a, b) => (b.v || 0) - (a.v || 0));
      document.getElementById("reg-chain-table").innerHTML =
        "<thead><tr><th>Entity</th><th>Counterparty</th><th>Type</th><th>Disclosed value</th>" +
        "<th>Volume</th><th>Arrangement</th><th>Source</th></tr></thead><tbody>" +
        rows.map((c) => '<tr>' +
          '<td style="font-weight:600;white-space:nowrap">' + esc(c.e) + '</td>' +
          '<td style="white-space:nowrap">' + esc(c.c) + '</td>' +
          '<td style="white-space:nowrap;color:var(--s1)">' + tc(c.t) + '</td>' +
          '<td style="white-space:nowrap;font-family:var(--mono)">' +
            (c.v ? usd(c.v) : '<span style="color:var(--muted)">not disclosed</span>') + '</td>' +
          '<td style="white-space:nowrap">' + esc(c.vol) + '</td>' +
          '<td style="text-align:left;max-width:460px">' + esc(c.d) + '</td>' +
          '<td style="text-align:left;white-space:nowrap">' + link(c.u) + '</td>' +
        '</tr>').join("") + "</tbody>";
    };
    sel.addEventListener("change", render);
    render();
  })();

  /* ----- value addition ----- */
  document.getElementById("reg-va-table").innerHTML =
    "<thead><tr><th>Initiative</th><th>Category</th><th>From</th><th>Status</th><th>Announced value</th><th>Source</th></tr></thead><tbody>" +
    R.VALUE_ADD.slice().sort((a, b) => (b.v || 0) - (a.v || 0)).map((v) => '<tr>' +
      '<td style="font-weight:600;text-align:left;max-width:420px">' + esc(v.n) + '</td>' +
      '<td style="white-space:nowrap;color:var(--s3)">' + tc(v.c) + '</td>' +
      '<td style="white-space:nowrap;font-family:var(--mono)">' + esc(v.y) + '</td>' +
      '<td style="white-space:nowrap">' + esc(v.st) + '</td>' +
      '<td style="white-space:nowrap;font-family:var(--mono)">' +
        (v.v ? usd(v.v) : '<span style="color:var(--muted)">&ndash;</span>') + '</td>' +
      '<td style="text-align:left;white-space:nowrap">' + link(v.u) + '</td>' +
    '</tr>').join("") + "</tbody>";

  /* ----- institutional routes ----- */
  (function channels() {
    const pSel = document.getElementById("reg-chan-filter");
    const cSel = document.getElementById("reg-chan-cat");
    Array.from(new Set(R.CHANNELS.map((c) => c.pr).filter(Boolean))).sort().forEach((p) => {
      const o = document.createElement("option"); o.value = p; o.textContent = p; pSel.appendChild(o);
    });
    Array.from(new Set(R.CHANNELS.map((c) => c.cat).filter(Boolean))).sort().forEach((c) => {
      const o = document.createElement("option"); o.value = c; o.textContent = tc(c); cSel.appendChild(o);
    });
    const render = () => {
      const p = pSel.value, cat = cSel.value;
      const rows = R.CHANNELS.filter((c) => (p === "all" || c.pr === p) && (cat === "all" || c.cat === cat));
      document.getElementById("reg-chan-count").textContent =
        rows.length + " of " + R.CHANNELS.length + " offices (contact details held privately)";
      document.getElementById("reg-chan-table").innerHTML =
        "<thead><tr><th>Office</th><th>Type</th><th>Level</th><th>Province / district</th></tr></thead><tbody>" +
        rows.map((c) => '<tr>' +
          '<td style="font-weight:600;text-align:left;max-width:340px">' + esc(c.n) +
            (c.r ? '<div style="font-weight:400;font-size:11.5px;color:var(--muted)">' + esc(c.r) + '</div>' : "") + '</td>' +
          '<td style="white-space:nowrap;color:var(--s3)">' + tc(c.cat) + '</td>' +
          '<td style="white-space:nowrap">' + esc(c.l) + '</td>' +
          '<td style="white-space:nowrap">' + (esc(c.pr) || esc(c.di) || "&ndash;") + '</td>' +
        '</tr>').join("") + "</tbody>";
    };
    pSel.addEventListener("change", render);
    cSel.addEventListener("change", render);
    render();
  })();

  /* ----- cooperatives by province ----- */
  new Chart(document.getElementById("reg-coop-chart"), {
    type: "bar",
    data: {
      labels: R.COOP_PROV.map((p) => p.p),
      datasets: [{
        label: "Societies", data: R.COOP_PROV.map((p) => p.n),
        backgroundColor: "#d55181", borderRadius: 4, borderSkipped: false,
      }],
    },
    options: {
      indexAxis: "y", responsive: true, maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: (c) => fmt(c.parsed.x) + " societies, none publishes a contact" } },
      },
      scales: {
        x: { beginAtZero: true, grid: { color: "#1b2330" } },
        y: { grid: { display: false } },
      },
    },
  });

  /* These charts are built while the panel is display:none, so Chart.js measures the canvas at
     0x0 and does not recover on its own. Resize them when the tab is actually shown — the same
     shape as the map's invalidateSize() hook. */
  const regBtn = document.querySelector('nav.tabs button[data-tab="register"]');
  if (regBtn) {
    regBtn.addEventListener("click", () => {
      requestAnimationFrame(() => {
        document.querySelectorAll("#tab-register canvas").forEach((cv) => {
          const ch = Chart.getChart(cv);
          if (ch) ch.resize();
        });
      });
    });
  }
})();

/* ================================================================
   KYC ENRICHMENT
   Adds two cards to the existing counterparty report: companies-registry
   standing (the thing the old caveat told you to go to PACRA for) and any
   published contact channel. Observes the searched/not-researched
   distinction so a blank never reads as a verified absence.
================================================================ */
(function kycEnrich() {
  const R = window.REGISTER;
  if (!R) return;
  const esc = (s) => String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const norm = (n) => String(n || "").toUpperCase().replace(/[^A-Z0-9 ]/g, " ")
    .replace(/\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b/g, " ")
    .replace(/\s+/g, " ").trim();

  const host = document.getElementById("kyc-report");
  if (!host) return;

  const regCard = document.createElement("div");
  regCard.className = "card"; regCard.id = "kyc-registry-card"; regCard.hidden = true;
  const conCard = document.createElement("div");
  conCard.className = "card"; conCard.id = "kyc-contact-card"; conCard.hidden = true;
  // sit these directly under the licence table, before the adverse lists
  const licCard = document.getElementById("kyc-lic-card");
  if (licCard && licCard.parentNode) {
    licCard.parentNode.insertBefore(regCard, licCard.nextSibling);
    regCard.parentNode.insertBefore(conCard, regCard.nextSibling);
  } else {
    host.appendChild(regCard); host.appendChild(conCard);
  }

  function flag(v, okText, badText) {
    if (v === 1) return '<span style="color:var(--good)">' + okText + '</span>';
    if (v === 0) return '<span style="color:var(--critical)">' + badText + '</span>';
    return '<span style="color:var(--muted)">not resolved</span>';
  }

  function paint(name) {
    const k = norm(name);
    // R.CONTACTS is intentionally absent from the shipped payload - see the privacy note below.
    const reg = R.REG[k], coop = R.COOPS[k];

    if (reg && reg.s === "ok") {
      regCard.hidden = false;
      regCard.innerHTML =
        '<h3 style="margin-top:0">Companies-registry standing (PACRA)</h3>' +
        '<p class="note">Statutory status straight from the public companies registry. Beneficial ownership is ' +
        'the field the old KYC caveat sent you to PACRA for &mdash; it is now in the check.</p>' +
        '<table class="data"><tbody>' +
        '<tr><td style="text-align:left;width:210px">Registered name</td><td style="text-align:left;font-weight:600">' + esc(reg.n) + '</td></tr>' +
        '<tr><td style="text-align:left">Registration number</td><td style="text-align:left;font-family:var(--mono)">' + esc(reg.no) + '</td></tr>' +
        '<tr><td style="text-align:left">Registered</td><td style="text-align:left;font-family:var(--mono)">' + esc(reg.d) + '</td></tr>' +
        '<tr><td style="text-align:left">Status</td><td style="text-align:left">' + esc(reg.st) + '</td></tr>' +
        '<tr><td style="text-align:left">Declared line of business</td><td style="text-align:left">' +
          (reg.b ? esc(reg.b) : '<span style="color:var(--muted)">several candidate entities &mdash; not resolved</span>') + '</td></tr>' +
        '<tr><td style="text-align:left">Beneficial ownership</td><td style="text-align:left">' +
          flag(reg.bo, "declared", "NOT declared") + '</td></tr>' +
        '<tr><td style="text-align:left">Annual returns</td><td style="text-align:left">' +
          flag(reg.ar, "filed", "not filed") + '</td></tr>' +
        '<tr><td style="text-align:left">Minimum share capital</td><td style="text-align:left">' +
          flag(reg.nc, "met", "below the K20,000 floor") + '</td></tr>' +
        '</tbody></table>';
    } else if (reg && reg.s === "none") {
      regCard.hidden = false;
      regCard.innerHTML =
        '<h3 style="margin-top:0">Companies-registry standing (PACRA)</h3>' +
        '<div class="callout"><strong>Searched, no registry record found.</strong> This holder did not match the ' +
        'public companies registry. Read it carefully: cooperatives register with the Registrar of Cooperatives ' +
        'instead, and the registry search cannot handle ampersands, so a punctuated name can fail to match a ' +
        'company that is in fact registered. Absence here is a prompt to check by hand, not a finding.</div>';
    } else if (coop) {
      regCard.hidden = false;
      regCard.innerHTML =
        '<h3 style="margin-top:0">Cooperative society</h3>' +
        '<p class="note">Registers with the Registrar of Cooperatives (Ministry of Small and Medium Enterprise ' +
        'Development), not the companies registry, so no company record exists by design.</p>' +
        '<table class="data"><tbody>' +
        '<tr><td style="text-align:left;width:210px">District</td><td style="text-align:left">' + (esc(coop.d) || "&ndash;") + '</td></tr>' +
        '<tr><td style="text-align:left">Province</td><td style="text-align:left">' + (esc(coop.p) || "&ndash;") + '</td></tr>' +
        '<tr><td style="text-align:left">Licence reference</td><td style="text-align:left;font-family:var(--mono)">' + (esc(coop.lr) || "&ndash;") + '</td></tr>' +
        '</tbody></table>' +
        '<div class="callout">No mining cooperative in this register publishes a phone, email or address. Reach ' +
        'them through the Zambia Federation of Cooperatives in Mining or the provincial cooperative office &mdash; ' +
        'see the Register &amp; Ownership tab.</div>';
    } else {
      regCard.hidden = true;
    }

    // PRIVACY: company contact details are held locally in private/ and are deliberately not
    // shipped in data/register_data.js, so this card states the route rather than the number.
    conCard.hidden = false;
    conCard.innerHTML =
      '<h3 style="margin-top:0">Contacting this holder</h3>' +
      '<div class="callout">Contact details are <strong>held privately and not published with this app</strong>. ' +
      'Where a channel was found it came from the company'+"'"+'s own published sources; those records live in ' +
      '<code>private/</code> alongside the dataset and are excluded from the repository. For the artisanal and ' +
      'cooperative population no contact exists in any public source at all &mdash; the route there is the ' +
      'institutional one listed under <strong>Register &amp; Ownership</strong>.</div>';
  }

  // The KYC engine rewrites #kyc-name on every search; watch it and repaint.
  const nameEl = document.getElementById("kyc-name");
  if (!nameEl) return;
  let lastName = "";
  new MutationObserver(() => {
    const n = nameEl.textContent.trim();
    if (n && n !== lastName) { lastName = n; paint(n); }
  }).observe(nameEl, { childList: true, characterData: true, subtree: true });
})();

/* ================================================================
   ECONOMIC LINKAGE
   The joins between the two state registers: which minerals sit under
   a non-mining declared business, how findable each licence tier is,
   the gemstone licence-type vs commodity gap, and the processing
   cohort. Also shades non-mining-declared holders on the map.
================================================================ */
(function economicLinkage() {
  const R = window.REGISTER;
  if (!R || !R.MINERAL_LINK) return;
  const fmt = (n) => Number(n).toLocaleString("en-US");
  const esc = (s) => String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  /* ----- minerals under a non-mining declaration ----- */
  let mineralChart = null;
  function drawMineral(sortBy) {
    const rows = R.MINERAL_LINK.slice()
      .sort((a, b) => sortBy === "sh" ? b.sh - a.sh : b.nm - a.nm)
      .slice(0, 20);
    if (mineralChart) mineralChart.destroy();
    mineralChart = new Chart(document.getElementById("reg-mineral-chart"), {
      type: "bar",
      data: {
        labels: rows.map((r) => r.m),
        datasets: [{
          label: sortBy === "sh" ? "Share of that mineral's entries (%)" : "Licence-commodity entries",
          data: rows.map((r) => sortBy === "sh" ? r.sh : r.nm),
          backgroundColor: "#d55181", borderRadius: 4, borderSkipped: false,
        }],
      },
      options: {
        indexAxis: "y", responsive: true, maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: {
            label: (c) => {
              const r = rows[c.dataIndex];
              return fmt(r.nm) + " of " + fmt(r.all) + " entries (" + r.sh + "%) held on a non-mining declaration";
            },
          } },
        },
        scales: {
          x: { beginAtZero: true, grid: { color: "#1b2330" },
               ticks: { callback: (v) => sortBy === "sh" ? v + "%" : fmt(v) } },
          y: { grid: { display: false }, ticks: { font: { size: 11 } } },
        },
      },
    });
  }
  const msel = document.getElementById("reg-mineral-sort");
  if (msel) { msel.addEventListener("change", (e) => drawMineral(e.target.value)); drawMineral("nm"); }

  /* ----- legibility by licence tier ----- */
  const bt = document.getElementById("reg-buckets-table");
  if (bt) {
    bt.innerHTML =
      "<thead><tr><th>Licence tier</th><th>Licences</th><th>Distinct holders</th><th>Researched</th>" +
      "<th>Reachable</th><th>Reach rate</th><th>In 2025 default notice</th><th>Declared non-mining</th></tr></thead><tbody>" +
      R.BUCKETS.filter((b) => b.b !== "Portal / test").map((b) => {
        const pct = b.h ? Math.round((100 * b.rch) / b.h) : 0;
        const col = pct >= 15 ? "var(--good)" : pct > 0 ? "var(--warning)" : "var(--critical)";
        return '<tr>' +
          '<td style="font-weight:600;text-align:left">' + esc(b.b) + '</td>' +
          '<td class="num" style="font-family:var(--mono)">' + fmt(b.lic) + '</td>' +
          '<td style="font-family:var(--mono)">' + fmt(b.h) + '</td>' +
          '<td style="font-family:var(--mono)">' + fmt(b.res) + '</td>' +
          '<td style="font-family:var(--mono)">' + fmt(b.rch) + '</td>' +
          '<td style="font-family:var(--mono);color:' + col + '">' + pct + '%</td>' +
          '<td style="font-family:var(--mono);color:var(--serious)">' + fmt(b.def) + '</td>' +
          '<td style="font-family:var(--mono);color:var(--s5)">' + fmt(b.nmh) + '</td>' +
        '</tr>';
      }).join("") + "</tbody>";
  }

  /* ----- gemstone: licence type vs commodity ----- */
  if (R.GEM && document.getElementById("reg-gem-chart")) {
    const g = R.GEM.byType.slice(0, 10);
    new Chart(document.getElementById("reg-gem-chart"), {
      type: "bar",
      data: {
        labels: g.map((x) => x.t.replace(" Licence", "").replace(" (2008)", "")),
        datasets: [{
          label: "Licences listing a gem commodity",
          data: g.map((x) => x.n),
          backgroundColor: g.map((x) => /Gemstone/.test(x.t) ? "#d55181" : "#3987e5"),
          borderRadius: 4, borderSkipped: false,
        }],
      },
      options: {
        responsive: true, maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: {
            title: (it) => g[it[0].dataIndex].t,
            label: (c) => fmt(c.parsed.y) + " licences list a gem commodity" +
              (/Gemstone/.test(g[c.dataIndex].t) ? " (dedicated gemstone type)" : ""),
          } },
        },
        scales: {
          x: { grid: { display: false }, ticks: { font: { size: 10.5 }, maxRotation: 30 } },
          y: { beginAtZero: true, grid: { color: "#1b2330" } },
        },
      },
    });
  }

  /* ----- the processing cohort ----- */
  (function processors() {
    const sel = document.getElementById("reg-proc-filter");
    const tbl = document.getElementById("reg-proc-table");
    if (!sel || !tbl) return;
    const render = () => {
      const f = sel.value;
      const rows = R.PROCESSORS.filter((p) =>
        f === "all" ? true : f === "def" ? p.def > 0 : !!p.nm);
      document.getElementById("reg-proc-count").textContent =
        rows.length + " of " + R.PROCESSORS.length + " holders";
      tbl.innerHTML =
        "<thead><tr><th>Holder</th><th>MPLs</th><th>Commodities</th><th>Flags</th>" +
        "<th>Declared business (if not mining)</th></tr></thead><tbody>" +
        rows.map((p) => {
          const flags = [];
          if (p.def > 0) flags.push('<span style="color:var(--serious)">default ' + p.def + '</span>');
          if (p.can > 0) flags.push('<span style="color:var(--critical)">cancelled ' + p.can + '</span>');
          return '<tr' + (p.lat && p.lng ? ' style="cursor:pointer" data-lat="' + p.lat + '" data-lng="' + p.lng + '"' : '') + '>' +
            '<td style="font-weight:600;text-align:left">' + esc(p.h) + '</td>' +
            '<td style="font-family:var(--mono)">' + p.n + '</td>' +
            '<td style="text-align:left;max-width:330px;font-size:12px">' + esc(p.comm) + '</td>' +
            '<td style="white-space:nowrap">' + (flags.join(" · ") || "&ndash;") + '</td>' +
            '<td style="text-align:left;color:var(--s5)">' + (p.nm ? esc(p.nm) : "&ndash;") + '</td>' +
          '</tr>';
        }).join("") + "</tbody>";
      // clicking a processor flies the map to its plant
      tbl.querySelectorAll("tbody tr[data-lat]").forEach((tr) => {
        tr.addEventListener("click", () => {
          if (!window._leafletMap) return;
          document.querySelector('nav.tabs button[data-tab="map"]').click();
          window._leafletMap.invalidateSize();
          window._leafletMap.setView([Number(tr.dataset.lat), Number(tr.dataset.lng)], 11);
          document.getElementById("map").scrollIntoView({ behavior: "smooth" });
        });
      });
    };
    sel.addEventListener("change", render);
    render();
  })();

  /* ----- map overlay: shade licences whose holder declared a non-mining business ----- */
  (function mapOverlay() {
    if (!window.LICENSES || !window._leafletMap || !R.NM_HOLDERS) return;
    const norm = (n) => String(n || "").toUpperCase().replace(/\s*\(\d+(\.\d+)?%\)/g, "")
      .replace(/[^A-Z0-9 ]/g, " ")
      .replace(/\b(LIMITED|LTD|PLC|COMPANY|CO|INCORPORATED|INC|THE)\b/g, " ")
      .replace(/\s+/g, " ").trim();
    const nm = new Set(R.NM_HOLDERS);
    const layer = L.layerGroup();
    let n = 0;
    LICENSES.points.forEach((pt) => {
      // point shape: [lat, lng, code, type, holder, ...]
      const holders = String(pt[4] || "").split(/\s*;\s*|\s*\/\s*/);
      if (!holders.some((h) => nm.has(norm(h)))) return;
      n++;
      L.circleMarker([pt[0], pt[1]], {
        radius: 4, color: "#d55181", weight: 1.4, fillColor: "#d55181", fillOpacity: 0.35,
      }).bindPopup(
        '<strong>' + esc(pt[4]) + '</strong><br>' + esc(pt[2]) + ' &middot; ' + esc(pt[3]) +
        '<br><em style="color:#d55181">Holder declared a non-mining line of business at PACRA</em>'
      ).addTo(layer);
    });
    if (n) {
      window._nmLayer = layer;
      // register with the existing layer control if one is exposed
      if (window._leafletLayerControl && window._leafletLayerControl.addOverlay) {
        window._leafletLayerControl.addOverlay(layer, "Holder declared non-mining (" + fmt(n) + ")");
      }
    }
  })();
})();

/* ================================================================
   MINING BUSINESSES
   Traders, processors, services and supply - the side of the sector
   that never appears on a mineral right. Identity and business facts
   only; contact details stay in private/ and are not in this payload.
   Data: data/business_data.js.
================================================================ */
(function businesses() {
  const B = window.BIZ;
  if (!B) return;
  const fmt = (n) => Number(n).toLocaleString("en-US");
  const esc = (s) => String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const tc = (s) => String(s || "").replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

  const SEG_COLOR = {
    trader: "#3987e5", gemstone_dealer: "#d55181", gold_buyer: "#d9a114", scrap_metal: "#8b98a5",
    trading_house: "#3987e5", processor: "#9a7fd1", smelter_refiner: "#9a7fd1", lapidary: "#d55181",
    assay_lab: "#22b381", export_intermediary: "#64718a", drilling: "#e06a3a",
    explosives: "#f85149", mining_contractor: "#e06a3a", equipment_dealer: "#d9a114",
    geo_consultancy: "#22b381", haulage: "#8b98a5", rail: "#8b98a5", freight_clearing: "#64718a",
    engineering_epcm: "#3987e5", tailings_water: "#22b381", security: "#64718a",
    consumables_reagents: "#d55181", power_fuel: "#d9a114",
  };

  /* ----- segment chart ----- */
  const seg = B.BY_SEGMENT.filter((s) => s.n >= 4);
  if (document.getElementById("biz-segment-chart")) {
    new Chart(document.getElementById("biz-segment-chart"), {
      type: "bar",
      data: {
        labels: seg.map((s) => tc(s.s)),
        datasets: [{
          label: "Companies", data: seg.map((s) => s.n),
          backgroundColor: seg.map((s) => SEG_COLOR[s.s] || "#64718a"),
          borderRadius: 4, borderSkipped: false,
        }],
      },
      options: {
        indexAxis: "y", responsive: true, maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: {
            label: (c) => {
              const s = seg[c.dataIndex];
              return fmt(s.n) + " companies · " + s.hi + " with operations evidenced · " + s.tw + " located to a town";
            },
          } },
        },
        scales: {
          x: { beginAtZero: true, grid: { color: "#1b2330" } },
          y: { grid: { display: false }, ticks: { font: { size: 11 } } },
        },
      },
    });
  }

  /* ----- searchable table ----- */
  (function table() {
    const segSel = document.getElementById("biz-seg-filter");
    const confSel = document.getElementById("biz-conf-filter");
    const q = document.getElementById("biz-search");
    const tbl = document.getElementById("biz-table");
    if (!tbl) return;
    B.BY_SEGMENT.forEach((s) => {
      const o = document.createElement("option");
      o.value = s.s; o.textContent = tc(s.s) + " (" + s.n + ")";
      segSel.appendChild(o);
    });
    const render = () => {
      const sv = segSel.value, cv = confSel.value, qv = (q.value || "").trim().toUpperCase();
      const rows = B.ALL.filter((b) =>
        (sv === "all" || b.s === sv) &&
        (cv === "all" || b.c === cv) &&
        (!qv || (b.n + " " + (b.w || "") + " " + (b.t || "") + " " + (b.o || "")).toUpperCase().includes(qv))
      ).sort((a, b) => (a.c === "high" ? -1 : 1) - (b.c === "high" ? -1 : 1) || a.n.localeCompare(b.n));
      document.getElementById("biz-count").textContent =
        fmt(rows.length) + " of " + fmt(B.ALL.length) + " companies";
      tbl.innerHTML =
        "<thead><tr><th>Company</th><th>Segment</th><th>What they do</th><th>Town</th>" +
        "<th>Ownership</th><th>Scale</th><th>Registry</th><th>Evidence</th></tr></thead><tbody>" +
        rows.slice(0, 400).map((b) => {
          const col = SEG_COLOR[b.s] || "#64718a";
          const conf = b.c === "high"
            ? '<span style="color:var(--good)">operations evidenced</span>'
            : '<span style="color:var(--muted)">registry only</span>';
          return '<tr>' +
            '<td style="font-weight:600;text-align:left">' + esc(b.n) + '</td>' +
            '<td style="white-space:nowrap;color:' + col + '">' + tc(b.s) + '</td>' +
            '<td style="text-align:left;max-width:340px;font-size:12px">' + esc(b.w) + '</td>' +
            '<td style="white-space:nowrap">' + (esc(b.t) || "&ndash;") + '</td>' +
            '<td style="text-align:left;max-width:200px;font-size:12px">' + (esc(b.o) || "&ndash;") + '</td>' +
            '<td style="text-align:left;max-width:240px;font-size:12px">' + (esc(b.sc) || "&ndash;") + '</td>' +
            '<td style="white-space:nowrap;font-family:var(--mono);font-size:11px">' +
              (b.pn ? esc(b.pn) + (b.ps && b.ps !== "Active" ? ' <span style="color:var(--warning)">' + esc(b.ps) + '</span>' : "") : "&ndash;") +
              (b.g ? ' <span style="color:var(--s3)">NCC ' + esc(b.g) + '</span>' : "") + '</td>' +
            '<td style="white-space:nowrap">' + conf + '</td>' +
          '</tr>';
        }).join("") + "</tbody>";
      if (rows.length > 400) {
        tbl.insertAdjacentHTML("afterend",
          '<p class="note" style="margin-top:6px">Showing the first 400 of ' + fmt(rows.length) + ' — narrow the filters.</p>');
      }
    };
    [segSel, confSel].forEach((el) => el.addEventListener("change", render));
    q.addEventListener("input", render);
    render();
  })();

  /* ----- map layer: businesses at town level ----- */
  (function mapLayer() {
    if (!window._leafletMap || !window._leafletLayerControl || !B.MAPPED.length) return;
    const layer = L.layerGroup();
    B.MAPPED.forEach((b) => {
      // jitter within ~4km so co-located companies in the same town don't stack invisibly
      const j = () => (Math.random() - 0.5) * 0.07;
      L.circleMarker([b.lat + j(), b.lng + j()], {
        radius: 5, color: SEG_COLOR[b.s] || "#64718a", weight: 1.5,
        fillColor: SEG_COLOR[b.s] || "#64718a", fillOpacity: 0.5,
      }).bindPopup(
        '<strong>' + esc(b.n) + '</strong><br>' +
        '<span style="color:' + (SEG_COLOR[b.s] || "#64718a") + '">' + tc(b.s) + '</span><br>' +
        esc(b.w) + '<br>' +
        (b.o ? '<em>' + esc(b.o) + '</em><br>' : "") +
        (b.sc ? esc(b.sc) + '<br>' : "") +
        (b.pn ? '<span style="font-family:monospace">PACRA ' + esc(b.pn) + ' · ' + esc(b.ps) + '</span><br>' : "") +
        '<em style="color:#9aa7b6">Plotted at ' + esc(b.t) + ' town centroid — not a company address</em>'
      ).addTo(layer);
    });
    window._leafletLayerControl.addOverlay(layer,
      "Mining businesses: traders · services (" + fmt(B.MAPPED.length) + ")");
  })();
})();
