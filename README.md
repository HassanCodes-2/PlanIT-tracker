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
| `screenshots/index.html` | Visual gallery of the app's screens |
| `docs/RESEARCH.md` | Market research, feature rationale, stack decision |
| `docs/PLAN.md` | Product spec, design tokens, data model, milestones |
| `supabase/schema.sql` | Database schema + RLS + signup seeding |

## Core concept

- **Deeds** — recurring items (daily / weekdays / X per week / X per month), with optional goal, parent deed, and reasons tracking
- **Categories** — Today screen sections (Health, Learning, Work, Social + custom)
- **Logs** — one outcome per deed per day: on time / late / skipped (+ optional reason); missed is derived
- **Stats** — heatmap, period filters (weeks/months/years/all time), status % summary, per-deed stats

## Setup

### Local toolchain (installed Nov 2026)

| Tool | Location |
|---|---|
| Flutter 3.50.1 (stable) | `C:\Users\fahad\AppData\Local\flutter` |
| Android SDK 36 + platform-tools | `C:\Users\fahad\AppData\Local\Android\Sdk` |
| JDK 17 (Microsoft) | `C:\Users\fahad\AppData\Local\Android\jdk\jdk-17.0.21.1+2` |

`PATH`, `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT` are set at the user level.
Open a **new terminal** before running Flutter commands.

### Database

1. Create a Supabase project → run `supabase/schema.sql` in the SQL editor
2. Copy the project URL and publishable key
3. Run the app:

```powershell
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_KEY=<publishable-or-anon-key>
```

Without the defines the app runs with mock data.

### Install on Android (sideload)

- `dist\planit-release.apk` — recommended (smaller, faster)
- `dist\planit-debug.apk` — debug build

Copy the APK to your phone and tap it (allow "Install unknown apps" for your file manager), or install over USB:

```powershell
adb install -r dist\planit-release.apk
```

## Features in the current build

- **Local-first data** — SQLite (Drift) with starter categories and deeds on first launch
- **Notes & ideas** — a full notepad tab: Keep-style colored cards, pin-to-top, instant search, auto-save editor, "edited 2h ago" timestamps; included in backups
- **Onboarding** — first-launch welcome: your name, focus areas, starter deeds
- **Today** - personal greeting, streak and daily progress, date picker + day scroller, category sections with color stripes; tap to log "done" (with confetti when you clear the day), long-press for focus timer / done late / skipped (+ reason) / history / clear - all with undo
- **Focus timer** — 5/15/25/45 minute sessions with a live progress ring; finish → mark the deed done
- **Deed history** — per-deed 14-day heatmap, summary, skip reasons and recent logs
- **Stats** — current & best streak, trend arrows vs previous period, status heatmap, period filters, per-deed breakdown
- **Stats glow-up (v1.4)** — animated percentage rings, sliding Week/Month/Year/All bar, icon-only status cards, Phosphor icon set app-wide, trend arrows
- **Digital theme (v1.5)** — futuristic monochrome HUD: black/gray/white, segmented progress, mono clock, selectable in Settings alongside Midnight blue
- **Reminders** — local notifications scheduled from each deed's reminder time
- **Theme** — dark / light / system, persisted; style and accent presets live in Settings
- **Backup** — export everything to a JSON file via the Android share sheet
- **Polish** — custom app icon, splash screen, haptic feedback
- **Accessibility** - 4.5:1 text, 3:1 card borders and status glyphs, semantics on every card/date/heatmap row, and 320dp + 2x text layout tests

> Accounts & cloud sync (Supabase) are scaffolded but not enabled until a Supabase project is connected.

## Status

- [x] Research & plan
- [x] M0 Skeleton
- [ ] M1 Auth (needs Supabase project)
- [x] M2 Data & Today (local)
- [x] M3 Logging UX
- [x] M4 Create/Edit Deed
- [x] M5 Stats
- [x] M6 Reminders & Settings (core)
- [ ] M7 Sync & Offline (needs Supabase)
- [x] M8 Polish (icon, splash, undo, backup, streaks)
