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

## Status

- [x] Research & plan
- [x] M0 Skeleton
- [ ] M1 Auth
- [ ] M2 Data & Today
- [ ] M3 Logging UX
- [ ] M4 Create/Edit Deed
- [ ] M5 Stats
- [ ] M6 Reminders & Settings
- [ ] M7 Sync & Offline
- [ ] M8 Polish