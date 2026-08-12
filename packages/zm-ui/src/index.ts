/**
 * @zambia-legibility/zm-ui
 *
 * The design system behind the Zambia Minerals Legibility Terminal
 * (https://danielpatelzamb.github.io/zambia-legibility-map/), extracted as React
 * components so new surfaces can be built on the same vocabulary.
 *
 * Import the tokens once at your app root — every component reads CSS custom
 * properties and renders unstyled colours without them:
 *
 *   import "@zambia-legibility/zm-ui/styles.css";
 *   import { Card, HeroStats, DataTable } from "@zambia-legibility/zm-ui";
 */
export {
  Card, HeroStats, Callout, DataTable, Badge, ScoreBar, Chip, SERIES,
} from "./components/primitives.js";

export type {
  CardProps, HeroStat, HeroStatsProps, CalloutProps, Column, DataTableProps,
  BadgeProps, ScoreBarProps, ChipProps, Status,
} from "./components/primitives.js";
