# PlanIT — Launch Readiness & Improvement Report

> Compiled from 10 independent web-research agents (5× DeepSeek, 5× GLM), Nov 26 2026.
> Each agent researched a different module. Merged and de-duplicated below.
> **Every item awaits your final call.** Effort: S (< 1 day) · M (1–3 days) · L (3+ days)

---

## 🟥 P0 — LAUNCH BLOCKERS (do before publishing anything)

| # | Item | Why | Effort | Source |
|---|------|-----|--------|--------|
| 1 | **Play compliance pack** — signed AAB (APK not accepted), target API 36, privacy policy URL (public HTTPS) + in-app link, Data-safety form ("no collection"), IARC content rating, ads "No", audience 13+ | Hard Play requirements; app is rejected without them | S | Play |
| 2 | **Closed-testing runway** — 12+ real testers opted in continuously for **14 days** before production access (personal accounts). Realistic total: 4–6 weeks | Hard requirement; start recruiting testers on day 1 | S (ops) | Play |
| 3 | **JSON import + restore** (export exists, import doesn't). Add `formatVersion`, snapshot DB before import, rollback on failure | "Export-only is a one-way door" — uninstall = total data loss; switchers can't migrate in. Flagged by **2 agents independently** | S–M | Sync + Competitors |
| 4 | **Reminder permission state machine** — prime once, ask in context, **never re-request after denial** (2 denials permanently kill the dialog), deep-link to Android settings + show status | Current flow can burn the permission dialog permanently | S | Reminders |
| 5 | **Notification plumbing safety** — never declare `USE_EXACT_ALARM` (Play rejection for habit apps); create proper channels (`daily_reminders` DEFAULT, `focus_timer` HIGH, `weekly_review` LOW); cancel by deed ID instead of `cancelAll()` (currently also kills the focus alert); reschedule on boot | Rejection risk + reminder-reliability bugs | S–M | Reminders |
| 6 | **DB encryption** — Drift + SQLite3MultipleCiphers, random key in `flutter_secure_storage` (Keystore). ⚠️ `sqlcipher_flutter_libs` is EOL — do not use | Notes may contain health/faith/therapy content; DB is plaintext today | M | Security |
| 7 | **Android backup rules** — `dataExtractionRules` + `fullBackupContent` excluding the DB, so plaintext data never auto-uploads to Google Drive / D2D transfer | Top privacy leak; one XML file | S | Security |
| 8 | **Accessibility trio** — ① add `onTapHint`("mark done") / `onLongPressHint`("open outcomes") to deed cards; ② verify `header: true` still announces (Flutter 3.38 regression — may need `headingLevel`); ③ fix sheet focus (focus title on open, restore to trigger on close) | Core interactions unusable-ish on TalkBack; cheap fixes | S–M | A11y |

---

## 🟧 P1 — HIGH IMPACT (the "fully complete" layer)

### Product features
| # | Item | Why | Effort |
|---|------|-----|--------|
| 9 | **Month calendar/history view** per deed (Loop/Habitify/Way of Life all have it) | 7-day heatmap can't show patterns; "table stakes" + best screenshot view | M |
| 10 | **Quantities & multi-log per day** (water ×8, pages, meds) + per-deed timed goals | Biggest functional gap vs competitors; unlocks whole use-cases | M |
| 11 | **Streak freeze** (1–2/month, auto, capped) + **never-miss-twice recovery prompt** | Duolingo A/B-proven; loss aversion with escape hatch; cheap | S |
| 12 | **Weekly review** — 3 prompts + auto compare-to-last-week (reuse stats + notes) | Reflection ≈ +20% performance in studies; creates weekly re-open loop | S–M |
| 13 | **Actionable reminders** — Done / Snooze / Skip buttons in the notification (Loop does this) | Act-from-shade is the strongest retention lever in category | M |
| 14 | **Widgets** — ① Today progress ring + streak (S), ② single-deed tap-to-log toggle (S–M), via `home_widget` 0.10 + `home_widget_generator` | #1 requested category feature; proof: HabitKit (Flutter, solo) ships them | S–M |
| 15 | **App shortcuts** — "Log today" / "Add deed" via `quick_actions` + post-onboarding widget-pin prompt | ~1 hour of work, visible polish | S |
| 16 | **Biometric app lock** (`local_auth`; needs `FlutterFragmentActivity`) | High user-visible value for a notes-heavy audience | M |
| 17 | **Passphrase-encrypted export** (Argon2id + AES-GCM) replacing plaintext JSON | Privacy control **and** the phone-migration story (replaces D2D restore) | M |
| 18 | **Auto-backup** — 7-day on-device snapshots + one-tap backup to a user-visible Drive file | Kills "uninstall = data loss" without servers (HabitKit's proven model) | M |

### Infrastructure
| # | Item | Why | Effort |
|---|------|-----|--------|
| 19 | **Sentry Flutter** (crash + performance, free tier 5k errors/mo) | Zero visibility today; Play vitals only shows post-hoc | S |
| 20 | **Play vitals baseline** — monitor user-perceived crash rate (<1.09%) | Free, automatic, and it's what Play judges | S |

### Business (your call — changes the app's nature)
| # | Item | Why | Effort |
|---|------|-----|--------|
| 21 | **Freemium + one-time Pro ($9.99)** — free: 7 deeds (HabitNow's proven gate); Pro: unlimited + Digital theme + deep stats (+ widgets later). **No subscription until sync exists** | Category-standard; HabitKit (Flutter solo) = $602K/yr existence proof | M |
| 22 | **ASO pack** — title `PlanIT: Habit Tracker`, 80-char short desc, 6-screenshot narrative, localize 5 languages (DE/ES/FR/PT-BR/TR) | Metadata-only localization = ~30–80% more installs; cheapest growth lever | S |
| 23 | **Play Billing** — `in_app_purchase` 3.3.x (Billing 8 = compliant), acknowledge-on-purchase, license testers | Required only if #21 approved | S |

> ⚠️ **Interaction warning (analytics × Play):** adding Sentry/PostHog flips the data-safety form from "no data collected" to declared types. **Aptabase** (20k events/mo, no IDs) is the alternative that keeps the clean "no collection" listing. Decision: clean listing vs funnels.
> ⚠️ **Interaction warning (monetization × EAA):** if #21 adds purchases, EU accessibility law (EAA) may apply — the a11y fixes in P0/P1 become legally relevant, not just good practice.

---

## 🟨 P2 — STRONG FOLLOW-UPS (post-launch v1.8+)

| # | Item | Why | Effort |
|---|------|-----|--------|
| 24 | Loop Habit Tracker CSV import (dominant free rival; documented format) | Switcher capture | M |
| 25 | PostHog (EU, strictly opt-in) — funnels incl. `first_deed_logged` activation metric; D1 ≥25% / D7 ≥8% targets | Only free funnel/retention option | S |
| 26 | Per-deed multiple reminder times/day | Meds & routines | S–M |
| 27 | Planned rest days / 5-of-7 flexible quotas (bounded slack beats rigid — studies) | Retention | M |
| 28 | Mood/energy tag on skip reasons (as pattern insight, not therapy) | Diagnoses churn | S |
| 29 | Implementation-intentions screen in onboarding ("After ___, I'll do ___") | Strongest evidence (d=0.65) of any mechanism | S |
| 30 | Milestone badges with identity-framed copy (10/30/100: "You're someone who shows up") | Cheap churn-moment fix | S |
| 31 | Streak-at-risk nudge (max 1/day, opt-in) | Retention | M |
| 32 | Quiet hours (22:00–07:00 default, never bypass DND) | Etiquette/reviews | S |
| 33 | Weekly review digest notification (Sunday, opt-in, LOW channel) | Re-open loop | M |
| 34 | Full chart a11y: summary-first + "view as table" for heatmap; ring % in labels; 24dp cell floor | WCAG 2.2 / TalkBack crawl risk | M |
| 35 | Same-time reminder aggregation (InboxStyle) | 3 deeds @ 09:00 = 1 notification | M |
| 36 | Note color payoff: tint card header/left rail (currently an 8×8 dot) | Feature currently invisible | S |

---

## ⏸️ DEFER (post-traction, explicitly not now)

- **Cloud sync** — Supabase LWW / PowerSync (free tier pauses after 1 week idle; ElectricSQL Dart client deprecated). *Prep now, free:* add UUIDs + `updated_at` + `deleted_at` columns so sync is an upgrade, not a migration.
- **Social / accountability** (Habitica parties etc.) — L effort, weakens the private pitch
- **Negative/"quit" habits** — M–L, half the market but post-launch
- **Full gamification** (points/leaderboards) — evidence says it can undermine intrinsic motivation
- **Quick Settings tiles, Wear OS, lock-screen widgets** — low ROI today
- **Habitica/Habitify importers** — poor export formats on their side

---

## ⚠️ ANTI-FEATURES (research says don't build these)

1. Red-X shame calendars / reset-to-zero (triggers what-the-hell effect)
2. Paid streak repair (trust killer — Duolingo backlash)
3. Points/leaderboards as the core loop
4. Unlimited freeze stockpiles (cap 1–2)
5. "21 days to form a habit" claims (real median 59–66 days, range 4–335)
6. Keyword stuffing / "best #1" claims in listing (rejection)

---

## 💎 ALREADY LAUNCH-READY (agents confirmed as differentiators — put these in the listing)

- Honest outcomes: done/late/skipped + reasons + undo (rare in category)
- Focus timer inside the daily loop (not a bolt-on Pomodoro)
- Notes as a real workspace (colors/pin/search/autosave)
- Stats depth: per-deed trends, deltas, rings, heatmap, 4 period filters
- Private-by-default: offline, no account, no ads, no SDKs
- Craft: Midnight + Digital themes, categories, archive/restore, toasts

---

## 📋 SUGGESTED BUILD ORDER (if you approve)

**Sprint A — Launch gate (1–1.5 wk):** #3 import · #4/#5 notification fixes · #7 backup rules · #8 a11y trio · #1 privacy policy · #19 Sentry
**Sprint B — Differentiation (1–2 wk):** #6 DB encryption · #11 streak freeze + recovery · #12 weekly review · #15 shortcuts · #9 month calendar
**Sprint C — Growth (parallel, ~4–6 wks elapsed):** #2 testers recruited day 1 · #22 ASO + localization · #21/#23 monetization (if approved) · #14 widgets · #13 actionable reminders · #17/#18 backups/lock
**Then:** Play submission on day 14 of closed testing.

*Every recommendation above carries source URLs in the underlying agent reports; this document is the merged executive layer.*
