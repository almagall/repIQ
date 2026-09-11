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
| Current shipping version | `1.5 (build 13)` (Aug 2026) — first build carrying the hero-ring logger, the v1 scope-down, the progression rewrite, the Rep Sheet, and the target-adherence Progress tab |

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
 │   ├─ Workout/          ActiveWorkout, SetLogger (hero-ring logger), PR celebration, mini-bar, summary
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

`AnalyticsService` (history aggregates; much of it now unread since the Progress rebuild), `AuthService`, `DigestService` (Monthly Wrapped), `ExerciseLibraryService`, `ExportService`, `GoalService`, `GymService` (Profile "set your gym" — vestigial without gym leaderboards, kept for now), `InsightEngine`, `LiveActivityService`, `NetworkMonitor`, `NotificationService`, `OfflineSetQueue`, `ProfileService`, `ProgressionService`, `SetFeedbackEngine`, `TargetAdherenceService` (Progress tab — grades logged sets against stored targets), `TemplateService`, `WidgetService`, `WorkoutAutoSave`, `WorkoutService`, `WrappedArchetype` (Rep Sheet "style" card — internal name kept).

`TargetAdherenceService` grades **mode-aware**: hypertrophy counts every working set (they share one prescription), ramped strength counts only the top set (the ramp is meant to feel easy, and the engine judges the top set alone), straight-set strength counts every set. The set scheme isn't in `progression_log`, so straight sets are recognised by their *stored* targets all sharing one weight; reconstructed sessions (no stored targets) keep the top-set rule because they predate straight sets. Sessions logged before targets were persisted are **reconstructed at read time** from `progression_log` — each row is the prescription the *following* session was given, so the applicable one is the last recorded before that session started. That reconstruction is exact for everything actually graded; the only thing it can't reproduce is individual ramp-up weights, which were never graded.

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
  - `strength`: 3–5 reps, target RPE 8.0. Layout depends on the **set scheme** below.
- **Set scheme** — `workout_day_exercises.set_scheme` ∈ `{ramped, straight}` (Sep 2026, `20260910_set_scheme.sql`). Consulted **only for `strength`**; hypertrophy is always straight and ignores it. `ramped` (default): weight ascends from ~80% start pct to the top set, RPE ramps 6.0 → target, the top set alone is judged. `straight`: every set at the prescribed weight, the weakest set gates progression, every set is graded for adherence. Decoded leniently (`decodeIfPresent ?? .ramped`) so a client ahead of the migration still loads templates.
- **Progression target** — output of `ProgressionService.calculateTarget`: prescribed `targetWeight × targetReps @ targetRPE` for next session, plus a `decision` ∈ `{increaseWeight, increaseReps, maintain, deload, deloadVolume}` and English `reasoning`.
- **Mesocycle** — training block measured in `weeksSinceDeload`. RPE offset escalates: 0 weeks (offset 0), 3–4 weeks (+0.5), 5–6 weeks (+1.0), 7+ weeks (force deload).
- **Deload** — planned recovery week (~90% of current e1RM). Triggered proactively at 7+ weeks or reactively on declining e1RM / consecutive bad sessions.
- **PR (Personal Record)** — max ever lifted. Types: `weight`, `reps` (at a specific weight), `volume`, `estimated1rm`. Detected inline during set completion (instant celebration) and again post-session against DB.
- **Workout day** — a named day in a template (e.g. "Push A", "Pull B"). Same exercise on different days has **independent progression history** — see "Workout-day scoping" below.
- **Superset** — two+ exercises performed back-to-back with no rest between, then rest after the round. Configured at session-level (not in template), via `ExerciseLogEntry.supersetGroup: Int?`.
- **Pending set** — set logged offline, queued in `OfflineSetQueue` until network returns. Marked completed in UI immediately so workouts continue without interruption.
- **Goal target** vs **pending value** — on `SetEntry`: `targetWeight/targetReps/targetRPE` are immutable snapshots from `perSetTarget` at workout start; `weight/reps/rpe` are the live values that get adjusted (in-app inputs or Live Activity steppers) and ultimately saved. The snapshot is **also persisted** to `workout_sets.target_weight/target_reps/target_rpe` at log time — see "Target adherence" below.
- **Target adherence** — how often a lifter met the prescription. A set is **graded** only when it is a working set carrying a stored target (`WorkoutSet.isGraded`); it is a **hit** when `weight >= target_weight && reps >= target_reps` (`WorkoutSet.hitTarget`). Deliberately binary — there is no "one rep short" state. Lifting *lighter* than prescribed is a miss regardless of reps, otherwise dropping the weight and repping out would outscore doing what was asked. Targets are stored only when the engine actually prescribed one, so warm-ups, cool-downs, drop/failure sets, extra sets beyond the prescription, and the first session of a brand-new exercise all persist NULL and are excluded from adherence rather than counted as misses.
- **Rep Sheet** — a per-month recap generated by `DigestService` and rendered as a swipeable industrial spec-card **deck** (`RepSheetDeckView`, single accent blue, tap-zones + drag, depleting/restacking stack, exit-any-time). `DigestService.generateRepSheet` builds a display-ready deck at generation time — each card gated on data sufficiency, then notability-ranked (cover first, always-on next-month coaching last, ≤10 total) — and persists it to the previously-unused `monthly_wrapped.data` JSONB column (`RepSheetContent`). Self-contained retention feature, no friends required; surfaces via a Dashboard banner and a Progress-tab CTA/badge. (Formerly "Monthly Wrapped"; renamed to shed the Spotify association. Internal `DigestService` helper names and the `monthly_wrapped` table keep the old names.)

---

## Persistence model — three layers

Critical to keep in your head when touching anything that writes data.

### Layer 1: Supabase remote (primary source of truth)

- Completed sets, sessions, profile, goals, PRs, monthly wrapped.
- Tables of note (still live): `workout_sessions`, `workout_sets`, `exercises`, `templates`, `workout_days`, `workout_day_exercises`, `profiles`, `personal_records`, `goals`, and the monthly-digest tables.
- `workout_sets` carries the **per-set target snapshot** (`target_weight`, `target_reps`, `target_rpe`, added Aug 2026 in `20260823_set_targets.sql`). Nullable, written only for working sets the engine prescribed. Rows logged before that migration are NULL — `progression_log` can reconstruct hypertrophy straight sets and strength top sets for older sessions, but **not** individual ramp-up weights, which only ever existed on `SetEntry`.
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

`repIQ/Services/ProgressionService.swift::calculateTarget(...)` decides what to prescribe next session. Read this whole file before changing anything in it. `calculateTarget` dispatches by training mode to `hypertrophyTarget` / `strengthTarget` / `straightStrengthTarget` (strength picks by `setScheme`; bodyweight → `calculateBodyweightTarget`). **All paths are double progression**; they differ in what drives the weight bump. e1RM is intentionally *not* a decision input for hypertrophy — the Epley/Brzycki estimate is unreliable in the 10–15 rep band, so hypertrophy follows actual reps against the range instead. (This replaced the old unified e1RM-trend + confidence-gate model, which stalled weight whenever the *median* rep count sat below the cap and never credited beating the prescription.)

Both mode functions share the same preamble ordering: **deload safety nets → baseline (<2 sessions) → single off-day → progression state machine.**

**The prescription is a single rep goal, not a range.** `targetRepsLow == targetRepsHigh` always (so `targetRepRangeDisplay` renders one number, e.g. "185 × 10"). The rep *band* (10–15 etc.) still lives on `TrainingMode.repRange` and drives the weight-bump trigger and reset; the target is just the one number to hit this session, which climbs week to week toward the top of the band.

**Legacy `progression_log` rows are normalized at read, not migrated.** Rows written before the rewrite still carry a rep *spread* and reasoning prose from the old e1RM-trend model. `ActiveWorkoutViewModel.clampedTarget` treats `low != high` as the legacy marker (the current engine writes `low == high` at all three construction sites), collapses the spread to `low`, and clears the stored reasoning rather than attributing the removed model's explanation to the live engine. The stored *decision and weight* are left alone — they're what the old engine prescribed, and recomputing every exercise at workout start would put N extra queries on the critical path for something that self-heals after one logged session.

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

### Strength, straight sets — linear progression with rep rebuild (in order)

`setScheme == .straight`. Reference = the whole set like hypertrophy (`minReps`, median `workingWeight`), because every set shares one weight. Range 3–5. Preamble 1–4 identical to hypertrophy (deload weight is `workingWeight × 0.90`, not e1RM-derived). Then:

5. **`minReps >= top`** → **`.increaseWeight`** by **one increment**, target reps **stay at `top`**.
6. **`minReps < bottom`** → `.maintain`, target reps = `bottom`.
7. **RPE early-bump:** hardest set `<= targetRPE − 2` → `.increaseWeight` one increment, reps at `top`.
8. **else** → `.increaseReps`, `min(minReps + 1, top)` — reads as "repeat this weight until you get every rep".

Two deliberate departures from ramped strength, both because five straight sets at a new load is a much larger step than one top set: the bump is one increment rather than e1RM-sized, and reps don't reset to the bottom (a 5×5 dropping to 5×3 for a 2% load change wastes two sessions). This is what makes "add weight every session you get all your reps" programs (Starting Strength, StrongLifts, Reddit PPL) honest in the engine.

`calculateTarget` takes `allowDeload: Bool = true`. When `false`, both deload nets are suppressed and flow into the normal state machine (a declining lifter gets `.maintain`/`.increaseReps` instead of a deload). This backs the "Keep Progressing" choice on the deload prompt (see below). Weight always advances by exactly one increment (hypertrophy) or an e1RM-sized-but-floored jump (strength) — never proportional to overshoot; beating the top of the range just earns the bump sooner.

### Deload is a choice, not silent (performance deloads)

Performance-based deloads (`.deload` / `.deloadVolume`) are computed at the *end* of the triggering session and stored in `progression_log`, but they are **not applied silently**. At the start of the next session, `ActiveWorkoutViewModel.startWorkout` scans the loaded targets; if any is a deload it sets `pendingDeload` and `ActiveWorkoutView.performanceDeloadBanner` prompts the user (whole-session, two required buttons, no dismiss):
- **Take Deload** (`takeDeload()`) → keep the loaded ~90% targets.
- **Keep Progressing** (`keepProgressing()`) → re-fetch each flagged exercise's last 3 sessions, recompute with `allowDeload: false`, and rebuild the not-yet-completed pre-filled sets + their GOAL snapshots.

Stateless by design: the decision is recomputed from actual sets every completion, so a still-declining user is re-prompted next session (no remembered choice). This is separate from the **time-based** proactive deload (`shouldSuggestDeload` → `deloadSuggestionBanner`, opt-in); the time-based banner is suppressed when a `pendingDeload` is already showing so the user never sees two deload prompts at once. Note: `weeksSinceDeload` is not passed at the completion call site, so the engine's "7+ weeks → force deload" ceiling is currently dead in this path — the 7-week case is handled entirely by the time-based suggestion.

### Per-set target computation

`ActiveWorkoutViewModel.perSetTarget(decision:previousSet:trainingMode:setScheme:setPosition:totalSets:equipment:)` maps the prescribed `(targetWeight, single targetReps, RPE)` to *each* set:

- **Hypertrophy:** every working set gets `targetWeight × targetRepsLow` (the single session rep goal — same number on every set). RPE = `base + 0.5 × setIndex` (climbs with fatigue).
- **Strength, straight:** same as hypertrophy — one weight, one rep goal, climbing RPE.
- **Strength, ramped:** weight ramps from `targetWeight × startPct` (startPct depends on totalSets) up to full targetWeight on the top set; reps stay at `targetRepsLow`; RPE ramps linearly from 6.0 to `targetRPE + mesocycleOffset`.
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
- **Progression ring** (`ProgressionHeroCard(style: .ring)`) — same verdict the Progress tab leads with, above the CTA so "am I progressing?" is answered before "train now". Hidden while `verdict.isBaseline`. `DashboardViewModel` fetches it with the same `fetchProgressionRate` call, so the two screens cannot disagree. Sized deliberately: a larger ring pushed Start Workout behind the tab bar.
- **Quick Start** — hero CTA. Triggers template picker → `WorkoutDayPickerView` → `coordinator.startWorkout(template:day:date:)`.
- **My Templates** — list of user templates. Tap → `WorkoutDayPickerView`.
- **Workout History** — link to `WorkoutHistoryView`.
- **Activity** — week strip (binary trained/didn't) or month calendar.
- **Goals** — up to 3 active goals with progress bars; link to `GoalSettingView`.

(The old "Social Pulse" card was removed.)

### Progress (`repIQ/Views/Progress/ProgressTabView.swift`)

Rebuilt Aug 2026 around **target adherence**. The tab answers one question — are your targets going up, and are you hitting them — and then stops. Order, top to bottom:

- **Targets hero** (`TargetsHeroCard`) — "N/M targets going up **next session**", plus a stacked bar of the four engine decisions (more weight / more reps / same target / eased back) and a coaching line. Reports *progression*, not adherence: adherence is the section underneath, and a hero summarising its own rows is a subtotal, not a headline.
- **Rep Sheet banner** (only while last month's sheet is unread)
- **Focus card** (`TargetFocusCard`) — the single lift worth acting on, capped at one and omitted entirely when nothing is wrong. Deep-links straight to the exercise, skipping the day.
- **Targets by day** (`DayTargetsPanel`) — one panel, one row per workout day, sorted worst-first. Days expand *in place* to reveal their lifts; the workout day is a real unit (it owns the targets and the progression history) but not a destination, so there's no third navigation level.
- **Rep Sheet link** (once the sheet is no longer news)

Driven by `TargetsOverviewViewModel`, which owns four presentation states — `firstRun`, `baseline`, `active`, `paused` — so the hero always shows *some* honest number rather than a spinner or a stale percentage. The exercise drill-in is still `ExerciseProgressView` (via `ExerciseProgressLoaderView`).

**Two measurements, deliberately not derived from each other.** Adherence ("did you do what was asked") comes from logged sets vs stored targets; progression ("is the next target higher") comes from `progression_log`. They come apart constantly — a soft prescription yields high adherence and no progress — which is the whole insight the tab is built on.

**They must count the same lifts, though.** `AdherenceRules.windowDays` (28) and `AdherenceRules.minSessions` (3) are shared by `fetchProgressionRate` and the day rows. When they drifted (56-day hero vs ungated 28-day rows) the day rows summed to 22 against a headline of 20. `DayAdherence.trackedExercises` applies the gate; the progression line is hidden entirely when no lift on a day qualifies.

**Percentages always show their fraction.** "71%" is unreadable alone; "52 of 72 sets hit" defines the number and the bar together. Day and report ratios are literally `hits ÷ graded` so the printed fraction can never disagree with the percentage — which is why the rollup is a raw set count rather than a mean of per-lift means.

**Removed in the rebuild** (they described what happened rather than what to do, and each competed with the answer above): last-workout recap, training-days heatmap, recent-PR list and the all-PRs screen, monthly stats, lifetime totals, vs-past-you, volume trend and its week sheet, muscle-balance body diagram, strength-trajectory card, the lift-compare screen, the exercise picker, and the time-window picker. Eleven view files deleted. Long-range history lives in the monthly Rep Sheet. `ProgressDashboardViewModel` survives only because `WorkoutHistoryView` and `SessionDetailView` still use it — it is no longer wired to this tab, and much of what `loadDashboard` fetches now has no reader.

**The hero metric is progression rate, not an e1RM trend.** `AnalyticsService.fetchProgressionRate` reads `progression_log`, scoped by exercise *and* workout day, and counts how many regularly-trained exercises (3+ logged sessions — one row is written per exercise per completed session, so the row count is the session count) had a latest decision of `increaseWeight` or `increaseReps`. e1RM was rejected as the headline because it is meaningless for bodyweight work and unreliable in the 10–15 rep band — the same reason `ProgressionService` doesn't feed it into hypertrophy decisions. e1RM still drives the per-lift trajectory rows, where the reps are low enough for it to hold.

**Muscle balance is measured in sets per week, not volume.** Absolute load differs between muscle groups for physiological reasons, so a volume share painted legs and back as dominant and arms as neglected for every user regardless of programming. `MuscleGroupVolume.setCount` is a `Double` because synergists earn half a set on compound lifts.

**Layout is a flow, not stacked cards.** The hero is the only bordered element; everything else is separated by whitespace and hairline rules. `RQCard` takes `bordered: Bool = true` — the Progress components pass `false`. This is currently piloted on Progress only, so the tab deliberately looks different from Home and Profile.

**No coloured left accent bars anywhere on this tab.** They read as generated-UI boilerplate; state is signalled by a hairline rule plus a coloured uppercase label instead. Colour marks data (a number, a percentage, a status word), never a container.

**Removed from this tab** (see Recent ships for reasoning): MEV/MAV/MRV volume landmarks, effective reps, the push:pull ratio strip, and the 0–100 consistency score with its letter grade. `AnalyticsService.fetchVolumeLandmarkData`, `fetchEffectiveRepsSummary`, `fetchPushPullBalance` and `fetchConsistencyScore` were deleted along with their model types.

### Profile (`repIQ/Views/Profile/ProfileView.swift`)

Avatar / username / gym info, then Settings (weight unit, rest timer, body & health, notifications, privacy, gym, account) and Sign Out. (The "My Stats" league/IQ/streak card was removed.) Notification settings offer workout reminders + monthly-wrapped reminders (the streak-protection reminder was removed).

### Templates (`repIQ/Views/Templates/`)

`TemplateListView` → `TemplateDetailView` → `TemplateEditorView` (name + days) → `WorkoutDayEditorView` (exercises + training mode + set scheme (strength only) + targetSets + repCap + supersetGroup) → `ExercisePickerView`. Pre-built programs in `ProgramBrowserView` → `ProgramDetailView` (one-tap create-template).

**Programs are a template generator, nothing more.** `ProgramCatalog` (`repIQ/Data/Programs/`) holds hard-coded `ProgramDefinition`s; `ProgramBrowserViewModel.materializeProgram` resolves exercise names to ids and writes ordinary `templates` / `workout_days` / `workout_day_exercises` rows (mode, set scheme, sets, rep cap, rest override, notes). After that a program template is indistinguishable from a custom one — same editor, same engine, same logger. `templates.source_program` is written and never read. There is no training-max / percentage / week-cycle layer; a program whose identity *is* such a scheme (5/3/1, nSuns, Texas Method, Conjugate) cannot be expressed honestly and should not be in the catalog.

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
6. User logs sets via `SetLoggerView` — the hero-ring logger, one exercise per screen:
   - A pinned **hero ring** (one arc segment per working set, filled in accent as sets complete; warmups never earn a segment) shows the live set's weight × reps at its center; between sets the same ring becomes the rest countdown (green inner arc, `restTimerProgress`).
   - The prescription is **prefilled into the pending set**, so an as-planned set is one tap on the Log button, which states what it commits: `Log 150 × 12 @8`. Below the ring: Target/Last card (hypertrophy targets deliberately omit the prescribed RPE — rep-driven engine; strength keeps it), WEIGHT block (coarse/fine steppers around the `PlateBreakdownView` bar for barbell/smith), slim REPS row, RPE chip row (whole numbers 1–10, heat-tinted, **never prefilled** — a target-seeded default would feed fabricated effort into the engine), then the ledger: every set with per-set positional verdicts (PR / ▲ BEAT / MATCH / ▼ MISS vs the same position last session), NOW highlight, add warmup/working/drop/failure rows.
   - Logging → `viewModel.completeSet(exerciseIndex:setIndex:)` → auto-save to Supabase (or `OfflineSetQueue`), inline PR detection → `prCelebration` overlay, superset-aware rest, post-set `SetFeedbackEngine` coaching rendered as a COACH card during rest.
   - Superset members page between each other: the logger auto-advances to the partner after each log (gold "then → partner · NO REST" strip), and rest runs only between rounds.
   - Tap the ring's weight/reps (or any value) to type exact numbers; steppers cover nudges.
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
- **Backgrounds — the "Tide" ramp** (Aug 2026): `background` (#080C11), `surfacePrimary` (#0E161E), `surfaceSecondary` (#12202C), `surfaceTertiary` (#1A2A38). Neutrals pulled toward the accent's hue as **flat tints, never gradients**. The four values sit in a narrow lightness band on purpose — depth comes from small consistent steps plus a shadow, and wide jumps between surfaces look cheap.
- **Structure**: `hairline` (#16232F) — the 1px rules. Not part of the text ramp; a border is not disabled text. `edgeHighlight` is the tinted inset highlight along a raised sheet's upper lip.
- **Text**: `textPrimary` (white), `textSecondary` (#8FA5BA), `textTertiary` (#5E7488) — same hue bias as the surfaces.

**No gradients on surfaces, and no corner glows.** A coloured radial bloom bleeding from a dark card's corner is the most recognisable generated-UI signature going; it was in early drafts of this tab and was cut. Depth is edge, value and shadow only.
- **Progression state**: `stateAdvancing` (#2FD48A), `stateHolding` (#E0A93B), `stateBacking` (#FF5C5C). Backs `StrengthTrend.color`, which is the app's shared trend vocabulary. Deliberately *not* the semantic set — a deload is a plan, not an error; holding a weight to bank reps is not a warning.
- **Semantic**: `success` (green), `warning` (gold), `error` (red), `info` (light blue) — reserved for actual confirmations, alerts and failures.
- **Training modes**: `hypertrophy` (purple), `strength` (orange)
- **Set types**: `warmup`, `working` (green), `cooldown`, `dropSet`, `failure` (red)
- **Muscle groups**: 11 unique colors (chest, back, shoulders, biceps, triceps, etc.)

### Spacing (`RQSpacing`)

`xxs=2, xs=4, sm=6, md=10, lg=14, xl=20, xxl=28, xxxl=40`. Conventions: `cardPadding=16`, `cardSpacing=10`, `screenHorizontal=16`.

### Radius (`RQRadius`)

Two scales, on purpose, so screens migrate one at a time rather than every corner changing at once.

- **Sharp (original)**: `small=2, medium=4, large=6, extraLarge=12`. Still used by the logger, Home, Profile and Templates.
- **Sheet (Tide)**: `sheet=18, sheetInner=11, control=9, pill=999`. Used by the Progress tab. `sheetInner` is deliberately `sheet − padding`: a nested element inside a padded card needs a smaller radius or the two curves fight, which is the most common tell of a layout nobody measured.

Raised surfaces go through **`.rqSheet(fill:radius:elevated:)`**, which supplies the fill, the clip, the inset top edge and a **two-layer shadow** — a 1px contact shadow plus a wide soft one. A single blurred shadow reads as a stock component; the pair reads as an object resting on a surface.

**Home, Profile, Templates and the logger have not been restyled yet.** Colours are app-wide so they picked up Tide automatically, but geometry and typography have not — those passes are still outstanding.

### Typography (`RQTypography`)

- **Titles** are monospaced (industrial feel): `largeTitle, title1, title2, title3`.
- **Body** is proportional: `headline, body, callout, subheadline, footnote, caption`.
- **Numbers** are monospaced: `numbers, numbersSmall`.
- **Special**: `poster` (76pt heavy mono — currently unused; the set prescription moved into the logger's hero ring), `hero` (52pt heavy mono — the progression answer, one per screen), `targetWeight` (44pt heavy mono — big countdown/prescription numbers), `label` (10pt mono uppercase — section headers).
- **Labels need tracking.** SwiftUI `Font` can't carry it, so `label` travels with `labelTracking` (2pt = 0.2em). Use the **`.rqLabel()`** view modifier rather than pairing them by hand — the manual `.font(RQTypography.label).tracking(1.5)` pattern had already drifted across call sites.
- **Tide ramp** (Progress tab): `figureXL/L/M`, `sheetTitle`, `sheetBody`, `sheetCaption`, `sheetLabel`. Proportional, not monospaced — the sheet layout leans on weight and size contrast rather than the technical voice the sharp screens use, and mixing the two ramps on one screen is what made early drafts feel assembled. Use **`.rqFigure(_:)`** for display numerals (tight tracking + tabular digits, so figures don't shimmer on refresh) and **`.rqSheetLabel()`** for section headers.

### Components (`repIQ/Views/Components/`)

| Component | Use for |
|---|---|
| `RQCard` | Bordered card container. Pass content via view builder. `bordered: false` drops the border and inset for the flow layout. |
| `RQStatRow` | 2–4 figures split by vertical hairlines: value over a tracked label, optional delta. `prominence` picks the value size (`.section` for lifetime/monthly totals, `.inline` inside a card that already has a headline). Reserves the delta line across the row so labels share a baseline when only some tiles have one. |
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

The following were stripped to focus the first release on core tracking. The client code was deleted; the Supabase tables/migrations remain but are idle. Bringing any of these back is a future-release effort — check `main`'s git history (the v1 scope-down commits) for the removal diffs.

- **Social tab** and everything under it: feed, friends, friend profiles, gym hub, leagues, promotion race, challenges, achievements, badges, clubs, matchmaking, social profile, add-friends, weekly digest.
- **Gamification:** IQ points, badges, league tiers, milestone/achievement catalogs (the `MilestoneCatalog`/`AchievementCatalog` data files still exist but are not rendered anywhere).
- **Lift percentiles** (exercise drill-in) and **community tips**.
- **Training-now presence** (`user_presence`).
- **Shareable templates** (`is_shared` toggle + clone).
- **Training streak — entirely.** Both the profile-based daily streak (workout-summary "Day Streak", share-card streak line, home-widget streak) and the analytics weekly streak (Progress-tab "WEEK STREAK" flame, consistency-score streak factor, streak-based smart insights, streak-protection notification). The Rep Sheet's consistency card surfaces trained-days / rest-days / best-week (not a streak); `DigestService` still computes the `longest_streak` scalar but the deck no longer renders it.

**Kept:** the full logging loop, progression engine + deload prompts, Progress analytics (minus streak/percentiles), goals, history, templates + pre-built programs, Live Activity / Dynamic Island, Rep Sheet (monthly recap), offline queue, crash-recovery autosave, export, workout/Rep-Sheet reminders.

---

## Recent ships

- **Unreleased (post-build 13)** — Sep 10 2026 — **Straight-set strength, and programs that persist what they define.** Pre-built programs were a template generator that silently dropped their own `restSecondsOverride` and `notes` on materialization (columns existed since the initial schema; `addExerciseToDay` never wrote them), and carried a dead `progressionType` + orphan `ProgramEngine` protocol implying a TM/percentage layer that doesn't exist. Both fixed/removed; notes now render as a NOTE line in the logger, and programs can set `repCap`. The real engine gap was that `.strength` *always* ramped, turning every 5×5 / 3×5 program into a one-heavy-set pyramid with an e1RM-sized 5→3 reset. New **`set_scheme`** on `workout_day_exercises` (`20260910_set_scheme.sql`, default `ramped`): `straight` gives every set the prescribed weight, progression is gated by the weakest set, a bump is one increment with reps held at the top (linear progression with rep rebuild on a miss), and adherence grades every set. Editor exposes Ramped/Straight for strength exercises. Recovery snapshots now carry `setScheme` + `repCap` so a recovered workout logs the same decision a normal one would; `takeDeload`'s rebuild now passes `totalSets` (it was defaulting to 4, so a 3-set ramp never reached full weight). Catalog retagging (step 3: cut 5/3/1-family/Texas/Conjugate, mark novice programs straight, retag GZCL T2) is **not yet done**.
- **Unreleased (post-build 11)** — Aug 23 2026 — **Progress tab rebuilt on target adherence, and the "Tide" theme.** repIQ prescribes a weight and rep goal for every working set and never told anyone how often they met it — the one thing no competitor can compute, because no competitor prescribes. Now: per-set targets persist to `workout_sets` (`20260823_set_targets.sql`, three nullable columns), `TargetAdherenceService` grades them **binary** (hit = met or beat *both* weight and reps; lifting lighter never counts) and **mode-aware** (every set for hypertrophy, top set only for strength), and history back-fills at read time from `progression_log` so the feature works on day one instead of after weeks of new logging. The tab now leads with **targets going up next session** and breaks adherence down **by workout day**, expanding in place. Eleven view files removed — recap, heatmap, PR list, monthly/lifetime stats, vs-past-you, volume trend, muscle diagram, trajectory card, compare screen, exercise picker, window picker — because they described what happened rather than what to do. Visually this introduced **Tide**: flat accent-tinted neutrals, no surface gradients and no corner glows, an 18/11 nested-radius sheet system with two-layer shadows, and a proportional type ramp separate from the monospaced one. One bug caught in review before commit: the hero used a 56-day window while the day rows used an ungated 28, so the rows summed to 22 against a headline of 20 — both now share `AdherenceRules`.
- **Unreleased (post-build 11)** — Aug 2026 — **Workout logger redesign: hero-ring set logger.** Replaced the form-style logger (`ExerciseLogView` + `SetRowView` + `SetContextStrip` + `SetFeedbackChipView` + full-screen `RestTimerView` — all deleted) with `SetLoggerView`: one exercise per screen, a pinned segmented **hero ring** (arc per working set, center shows the live set's weight × reps, becomes the rest countdown between sets — no timer overlay), Target/Last comparison card, coarse/fine weight steppers around the plate diagram, slim reps row, whole-number 1–10 RPE chips (never prefilled — fabricated effort would feed the engine), a Log button that states its values (`Log 150 × 12 @8`), and a per-set ledger with positional PR/BEAT/MATCH/MISS verdicts. Warmups: never prefilled (unchanged constraint), no ring segment, no RPE row, gold-outline log button; cold-start suggestion became a COACH-style card that inserts *empty* warmup sets. `SetFeedbackEngine` output now renders as a COACH card during rest. Supersets page member→member with auto-advance and a gold NO REST strip; rest runs between rounds. Also normalized **logged RPE to whole numbers** at every entry point (picker, fill-from-target, Live Activity stepper seed, Siri voice logging) — prescribed RPE keeps its half-step ramps.
- **Unreleased (post-build 11)** — Jul 2026 — **Progress tab: progression-rate hero, honesty audit, flow layout.** Replaced the tab's implicit "read the charts yourself" framing with a **hero that answers "am I progressing?" in one number** — `N/M exercises moving up`, from `AnalyticsService.fetchProgressionRate` over `progression_log`. Chosen over an e1RM trend because e1RM is meaningless for bodyweight and unreliable at 10–15 reps, so the metric now covers every exercise the app can log. A **forward-looking coaching line** sits under it, preferring an insight that names a tracked lift (`InsightEngine` gained a positive "Room to push" rule for when nothing is wrong) — this is the gap Strong and Hevy leave open, and the one place repIQ's autoregulation engine shows up on the Progress tab. Then an **audit of every visual for honesty**, cutting four: **MEV/MAV/MRV landmarks** (per-individual estimates presented as precise thresholds, and our counting gave synergists no set credit so pressing showed triceps "below MEV"), **effective reps** (`effectiveReps` assumes RPE 8 when unlogged, and RPE is optional — so non-RPE users saw `3 × setCount` dressed as analysis), the **push:pull strip** (redundant beside the muscle diagram), and the **0–100 consistency score** (its weights penalised 3-day programs, periodised volume variation, and deload weeks — telling well-programmed lifters they were inconsistent; the heatmap stayed). Muscle balance switched from **volume to sets per week**; `StrengthPrediction.isReliable` raised R² 0.3 → 0.5; vs-past-you now ranks candidates on the three-month window it actually displays; trajectory velocity now derives from the same four-week delta the row shows, so the words can't contradict the number. Visually, a **flow layout** (hero is the only bordered element, `RQCard` gained `bordered:`) with **no coloured left accent bars**, piloted on Progress only. Net ~-580 lines.
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
- **Re-introducing the social/gamification layer** (feed, friends, leagues, IQ, badges, clubs, streaks) in a post-v1 release — the DB tables and migrations are still in place; the client code was removed in the v1 scope-down commits (now on `main`).

If you find yourself building one of these, check the existing intent infrastructure (`repIQ/Intents/`) and Live Activity setup before reinventing.

---

## When in doubt

- Read the actual code before assuming behavior — this file is a map, not the territory.
- For workout logic: start at `ActiveWorkoutViewModel`. It's huge but it's the source.
- For progression decisions: `ProgressionService.calculateTarget`. Read the whole function — it's worth it.
- For UI patterns: look at how an existing similar screen does it. The conventions are pretty consistent (RQCard wrappers, `@Observable` VMs, NavigationStack per tab).
- Check git log for context — commit messages are descriptive: `git log --oneline -20`.
