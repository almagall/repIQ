# repIQ

A best-in-class iOS workout-logging app — SwiftUI, iOS 17+, Supabase backend. Goal: disrupt the workout-app category with intelligent autoregulation and friction-free logging (Lock Screen + Dynamic Island).

For the first App Store release the app is deliberately scoped to the **core tracking loop**: log workouts, get autoregulated progression targets, and review progress. The social and gamification layers (feed, friends, clubs, leagues, IQ points, badges, challenges, matchmaking, lift percentiles, training-now presence, and the training **streak**) were removed to keep v1 focused; they may return in a later release. See "Removed for v1" below.

This file is auto-loaded into every Claude session in this repo. Keep it accurate; outdated entries are worse than no entries.

---

## Quick reference

| What | Where |
|---|---|
| Open project | `repIQ.xcodeproj` (no workspace exists) |
| Main app target | `repIQ` (bundle: `com.repiq.repIQ`, Team: `A6A68RW9W3`) |
| Live Activity widget target | `repIQActivity` (bundle: `com.repiq.repIQ.repIQActivity`) |
| Build for sim | `xcodebuild -project repIQ.xcodeproj -scheme repIQ -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build` |
| Build widget standalone | swap scheme to `repIQActivity` |
| Archive for App Store | `xcodebuild ... -configuration Release -destination 'generic/platform=iOS' -archivePath build/repIQ.xcarchive archive` |
| Supabase URL | `https://yuwtotiahdmnjplrumdu.supabase.co` (config in `repIQ/Config/Supabase.swift`) |
| App Group | `group.com.repiq.shared` (used by Live Activity intent bridging) |
| Current shipping version | `1.5 (build 11)` (May 2026) — the social/streak strip is unreleased post-11 work |

---

## Top-level architecture

```
RootView (AppState)
 ├─ AuthView                        if !isAuthenticated
 ├─ OnboardingView                  if needsOnboarding
 └─ MainTabView                     authenticated + onboarded
     ├─ Tab 0  DashboardView        (Home)
     ├─ Tab 1  ProgressTabView      (Progress)
     └─ Tab 2  ProfileView          (Profile)

WorkoutCoordinator (hoisted to RootView, env-injected)
 ├─ owns ActiveWorkoutViewModel
 ├─ presentation: .hidden | .minimized | .expanded
 ├─ static current: weak ref so App Intents can reach the running VM
 └─ drives the fullScreenCover binding in MainTabView for the workout overlay
```

- **Three tabs.** Home, Progress, Profile. (There was a 4th "Social" tab; removed for v1.)
- **Observation:** Swift's `@Observable` macro everywhere — *not* `ObservableObject`. Bindings via `@Bindable`.
- **State of truth:** `WorkoutCoordinator` owns the in-flight `ActiveWorkoutViewModel`. SwiftUI `@State` is for view-only ephemeral UI state.
- **Navigation:** Each tab is its own `NavigationStack`. The active workout is presented via `fullScreenCover` whose binding is custom — dismissing it minimizes (preserves VM) instead of tearing down. See `MainTabView.expandedBinding`.

---

## Project layout

```
repIQ/
 ├─ App/                  RootView, MainTabView, AppState, splash
 ├─ Auth/                 AuthView, sign-in/up flows, OAuth
 ├─ Onboarding/           7-step OnboardingView
 ├─ Config/               Supabase client config, AppConstants (Constants.swift), AppStorage keys
 ├─ Design/               Theme.swift (RQColors, RQSpacing, RQRadius), Typography.swift
 ├─ Models/               Domain types (Codable structs, enums)
 ├─ Services/             Supabase calls + local services (one class per file)
 ├─ ViewModels/           @Observable VMs; ActiveWorkoutViewModel is the giant
 ├─ Views/
 │   ├─ App/              Tab + root
 │   ├─ Auth/, Onboarding/
 │   ├─ Dashboard/        Home tab
 │   ├─ Progress/         Progress tab
 │   ├─ Social/           Only the Rep Sheet monthly recap survives here now (RepSheetView)
 │   │   └─ Wrapped/      RepSheetDeckView, MonthlyReportView, MonthlyComparisonView
 │   ├─ Profile/          Profile tab
 │   ├─ Templates/        Template + WorkoutDay editing
 │   ├─ Workout/          ActiveWorkout, SetRow, RestTimer, PR celebration, mini-bar, summary
 │   ├─ History/          Past sessions
 │   ├─ Goals/            Goal setting
 │   └─ Components/       RQCard, RQButton, RQTextField, RPESelector, etc.
 ├─ Intents/              LiveActivityIntent definitions + WorkoutIntentBridge
 ├─ Utilities/, Extensions/
 ├─ Assets.xcassets/      App icons, accent color, etc.
 ├─ Info.plist
 └─ repIQ.entitlements    App Group, push (if added later)

repIQActivity/             Live Activity widget extension target
 ├─ repIQActivityBundle.swift
 ├─ repIQActivityLiveActivity.swift  (Lock Screen + Dynamic Island layouts)
 ├─ Info.plist
 └─ repIQActivity.entitlements       Same App Group as main app
```

Xcode 16's **filesystem-synchronized groups** are used for the main `repIQ` target — any file added under `repIQ/` is auto-included, and deleting a file removes it from the build with no `project.pbxproj` edit. The widget target uses traditional explicit references; new files for the widget target must be added to `project.pbxproj` manually (see how `WorkoutIntentBridge.swift` etc. are referenced from `../repIQ/Intents/`).

### Current services

`AnalyticsService` (Progress tab data — the big one), `AuthService`, `DigestService` (Monthly Wrapped), `ExerciseLibraryService`, `ExportService`, `GoalService`, `GymService` (Profile "set your gym" — vestigial without gym leaderboards, kept for now), `InsightEngine`, `LiveActivityService`, `NetworkMonitor`, `NotificationService`, `OfflineSetQueue`, `ProfileService`, `ProgramEngine`, `ProgressionService`, `SetFeedbackEngine`, `TemplateService`, `WidgetService`, `WorkoutAutoSave`, `WorkoutService`, `WrappedArchetype` (Rep Sheet "style" card — internal name kept).

`DigestService` owns both the (idle) weekly digest and the **Rep Sheet** monthly recap.

The social/gamification services (`SocialService`, `FeedService`, `ChallengeService`, `MatchmakingService`, `LiftPercentileService`, `PresenceService`, `TipsService`, `NudgeService`, `GamificationService`) were **deleted**.

---

## Domain glossary

Critical to read before touching workout logic.

- **Set** — a single attempt: weight × reps, optional RPE. Type ∈ `{warmup, working, cooldown, drop, failure}`.
- **Working set** — counts toward progression. Warmup/cooldown do not.
- **Rep** — one repetition of the movement.
- **RPE (Rate of Perceived Exertion)** — 1–10, optional. 8 = "could do 2 more reps before failure," 10 = max effort. Used by progression engine to detect hidden fatigue.
- **e1RM (estimated 1-rep max)** — Epley formula: `weight × (1 + reps / 30)`. Confidence is high at low reps (1–5), low at high reps (15+). Defined on `WorkoutSet.estimated1RM`.
- **Volume** — `weight × reps`, summed across sets / exercises / sessions.
- **Training mode** — per-exercise on a workout day:
  - `hypertrophy`: 10–15 reps, target RPE 8.0, **straight sets** (same weight × reps every set; RPE climbs 0.5/set due to fatigue).
  - `strength`: 3–5 reps, target RPE 8.0, **ramped to top set** (weight ascends from ~80% start pct to top-set weight; RPE ramps 6.0 → target).
- **Progression target** — output of `ProgressionService.calculateTarget`: prescribed `targetWeight × targetReps @ targetRPE` for next session, plus a `decision` ∈ `{increaseWeight, increaseReps, maintain, deload, deloadVolume}` and English `reasoning`.
- **Mesocycle** — training block measured in `weeksSinceDeload`. RPE offset escalates: 0 weeks (offset 0), 3–4 weeks (+0.5), 5–6 weeks (+1.0), 7+ weeks (force deload).
- **Deload** — planned recovery week (~90% of current e1RM). Triggered proactively at 7+ weeks or reactively on declining e1RM / consecutive bad sessions.
- **PR (Personal Record)** — max ever lifted. Types: `weight`, `reps` (at a specific weight), `volume`, `estimated1rm`. Detected inline during set completion (instant celebration) and again post-session against DB.
- **Workout day** — a named day in a template (e.g. "Push A", "Pull B"). Same exercise on different days has **independent progression history** — see "Workout-day scoping" below.
- **Superset** — two+ exercises performed back-to-back with no rest between, then rest after the round. Configured at session-level (not in template), via `ExerciseLogEntry.supersetGroup: Int?`.
- **Pending set** — set logged offline, queued in `OfflineSetQueue` until network returns. Marked completed in UI immediately so workouts continue without interruption.
- **Goal target** vs **pending value** — on `SetEntry`: `targetWeight/targetReps/targetRPE` are immutable snapshots from `perSetTarget` at workout start; `weight/reps/rpe` are the live values that get adjusted (in-app inputs or Live Activity steppers) and ultimately saved.
- **Rep Sheet** — a per-month recap generated by `DigestService` and rendered as a swipeable industrial spec-card **deck** (`RepSheetDeckView`, single accent blue, tap-zones + drag, depleting/restacking stack, exit-any-time). `DigestService.generateRepSheet` builds a display-ready deck at generation time — each card gated on data sufficiency, then notability-ranked (cover first, always-on next-month coaching last, ≤10 total) — and persists it to the previously-unused `monthly_wrapped.data` JSONB column (`RepSheetContent`). Self-contained retention feature, no friends required; surfaces via a Dashboard banner and a Progress-tab CTA/badge. (Formerly "Monthly Wrapped"; renamed to shed the Spotify association. Internal `DigestService` helper names and the `monthly_wrapped` table keep the old names.)

---

## Persistence model — three layers

Critical to keep in your head when touching anything that writes data.

### Layer 1: Supabase remote (primary source of truth)

- Completed sets, sessions, profile, goals, PRs, monthly wrapped.
- Tables of note (still live): `workout_sessions`, `workout_sets`, `exercises`, `templates`, `workout_days`, `workout_day_exercises`, `profiles`, `personal_records`, `goals`, and the monthly-digest tables.
- **Deferred/idle tables:** the social/gamification tables (`iq_points_ledger`, `user_badges`, `feed_items`, `feed_reactions`, `feed_comments`, `friendships`, `clubs`, `club_members`, `user_presence`, league columns, etc.) still exist in the database but the client no longer reads or writes them. Their migrations remain under `supabase/`. Leave them; re-wiring them is a future-release task.
- Profile is auto-created by a DB trigger on auth signup. If email confirmation delays the trigger, `RootView.AppState.syncUsernameFromMetadata()` patches the username on next sign-in (`repIQ/Views/App/RootView.swift`).
- Auth client config: `repIQ/Config/Supabase.swift`. Anon key in source (safe — public).

### Layer 2: OfflineSetQueue (local file-based queue)

- File: `Documents/pending_sets.json`.
- Triggered when `WorkoutService.saveSet()` throws (network failure).
- Set marked completed locally so the user keeps lifting; re-sync fires on `NetworkMonitor.onReconnect`.
- Per-set retry; no exponential backoff.
- See `repIQ/Services/OfflineSetQueue.swift`.

### Layer 3: WorkoutAutoSave (crash recovery snapshot)

- File: `Documents/active_workout_state.json`.
- Periodic write (`autoSaveTask`) of the full in-progress workout: sessionId, templateName, dayName, startTime, all `SavedExerciseState` + `SavedSetState`.
- On app launch, `MainTabView.task` checks `WorkoutAutoSave.hasRecoverableState` and shows "Resume Workout?" if a state exists ≤ 4 hours old.
- Cleared on Finish or Abandon.
- See `repIQ/Services/WorkoutAutoSave.swift`.

**Conflict policy:** last-write-wins. There's no merge logic. Don't add one without a real reason.

---

## Progression engine — the heart of the app

`repIQ/Services/ProgressionService.swift::calculateTarget(...)` decides what to prescribe next session. Read this whole file before changing anything in it. `calculateTarget` dispatches by training mode to `hypertrophyTarget` / `strengthTarget` (bodyweight → `calculateBodyweightTarget`). **Both modes are double progression**; they differ in what drives the weight bump. e1RM is intentionally *not* a decision input for hypertrophy — the Epley/Brzycki estimate is unreliable in the 10–15 rep band, so hypertrophy follows actual reps against the range instead. (This replaced the old unified e1RM-trend + confidence-gate model, which stalled weight whenever the *median* rep count sat below the cap and never credited beating the prescription.)

Both mode functions share the same preamble ordering: **deload safety nets → baseline (<2 sessions) → single off-day → progression state machine.**

**The prescription is a single rep goal, not a range.** `targetRepsLow == targetRepsHigh` always (so `targetRepRangeDisplay` renders one number, e.g. "185 × 10"). The rep *band* (10–15 etc.) still lives on `TrainingMode.repRange` and drives the weight-bump trigger and reset; the target is just the one number to hit this session, which climbs week to week toward the top of the band.

### Hypertrophy — strict double progression (in order)

Reference = the whole set (uses `minReps`, the *minimum* reps across working sets, and `workingWeight` = median). Range 10–15 (narrowed by `repCap`).

1. **`weeksSinceDeload >= 7`** (allowDeload) → `.deload` at 90% of working weight.
2. **2+ consecutive sessions with >10% weight drop** (allowDeload) → `.deload` at 90%.
3. **<2 sessions** → `.maintain` (baseline).
4. **Single off-day** — `workingWeight < 90%` of recent best **AND** sub-par (`minReps < bottom` OR hardest RPE `>= targetRPE + 1`) → `.maintain` at proven working weight. A lighter session with solid reps at reasonable effort is *not* an off-day; it falls through to normal progression from the actual weight (so a clean high-rep session at a lower load isn't yanked back up to an old best).
5. **`minReps >= top`** (every set hit the top of the range, overshoot included) → **`.increaseWeight`** by one increment, target reps = `bottom` (reset).
6. **`minReps < bottom`** (missed the floor) → `.maintain`, hold and rebuild, target reps = `bottom`.
7. **RPE early-bump:** hardest set's RPE `<= targetRPE − 3` (**3+ RIR**) → **`.increaseWeight`** one increment, reset to `bottom`. Deliberately stricter than strength's 2-RIR bar — hypertrophy banks reps at a load unless there's a clear surplus. Only fires when RPE is logged; absent RPE → pure strict double progression.
8. **else** (in range, not all at top) → **`.increaseReps`**, target reps = `min(minReps + 1, top)`.

### Strength — top-set double progression (in order)

Reference = the **top set** (heaviest working set), since ramped sets have different weights. e1RM *is* valid at 3–5 reps, so it sizes the weight jump. Range 3–5.

1–3. Same deload/baseline nets as hypertrophy (deload weight is e1RM-derived: `currentE1RM × 0.90 × pctOfE1RM(bottom)`).
4. **Single off-day** — `topSetWeight < 90%` of recent best **AND** sub-par (`topSetReps < bottom` OR top-set RPE `>= targetRPE + 1`) → `.maintain` at proven top-set weight; otherwise falls through to normal progression from the actual weight.
5. **`topSetReps >= top`** (top set hit 5) → **`.increaseWeight`** via `increaseWeightTarget` (e1RM-sized, floored one increment above the top set so a 5→3 reset jumps more than one increment), reset to `bottom`.
6. **`topSetReps < bottom`** → `.maintain`, rebuild.
7. **RPE early-bump:** top set's RPE `<= targetRPE − 2` (**2+ RIR**) → **`.increaseWeight`**.
8. **else** → **`.increaseReps`** on the top set: `min(topSetReps + 1, top)`.

`calculateTarget` takes `allowDeload: Bool = true`. When `false`, both deload nets are suppressed and flow into the normal state machine (a declining lifter gets `.maintain`/`.increaseReps` instead of a deload). This backs the "Keep Progressing" choice on the deload prompt (see below). Weight always advances by exactly one increment (hypertrophy) or an e1RM-sized-but-floored jump (strength) — never proportional to overshoot; beating the top of the range just earns the bump sooner.

### Deload is a choice, not silent (performance deloads)

Performance-based deloads (`.deload` / `.deloadVolume`) are computed at the *end* of the triggering session and stored in `progression_log`, but they are **not applied silently**. At the start of the next session, `ActiveWorkoutViewModel.startWorkout` scans the loaded targets; if any is a deload it sets `pendingDeload` and `ActiveWorkoutView.performanceDeloadBanner` prompts the user (whole-session, two required buttons, no dismiss):
- **Take Deload** (`takeDeload()`) → keep the loaded ~90% targets.
- **Keep Progressing** (`keepProgressing()`) → re-fetch each flagged exercise's last 3 sessions, recompute with `allowDeload: false`, and rebuild the not-yet-completed pre-filled sets + their GOAL snapshots.

Stateless by design: the decision is recomputed from actual sets every completion, so a still-declining user is re-prompted next session (no remembered choice). This is separate from the **time-based** proactive deload (`shouldSuggestDeload` → `deloadSuggestionBanner`, opt-in); the time-based banner is suppressed when a `pendingDeload` is already showing so the user never sees two deload prompts at once. Note: `weeksSinceDeload` is not passed at the completion call site, so the engine's "7+ weeks → force deload" ceiling is currently dead in this path — the 7-week case is handled entirely by the time-based suggestion.

### Per-set target computation

`ActiveWorkoutViewModel.perSetTarget(decision:previousSet:trainingMode:setPosition:totalSets:equipment:)` maps the prescribed `(targetWeight, single targetReps, RPE)` to *each* set:

- **Hypertrophy:** every working set gets `targetWeight × targetRepsLow` (the single session rep goal — same number on every set). RPE = `base + 0.5 × setIndex` (climbs with fatigue).
- **Strength:** weight ramps from `targetWeight × startPct` (startPct depends on totalSets) up to full targetWeight on the top set; reps stay at `targetRepsLow`; RPE ramps linearly from 6.0 to `targetRPE + mesocycleOffset`.
- Weight is rounded down to the equipment increment via `ProgressionService.weightIncrement(for:)` and `roundToIncrement`.
- Bodyweight exercises (`calculateBodyweightTarget`) skip e1RM entirely; rep-only single-target double progression. A below-floor session (`minReps < bottom`) holds at current reps (can't shed load); a rep drop reduces reps (`.deloadVolume`); hitting the top on every set suggests adding external weight (`.increaseWeight`, reset to bottom).

### Mesocycle RPE offset

`ProgressionService.mesocycleRPEOffset(weeksSinceDeload:)`:
- Weeks 0–2: offset 0 (base effort)
- Weeks 3–4: offset +0.5 (push harder)
- Weeks 5–6: offset +1.0 (peak intensity)
- Weeks 7+: should deload

Effective target RPE caps at 9.5 (`ProgressionTarget.effectiveTargetRPE`).

### PR detection

- **Inline** (during the workout): runs in `ActiveWorkoutViewModel.completeSet`. Detects weight PRs (heaviest ever) and rep PRs (most reps at this exact weight). Triggers `prCelebration` modal + heavy haptic.
- **Session-end**: `ProgressionService.detectPRs()` runs post-completion against DB. Inserts into `personal_records` table.

---

## Live Activity / Dynamic Island

Recently shipped (v1.4). The Lock Screen and Dynamic Island let users log sets without unlocking, via interactive `LiveActivityIntent` buttons.

### Architecture

```
Lock Screen / Dynamic Island         (rendered by repIQActivity widget extension)
   │  Button(intent: LogSetIntent())                ← tap stepper [−][+] or LOG SET
   ▼
LiveActivityIntent.perform()         (runs in main app process)
   │  WorkoutIntentBridge.shared.logSet() / .adjustSet(field:direction:)
   ▼
WorkoutIntentBridge                  (file: repIQ/Intents/WorkoutIntentBridge.swift)
   │  closures registered by ActiveWorkoutViewModel
   ▼
ActiveWorkoutViewModel.handleLogSetFromIntent / handleAdjustSetFromIntent
   │  mutates the upcoming SetEntry, calls existing completeSet
   ▼
LiveActivityService.update(buildContentState())  → push to Lock Screen
```

### Why the bridge?

Intent files (`LogSetIntent.swift`, `AdjustSetIntent.swift`, `SkipRestIntent.swift`, `WorkoutIntentBridge.swift`) are in **both** target memberships. They reference each other, but they cannot reference main-app types like `WorkoutCoordinator` directly — those aren't in the widget target. The bridge is the indirection layer:

- Main app registers handlers on `WorkoutIntentBridge.shared` when a workout starts (`ActiveWorkoutViewModel.registerIntentHandlers`, called from `startLiveActivity`).
- Handlers cleared in `completeWorkout` / `abandonWorkout` via `unregisterIntentHandlers`.
- If intent fires and no handlers are registered (app killed, no active workout) → throws `WorkoutIntentError.noActiveWorkout` with user-facing message "Open repIQ to continue your workout."

### Orphan cleanup

iOS keeps Live Activities visible after the app process dies, but the in-memory `LiveActivityService.activity` reference is lost. On next launch we'd request a *new* activity that stacks on top of the orphan, producing visually corrupted renders.

`LiveActivityService.cleanupOrphans()` is called from `RootView.task` at app launch and again from `start()` before requesting any new activity. It enumerates `Activity<WorkoutActivityAttributes>.activities` and ends every one. Required, do not remove.

### Lock Screen layout constraints

- iOS enforces ~135pt content height cap. Exceed it and content clips at the top *and* bottom.
- Layout is a 3-column horizontal stepper block (Weight / Reps / RPE), each column with label + value + `[−][+]`. Vertical 3-row stacking does not fit.
- `Text(timerInterval:)` in a busy HStack is dangerous — even with `.fixedSize()` it can starve sibling views and silently kill layout for the rest of the activity. Use a manually-formatted elapsed string instead, or place `Text(timerInterval:)` in a region with explicit `.frame(width:)` and no flex siblings.
- `Button(intent: AdjustSetIntent(field:direction:))` works inside Live Activity Lock Screen; iOS 17+ only.

### ContentState (`repIQ/Models/WorkoutActivityAttributes.swift`)

The state pushed to the activity. Fields:
- `currentExerciseName`, `setProgress` (display strings)
- `pendingWeight`, `pendingReps`, `pendingRPE` (live values, mutated by stepper)
- `goalWeight`, `goalReps`, `goalRPE` (frozen target snapshots, for the "GOAL" line)
- `previousSet` (`weight, reps, rpe`) (last session's set at the same set number, for the "LAST" line)
- `weightStep`, `weightUnit`
- `currentExerciseIndex`, `currentSetIndex` (passed back to intents)
- `restEndDate`, `isRestActive`, `setKind`

`buildContentState()` lives on `ActiveWorkoutViewModel` and is the single source — both `startLiveActivity` and `pushActivityUpdate` call it.

---

## Top-level screens

### Home (`repIQ/Views/Dashboard/DashboardView.swift`)

- **Welcome card** — first-time users only (`@AppStorage("hasSeenWelcomeCard")`).
- **Rep Sheet banner** — appears 1st–14th of each month if prior month's Rep Sheet is ready & unviewed (`RepSheetBannerCard` → pushes `RepSheetView`).
- **Quick Start** — hero CTA. Triggers template picker → `WorkoutDayPickerView` → `coordinator.startWorkout(template:day:date:)`.
- **My Templates** — list of user templates. Tap → `WorkoutDayPickerView`.
- **Workout History** — link to `WorkoutHistoryView`.
- **Activity** — week strip (binary trained/didn't) or month calendar.
- **Goals** — up to 3 active goals with progress bars; link to `GoalSettingView`.

(The old "Social Pulse" card was removed.)

### Progress (`repIQ/Views/Progress/ProgressTabView.swift`)

- Monthly stats header
- Last-workout recap
- **Strength trajectory** chart (top lifts, scoped by workout day)
- **Consistency** section: consistency ring (0–100 score) + 12-week daily heatmap with PR-day dots. (The flame/"WEEK STREAK" chip was removed with the streak feature.)
- Smart insights (prescriptive coaching)
- Volume trend (4-week baseline)
- Muscle balance body diagram (uses `MuscleMap` Swift package)
- Recent PRs
- Rep Sheet CTA (if ≥3 sessions this month) → `RepSheetView`

Driven by `ProgressDashboardViewModel`. The exercise drill-in is `ExerciseProgressView` (via `ExerciseProgressLoaderView`) — trend chart, PRs, recent sessions. (Its lift-percentile card and community-tips section were removed with the social layer.)

**Consistency score** (`AnalyticsService.fetchConsistencyScore`) is a 0–100 composite of three factors: **frequency (50%)**, **volume stability (30%)**, **recency (20%)**. The old streak factor (20%) was removed and its weight redistributed. `ConsistencyScore` no longer has a `streakScore` field.

### Profile (`repIQ/Views/Profile/ProfileView.swift`)

Avatar / username / gym info, then Settings (weight unit, rest timer, body & health, notifications, privacy, gym, account) and Sign Out. (The "My Stats" league/IQ/streak card was removed.) Notification settings offer workout reminders + monthly-wrapped reminders (the streak-protection reminder was removed).

### Templates (`repIQ/Views/Templates/`)

`TemplateListView` → `TemplateDetailView` → `TemplateEditorView` (name + days) → `WorkoutDayEditorView` (exercises + training mode + targetSets + repCap + supersetGroup) → `ExercisePickerView`. Pre-built programs in `ProgramBrowserView` → `ProgramDetailView` (one-tap create-template).

(The template "Share with friends" toggle and shared-template cloning were removed with the social layer. The `templates.is_shared` column and its RLS remain in the DB, unused.)

### Rep Sheet (`repIQ/Views/Social/RepSheetView.swift` + `Wrapped/`)

Standalone monthly recap. `RepSheetView` self-fetches the current user id (via `supabase.auth.session`), drives `DigestService.generateRepSheet` (idempotent per month), then hands off to `RepSheetDeckView` — a swipeable card deck that renders the pre-selected, pre-ordered cards in `RepSheet.content.order` (decoded from `monthly_wrapped.data`). `MonthlyReportView` / `MonthlyComparisonView` remain as the "View full report" breakdown + share card, reached from the deck's final coaching card. Legacy rows with no `data` payload fall back to a minimal cover→style→coaching deck via `RepSheetContent.fallback`. Card selection, gates, and the notability ranking all live in `DigestService` (data layer); `RepSheetDeckView` is pure rendering. Lives under `Views/Social/` for historical reasons — no social plumbing.

---

## Workout flow (end to end)

1. User taps **Start Workout** on Dashboard → template picker sheet → `WorkoutDayPickerView`.
2. User picks day + date → `coordinator.startWorkout(template:day:date:)`.
3. `WorkoutCoordinator` creates `ActiveWorkoutViewModel`, sets `presentation = .expanded`.
4. `MainTabView.fullScreenCover` shows `ActiveWorkoutView`.
5. `.task { await viewModel.startWorkout(template:day:date:) }` runs. This:
   - Creates session in Supabase (`workout_sessions`).
   - Fetches previous-session sets per exercise (scoped by `workoutDayId`).
   - Fetches latest progression targets per exercise.
   - Builds `ExerciseLogEntry`s with pre-computed `SetEntry`s via `perSetTarget`.
   - Starts elapsed timer + auto-save + Live Activity.
   - Surfaces the performance-deload prompt if any loaded target is a deload (see "Deload is a choice"); otherwise checks the time-based proactive deload suggestion.
6. User logs sets via `SetRowView` (in `ExerciseLogView`):
   - Adjust weight/reps/RPE → tap checkmark → `viewModel.completeSet(exerciseIndex:setIndex:)`.
   - Auto-saves to Supabase (or queues to `OfflineSetQueue` on failure).
   - Inline PR detection → `prCelebration` overlay if PR.
   - Auto-starts rest timer (with superset-aware logic).
   - Strong haptic for PR, medium for normal set.
7. **Minimize:** chevron-down → `coordinator.minimize()` → `presentation = .minimized` → `fullScreenCover` dismisses → mini-bar shows above tab bar (`MainTabView.withMiniBar`). Tap mini-bar → `coordinator.expand()` → cover re-presents with state intact.
8. **Lock Screen / DI:** Live Activity steppers + LOG SET button do the same operation as in-app set completion (via `WorkoutIntentBridge`).
9. **Finish:** alert confirm → `viewModel.completeWorkout()`:
   - Cancels auto-save + clears `WorkoutAutoSave`.
   - Ends Live Activity, unregisters intent handlers.
   - Updates session in Supabase.
   - Refreshes the home-widget last-workout date (`WidgetService.updateAfterWorkoutCompletion`).
   - Detects new PRs → DB.
   - Evaluates active goals (`GoalService.evaluateActiveGoals`) and surfaces any just-completed.
   - Builds `WorkoutSummaryData` → presents `WorkoutSummaryView`.
   - (No IQ points, badges, feed items, streak update, or presence write — those were removed.)
10. **Abandon:** alert confirm → `viewModel.abandonWorkout()` → marks session abandoned, ends Live Activity, no rewards.

### Mini-bar / minimize-expand pattern

The `expandedBinding` in `MainTabView` is custom: its `set` calls `coordinator.minimize()` instead of letting the cover dismiss the VM. This is required because:

- `@State` on `MainTabView` doesn't reliably persist a mutation made from inside the `fullScreenCover` content closure (mutating `@State` during view body).
- The previous bug (fixed in v1.4): `activeWorkoutViewModel` lived as `@State` on `MainTabView`. After minimize, the state was nil and the mini-bar's `if let vm = activeWorkoutViewModel` guard failed silently. **Don't move VM ownership back to `@State`.** It lives on `WorkoutCoordinator`.

---

## Design system

`repIQ/Design/Theme.swift` and `Typography.swift`. Always use these tokens — never raw color hex or pixel values in views.

### Colors (`RQColors`)

- **Accent**: `accent` (#00AAFF electric blue), `accentLight`, `accentDark`
- **Backgrounds**: `background` (#000), `surfacePrimary` (#0A0A0A), `surfaceSecondary` (#141414), `surfaceTertiary` (#1C1C1C)
- **Text**: `textPrimary` (white), `textSecondary` (#999), `textTertiary` (#555)
- **Semantic**: `success` (green), `warning` (gold), `error` (red), `info` (light blue)
- **Training modes**: `hypertrophy` (purple), `strength` (orange)
- **Set types**: `warmup`, `working` (green), `cooldown`, `dropSet`, `failure` (red)
- **Muscle groups**: 11 unique colors (chest, back, shoulders, biceps, triceps, etc.)

### Spacing (`RQSpacing`)

`xxs=2, xs=4, sm=6, md=10, lg=14, xl=20, xxl=28, xxxl=40`. Conventions: `cardPadding=16`, `cardSpacing=10`, `screenHorizontal=16`.

### Radius (`RQRadius`)

`small=2, medium=4, large=6, extraLarge=12`. The app trends toward sharp / industrial corners.

### Typography (`RQTypography`)

- **Titles** are monospaced (industrial feel): `largeTitle, title1, title2, title3`.
- **Body** is proportional: `headline, body, callout, subheadline, footnote, caption`.
- **Numbers** are monospaced: `numbers, numbersSmall`.
- **Special**: `targetWeight` (44pt heavy mono — rest timer big number), `label` (10pt mono uppercase — section headers).

### Components (`repIQ/Views/Components/`)

| Component | Use for |
|---|---|
| `RQCard` | Bordered card container. Pass content via view builder. |
| `RQButton` | Primary (accent bg, black text), secondary (outlined), destructive (red outline). Uppercase. |
| `RQTextField` | Standard text input. |
| `EmptyStateView` | Icon + title + message + optional CTA. |
| `LoadingOverlay` | Full-screen spinner + message. |
| `FirstTimeTooltip` | Dismissible one-time tip keyed by `@AppStorage`. |
| `RPESelector` | 1–10 RPE picker. |
| `MuscleHeatmapView`, `ExerciseHistoryChart`, `SwipeToDeleteWrapper`, `InfoSheet` | Other reusables — read each before reinventing. |

---

## Conventions

- **Models** are `Codable, Sendable` structs/enums where they cross actor or process boundaries (Live Activity content, intent params, etc.).
- **Services** are non-actor classes/structs; methods are `async throws` for network calls.
- **ViewModels** are `@Observable final class`. They run on the main actor by default in iOS 17+ Swift 6 mode (project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- **Persistence**: Supabase first; OfflineSetQueue is a fallback, not a primary write target.
- **Time**: store as `Date` (UTC under the hood). Display via `relativeDisplay` extension or `formatted(...)`.
- **No `print` in committed code.** Swallow errors at boundaries (Supabase services already do this).
- **Comments**: only for the "why" — hidden invariants, workarounds for specific bugs, surprising behavior. No restating what well-named code already says.
- **Filesystem-synchronized groups**: drop new Swift files anywhere under `repIQ/` and they're auto-included in the main app target. The widget target needs manual `project.pbxproj` edits.

---

## Hard constraints (do not break these)

1. **Warmup and cooldown sets must NEVER be pre-filled with values.** The user explicitly wants those weights/reps user-driven, not algorithmic. (Lives in user memory file `feedback_warmup_cooldown_no_prefill.md` as well.)
2. **Active workout VM must be owned by `WorkoutCoordinator`, not `@State` on `MainTabView`.** The minimize-bug fix in v1.4 depends on this.
3. **Live Activity orphan cleanup must run at launch.** `RootView.task` must call `LiveActivityService.shared.cleanupOrphans()` before anything else can request a new activity.
4. **Intent files must be in BOTH target memberships.** When adding a new `LiveActivityIntent`, edit `project.pbxproj` to add the file to `repIQActivity`'s Sources phase. See `WorkoutIntentBridge.swift` for the pattern.
5. **Workout day scoping is essential for progression.** Always pass `workoutDayId` when fetching previous sets / latest targets — same exercise on different days has independent histories.
6. **App Group `group.com.repiq.shared`** is configured on both targets. Adding additional groups or capabilities requires regenerating Distribution profiles in the Apple Developer portal — Xcode Organizer handles it during the next archive distribute.

---

## Removed for v1 (deferred, not deleted from history)

The following were stripped to focus the first release on core tracking. The client code was deleted; the Supabase tables/migrations remain but are idle. Bringing any of these back is a future-release effort — check git history on branch `strip-social-v1` for the removal diffs.

- **Social tab** and everything under it: feed, friends, friend profiles, gym hub, leagues, promotion race, challenges, achievements, badges, clubs, matchmaking, social profile, add-friends, weekly digest.
- **Gamification:** IQ points, badges, league tiers, milestone/achievement catalogs (the `MilestoneCatalog`/`AchievementCatalog` data files still exist but are not rendered anywhere).
- **Lift percentiles** (exercise drill-in) and **community tips**.
- **Training-now presence** (`user_presence`).
- **Shareable templates** (`is_shared` toggle + clone).
- **Training streak — entirely.** Both the profile-based daily streak (workout-summary "Day Streak", share-card streak line, home-widget streak) and the analytics weekly streak (Progress-tab "WEEK STREAK" flame, consistency-score streak factor, streak-based smart insights, streak-protection notification). The Rep Sheet's consistency card surfaces trained-days / rest-days / best-week (not a streak); `DigestService` still computes the `longest_streak` scalar but the deck no longer renders it.

**Kept:** the full logging loop, progression engine + deload prompts, Progress analytics (minus streak/percentiles), goals, history, templates + pre-built programs, Live Activity / Dynamic Island, Rep Sheet (monthly recap), offline queue, crash-recovery autosave, export, workout/Rep-Sheet reminders.

---

## Recent ships

- **Unreleased (post-build 11)** — Jul 2026 — **Monthly recap redesign: "Rep Sheet" card deck.** Renamed *Monthly Wrapped* → **Rep Sheet** (`MonthlyWrapped` → `RepSheet`, `MonthlyWrappedView` → `RepSheetView`, `WrappedStoryView` → `RepSheetDeckView`, `WrappedBannerCard` → `RepSheetBannerCard`) and replaced the Spotify-style one-way story with a swipeable **industrial spec-card deck** on a single accent blue (tap-zones + drag, depleting/restacking stack, exit-any-time). Shifted content from vanity totals to insight: a **13-card pool** (strength gained, biggest mover, breakthrough moment, PR wall, all-time rank, consistency heatmap, relative strength, muscle balance, month-over-month, when-you-train, style) each with a data-sufficiency **drop gate**, **notability-ranked** to ≤10 with cover first + an always-on next-month **coaching** closer; sparse months degrade gracefully. Two commits: (A) `DigestService.generateRepSheet` computes the full display-ready deck (`RepSheetContent`) and persists it to the previously-unused `monthly_wrapped.data` JSONB column — **no migration**; (B) the deck UI + rename + surfacing. Coaching is a month-scoped tip generator (not `InsightEngine`, whose rules are real-time nudges). Relative strength converts bodyweight kg→lb to match pound-canonical set weights. Internal `DigestService` helper names (`fetchWrappedHistory`, `markWrappedViewed`, …) and the `monthly_wrapped` table keep their names; `MonthlyReportView`/`MonthlyComparisonView` kept as the full report.
- **Unreleased (post-build 11)** — Jul 2026 — **Progression rewrite: mode-split double progression.** Replaced `calculateTarget`'s unified e1RM-trend + confidence-gate model (which stalled the prescribed weight whenever the median rep count sat below the cap, and never credited exceeding the prescription) with two mode-specific state machines. **Hypertrophy** = strict double progression driven by actual reps vs the range — weight advances one increment only when every working set reaches the top (`minReps >= top`) or the hardest set had 3+ RIR (RPE early-bump); e1RM is no longer a decision input (unreliable at 10–15 reps). **Strength** = top-set double progression — bump when the top set hits 5, e1RM sizes the (floored) jump since it's valid at 3–5 reps. Targets are a **single rep goal**, not a range (`targetRepsLow == targetRepsHigh`; displays as one number that climbs toward the band top, e.g. "185 × 10"). Bodyweight path rewritten to the same single-target double progression with a below-floor guard (also fixes an inverted stored range on rep-drop deloads). Deload nets + Keep-Progressing path preserved. No schema change (`progression_log` shape unchanged; `estimated_1rm` unused for hypertrophy).
- **Unreleased (post-build 11)** — Jul 2026 — **v1 scope-down: removed social + gamification + streak.** Deleted the Social tab and its ~21 views, `SocialViewModel`, and 9 services (`SocialService`, `FeedService`, `ChallengeService`, `MatchmakingService`, `LiftPercentileService`, `PresenceService`, `TipsService`, `NudgeService`, `GamificationService`). Stripped all IQ/badge/feed/presence work from `completeWorkout`. Removed the **training streak** in its entirety (both the profile-daily and analytics-weekly systems), reweighted the consistency score to frequency 50% / volume-stability 30% / recency 20% (dropped `ConsistencyScore.streakScore`), and removed the streak-protection notification. `MonthlyWrappedView` was decoupled from `SocialViewModel` and kept as a standalone recap. Three tabs remain (Home / Progress / Profile). No schema changes — social/streak tables are left idle in the DB.
- **Unreleased (post-build 11)** — Jun 16 2026 — **Opt-in performance deloads.** Performance-based deloads (declining e1RM / consecutive bad sessions) are no longer applied silently at the next session. `calculateTarget` gained an `allowDeload` flag; `ActiveWorkoutViewModel` detects deload targets on `startWorkout` and surfaces a "Recovery Recommended" prompt (`ActiveWorkoutView.performanceDeloadBanner`) with **Take Deload** / **Keep Progressing**. Declining recomputes each flagged lift with `allowDeload: false` and rebuilds the pre-filled sets. Stateless (re-prompts each session while declining); the time-based proactive banner is suppressed while a performance prompt is showing.
- **1.5 (build 11)** — May 18 2026 — Social-feature surfacing pass (later removed in the v1 scope-down above). Also fixed the "Share my Wrapped" black-screen crash (`ImageRenderer` was producing a ~75-megapixel image on the main thread + SwiftUI `.sheet` raced the hidden status bar — now scale 1.0 with direct UIKit presentation off the active scene). Wrapped story hides the tab bar for full-screen immersion. Feed workout titles read narratively (feed since removed).
- **1.5 (build 10)** — May 2026 — Bumped to v1.5. Fixed Wrapped streak parse + bodyweight-exercise display. Fixed Wrapped month label off-by-one and archetype-slide buttons being blocked by tap zones. Progress tab overhaul: new sections, narrative copy, time-window picker. Replaced stacked target/last text with a per-set comparison rail. Progression-engine + UX fixes: bump weight at rep cap with flat e1RM (double-progression unstick), derive PRs from `workout_sets` not the `personal_records` cache, filter prior-session sets to working-only, fix inverted rep range when prior session exceeded rep cap.
- **1.4 (build 7)** — May 2026 — Interactive Lock Screen / Dynamic Island set logging via App Intents. Stepper buttons for weight/reps/RPE on the upcoming set + LOG SET commit button. GOAL and LAST context lines. Skip-rest button during rest periods. Minimize-bug fix (VM ownership moved from `MainTabView` `@State` to `WorkoutCoordinator`). Live Activity orphan cleanup at app launch + before every new activity request.
- **1.0 (build 3)** — April 2026 — First TestFlight build (mini-bar, basic Live Activity for workouts, workout logging fixes, Progress tab revamp, insights revamp).

---

## Useful commands

```bash
# Run the app on simulator
xcodebuild -project repIQ.xcodeproj -scheme repIQ \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# Verify widget builds standalone
xcodebuild -project repIQ.xcodeproj -scheme repIQActivity \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# Inspect version & signing
xcodebuild -project repIQ.xcodeproj -scheme repIQ \
  -showBuildSettings -configuration Release \
  | grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION|DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER"

# Archive for App Store distribution
xcodebuild -project repIQ.xcodeproj -scheme repIQ \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/repIQ.xcarchive archive

# Then: open Xcode Organizer → Distribute App → App Store Connect → Upload.
```

---

## Things that don't exist (yet) but are on the roadmap

- Apple Watch companion (hands-free logging, heart rate, mid-workout fatigue suggestions)
- StandBy mode view (full-screen rest timer + next-set preview when phone is on charger)
- Critical alerts for rest-end (breakthrough DND)
- Siri shortcuts donation ("Hey Siri, log 135 by 8") — App Intents already exist; just need shortcut donation + phrase polish
- Lock-screen circular rest-ring redesign
- **Re-introducing the social/gamification layer** (feed, friends, leagues, IQ, badges, clubs, streaks) in a post-v1 release — the DB tables and migrations are still in place; the client code was removed on branch `strip-social-v1`.

If you find yourself building one of these, check the existing intent infrastructure (`repIQ/Intents/`) and Live Activity setup before reinventing.

---

## When in doubt

- Read the actual code before assuming behavior — this file is a map, not the territory.
- For workout logic: start at `ActiveWorkoutViewModel`. It's huge but it's the source.
- For progression decisions: `ProgressionService.calculateTarget`. Read the whole function — it's worth it.
- For UI patterns: look at how an existing similar screen does it. The conventions are pretty consistent (RQCard wrappers, `@Observable` VMs, NavigationStack per tab).
- Check git log for context — commit messages are descriptive: `git log --oneline -20`.
