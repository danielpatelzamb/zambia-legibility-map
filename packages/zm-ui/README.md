# @zambia-legibility/zm-ui

The design system behind the [Zambia Minerals Legibility Terminal](https://danielpatelzamb.github.io/zambia-legibility-map/), as React components.

The terminal itself is vanilla JS — one `app.js`, one `styles.css`, no build step, which is why it loads instantly and has no dependency surface. This package exists so *other* surfaces can be built on the same vocabulary without copying CSS around.

## Status

**Not yet built or published.** The source is complete and typed, but `npm install && npm run build` has never run — the machine this was authored on has no Node. Nothing here has been executed. Treat the first build as a real step that may surface type errors, not a formality.

```bash
cd packages/zm-ui
npm install
npm run typecheck   # do this first — it is the fastest signal
npm run build
```

## Usage

Tokens must be imported once at your app root. Every component reads CSS custom properties, so without them colours resolve to nothing and the UI renders unstyled.

```tsx
import "@zambia-legibility/zm-ui/styles.css";
import { Card, HeroStats, DataTable, Badge, SERIES } from "@zambia-legibility/zm-ui";

export function LicenceSummary({ holders }) {
  return (
    <>
      <HeroStats
        stats={[
          { value: "7,468", label: "licences on the register", color: SERIES[0] },
          { value: "746", label: "have never declared beneficial owners", color: "var(--critical)" },
          { value: "275", label: "organisations reachable by any channel", color: "var(--good)" },
        ]}
      />
      <Card
        title="Who owns the ground"
        note="Every organisational holder queried against PACRA's public companies-registry API."
      >
        <DataTable
          columns={[
            { header: "Holder", cell: (h) => h.name, left: true },
            { header: "Hectares", cell: (h) => h.hectares.toLocaleString(), numeric: true },
            { header: "Ownership", cell: (h) => <Badge on={h.boDeclared} status={h.boDeclared ? "good" : "critical"}>
              {h.boDeclared ? "DECLARED" : "UNDECLARED"}
            </Badge> },
          ]}
          rows={holders}
        />
      </Card>
    </>
  );
}
```

## Components

| Component | What it is for |
|---|---|
| `Card` | The content container. Every panel in the terminal is one. Takes `title` and `note`. |
| `HeroStats` | The row of big numbers at the top of a tab. Six reads well; past eight it wraps badly. |
| `Callout` | Provenance notes and caveats. `tone="void"` is the red-bordered box used where data is **absent**. |
| `DataTable` | The one table style. Sticky header, hairline rows. Mark numeric columns `numeric` for monospace. |
| `Badge` | Pill for a binary or graded signal. The off state stays visible on purpose. |
| `ScoreBar` | Labelled bar with a monospace readout. |
| `Chip` | Quick filter. A shortcut for a select, never the only route to a filter. |

## Conventions that matter

**Dark only, deliberately.** This is an analyst tool built for long sessions, and the categorical palette was chosen against `#0a0e14`. There is no light theme, and inverting the tokens would not produce one — a light variant needs a re-derived palette.

**Series colours are ordered, not a menu.** Use `SERIES[0]`, then `SERIES[1]`, and so on. They are sequenced for distinguishability: `s1`+`s2` is the most legible pair, `s1`+`s4` the least. Picking out of order by taste degrades the chart.

**Status colours carry meaning.** `good` / `warning` / `serious` / `critical` escalate in severity. Never use them decoratively — in this system red means something is wrong or missing, and diluting that costs you the one signal readers actually scan for.

**Absence is a first-class state.** `Callout tone="void"` and `Badge on={false}` exist because the terminal's whole argument is about what the public record *does not* contain. Do not hide a missing value — render it as missing.

**Numbers are monospace and pre-formatted.** Components do not format for you; pass a formatted string. Locale formatting belongs at your call site where you know the locale.

## Tokens

`src/tokens/tokens.css` is copied verbatim from the app's `styles.css` `:root` block so the two cannot drift. Surfaces `--bg` → `--baseline`, text `--ink` / `--ink-2` / `--muted`, accent `--amber`, series `--s1`…`--s5`, status `--good` / `--warning` / `--serious` / `--critical`, plus a spacing scale (`--sp-1`…`--sp-6`) and radii.

The app does not yet consume this file — it still has its own copy. Making `styles.css` import the package's tokens would remove the duplication, and is the obvious next step.
