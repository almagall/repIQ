# repIQ

A best-in-class iOS workout-logging app — SwiftUI, iOS 17+, Supabase backend. Goal: disrupt the workout-app category with intelligent autoregulation, friction-free logging (Lock Screen + Dynamic Island), and a social loop that rewards consistency.

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
| Current shipping version | `1.5 (build 11)` (May 2026) |

---

## Top-level architecture

```
RootView (AppState)
 ├─ AuthView                        if !isAuthenticated
 ├─ OnboardingView                  if needsOnboarding
 └─ MainTabView                     authenticated + onboarded
     ├─ Tab 0  DashboardView        (Home)
     ├─ Tab 1  ProgressTabView      (Progress)
     ├─ Tab 2  SocialTabView        (Social)
     └─ Tab 3  ProfileView          (Profile)

WorkoutCoordinator (hoisted to RootView, env-injected)
 ├─ owns ActiveWorkoutViewModel
 ├─ presentation: .hidden | .minimized | .expanded
 ├─ static current: weak ref so App Intents can reach the running VM
 └─ drives the fullScreenCover binding in MainTabView for the workout overlay
```

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
 ├─ Config/               Supabase client config, AppConstants, AppStorage keys
 ├─ Design/               Theme.swift (RQColors, RQSpacing, RQRadius), Typography.swift
 ├─ Models/               Domain types (Codable structs, enums)
 ├─ Services/             Supabase calls + local services (one class per file)
 ├─ ViewModels/           @Observable VMs; ActiveWorkoutViewModel is the giant
 ├─ Views/
 │   ├─ App/              Tab + root
 │   ├─ Auth/, Onboarding/
 │   ├─ Dashboard/        Home tab
 │   ├─ Progress/         Progress tab
 │   ├─ Social/           Social tab (Feed / Friends / Gym Hub)
 │   ├─ Profile/          Profile tab
 │   ├─ Templates/        Template + WorkoutDay editing
 │   ├─ Workout/          ActiveWorkout, SetRow, RestTimer, PR celebration, mini-bar
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

Xcode 16's **filesystem-synchronized groups** are used for the main `repIQ` target — any file added under `repIQ/` is auto-included. The widget target uses traditional explicit references; new files for the widget target must be added to `project.pbxproj` manually (see how `WorkoutIntentBridge.swift` etc. are referenced from `../repIQ/Intents/`).

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

---

## Persistence model — three layers

Critical to keep in your head when touching anything that writes data.

### Layer 1: Supabase remote (primary source of truth)

- All completed sets, sessions, profile, goals, feed, friendships, badges, IQ ledger.
- Tables of note: `workout_sessions`, `workout_sets`, `exercises`, `templates`, `workout_days`, `workout_day_exercises`, `profiles`, `personal_records`, `iq_points_ledger`, `user_badges`, `feed_items`, `feed_reactions`, `feed_comments`, `friendships`, `goals`.
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

`repIQ/Services/ProgressionService.swift::calculateTarget(...)` decides what to prescribe next session. Read this whole file before changing anything in it.

### Decision tree (in order)

1. **<2 sessions of history** → `.maintain` (establish baseline).
2. **`weeksSinceDeload >= 7`** → force `.deload` (90% e1RM). Proactive recovery ceiling.
3. **2+ consecutive sessions with >10% weight drop** → `.deload`. Real fatigue, not a bad day.
4. **e1RM stable but RPE rising** → `.maintain`. Hidden fatigue signal.
5. **Single off-day** (this session's weight < 90% of recent best) → `.maintain` at proven capacity.
6. **e1RM trending up** (≥+2%):
   - High e1RM confidence (reps 1–5) → `.increaseWeight` (trust the extrapolation)
   - Low confidence (reps >10) → `.increaseReps` if not at top of range, else `.increaseWeight`
7. **e1RM flat** (>-2% to <+2%) → `.increaseReps` at same weight (drive adaptation via reps).
8. **e1RM declining** (<-2%) → `.deload`.

`calculateTarget` takes `allowDeload: Bool = true`. When `false`, every deload branch (2, 3, 8) is suppressed and routed into normal progression instead — declining e1RM falls through into the flat-e1RM double-progression logic. This backs the "Keep Progressing" choice on the deload prompt (see below).

### Deload is a choice, not silent (performance deloads)

Performance-based deloads (`.deload` / `.deloadVolume`) are computed at the *end* of the triggering session and stored in `progression_log`, but they are **not applied silently**. At the start of the next session, `ActiveWorkoutViewModel.startWorkout` scans the loaded targets; if any is a deload it sets `pendingDeload` and `ActiveWorkoutView.performanceDeloadBanner` prompts the user (whole-session, two required buttons, no dismiss):
- **Take Deload** (`takeDeload()`) → keep the loaded ~90% targets.
- **Keep Progressing** (`keepProgressing()`) → re-fetch each flagged exercise's last 3 sessions, recompute with `allowDeload: false`, and rebuild the not-yet-completed pre-filled sets + their GOAL snapshots.

Stateless by design: the decision is recomputed from actual sets every completion, so a still-declining user is re-prompted next session (no remembered choice). This is separate from the **time-based** proactive deload (`shouldSuggestDeload` → `deloadSuggestionBanner`, opt-in); the time-based banner is suppressed when a `pendingDeload` is already showing so the user never sees two deload prompts at once. Note: `weeksSinceDeload` is not passed at the completion call site, so the engine's "7+ weeks → force deload" ceiling is currently dead in this path — the 7-week case is handled entirely by the time-based suggestion.

### Per-set target computation

`ActiveWorkoutViewModel.perSetTarget(decision:previousSet:trainingMode:setPosition:totalSets:equipment:)` (~line 256) maps the prescribed `(targetWeight, repsLow..repsHigh, RPE)` to *each* set:

- **Hypertrophy:** every working set gets `(targetWeight, targetRepsLow, RPE = base + 0.5 × setIndex)`. RPE climbs as fatigue accumulates.
- **Strength:** weight ramps from `targetWeight × startPct` (startPct depends on totalSets) up to full targetWeight on the top set; reps stay at `targetRepsLow`; RPE ramps linearly from 6.0 to `targetRPE + mesocycleOffset`.
- Weight is rounded down to the equipment increment via `ProgressionService.weightIncrement(for:)` and `roundToIncrement`.
- Bodyweight exercises skip e1RM logic entirely; rep-only progression.

### Mesocycle RPE offset

`ProgressionService.mesocycleRPEOffset(weeksSinceDeload:)`:
- Weeks 0–2: offset 0 (base effort)
- Weeks 3–4: offset +0.5 (push harder)
- Weeks 5–6: offset +1.0 (peak intensity)
- Weeks 7+: should deload

Effective target RPE caps at 9.5 (`ProgressionTarget.effectiveTargetRPE`).

### PR detection

- **Inline** (during the workout): runs in `ActiveWorkoutViewModel.completeSet` (~lines 1208–1319). Detects weight PRs (heaviest ever) and rep PRs (most reps at this exact weight). Triggers `prCelebration` modal + heavy haptic.
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
- **Wrapped banner** — appears 1st–14th of each month if prior month's wrapped is ready & unviewed (`WrappedBannerCard`).
- **Quick Start** — hero CTA. Triggers template picker → `WorkoutDayPickerView` → `coordinator.startWorkout(template:day:date:)`.
- **My Templates** — list of user templates. Tap → `WorkoutDayPickerView`.
- **Workout History** — link to `WorkoutHistoryView`.
- **Activity** — week strip (binary trained/didn't) or month calendar.
- **Social Pulse** — league tier + IQ snippet and latest friend's activity. Tap to push into Leagues / social profile. Shown once `socialViewModel.currentUserId` resolves. Pushes via a `SocialDestination` enum + local `navigationDestination(for:)` that mirrors `SocialTabView`'s wiring.
- **Goals** — up to 3 active goals with progress bars; link to `GoalSettingView`.

### Progress (`repIQ/Views/Progress/ProgressTabView.swift`)

- Monthly stats header
- Last-workout recap
- **Strength trajectory** chart (top lifts, scoped by workout day)
- Streak + consistency heatmap (12-week daily binary)
- Smart insights (prescriptive coaching)
- Volume trend (4-week baseline)
- Muscle balance body diagram (uses `MuscleMap` Swift package)
- Recent PRs
- Monthly Wrapped CTA (if ≥3 sessions this month)

Driven by `ProgressDashboardViewModel` (~13KB). Sub-views `MonthlyStatsHeader`, `LastWorkoutRecapCard`, `StrengthTrajectoryCard`, `ConsistencyHeatmap`, `MuscleBalanceBodyView`.

### Social (`repIQ/Views/Social/SocialTabView.swift`)

3-section picker: **Feed** | **Friends** | **Gym Hub**.

- **Feed** — workout completions, PRs, milestones from friends. Fist-bump reactions + comment threads. Workout cards render narrative titles ("Crushed Pull — 4 PRs", "Marathon Push — 25 sets") via `FeedView.workoutNarrative(_:)`. Zero-duration cards drop the duration pill. `FeedView.swift`.
- **Friends** — list + pending requests. Friend rows are `NavigationLink`s into `FriendProfileView` (IQ / league / streak / bio + quick actions for Progression Race, Start a Challenge, Remove Friend). Training-partner status renders as a pill. `FriendsView.swift`.
- **Gym Hub** — gym-scoped leaderboards, challenges, leagues, progression races, matchmaking. `GymHubView.swift`.

Streak flame in toolbar; setup banner if username/profile incomplete.

**Overflow menu** (top-right `•••`) is the single entry point for `LeagueView`, `ChallengesView`, `AchievementsView`, `ClubsListView`, `WeeklyDigestView`, `MatchmakingView`, and `SocialProfileView` — without it those seven views are orphaned. Push targets are typed via the `SocialDestination` enum (defined at the bottom of `SocialTabView.swift`) so the same destinations are reachable from `DashboardView` and `ProfileView` too.

**Add Friends sheet** (`AddFriendsSheet.swift`) — leads with `MatchmakingService.findMatches` results ("Suggested for You") and an Invite Friends share entry (presents `UIActivityViewController` directly off the active scene with an App Store URL + the user's @username). Search-by-username is below the suggestions, not the only path.

**Comebacks** — feed cards for friends returning after 14+ days off get a "Welcome back" pill. Detection is client-side in `FeedView.comebackItemIds`, derived from the spacing between a friend's consecutive `workout_completed` items in the loaded feed window. No new `FeedItemType` case — the decoration is layered on top of an existing item.

**Clubs** (`ClubsListView` → `ClubDetailView`, `CreateClubView`) — 3–10 person training groups with public/private visibility. Backed by the `clubs` + `club_members` tables and the existing `ChallengeService` club methods.

**Lift Percentiles** (`LiftPercentileService` + `ExerciseProgressView.liftPercentileCard`) — on the exercise drill-in screen, shows the user's e1RM percentile vs friends and vs everyone in their league tier. Friends scope is computed client-side over each friend's working sets in 90 days. Tier scope calls the `lift_percentile_in_tier` RPC (migration `20260518_lift_percentiles.sql`), which derives e1RM in SQL via Epley and returns NULL when the cohort is under 5 users. Hidden silently when no scope has enough data.

**Promotion Race** (`LeagueView.promotionRaceCard`) — between the league header and the leaderboard. Shows IQ-to-next-tier, IQ delta to the rank above, IQ buffer over the rank below, and a "Top 5 promote" callout. Tier thresholds live on `LeagueTier.minIQ` (client-side only — automatic server-side promotion isn't wired yet).

**Training Now presence** (`PresenceService` + `GymHubView.trainingNowBanner`) — friends who are actively logging a workout appear in a green "Training Now" banner above the gym members list. Backed by a `user_presence` row with a 2-hour TTL (migration `20260518_shared_templates_and_presence.sql`). `ActiveWorkoutViewModel.startWorkout` upserts the row; `completeWorkout` and `abandonWorkout` clear it (fire-and-forget so a network blip never blocks the workout).

### Profile (`repIQ/Views/Profile/ProfileView.swift`)

Avatar / username / gym info, then a **My Stats** card (League / IQ / Streak triplet + quick links to `AchievementsView` and `SocialProfileView`), then Settings (weight unit, rest timer, body & health, notifications, privacy, gym, account) and Sign Out. Owns its own `SocialViewModel` and a local `navigationDestination(for: SocialDestination.self)` mirroring `SocialTabView`'s wiring.

### Templates (`repIQ/Views/Templates/`)

`TemplateListView` → `TemplateDetailView` → `TemplateEditorView` (name + days + **Share with friends** toggle once saved) → `WorkoutDayEditorView` (exercises + training mode + targetSets + repCap + supersetGroup) → `ExercisePickerView`. Pre-built programs in `ProgramBrowserView` → `ProgramDetailView` (one-tap create-template).

**Shareable templates**: `templates.is_shared` (migration `20260518_shared_templates_and_presence.sql`) plus RLS that lets accepted friends read shared templates, their days, and their exercises. `FriendProfileView` shows a friend's shared templates with a "Try It" button that clones into the current user's templates via `TemplateService.duplicateTemplate`.

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
   - Awards IQ points (`GamificationService.awardWorkoutRewards`).
   - Updates streak.
   - Detects new PRs → DB.
   - Creates feed item.
   - Builds `WorkoutSummaryData` → presents `WorkoutSummaryView`.
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
- **Services** are non-actor classes; methods are `async throws` for network calls.
- **ViewModels** are `@Observable final class`. They run on the main actor by default in iOS 17+ Swift 6 mode (project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- **Persistence**: Supabase first; OfflineSetQueue is a fallback, not a primary write target.
- **Time**: store as `Date` (UTC under the hood). Display via `relativeDisplay` extension or `formatted(...)`.
- **No `print` in committed code.** Use the existing logging hooks if a logger gets added; for now, swallow errors at boundaries (Supabase services already do this).
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

## Live Activity gotchas (learned the hard way)

- `Text(timerInterval:)` in a header HStack starves siblings → entire body of the activity stops rendering. Symptom: a glitched fragment of the header at top-left of the card and empty space below.
- iOS Lock Screen activity content max ~135pt. Designs that work in Xcode previews can clip on-device. Test by locking the simulator (`Cmd+L`).
- iOS sometimes caches stale activity binaries; if a layout change doesn't appear after rebuild, do **delete app from simulator → clean build folder → build `repIQActivity` scheme separately → switch to `repIQ` and run**. The widget target doesn't always rebuild on a main-app `Cmd+R`.
- Background tint (`activityBackgroundTint`) can be used as a quick "did the new code load" sentinel during debugging — change to `.red` and rebuild to confirm.

---

## Recent ships

- **Unreleased (post-build 11)** — Jun 16 2026 — **Opt-in performance deloads.** Performance-based deloads (declining e1RM / consecutive bad sessions) are no longer applied silently at the next session. `calculateTarget` gained an `allowDeload` flag; `ActiveWorkoutViewModel` detects deload targets on `startWorkout` and surfaces a "Recovery Recommended" prompt (`ActiveWorkoutView.performanceDeloadBanner`) with **Take Deload** / **Keep Progressing**. Declining recomputes each flagged lift with `allowDeload: false` (declining → normal double-progression) and rebuilds the pre-filled sets. Stateless (re-prompts each session while declining); the time-based proactive banner is suppressed while a performance prompt is showing. No schema change.
- **Unreleased (post-build 11)** — May 18 2026 — **Social expansion v1.** Three waves on `claude/objective-raman-7b8173`, merged to main. **Wave 1:** Clubs UI (`ClubsListView` / `ClubDetailView` / `CreateClubView`) on the existing `clubs`/`club_members` schema; `ExerciseTipsView` accepts an `initialExercise` parameter and is embedded as a compact 2-tip section on the exercise drill-in (Progress → exercise); "Welcome back" feed pill for friends returning after 14+ days off, derived client-side. **Wave 2:** Lift Percentiles (`LiftPercentileService` + `liftPercentileCard`) showing e1RM percentile vs friends (client-side) and vs league tier (new `lift_percentile_in_tier` RPC); Promotion Race card on `LeagueView` showing IQ-to-next-tier, IQ delta to the rank above/below, and a "Top 5 promote" callout, backed by client-side `LeagueTier.minIQ` thresholds. **Wave 3:** Shareable templates (`templates.is_shared` column + RLS that exposes shared templates and their days/exercises to accepted friends), share toggle in `TemplateEditorView`, and "Try It" clone button on `FriendProfileView`; silent training-now presence (`user_presence` table with 2h TTL, `PresenceService`, banner in `GymHubView`) written on workout start and cleared on complete/abandon. Two new Supabase migrations (`20260518_lift_percentiles.sql`, `20260518_shared_templates_and_presence.sql`) need to be applied before the new features have real backing data.
- **1.5 (build 11)** — May 18 2026 — Social-feature surfacing pass. Six views (`LeagueView`, `ChallengesView`, `AchievementsView`, `WeeklyDigestView`, `MatchmakingView`, `SocialProfileView`) were defined in code but unreachable; now linked via a `SocialDestination` enum + a `••• ` overflow menu in the Social tab, the new Home Social Pulse card, and the new Profile My Stats card. Friend cards push into a new `FriendProfileView` with IQ / league / streak / bio + buttons for Progression Race, Start a Challenge, Remove Friend (none of these were reachable before). `CreateChallengeView` now accepts a `preselectedFriend`. `AddFriendsSheet` got matchmaking-driven "Suggested for You" results and an Invite Friends share with a deep-linked App Store URL. Fixed the "Share my Wrapped" black-screen crash (`ImageRenderer` was producing a ~75-megapixel image on the main thread + SwiftUI `.sheet` raced the hidden status bar — now scale 1.0 with direct UIKit presentation off the active scene). Wrapped story hides the tab bar for full-screen immersion. Feed workout titles read narratively. Zero-duration feed cards drop the duration pill.
- **1.5 (build 10)** — May 2026 — Bumped to v1.5. Fixed Wrapped streak parse + bodyweight-exercise display. Fixed Wrapped month label off-by-one and archetype-slide buttons being blocked by tap zones. Progress tab overhaul: new sections, narrative copy, time-window picker. Replaced stacked target/last text with a per-set comparison rail. Progression-engine + UX fixes: bump weight at rep cap with flat e1RM (double-progression unstick), derive PRs from `workout_sets` not the `personal_records` cache, filter prior-session sets to working-only, fix inverted rep range when prior session exceeded rep cap, removed "Pick up where you left off" from the dashboard.
- **1.4 (build 7)** — May 2026 — Interactive Lock Screen / Dynamic Island set logging via App Intents. Stepper buttons for weight/reps/RPE on the upcoming set + LOG SET commit button. GOAL (programmed target) and LAST (prior-session same-set-number) context lines. Skip-rest button during rest periods. Minimize-bug fix (VM ownership moved from `MainTabView` `@State` to `WorkoutCoordinator`). Live Activity orphan cleanup at app launch + before every new activity request.
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
# Terminal upload (xcrun altool) requires API key + working Distribution profiles;
# see Live Activity gotchas above for why first-time profile mints need Organizer.
```

---

## Things that don't exist (yet) but are on the roadmap

- Apple Watch companion (hands-free logging, heart rate, mid-workout fatigue suggestions)
- StandBy mode view (full-screen rest timer + next-set preview when phone is on charger)
- Critical alerts for rest-end (breakthrough DND)
- Siri shortcuts donation ("Hey Siri, log 135 by 8") — App Intents already exist; just need shortcut donation + phrase polish
- Lock-screen circular rest-ring redesign
- Mentor/mentee pairing (Wave 4 of the social expansion — planned, not built)
- Server-side automatic league tier promotions (currently `LeagueTier.minIQ` is the only threshold and only the client compares against it)
- Realtime subscription for the Gym Hub "Training Now" banner (currently polled on view appear / refresh)

If you find yourself building one of these, check the existing intent infrastructure (`repIQ/Intents/`) and Live Activity setup before reinventing.

---

## When in doubt

- Read the actual code before assuming behavior — this file is a map, not the territory.
- For workout logic: start at `ActiveWorkoutViewModel`. It's huge (~1800 lines) but it's the source.
- For progression decisions: `ProgressionService.calculateTarget`. Read the whole function — it's worth it.
- For UI patterns: look at how an existing similar screen does it. The conventions are pretty consistent (RQCard wrappers, `@Observable` VMs, NavigationStack per tab).
- Check git log for context — commit messages are descriptive: `git log --oneline -20`.
