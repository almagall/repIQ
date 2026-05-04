# repIQ

**Intelligent Gym Workout Planning** — not just a logbook.

repIQ is a SwiftUI iOS app that calculates per-set targets using a real progressive-overload engine. It blends e1RM trending, RPE-based autoregulation, mesocycle awareness, and stall detection to tell a lifter what to do next — not just what they did. Currently shipping at **v1.5 (build 9)**.

## What Makes repIQ Different

Most gym apps record what you did. repIQ guides what you should do next.

- **Progressive Overload Engine** — Per-set target weight / reps / RPE based on recent sessions, with e1RM confidence weighting, RPE fatigue detection, mesocycle RPE drift modeling, and off-day escalation. ([ProgressionService.swift](repIQ/Services/ProgressionService.swift))
- **Hypertrophy vs Strength Modes** — Toggled per exercise. Hypertrophy targets ~10–15 reps at RPE 8; strength targets 3–5 reps at RPE 8.5.
- **17 Built-in Programs** — Hypertrophy (PPL 6/3-day, U/L 4-day, Arnold, Bro, FB 3-day), Strength (5/3/1, 5/3/1 BBB, Starting Strength, StrongLifts 5×5, Texas Method, GZCL, nSuns), Hybrid (PHUL, PHAT, Conjugate, Reddit PPL).
- **Real-Time PR Detection** — Weight, rep, volume, and e1RM PRs detected and celebrated mid-workout.
- **Inline Target Reasoning** — Every prescription comes with the *why* ("Hit top of rep range. Increasing weight and resetting reps.") shown directly in the active workout view.
- **Smart Rest Timer** — Auto-bumps after hard sets (RPE ≥ 8.5), trims after easy ones (RPE ≤ 6). Toggleable.
- **Voice Logging via Siri / App Intents** — "Hey Siri, log a set in repIQ." Three-prompt resolution gathers weight, reps, optional RPE; power users can wire a one-shot custom Shortcut on top of the same `LogSetByVoiceIntent`.
- **Interactive Live Activity** — Lock Screen / Dynamic Island steppers + LOG button log working sets without opening the app. Rest timer ticks via `Text(timerInterval:)`.
- **Home Screen Widget** — Streak, weekly working-set count, last PR, and last-trained on Small + Medium families.
- **Repeat Last Workout** — One-tap dashboard pill re-runs the most recent template+day with fresh targets.
- **Social + Gamification** — Friends, fist-bumps, comments, gym communities, head-to-head challenges, clubs, matchmaking, weekly progression races, leagues (Bronze→Diamond), IQ points, badges, milestones — all earned through real training, no streak freezes or paid shortcuts.
- **Smart Nudges + Wrapped** — Coaching nudges grounded in the user's analytics + social graph; weekly digests; monthly Wrapped report.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | SwiftUI (iOS 17+) |
| Architecture | MVVM with `@Observable` |
| Backend | Supabase (Auth, PostgreSQL, RLS) |
| Charts | Swift Charts |
| Live Activities & Widgets | ActivityKit + WidgetKit (single extension, `repIQActivity`) |
| Intents | App Intents (button + voice) |
| Dependencies | `supabase-swift` v2.x, `MuscleMap` (single SPM dep each) |

Design system in `repIQ/Design/` — dark theme, electric blue accent (`#00AAFF`).

## Recent Ships

- **v1.5 (build 9)** — Auto-detect goal completion: workout completion now re-evaluates every active goal against fresh training data, marks any that hit target as `completed`, and surfaces a celebration card on the workout summary. New onboarding step for body context + injuries (sex, birth date, height, body weight, injury list) — all optional, stored in metric on the server, ready to feed future relative-strength stats and injury-aware programming.
- **v1.5 (build 8)** — Monthly Wrapped rebuild: Spotify-style 10-slide story flow (tap-to-advance, swipe-to-dismiss), training-archetype reveal (PR Hunter / Volume Hammer / Consistency King / Variety Seeker / Steady Builder), memorable-unit volume comparisons ("3.2× a Toyota Corolla"), 9:16 share-card export via SwiftUI `ImageRenderer`, dashboard banner card on the 1st–14th, push notification on the 1st of each month, dot badge on the Progress tab until viewed. Fixed a long-standing silent bug where the wrapped query selected a non-existent `exercise_name` column on `personal_records`. Real consecutive-day streak calc replaces the placeholder. New `most_consistent_muscle` aggregation (the column existed but was never populated).
- **v1.4 (build 7)** — Voice set logging via App Intents + AppShortcuts, RPE-aware smart rest timer with Profile toggle, "Repeat last workout" one-tap dashboard pill, real home screen widget suite (Small + Medium) replacing the stub, interactive Live Activity logging, minimize-bug fix.
- **v1.3** — Workout mini-bar above the tab bar (manual `ZStack` overlay; `tabViewBottomAccessory` was unreliable), minimizable workout, Live Activity for in-progress workouts.
- **v1.2** — Progress tab revamp: recap card, projections, body diagram, polish; insight section overhaul; consistency heatmap.
- **v1.1** — Auto-save fixes, scope trajectories by workout day, custom exercises, incomplete-set prompts, smarter Strength Trajectory, monthly stats header.

Older history in `git log`.

## Architecture

```
SwiftUI Views ── @Observable ViewModels ── Services ── Supabase
                                       └── Engines (in-process pure logic)
```

- **Services** wrap Supabase queries (one per domain: workouts, templates, social, gamification, etc.).
- **Engines** are pure logic (`ProgressionService`, `SetFeedbackEngine`, `InsightEngine`, `ProgramEngine`, `PlateCalculator`).
- **Coordinator** (`WorkoutCoordinator`) owns the active-workout view model so it survives `expanded ↔ minimized` transitions.
- **App Intents** (`repIQ/Intents/`) live in both the main app and the activity extension via shared file references; the bridge (`WorkoutIntentBridge`) lets intents from either process reach the live view model in the host app.

## Project Structure

```
repIQ/
├── Config/        Supabase client, app constants, smart-rest thresholds
├── Data/          Programs (Hypertrophy/Strength/Hybrid catalogs),
│                  AchievementCatalog, MilestoneDefinitions, VolumeLandmarks
├── Models/        Codable structs — Profile, Exercise, Template, WorkoutSession,
│                  WorkoutSet, PersonalRecord, Goal, ProgressionTarget, etc.
│                  Models/Social/ — friendship, feed, challenge, club, matchmaking
├── Services/      27 services — Auth, Workout, Template, Progression, Analytics,
│                  Insight, Goal, Social, Feed, Challenge, Gymnastics, Matchmaking,
│                  Gamification, Notification, Nudge, Digest, Tips, LiveActivity,
│                  Widget, Export, OfflineSetQueue, NetworkMonitor, etc.
├── ViewModels/    @Observable — Dashboard, Auth, Profile, Goal, Progress,
│                  ActiveWorkout, WorkoutCoordinator, TemplateEditor/List,
│                  ProgramBrowser, ViewModels/Social/
├── Views/
│   ├── App/       RootView (auth gate), MainTabView
│   ├── Auth/      SignIn, SignUp
│   ├── Onboarding/  7-step flow (experience, goal, frequency, program, goal builder, gym, how-it-works)
│   ├── Dashboard/   Quick start (with repeat-last variant), templates, history, calendar, goals
│   ├── Templates/   List, Detail, Editor, DayEditor, ExercisePicker, ProgramDetail, ProgramBrowser
│   ├── Workout/     Active workout, exercise log, set row, plate breakdown, day picker
│   ├── Progress/    Recap card, exercise progress, session detail, charts
│   ├── History/
│   ├── Goals/
│   ├── Social/      Feeds, friends, challenges, clubs, gym, matchmaking
│   ├── Profile/     Settings (rest timer, smart rest toggle, weight unit, gym), notifications, privacy, export, account
│   └── Components/  RQButton, RQCard, RQTextField, RPESelector, FirstTimeTooltip, etc.
├── Design/        Theme (RQColors, RQTypography, RQSpacing, RQRadius)
├── Extensions/    Color hex init, Date relative/short/day, Double formatting
├── Utilities/     PlateCalculator
├── Intents/       LogSetIntent, AdjustSetIntent, SkipRestIntent (Live Activity buttons),
│                  LogSetByVoiceIntent (Siri voice), repIQAppShortcuts (auto-discovered phrases),
│                  WorkoutIntentBridge
├── PrivacyInfo.xcprivacy
├── repIQ.entitlements (App Group: group.com.repiq.shared)
└── repIQApp.swift

repIQActivity/    Single WidgetKit extension hosting both:
                    - repIQActivityLiveActivity (in-progress workout)
                    - repIQHomeWidget (home screen, Small + Medium)
```

> **Note:** A legacy `repIQWidget/` folder exists on disk but is not in `repIQ.xcodeproj`. Slated for cleanup.

## Database

**25 PostgreSQL tables** in Supabase, all with Row-Level Security:

- **Core training:** `profiles`, `exercises`, `templates`, `workout_days`, `workout_day_exercises`, `workout_sessions`, `workout_sets`, `personal_records`, `progression_log`, `goals`
- **Social:** `friendships`, `feed_items`, `feed_reactions`, `feed_comments`, `challenges`, `clubs`, `club_members`
- **Gamification:** `iq_points_ledger`, `badges`, `user_badges`, `user_milestones`
- **Engagement:** `weekly_digests`, `monthly_wrapped`, `exercise_tips`, `tip_votes`

19 migrations in `supabase/migrations/` (`001_initial_schema.sql` through `20260408_progression_log_workout_day.sql`). Run them in order.

## Setup

1. Clone the repo.
2. Open `repIQ.xcodeproj` in Xcode 26+ (project targets iOS 17+; current build uses iOS 26.2 SDK).
3. SPM auto-resolves `supabase-swift` and `MuscleMap`.
4. Create a Supabase project. Copy your URL + anon key into `repIQ/Config/Supabase.swift`.
5. Run all 19 migrations in `supabase/migrations/` via the Supabase SQL editor (or `supabase db push`), in filename order.
6. Build & run on iPhone 17 Pro simulator.

## Roadmap (not yet shipped)

Tracked in `.claude/plans/`. Current near-term plan focuses on small, high-leverage wins:

- **Set quick-tag chips** — "form clean", "form broke", "felt heavy" as one-tap tags on a working set.
- **Profile editing for body & injuries** — captured at onboarding; users should be able to update height, weight, injuries, etc. from the Profile screen later. Currently captured-but-not-editable.
- **Injury-aware exercise filtering** — body data is captured but not yet used to filter or warn on exercises that conflict with declared injuries.
- **Wrapped Tier 3** — AI-narrated insights (Anthropic API grounded in user data), year-over-year comparison slide, cohort comparison slide, PR mini-replay animations.

Bigger explorations on the back burner: VBT via accelerometer, on-device Vision form check, AI coach grounded in user data, periodization planner, adaptive programs, gym equipment heatmap, NFC quick-start tags, AR bar-path overlay.

Apple Watch companion is planned for a future update.
