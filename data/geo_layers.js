// geo_layers.js: hand-authored geographic layers for the Legibility Map.
// All coordinates are [lat, lng] (Leaflet convention).
//
// IMPORTANT PROVENANCE NOTE:
//  - Corridor polylines are SCHEMATIC: straight segments between real waypoint
//    cities/ports, not surveyed alignments. Redraw from OSM rail/road (Geofabrik,
//    ODbL) for a production version.
//  - License areas are ILLUSTRATIVE: hand-placed markers/polygons around publicly
//    known operations. They are NOT data from the Zambian Mining Cadastre
//    (portals.landfolio.com/zambia), whose query endpoint is login-gated.
//  - Clearing-agent points are city-level clusters representing where agents on the
//    ZRA licensed clearing agents list (zra.org.zm) are concentrated, not
//    individual geocoded addresses.
//  - LME warehouse points are an illustrative subset of LME-approved warehouse
//    LOCATIONS (cities). The LME approves warehouse companies at listed locations;
//    none are in Zambia, that absence is the point.

window.GEO = {

  corridors: [
    {
      name: "Lobito Corridor (Benguela Railway)",
      mode: "rail",
      color: "#e4572e",
      status: "Rehabilitated; 30-yr concession to Lobito Atlantic Railway (Trafigura, Mota-Engil, Vecturis). USD 753M financing (DFC $553M + DBSA $200M), financial close June 2026. Zambia branch (Chingola-Jimbe) planned.",
      port: "Port of Lobito, Angola (Atlantic)",
      waypoints: [
        [-12.35, 13.55],  // Lobito
        [-12.58, 13.41],  // Benguela
        [-12.78, 15.73],  // Cubal area
        [-12.37, 16.93],  // Huambo
        [-11.78, 19.91],  // Luena
        [-10.71, 22.23],  // Luau (DRC border)
        [-10.98, 23.45],  // Dilolo
        [-10.72, 25.47],  // Kolwezi
        [-11.66, 27.48],  // Lubumbashi
        [-12.25, 27.80],  // Kasumbalesa (Zambia border)
        [-12.53, 27.85],  // Chingola
        [-12.80, 28.21]   // Kitwe
      ]
    },
    {
      name: "TAZARA (Dar es Salaam Corridor)",
      mode: "rail",
      color: "#2e9db5",
      status: "Revival under 2024 China-Tanzania-Zambia MoU (FOCAC). Historic Copperbelt outlet to the Indian Ocean.",
      port: "Port of Dar es Salaam, Tanzania (Indian Ocean)",
      waypoints: [
        [-12.80, 28.21],  // Kitwe
        [-12.97, 28.63],  // Ndola
        [-13.97, 28.67],  // Kapiri Mposhi (TAZARA railhead)
        [-13.23, 30.23],  // Serenje
        [-11.83, 31.45],  // Mpika
        [-9.34, 32.75],   // Nakonde / Tunduma border
        [-8.90, 33.45],   // Mbeya
        [-7.77, 35.69],   // Iringa area
        [-6.82, 37.66],   // Morogoro
        [-6.80, 39.28]    // Dar es Salaam
      ]
    },
    {
      name: "North-South Corridor (Durban)",
      mode: "road/rail",
      color: "#8d76c9",
      status: "Dominant historic route for refined metal; longest distance, congested borders (Chirundu, Beitbridge).",
      port: "Port of Durban, South Africa",
      waypoints: [
        [-12.97, 28.63],  // Ndola
        [-14.44, 28.45],  // Kabwe
        [-15.42, 28.28],  // Lusaka
        [-16.03, 28.85],  // Chirundu border
        [-17.83, 31.05],  // Harare
        [-20.15, 28.58],  // Bulawayo
        [-22.22, 30.00],  // Beitbridge border
        [-23.90, 29.45],  // Polokwane
        [-26.20, 28.04],  // Johannesburg
        [-29.86, 31.02]   // Durban
      ]
    },
    {
      name: "Beira Corridor",
      mode: "road",
      color: "#2fb59f",
      status: "Shortest route to a seaport; capacity and draft constraints at Beira.",
      port: "Port of Beira, Mozambique",
      waypoints: [
        [-15.42, 28.28],  // Lusaka
        [-16.03, 28.85],  // Chirundu
        [-17.83, 31.05],  // Harare
        [-18.97, 32.67],  // Mutare / Forbes border
        [-19.84, 34.84]   // Beira
      ]
    },
    {
      name: "Walvis Bay (Trans-Caprivi) Corridor",
      mode: "road",
      color: "#bc6c25",
      status: "Road corridor via Katima Mulilo bridge; niche but growing westbound option.",
      port: "Port of Walvis Bay, Namibia (Atlantic)",
      waypoints: [
        [-15.42, 28.28],  // Lusaka
        [-17.85, 25.86],  // Livingstone
        [-17.48, 24.27],  // Katima Mulilo border
        [-17.90, 19.77],  // Rundu area
        [-19.57, 18.11],  // Grootfontein
        [-20.46, 16.65],  // Otjiwarongo
        [-22.96, 14.51]   // Walvis Bay
      ]
    }
  ],

  // Illustrative operations on the Copperbelt / North-Western Province.
  // type: "mining" = large-scale mining licence area; "processing" = smelter/refinery
  // (Mineral Processing Licence territory in cadastre terms); "development" = pre-production.
  licenses: [
    { name: "Kansanshi Mine (First Quantum)", type: "mining", latlng: [-12.09, 26.43], note: "Cu-Au open pit, Solwezi. Zambia's largest copper mine." },
    { name: "Kansanshi Smelter (First Quantum)", type: "processing", latlng: [-12.12, 26.40], note: "Copper smelter adjacent to Kansanshi mine." },
    { name: "Sentinel / Trident (First Quantum)", type: "mining", latlng: [-12.23, 25.32], note: "Kalumbila. Large open-pit copper." },
    { name: "Lumwana (Barrick)", type: "mining", latlng: [-11.84, 25.86], note: "Open-pit copper; Super Pit expansion underway." },
    { name: "Konkola / KCM (Vedanta)", type: "mining", latlng: [-12.37, 27.83], note: "Chililabombwe. Deep underground copper." },
    { name: "Nchanga smelter complex (KCM)", type: "processing", latlng: [-12.52, 27.86], note: "Chingola. Smelter/refinery complex." },
    { name: "Mopani (Mufulira + Nkana)", type: "mining", latlng: [-12.55, 28.24], note: "Kitwe/Mufulira. Now majority IRH (Abu Dhabi)." },
    { name: "Mufulira Smelter (Mopani)", type: "processing", latlng: [-12.54, 28.26], note: "Smelter + refinery; produces cathode." },
    { name: "Chambishi Copper Smelter (NFCA/CNMC)", type: "processing", latlng: [-12.65, 28.05], note: "Major Chinese-owned smelter; top exporter in vendor BoL data." },
    { name: "CNMC Luanshya", type: "mining", latlng: [-13.14, 28.40], note: "Baluba / Muliashi copper." },
    { name: "Mingomba (KoBold Metals / ZCCM-IH)", type: "development", latlng: [-12.32, 27.87], note: "AI-discovered high-grade deposit; shaft groundbreaking 29 Apr 2026; ~$2B+, ~300kt/yr targeted, first output early 2030s." }
  ],

  // City-level clusters of ZRA-licensed customs clearing agents (see zra.org.zm
  // downloadable list). Counts are qualitative (relative concentration), not exact.
  clearingHubs: [
    { name: "Lusaka", latlng: [-15.42, 28.28], weight: 5, note: "Largest concentration of licensed clearing agents (HQ addresses)." },
    { name: "Ndola / Kitwe (Copperbelt)", latlng: [-12.89, 28.44], weight: 4, note: "Copperbelt cluster serving mine logistics." },
    { name: "Kasumbalesa border", latlng: [-12.25, 27.80], weight: 4, note: "DRC border; key transit chokepoint for Congolese cobalt/copper." },
    { name: "Nakonde border", latlng: [-9.34, 32.75], weight: 3, note: "Tanzania border (TAZARA/Dar road)." },
    { name: "Chirundu border", latlng: [-16.03, 28.85], weight: 3, note: "Zimbabwe border (North-South corridor); one-stop border post." },
    { name: "Livingstone / Kazungula", latlng: [-17.79, 25.26], weight: 2, note: "Botswana/Namibia routes; Kazungula bridge." },
    { name: "Mwami border", latlng: [-13.52, 32.94], weight: 1, note: "Malawi border." }
  ],

  // Illustrative subset of LME-approved warehouse locations (cities). NONE are in
  // Zambia or anywhere upstream on these corridors, the "void" thesis.
  lmeWarehouses: [
    { name: "Rotterdam", latlng: [51.92, 4.48] },
    { name: "Antwerp", latlng: [51.22, 4.40] },
    { name: "Hamburg", latlng: [53.55, 9.99] },
    { name: "Trieste", latlng: [45.65, 13.77] },
    { name: "Jebel Ali (Dubai)", latlng: [25.01, 55.06] },
    { name: "Singapore", latlng: [1.29, 103.85] },
    { name: "Port Klang", latlng: [3.00, 101.40] },
    { name: "Kaohsiung", latlng: [22.62, 120.28] },
    { name: "Gwangyang", latlng: [34.94, 127.70] },
    { name: "Busan", latlng: [35.10, 129.04] },
    { name: "New Orleans", latlng: [29.95, -90.07] },
    { name: "Baltimore", latlng: [39.29, -76.61] }
  ],

  // The verification void: rough hull around the Copperbelt + North-Western mining belt.
  voidPolygon: {
    latlngs: [
      [-11.55, 24.55],
      [-11.35, 26.20],
      [-11.90, 28.10],
      [-12.20, 28.90],
      [-13.40, 28.95],
      [-13.55, 28.20],
      [-13.00, 27.20],
      [-12.60, 25.60],
      [-12.55, 24.65]
    ],
    label: "THE VERIFICATION VOID",
    note: "No LME-approved warehouse, no independent assay/verification node, no trusted-warehouse infrastructure upstream of the border. Metal becomes 'bankable' only thousands of km downstream."
  },

  ports: [
    { name: "Lobito", latlng: [-12.35, 13.55] },
    { name: "Dar es Salaam", latlng: [-6.80, 39.28] },
    { name: "Durban", latlng: [-29.86, 31.02] },
    { name: "Beira", latlng: [-19.84, 34.84] },
    { name: "Walvis Bay", latlng: [-22.96, 14.51] }
  ]
};
