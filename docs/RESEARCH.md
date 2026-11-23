# PlanIT — Research: Daily Task Checker & Planner App

> **Direction update (post-demo review):** After reviewing demo screenshots (a prayer/deeds tracker), the product direction is now a **general habit/deed tracker** with that app's UX model — recurring deeds, categories, rich completion statuses (on time/late/skipped/missed), reasons tracking, and heatmap stats. See `docs/PLAN.md` for the current spec. The market research, feature patterns, productivity methods, and stack rationale below remain valid and inform the design.

> Research compiled Nov 2026 from current market reviews (Zapier, ToolFinder, Asana), build guides (Koder.ai), database design references, and open-source projects (Super Productivity, Vikunja, Tududi).

---

## 1. The Core Insight: Apps Win on a Daily Loop, Not Features

The most common failure mode for planner apps is feature bloat. Successful apps (Todoist, TickTick, Things) are built around one **repeated daily loop** that feels effortless:

```
CAPTURE  →  PRIORITIZE  →  SCHEDULE  →  DO  →  REVIEW
 (5 sec)     (1 min)       (3 min)    (day)   (60 sec)
```

| Stage | What the app must do |
|---|---|
| **Capture** | One-tap/one-keystroke task entry. Zero friction — details optional, added later. |
| **Prioritize** | Turn a raw pile into a short list (e.g., "Top 3 Today" + "Later"). |
| **Schedule** | Convert priorities into a realistic plan (Today view / time blocks). |
| **Do** | Show "Now" and "Next" clearly. One primary action: done or defer. |
| **Review** | 60-second end-of-day: what got done, what moved, optional reflection. |

**Recommendation:** every feature decision should be tested against "does this strengthen the loop?"

---

## 2. Market Landscape (2026)

### Commercial leaders & what they're loved for

| App | Signature strengths | Lesson for PlanIT |
|---|---|---|
| **Todoist** | Balance of power & simplicity, natural-language input ("tomorrow 5pm"), best-in-class quick add | Speed of capture is the #1 retention factor |
| **TickTick** | Tasks + calendar + habit tracker + Pomodoro timer in one; best value | "All-in-one" bundling (planner + checker + habits) is the winning trend |
| **Microsoft To Do** | Free, "My Day" daily focus list, Outlook integration | A "My Day" reset-every-morning view is a killer feature — simple and loved |
| **Apple Reminders / Google Tasks** | Free, OS-integrated, simple | Being fast and pre-installed beats being powerful |
| **Things 3** | Elegant, calm design; one-time purchase | Design quality alone can carry a product |
| **Any.do** | Voice input, daily "plan my day" moment | A deliberate "plan your day" ritual drives daily active use |
| **Notion** | Infinite customization (blocks/databases) | Power users want it, but it's overkill for a daily checker |
| **Motion / Reclaim** | AI auto-scheduling into calendar | The 2026 differentiator, but complex to build — later phase |

### Open-source references (study their code/schemas)
- **Super Productivity** (GitHub, Angular/TS) — to-do list + timeboxing + time tracker, offline-first. Closest to "daily checker + planner".
- **Vikunja** — self-hosted Todoist alternative (Go backend + Vue), lists/Kanban/calendar.
- **Tududi** — personal task manager with clean schema (tasks, projects, recurrence fields).
- **Awesome Selfhosted → Task Management** — a curated list worth mining for ideas.

### What reviewers say makes a "best" to-do app (Zapier's criteria)
1. **Fast to add and organize tasks** (a couple of taps/keystrokes, or people quit)
2. **Multiple ways to organize** (lists, tags, due dates, priorities)
3. **Reminders/notifications** for deadlines
4. **Clean, calm UI**
5. **Syncs across devices** (at minimum desktop + mobile)

---

## 3. Recommended MVP Feature Set

### ✅ Must-haves (v1)
| Feature | Notes |
|---|---|
| **Quick add** | One input, minimal fields, from anywhere in the app |
| **Today / My Day view** | Resets each morning; the app's home base |
| **Check off tasks** | Satisfying completion interaction (the "checker" half of PlanIT) |
| **Priority** | High / Medium / Low — instantly understood |
| **Due dates** | Optional, fast to set: Today / Tomorrow / pick date |
| **Reminders** | Local notifications tied to task + time |
| **Recurring tasks** | Daily / weekly / monthly — essential for "daily checker" use |
| **Subtasks** | Break big tasks down (simple checklist, one nesting level) |
| **End-of-day review** | Done list + carryover of unfinished items |
| **Offline-first / local persistence** | App must work without a network |

### 🔜 Phase 2 (after the loop feels great)
- Tags/projects/lists
- Calendar sync (iCal / Google Calendar)
- Time blocking (drag tasks onto a day timeline)
- Templates ("Morning routine", "Weekly review")
- Habit tracker with streaks
- Pomodoro / focus timer
- Stats: completion rate, streaks, weekly summary
- Cross-device sync + accounts

### 🚀 Phase 3 (differentiators)
- AI daily planning ("plan my day from my backlog + calendar")
- Eisenhower matrix view, effort/impact view
- Calendar auto-scheduling (Motion-style)
- Widgets, voice capture, integrations (Slack, GitHub, email)

### ❌ Explicitly NOT in v1 (scope protection)
- Team collaboration / shared workspaces
- Gantt charts, task dependencies
- Note-taking/document editor
- Automation rules

**Screen budget: 4–5 screens.** Inbox/All Tasks · Today · Task detail · Review · Settings.

---

## 4. Productivity Methods → Feature Mapping

Research (Aftertone, Taskade, Monday.com) shows each method solves a *different* failure mode. PlanIT should default to one and optionally support others:

| Method | Problem it solves | Feature it suggests |
|---|---|---|
| High/Med/Low priority | Everything feels urgent | Default priority picker (recommended default) |
| **Eisenhower Matrix** | Urgency crowds out importance | 4-quadrant view (Do / Schedule / Delegate / Drop) — optional mode |
| **Time blocking** | Important work never gets scheduled | Day timeline with drag-and-drop blocks |
| **"Eat the Frog" / Ivy Lee** | Avoiding the most important task | "Top 3 Today" — pick 1–3 must-dos each morning |
| **Pomodoro** | Can't start / focus fragments | Focus timer attached to a task |
| **GTD** | Things fall through cracks | Inbox capture + weekly review |
| **Daily review** | No sense of progress | End-of-day summary + carryover prompt |

Best pattern: **one active prioritization mode at a time**, selectable in Settings — never conflicting signals on the same task.

---

## 5. Tech Stack Options

### Option A — Web app / PWA (recommended start) ⭐
The 2026 consensus stack for solo/small-team web apps is TypeScript end-to-end:
- **Next.js (React) + TypeScript** — frontend + API routes in one codebase
- **PostgreSQL** (or **SQLite** for simplicity at first) + **Prisma/Drizzle ORM**
- **Tailwind CSS** — fast, clean UI
- **Auth**: NextAuth/Auth.js or Clerk (or skip auth entirely for personal use)
- **Deploy**: Vercel/Netlify free tier; installable as a PWA on phone + desktop

*Pros:* fastest iteration, one codebase, cheap deploy, works everywhere. *Cons:* notifications/widgets weaker than native (improving via PWA support).

### Option B — Cross-platform mobile
- **Flutter** (Dart) — one codebase → iOS/Android/web, slick animations, great offline support
- **React Native (Expo)** — reuse React/TS knowledge, OTA updates, huge ecosystem

*Pros:* native push notifications, widgets, app-store presence. *Cons:* slower iteration; desktop/web weaker.

### Option C — Desktop app
- **Tauri (Rust + web frontend)** — tiny binaries, or **Electron** (heavier, more mature)

*Good fit if:* PlanIT is mainly a work-hours companion on Windows.

### Recommendation
Start **web-first (Next.js PWA)** with an API layer clean enough to add a Flutter/React Native client later. This matches how most successful indie planners launched.

---

## 6. Data Model (Reference Schema)

Core entities: `users → projects → tasks`, plus labels and recurrence.

```sql
users        (id, name, email UNIQUE, password_hash, created_at)

projects     (id, user_id FK, name, description, created_at)

tasks        (id, project_id FK NULL, user_id FK,
              title, description,
              status       ENUM('todo','in_progress','done'),
              priority     ENUM('low','medium','high') DEFAULT 'medium',
              due_date     DATE NULL,
              completed_at TIMESTAMP NULL,
              recurrence   TEXT NULL,          -- RRULE string or simple enum
              recurrence_end DATE NULL,
              parent_task_id FK NULL,          -- one level of subtasks
              sort_order   INT,
              created_at, updated_at)

labels       (id, user_id FK, name, color)
task_labels  (task_id FK, label_id FK)        -- M:N

reminders    (id, task_id FK, remind_at TIMESTAMP, fired BOOLEAN)

-- "My Day" is derived (due today OR pinned to day), not stored per task:
day_plans    (id, user_id FK, date, ...)      -- optional: pins, top-3, reflections
```

**Recurring tasks — the one genuinely tricky design decision.** Two proven approaches:
1. **Template + instances**: a `recurrence` definition spawns a concrete task instance each time one is completed (Todoist-style). Easiest to reason about. ✅ Recommended.
2. **Virtual occurrences**: store one RRULE row, render occurrences on the fly (calendar-style). More compact, harder queries.

An RRULE string (RFC 5545, e.g. `FREQ=WEEKLY;BYDAY=MO,WE`) covers daily/weekly/monthly/custom with one field and has mature libraries in every stack.

---

## 7. Suggested Success Metrics (define "working")
- Days-with-a-plan per week (north star — e.g., user plans 4+ days/week)
- Task completion rate on planned days
- Time from open app → first task captured (< 5 seconds)
- End-of-day review completion rate

---

## 8. Final Stack Decision (Nov 2026)

**Platform:** Mobile-first — *Flutter (Dart)*
**Backend:** *Supabase* (Auth + Postgres + Row Level Security + Realtime)
**Focus:** v1 = daily checker (add tasks → tick off → reminders)

### Why Flutter over React Native/Expo
- Standard list/checker UI → Flutter's widget set fits perfectly; consistent look on Android + iOS out of the box
- One coherent framework, one language (Dart), best-in-class docs — lowest friction for a solo build
- First-class local notifications (`flutter_local_notifications` + timezone) for reminders
- Mature local DB for offline cache (`drift`/SQLite) when offline mode is added
- 2026 consensus: pick Expo/RN when you already know React/TS or plan a shared web app; pick Flutter for cohesive custom mobile UI. PlanIT is mobile-first with no existing web codebase → Flutter wins.
- *Revisit if:* you're already fluent in React/TypeScript — then Expo would be equally valid.

### Why Supabase over Firebase
- Our researched schema is relational (users → projects → tasks → labels) → maps 1:1 onto Postgres
- Auth included (email/password, magic link, social) with Row Level Security enforcing per-user data
- Realtime subscriptions → instant cross-device sync (the requirement)
- Postgres = portability, predictable pricing, no vendor lock-in
- Firebase's edge is built-in Firestore offline sync; we get offline later via local Drift cache + sync layer

### Supporting choices
| Concern | Choice |
|---|---|
| State management | Riverpod |
| Local cache (offline, phase 2) | Drift (SQLite) |
| Reminders | flutter_local_notifications + timezone |
| Recurrence | RRULE string; spawn next instance on completion |
| Push (phase 2) | FCM via Supabase Edge Functions |
| CI / iOS builds without Mac | Flutter + Codemagic (or EAS if switching to Expo) |

---

## 9. Open Decisions (resolved)

1. **Platform** → ✅ Mobile (Flutter)
2. **Users** → ✅ Accounts & sync (Supabase)
3. **Stack** → ✅ Flutter + Supabase (see §8)
4. **Signature** → ✅ Daily checker: adding tasks, ticking them off, reminders

