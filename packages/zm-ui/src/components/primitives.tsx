import type { CSSProperties, ReactNode, HTMLAttributes } from "react";

/* ------------------------------------------------------------------
   zm-ui primitives
   Ported from the deployed terminal's own CSS classes, one component
   per class that earned its keep across eight tabs. Each takes the
   same shape the app uses it in, so a design built from these maps
   1:1 onto markup that already ships.
------------------------------------------------------------------ */

const T = {
  bg: "var(--bg)", panel: "var(--panel)", panel2: "var(--panel-2)",
  border: "var(--border)", grid: "var(--grid)", baseline: "var(--baseline)",
  ink: "var(--ink)", ink2: "var(--ink-2)", muted: "var(--muted)",
  amber: "var(--amber)", mono: "var(--mono)",
  good: "var(--good)", warning: "var(--warning)", serious: "var(--serious)", critical: "var(--critical)",
} as const;

/** The five categorical series colours, in the order they should be used. */
export const SERIES = ["var(--s1)", "var(--s2)", "var(--s3)", "var(--s4)", "var(--s5)"] as const;

/** Status level. These carry meaning in this system — never decorative. */
export type Status = "good" | "warning" | "serious" | "critical";
const STATUS_COLOR: Record<Status, string> = {
  good: T.good, warning: T.warning, serious: T.serious, critical: T.critical,
};

/* ---------------- Card ---------------- */

export interface CardProps extends Omit<HTMLAttributes<HTMLDivElement>, "title"> {
  /** Card heading. Sentence case, no trailing punctuation. */
  title?: ReactNode;
  /** Standfirst under the heading. Explains what the data is and where it came from. */
  note?: ReactNode;
  children?: ReactNode;
}

/** The main content container. Every panel in the terminal is a Card. */
export function Card({ title, note, children, style, ...rest }: CardProps) {
  return (
    <div
      style={{
        background: T.panel, border: `1px solid ${T.border}`, borderRadius: "var(--radius)",
        padding: "14px 16px 16px", marginBottom: "var(--sp-4)", ...style,
      }}
      {...rest}
    >
      {title != null && (
        <h2 style={{ margin: "0 0 3px", fontSize: 15, fontWeight: 650, letterSpacing: "0.01em", color: T.ink }}>
          {title}
        </h2>
      )}
      {note != null && (
        <p style={{ color: T.ink2, fontSize: 12.5, margin: "2px 0 12px", lineHeight: 1.5 }}>{note}</p>
      )}
      {children}
    </div>
  );
}

/* ---------------- HeroStats ---------------- */

export interface HeroStat {
  /** The number. Pre-formatted — the component does not format for you. */
  value: ReactNode;
  /** What the number counts. Lowercase, no trailing period. */
  label: ReactNode;
  /** Any CSS colour; prefer a token or a SERIES entry. */
  color?: string;
}

export interface HeroStatsProps extends HTMLAttributes<HTMLDivElement> {
  stats: HeroStat[];
}

/** The row of big numbers at the top of a tab. Six reads well; more than eight wraps badly. */
export function HeroStats({ stats, style, ...rest }: HeroStatsProps) {
  return (
    <div
      style={{
        display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
        gap: "var(--sp-2)", marginBottom: "var(--sp-4)", ...style,
      }}
      {...rest}
    >
      {stats.map((s, i) => (
        <div
          key={i}
          style={{
            background: T.panel, border: `1px solid ${T.border}`,
            borderRadius: "var(--radius)", padding: "10px 12px",
          }}
        >
          <div style={{ fontFamily: T.mono, fontSize: 22, fontWeight: 700, color: s.color ?? T.ink, lineHeight: 1.1 }}>
            {s.value}
          </div>
          <div style={{ fontSize: 11, color: T.muted, marginTop: 3, lineHeight: 1.35, textTransform: "uppercase", letterSpacing: "0.03em" }}>
            {s.label}
          </div>
        </div>
      ))}
    </div>
  );
}

/* ---------------- Callout ---------------- */

export interface CalloutProps extends HTMLAttributes<HTMLDivElement> {
  /** `void` is the terminal's signature red-bordered box: use it where data is ABSENT. */
  tone?: "neutral" | "void";
  children?: ReactNode;
}

/** Provenance notes, caveats, and the absence-of-data callouts the terminal is built around. */
export function Callout({ tone = "neutral", children, style, ...rest }: CalloutProps) {
  const isVoid = tone === "void";
  return (
    <div
      style={{
        borderLeft: `3px solid ${isVoid ? T.critical : T.amber}`,
        background: isVoid ? "rgba(248, 81, 73, 0.06)" : "rgba(245, 166, 35, 0.05)",
        borderRadius: "var(--radius-sm)", padding: "9px 12px", marginTop: "var(--sp-3)",
        fontSize: 12.5, color: T.ink2, lineHeight: 1.55, ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}

/* ---------------- DataTable ---------------- */

export interface Column<Row> {
  header: ReactNode;
  /** Cell renderer. Return a string/number for text, or a node for anything richer. */
  cell: (row: Row) => ReactNode;
  /** Monospace + nowrap. Use for every number, code and date. */
  numeric?: boolean;
  /** Left-align. Default is centre, which suits short values but not prose. */
  left?: boolean;
}

export interface DataTableProps<Row> {
  columns: Column<Row>[];
  rows: Row[];
  /** Shown in place of the table when `rows` is empty. */
  empty?: ReactNode;
}

/** The terminal's one table style. Sticky header, hairline rows, monospace numerics. */
export function DataTable<Row>({ columns, rows, empty = "No matches." }: DataTableProps<Row>) {
  if (!rows.length) return <p style={{ color: T.muted, fontSize: 12.5 }}>{empty}</p>;
  const th: CSSProperties = {
    position: "sticky", top: 0, background: T.panel2, color: T.ink2,
    fontSize: 11, fontWeight: 650, textTransform: "uppercase", letterSpacing: "0.04em",
    padding: "7px 9px", borderBottom: `1px solid ${T.baseline}`, textAlign: "left",
  };
  return (
    <div style={{ overflowX: "auto", marginTop: "var(--sp-2)" }}>
      <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 12.5, color: T.ink }}>
        <thead>
          <tr>{columns.map((c, i) => <th key={i} style={th}>{c.header}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((r, ri) => (
            <tr key={ri} style={{ borderBottom: `1px solid ${T.grid}` }}>
              {columns.map((c, ci) => (
                <td
                  key={ci}
                  style={{
                    padding: "7px 9px",
                    textAlign: c.left ? "left" : c.numeric ? "right" : "center",
                    fontFamily: c.numeric ? T.mono : undefined,
                    whiteSpace: c.numeric ? "nowrap" : undefined,
                  }}
                >
                  {c.cell(r)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* ---------------- Badge ---------------- */

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  /** Off renders as an outline — used to show a standard NOT met, not to hide it. */
  on?: boolean;
  status?: Status;
  children?: ReactNode;
}

/** Pill for a binary or graded signal. The off state is deliberately visible. */
export function Badge({ on = true, status, children, style, ...rest }: BadgeProps) {
  const c = status ? STATUS_COLOR[status] : T.amber;
  return (
    <span
      style={{
        display: "inline-block", fontFamily: T.mono, fontSize: 10, fontWeight: 700,
        padding: "2px 7px", borderRadius: "var(--radius-pill)", margin: "1px 3px 1px 0",
        letterSpacing: "0.03em", border: `1px solid ${on ? c : T.grid}`,
        background: on ? c : T.panel2, color: on ? T.bg : T.muted, ...style,
      }}
      {...rest}
    >
      {children}
    </span>
  );
}

/* ---------------- ScoreBar ---------------- */

export interface ScoreBarProps {
  label: ReactNode;
  /** 0–100. Values outside are clamped. */
  value: number;
  /** Right-aligned readout. Give units; the bar alone is not a number. */
  readout?: ReactNode;
  color?: string;
}

/** Labelled progress bar with a monospace readout. Used for every component score. */
export function ScoreBar({ label, value, readout, color = "var(--s1)" }: ScoreBarProps) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 10, margin: "7px 0 2px" }}>
        <span style={{ fontSize: 12, color: T.ink2 }}>{label}</span>
        {readout != null && (
          <span style={{ fontFamily: T.mono, fontSize: 12.5, whiteSpace: "nowrap", color: T.ink }}>{readout}</span>
        )}
      </div>
      <div style={{ height: 5, borderRadius: 3, background: T.grid, overflow: "hidden", marginBottom: 9 }}>
        <div style={{ height: "100%", width: `${Math.max(2, pct)}%`, borderRadius: 3, background: color }} />
      </div>
    </div>
  );
}

/* ---------------- Chip ---------------- */

export interface ChipProps extends HTMLAttributes<HTMLButtonElement> {
  selected?: boolean;
  count?: number;
  children?: ReactNode;
}

/** Quick filter. Chips are a shortcut for a select, never the only way to reach a filter. */
export function Chip({ selected = false, count, children, style, ...rest }: ChipProps) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      style={{
        fontSize: 11.5, padding: "3px 10px", borderRadius: "var(--radius-pill)", cursor: "pointer",
        border: `1px solid ${selected ? T.amber : T.grid}`,
        background: selected ? T.amber : T.panel2,
        color: selected ? T.bg : T.ink2,
        fontWeight: selected ? 650 : 400, fontFamily: "inherit", ...style,
      }}
      {...rest}
    >
      {children}
      {count != null && <span style={{ opacity: 0.65, marginLeft: 5 }}>{count}</span>}
    </button>
  );
}
