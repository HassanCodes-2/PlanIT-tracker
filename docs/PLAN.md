# PlanIT — Build Plan (v2: Habit/Deed Tracker)

> Product direction updated after reviewing the demo screenshots: a **general habit/deed tracker** with the demo's exact UX language — categories, recurring deeds, rich completion statuses, and heatmap stats.
> Companion doc: `docs/RESEARCH.md`.

---

## 1. Product Definition

**One-sentence promise:** "Track the deeds that make your days count — tick, reflect, and see the pattern."

**Core loop:**
```
CREATE deeds & categories → LOG daily outcomes → SEE the heatmap → ADJUST
```

**North-star metric:** consecutive days with ≥1 deed logged (streak).

### In v1 ✅
| # | Feature | Detail (demo-inspired) |
|---|---|---|
| 1 | **Today screen** | Date header, horizontal day scroller, deeds grouped by category with uppercase section headers |
| 2 | **Deeds** | Recurring items with icon + name (demo's vocabulary: "deed") |
| 3 | **Categories** | e.g., Health, Learning, Work, Social (+ custom). Sections on Today |
| 4 | **Create/Edit deed** | Name · icon · category · **Frequency** · **Goal** (optional) · **Parent deed** (optional) · **Reasons** toggle — matches demo screen |
| 5 | **Logging** | Tap = done. Long-press = outcome menu: **Done on time / Done late / Skipped (+ reason)**. Tap again = undo |
| 6 | **Reasons tracking** | Optional per-deed + global toggle; capture why a deed was skipped/late |
| 7 | **Stats — heatmap** | GitHub-style grid: days × deeds, colored by outcome |
| 8 | **Stats — period filters** | Weeks / Months / Years / All time |
| 9 | **Stats — status summary** | Cards: On time %, Late %, Skipped %, Missed % with counts |
| 10 | **Stats by deeds** | Per-deed completion list → detail history |
| 11 | **Reminders** | Per-deed reminder time, local notifications |
| 12 | **Accounts & sync** | Email/password + Google via Supabase; realtime sync |
| 13 | **Dark + light theme** | Dark-first design (demo), light theme included |
| 14 | **Hijri date (optional)** | Settings toggle next to Gregorian date — demo-familiar, off by default |
| 15 | **Offline resilience** | Local Drift cache, queued writes, sync on reconnect |

### NOT in v1 ❌
Shared/team tracking · social feed · widgets · AI insights · charts beyond heatmap · custom frequency beyond the 4 types · web app · prayer times auto-fill (that was demo-specific, not general)

### Screens (6)
1. **Auth** — login / sign up
2. **Today** — demo screen 2: date header (+ optional Hijri), day scroller, category sections, FAB to add deed
3. **Create/Edit Deed** — demo screen 1: name field, frequency, goal, parent deed, reasons toggle, save
4. **Deed Detail** — history calendar, stats, edit, archive
5. **Stats** — demo screen 3: heatmap, period tabs, status summary cards, stats by deeds
6. **Settings** — theme, week start, day rollover, reasons global, notifications, account

---

## 2. UX / Design Spec (from demo)

| Token | Value |
|---|---|
| Accent | Blue `#1B6CFF` |
| Dark background | `#121214` / cards `#1E1E22` |
| Light background | `#F7F7FA` / cards `#FFFFFF` |
| Text | Dark: `#EDEDF0`; Light: `#1A1A1E` |
| Section headers | Uppercase, letter-spaced, muted |
| Cards | Radius 16, subtle 1px border (`#2A2A30` dark) |
| Deed row | Icon (blue, in soft circle), name, right-side shading = outcome fill |
| Day scroller | ABBR weekday + day number; selected = blue pill |
| Bottom nav | 3 tabs: Today (list), Stats (bars), Settings (gear) |
| Buttons | Full-width pill, blue, white label ("Create deed") |

**Icon language:** per-category icon set (Material Symbols — e.g., fitness, book, briefcase, people, mosque/prayer as optional), plus per-deed override.

**Typography:** Inter or system default; 20–24sp screen titles, 14sp rows, 11sp labels.

---

## 3. Architecture

```
Flutter app (Riverpod + go_router + Material 3)
 ├─ features/today      → day scroller, category sections, log sheet
 ├─ features/deeds      → create/edit form, deed detail/history
 ├─ features/stats      → heatmap, filters, summaries
 ├─ features/settings   → theme, preferences, account
 ├─ data: Drift (cache) + Supabase repo (auth/db/realtime)
 └─ notifications: flutter_local_notifications + timezone
                 │
      Supabase (Auth + Postgres + RLS + Realtime)
```

**Logging rule:** one log per deed per date (`unique(deed_id, date)`). Outcomes: `done` / `late` / `skipped`; **missed** is derived (scheduled day, past, no log). Undo deletes the log.

---

## 4. Database (Supabase Postgres + RLS)

```sql
-- Categories (Today sections)
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  icon text not null default 'star',
  color text not null default '#1B6CFF',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- Deeds (recurring items)
create table public.deeds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  parent_id uuid references public.deeds(id) on delete cascade,   -- one level
  name text not null,
  icon text,
  frequency_type text not null default 'daily'
    check (frequency_type in ('daily','weekdays','times_per_week','times_per_month')),
  weekdays smallint[],             -- 1=Mon..7=Sun for 'weekdays'
  times_per_period smallint,       -- for times_per_week/month
  goal smallint, goal_period text check (goal_period in ('week','month')),
  reasons_enabled boolean not null default false,
  reminder_time time,
  sort_order int not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Logs (one per deed per day)
create table public.deed_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  deed_id uuid not null references public.deeds(id) on delete cascade,
  date date not null,
  status text not null check (status in ('done','late','skipped')),
  reason text,
  logged_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (deed_id, date)
);

alter table public.categories enable row level security;
alter table public.deeds      enable row level security;
alter table public.deed_logs  enable row level security;
-- each: for all using (auth.uid() = user_id) with check (auth.uid() = user_id)
```

**Seed on signup:** default categories (Health, Learning, Work, Social) + a starter set of deeds (exercise, read 20 min, plan tomorrow) so Today is never empty.

**Stats math (period P):**
- expected = occurrences scheduled in P per frequency/goal
- on-time = logs status done; late = done late; skipped; missed = expected − logged
- summary % = count / expected × 100

---

## 5. Tech Stack

| Layer | Package |
|---|---|
| Framework | Flutter stable (Material 3) |
| State | `flutter_riverpod` + annotations |
| Models | `freezed` + `json_serializable` |
| Remote | `supabase_flutter` |
| Local cache | `drift` + `sqlite3_flutter_libs` |
| Notifications | `flutter_local_notifications`, `timezone` |
| Routing | `go_router` |
| Dates | `intl`, `hijri` (optional display) |
| Charts | Custom Flutter widgets (heatmap + bars — no chart lib needed) |

---

## 6. Milestones

| Milestone | Deliverable |
|---|---|
| **M0 — Skeleton** | Flutter project, theme system (dark/light), go_router shell, Supabase config, bottom nav |
| **M1 — Auth** | Email/password + Google, session persistence, auth-aware routing |
| **M2 — Data & Today** | Supabase schema + RLS, Drift cache, categories/deeds seed, Today list with day scroller |
| **M3 — Logging UX** | Tap to done, long-press outcome sheet (on time/late/skip + reason), undo, shading states |
| **M4 — Create/Edit Deed** | Form with frequency, goal, parent deed, reasons toggle; validation; archive |
| **M5 — Stats** | Heatmap grid, period tabs, summary cards, per-deed stats & history |
| **M6 — Reminders & Settings** | Local notifications per deed, theme toggle, week start, rollover, Hijri toggle |
| **M7 — Sync & Offline** | Realtime updates, write queue, conflict handling |
| **M8 — Polish** | Empty states, animations, icons/splash, release build |

---

## 7. Seed Content (first launch)

**Categories:** Health 🏃 · Learning 📚 · Work 💼 · Social 👥
**Starter deeds:** "Exercise 20 min" (weekdays, 06:30) · "Read 20 pages" (daily) · "Plan tomorrow" (daily, 21:00)

---

## 8. Next Actions
1. Finish Flutter + Android setup (in progress)
2. `flutter create` + M0 structure
3. Supabase project + §4 SQL + seed logic