# repIQ

**Intelligent Gym Workout Planning** — not just a logbook.

repIQ is an iOS app that calculates session targets using structured progressive overload principles. It supports customizable workout templates, per-set feedback, PR tracking, deload detection, and progression visualization.

## What Makes repIQ Different

Most gym apps record what you did. repIQ guides what you should do next.

- **Progressive Overload Engine** — Calculates target weight, reps, and RPE for every set based on your previous sessions
- **Hypertrophy vs Strength Modes** — Each exercise is toggled independently. Hypertrophy targets 10-15 reps at RPE 8; Strength targets 3-5 reps at RPE 8.5
- **Stall Detection & Deloads** — Automatically detects when you've plateaued and recommends deload protocols
- **RPE-Based Autoregulation** — Tracks RPE drift across sessions to catch fatigue before it becomes a problem
- **Real-Time PR Detection** — Personal records calculated and celebrated instantly during your workout
- **2-3 Taps Per Set** — Weight pre-filled from targets. Fast, frictionless logging designed for between sets

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | SwiftUI (iOS 17+) |
| Architecture | MVVM with `@Observable` |
| Backend | Supabase (Auth, PostgreSQL, RLS) |
| Charts | Swift Charts (built-in) |
| Dependencies | `supabase-swift` v2.x (single SPM dependency) |

## Current Status

### Completed
- **Phase 1: Foundation + Auth** — Project structure, Supabase integration, email/password authentication, session management, dark theme design system (gold #D4A847 accent)
- **Phase 2: Dashboard + Exercise Library** — Dashboard with live stats, 50+ seeded exercises, search/filter by muscle group and equipment
- **Phase 3: Template System** — Full CRUD for workout templates with nested workout days and exercises, hypertrophy/strength toggle per exercise

### In Progress
- **Phase 4: Workout Logging** — Active workout session, set logging (weight/reps/RPE), previous session display

### Planned
- **Phase 5: Progressive Overload Engine** — Target calculations, stall detection, deload recommendations
- **Phase 6: PR Tracking + Charts** — Real-time PR detection, progress visualization with Swift Charts
- **Phase 7: Polish** — Rest timer, plate calculator, animations, haptics, accessibility

## Project Structure

```
repIQ/
├── Config/          Supabase client, app constants
├── Models/          Codable structs (Profile, Exercise, Template, WorkoutSet, etc.)
├── Services/        Supabase data layer (Auth, Templates, Exercises, Workouts)
├── ViewModels/      @Observable view models (one per major screen)
├── Views/
│   ├── App/         RootView (auth gate), MainTabView
│   ├── Auth/        SignIn, SignUp
│   ├── Dashboard/   Dashboard cards, quick start
│   ├── Templates/   List, Detail, Editor, DayEditor, ExercisePicker
│   ├── Workout/     (Phase 4 — coming soon)
│   ├── Progress/    (Phase 6 — coming soon)
│   ├── Profile/     Settings, unit toggle
│   └── Components/  RQButton, RQTextField, RQCard, RPESelector
├── Design/          Theme colors, typography, spacing
├── Extensions/      Color hex init, Date/Double formatting
└── Utilities/       (Phase 7 — plate calculator, etc.)
```

## Database

9 PostgreSQL tables in Supabase with Row-Level Security:

`profiles` · `exercises` · `templates` · `workout_days` · `workout_day_exercises` · `workout_sessions` · `workout_sets` · `personal_records` · `progression_log`

Migration at `supabase/migrations/001_initial_schema.sql`.

## Setup

1. Clone the repo
2. Open `repIQ.xcodeproj` in Xcode 26+
3. SPM will auto-resolve `supabase-swift`
4. Create a Supabase project and update `Config/Supabase.swift` with your URL and anon key
5. Run the SQL migration in Supabase SQL Editor
6. Build and run on iOS Simulator (iPhone 17 Pro)
