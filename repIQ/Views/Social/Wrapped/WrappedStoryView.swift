import SwiftUI

/// Spotify-style monthly wrapped story flow. Tap right two-thirds of the
/// screen to advance, tap left third to go back, swipe down (system gesture)
/// to dismiss. A linear progress bar pinned to the top tracks slide
/// position. Each slide renders one hero stat against an animated dark
/// background — designed for screenshotting + sharing.
struct WrappedStoryView: View {
    let wrapped: MonthlyWrapped
    var onClose: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onViewHistory: (() -> Void)? = nil

    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    private var slides: [WrappedSlideKind] { WrappedSlideKind.slides(for: wrapped) }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundGradient

            TabView(selection: $currentIndex) {
                ForEach(slides.indices, id: \.self) { idx in
                    slideView(slides[idx])
                        .tag(idx)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, RQSpacing.md)
                    .padding(.top, RQSpacing.sm)

                HStack {
                    Spacer()
                    Button {
                        (onClose ?? { dismiss() })()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(8)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .padding(.trailing, RQSpacing.md)
                }
                .padding(.top, RQSpacing.xs)
            }

            // Tap zones: left third = previous, right two-thirds = next.
            HStack(spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { advance(by: -1) }
                Color.clear
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { advance(by: 1) }
                    .frame(maxWidth: .infinity)
            }
            .allowsHitTesting(true)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: - Slide dispatcher

    @ViewBuilder
    private func slideView(_ kind: WrappedSlideKind) -> some View {
        switch kind {
        case .cover:
            CoverSlideView(wrapped: wrapped)
        case .sessions(let count):
            HeroStatSlideView(
                eyebrow: "WORKOUTS",
                heroNumber: "\(count)",
                heroSuffix: count == 1 ? "session" : "sessions",
                caption: count == 0 ? "A quiet month — that's part of training too." : "You showed up.",
                icon: "figure.strengthtraining.traditional"
            )
        case .volume(let pounds):
            VolumeSlideView(pounds: pounds)
        case .sets(let count):
            HeroStatSlideView(
                eyebrow: "WORKING SETS",
                heroNumber: "\(count)",
                heroSuffix: "sets",
                caption: "You logged the work.",
                icon: "number"
            )
        case .prs(let count, let biggest):
            PRsSlideView(count: count, biggest: biggest)
        case .topExercise(let name, let volume):
            TopExerciseSlideView(name: name, volume: volume)
        case .muscle(let name):
            HeroStatSlideView(
                eyebrow: "MOST CONSISTENT",
                heroNumber: name.capitalized,
                heroSuffix: nil,
                caption: "You hit it every week.",
                icon: "figure.flexibility"
            )
        case .favoriteDay(let day):
            HeroStatSlideView(
                eyebrow: "YOUR DAY",
                heroNumber: day,
                heroSuffix: nil,
                caption: "More workouts on \(day)s than any other day.",
                icon: "calendar"
            )
        case .streak(let days):
            HeroStatSlideView(
                eyebrow: "LONGEST STREAK",
                heroNumber: "\(days)",
                heroSuffix: days == 1 ? "day" : "days",
                caption: "Showing up matters.",
                icon: "flame.fill"
            )
        case .archetype(let archetype):
            ArchetypeSlideView(
                archetype: archetype,
                onShare: { onShare?() },
                onViewHistory: { onViewHistory?() }
            )
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(slides.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx <= currentIndex ? Color.white : Color.white.opacity(0.18))
                    .frame(height: 3)
                    .animation(.easeOut(duration: 0.25), value: currentIndex)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.04, green: 0.07, blue: 0.12)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Navigation

    private func advance(by delta: Int) {
        let next = currentIndex + delta
        if next < 0 { return }
        if next >= slides.count {
            (onClose ?? { dismiss() })()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex = next
        }
    }
}

// MARK: - Slide kinds

enum WrappedSlideKind {
    case cover
    case sessions(Int)
    case volume(Double)
    case sets(Int)
    case prs(Int, BiggestPR?)
    case topExercise(name: String, volume: Double)
    case muscle(String)
    case favoriteDay(String)
    case streak(Int)
    case archetype(WrappedArchetype)

    struct BiggestPR {
        let exerciseName: String
        let value: Double
        let recordType: String
    }

    /// Build the slide list for a given wrapped row, skipping slides whose
    /// data is missing or insignificant.
    static func slides(for w: MonthlyWrapped) -> [WrappedSlideKind] {
        var out: [WrappedSlideKind] = [.cover]
        out.append(.sessions(w.totalSessions))
        if w.totalVolume > 0 {
            out.append(.volume(w.totalVolume))
        }
        out.append(.sets(w.totalSets))
        let biggest: BiggestPR? = {
            guard let name = w.biggestPRExercise,
                  let value = w.biggestPRValue,
                  let type = w.biggestPRType else { return nil }
            return BiggestPR(exerciseName: name, value: value, recordType: type)
        }()
        out.append(.prs(w.totalPRs, biggest))
        if let name = w.topExerciseName, let vol = w.topExerciseVolume {
            out.append(.topExercise(name: name, volume: vol))
        }
        if let muscle = w.mostConsistentMuscle {
            out.append(.muscle(muscle))
        }
        if let day = w.favoriteDay {
            out.append(.favoriteDay(day))
        }
        if w.longestStreak >= 2 {
            out.append(.streak(w.longestStreak))
        }
        let archetype = WrappedArchetype(rawValue: w.archetype ?? "") ?? .steadyBuilder
        out.append(.archetype(archetype))
        return out
    }
}

// MARK: - Slide views

private struct CoverSlideView: View {
    let wrapped: MonthlyWrapped

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()
            Text(monthLabel(wrapped.monthStart).uppercased())
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(RQColors.accent)
            Text("YOUR\nWRAPPED")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(-8)
            Spacer()
            Text("Tap to begin")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, RQSpacing.xxl)
        }
        .padding(.horizontal, RQSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

private struct HeroStatSlideView: View {
    let eyebrow: String
    let heroNumber: String
    let heroSuffix: String?
    let caption: String
    let icon: String

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(RQColors.accent)
                .padding(.bottom, RQSpacing.md)

            Text(eyebrow)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))

            Text(heroNumber)
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            if let suffix = heroSuffix {
                Text(suffix)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, -RQSpacing.sm)
            }

            Text(caption)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, RQSpacing.xl)
                .padding(.top, RQSpacing.md)

            Spacer()
        }
        .padding(.horizontal, RQSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct VolumeSlideView: View {
    let pounds: Double

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()

            Image(systemName: "scalemass.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(RQColors.accent)
                .padding(.bottom, RQSpacing.md)

            Text("TOTAL VOLUME")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))

            Text(formatPounds(pounds))
                .font(.system(size: 88, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            Text("lbs lifted")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, -RQSpacing.sm)

            if let phrase = MemorableUnit.phrase(for: pounds) {
                VStack(spacing: 4) {
                    Text("That's")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(phrase)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(RQColors.accent)
                }
                .padding(.top, RQSpacing.xl)
            }

            Spacer()
        }
        .padding(.horizontal, RQSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatPounds(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}

private struct PRsSlideView: View {
    let count: Int
    let biggest: WrappedSlideKind.BiggestPR?

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()

            Image(systemName: count > 0 ? "trophy.fill" : "mountain.2.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(RQColors.accent)
                .padding(.bottom, RQSpacing.md)

            if count > 0 {
                Text("PERSONAL RECORDS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.55))

                Text("\(count)")
                    .font(.system(size: 96, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(count == 1 ? "new PR" : "new PRs")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, -RQSpacing.sm)

                if let biggest {
                    VStack(spacing: 6) {
                        Text("Biggest")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(biggest.exerciseName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(formatPR(biggest))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(RQColors.accent)
                    }
                    .padding(.top, RQSpacing.xl)
                }
            } else {
                Text("ZERO PRS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.55))

                Text("Plateaus.")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("They're part of the path. The next breakthrough comes after the longest pause.")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, RQSpacing.xl)
                    .padding(.top, RQSpacing.lg)
            }

            Spacer()
        }
        .padding(.horizontal, RQSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatPR(_ pr: WrappedSlideKind.BiggestPR) -> String {
        let value = pr.value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", pr.value)
            : String(format: "%.1f", pr.value)
        return "\(value) lbs"
    }
}

private struct TopExerciseSlideView: View {
    let name: String
    let volume: Double

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(RQColors.accent)
                .padding(.bottom, RQSpacing.md)

            Text("MOST PERFORMED")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))

            Text(name)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Text("\(formatVolume(volume)) lbs of total volume on it")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, RQSpacing.md)
                .padding(.horizontal, RQSpacing.xl)

            Spacer()
        }
        .padding(.horizontal, RQSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatVolume(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fK", value / 1_000) }
        return String(format: "%.0f", value)
    }
}

private struct ArchetypeSlideView: View {
    let archetype: WrappedArchetype
    var onShare: () -> Void
    var onViewHistory: () -> Void

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()

            Image(systemName: archetype.systemImageName)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(RQColors.accent)
                .padding(.bottom, RQSpacing.md)

            Text("YOU ARE A")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))

            Text(archetype.displayName.uppercased())
                .font(.system(size: 40, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            Text(archetype.headline)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, RQSpacing.xl)
                .padding(.top, RQSpacing.md)

            Spacer()

            VStack(spacing: RQSpacing.sm) {
                Button(action: onShare) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share my Wrapped")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.accent, in: Capsule())
                }

                Button(action: onViewHistory) {
                    Text("View past months")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, RQSpacing.xl)
            .padding(.bottom, RQSpacing.xxl)
        }
        .padding(.horizontal, RQSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
