# PlanIT

A general **habit / deed tracker** for Android & iOS — plan recurring deeds, log daily outcomes, and see the pattern in a heatmap.

> UX reference: demo screenshots provided Nov 2026 (categories, day scroller, deed logging with outcomes, stats heatmap).

## Stack

- **Flutter** (Material 3, dark-first) · Riverpod · go_router
- **Supabase** — Auth (email + Google), Postgres with RLS, Realtime sync
- **Drift/SQLite** — offline cache
- **flutter_local_notifications** — per-deed reminders

## Docs

| File | Contents |
|---|---|
| `docs/RESEARCH.md` | Market research, feature rationale, stack decision |
| `docs/PLAN.md` | Product spec, design tokens, data model, milestones |
| `supabase/schema.sql` | Database schema + RLS + signup seeding |

## Core concept

- **Deeds** — recurring items (daily / weekdays / X per week / X per month), with optional goal, parent deed, and reasons tracking
- **Categories** — Today screen sections (Health, Learning, Work, Social + custom)
- **Logs** — one outcome per deed per day: on time / late / skipped (+ optional reason); missed is derived
- **Stats** — heatmap, period filters (weeks/months/years/all time), status % summary, per-deed stats

## Setup

1. Create a Supabase project → run `supabase/schema.sql`
2. Copy the project URL + anon key
3. Run the app:

```powershell
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon>
```

## Status

- [x] Research & plan
- [ ] M0 Skeleton
- [ ] M1 Auth
- [ ] M2 Data & Today
- [ ] M3 Logging UX
- [ ] M4 Create/Edit Deed
- [ ] M5 Stats
- [ ] M6 Reminders & Settings
- [ ] M7 Sync & Offline
- [ ] M8 Polish