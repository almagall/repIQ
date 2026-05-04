import SwiftUI

/// Spotify-style monthly wrapped story flow. Tap right two-thirds of the
/// screen to advance, tap left third to go back, swipe down (system gesture)
/// to dismiss. A linear progress bar pinned to the top tracks slide
/// position. Each slide renders one hero stat against the app's industrial
/// dark theme — uses RQColors / RQTypography throughout so the wrapped
/// matches the rest of the app instead of feeling like a separate Spotify
/// clone.
struct WrappedStoryView: View {
    let wrapped: MonthlyWrapped
    var onClose: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onViewHistory: (() -> Void)? = nil
    var onViewReport: (() -> Void)? = nil

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
                            .foregroundStyle(RQColors.textSecondary)
                            .padding(8)
                            .background(RQColors.surfaceTertiary, in: Circle())
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
                onViewReport: { onViewReport?() },
                onViewHistory: { onViewHistory?() }
            )
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(slides.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx <= currentIndex ? RQColors.textPrimary : RQColors.surfaceTertiary)
                    .frame(height: 3)
                    .animation(.easeOut(duration: 0.25), value: currentIndex)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [RQColors.background, RQColors.surfaceSecondary],
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

// MARK: - Slide views (theme-compliant)

/// Shared fonts for the story. All monospaced where numerical / titular,
/// matching `RQTypography` design language. The hero numbers are larger
/// than anything in the standard typography scale, so we declare them
/// inline but mirror the `.bold/.heavy + .monospaced` style.
private enum WrappedFonts {
    static let cover = Font.system(size: 56, weight: .heavy, design: .monospaced)
    static let heroLarge = Font.system(size: 88, weight: .heavy, design: .monospaced)
    static let heroExtraLarge = Font.system(size: 96, weight: .heavy, design: .monospaced)
    static let heroSuffix = Font.system(size: 18, weight: .semibold, design: .monospaced)
    static let archetypeName = Font.system(size: 38, weight: .heavy, design: .monospaced)
    static let prDetailValue = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let memorableUnit = Font.system(size: 22, weight: .bold, design: .monospaced)
}

private struct CoverSlideView: View {
    let wrapped: MonthlyWrapped

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()
            Text(monthLabel(wrapped.monthStart).uppercased())
                .font(RQTypography.label)
                .tracking(4)
                .foregroundStyle(RQColors.accent)
            Text("YOUR\nWRAPPED")
                .font(WrappedFonts.cover)
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textPrimary)
                .lineSpacing(-8)
            Spacer()
            Text("Tap to begin")
                .font(RQTypography.caption)
                .foregroundStyle(RQColors.textTertiary)
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
                .font(RQTypography.label)
                .tracking(3)
                .foregroundStyle(RQColors.textSecondary)

            Text(heroNumber)
                .font(WrappedFonts.heroExtraLarge)
                .foregroundStyle(RQColors.textPrimary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            if let suffix = heroSuffix {
                Text(suffix)
                    .font(WrappedFonts.heroSuffix)
                    .foregroundStyle(RQColors.textSecondary)
                    .padding(.top, -RQSpacing.sm)
            }

            Text(caption)
                .font(RQTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textSecondary)
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
                .font(RQTypography.label)
                .tracking(3)
                .foregroundStyle(RQColors.textSecondary)

            Text(formatPounds(pounds))
                .font(WrappedFonts.heroLarge)
                .foregroundStyle(RQColors.textPrimary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            Text("lbs lifted")
                .font(WrappedFonts.heroSuffix)
                .foregroundStyle(RQColors.textSecondary)
                .padding(.top, -RQSpacing.sm)

            if let phrase = MemorableUnit.phrase(for: pounds) {
                VStack(spacing: 4) {
                    Text("That's")
                        .font(RQTypography.caption)
                        .foregroundStyle(RQColors.textTertiary)
                    Text(phrase)
                        .font(WrappedFonts.memorableUnit)
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
                    .font(RQTypography.label)
                    .tracking(3)
                    .foregroundStyle(RQColors.textSecondary)

                Text("\(count)")
                    .font(WrappedFonts.heroExtraLarge)
                    .foregroundStyle(RQColors.textPrimary)

                Text(count == 1 ? "new PR" : "new PRs")
                    .font(WrappedFonts.heroSuffix)
                    .foregroundStyle(RQColors.textSecondary)
                    .padding(.top, -RQSpacing.sm)

                if let biggest {
                    VStack(spacing: 6) {
                        Text("BIGGEST")
                            .font(RQTypography.label)
                            .tracking(2)
                            .foregroundStyle(RQColors.textTertiary)
                        Text(biggest.exerciseName)
                            .font(RQTypography.headline)
                            .foregroundStyle(RQColors.textPrimary)
                        Text(formatPR(biggest))
                            .font(WrappedFonts.prDetailValue)
                            .foregroundStyle(RQColors.accent)
                    }
                    .padding(.top, RQSpacing.xl)
                }
            } else {
                Text("ZERO PRS")
                    .font(RQTypography.label)
                    .tracking(3)
                    .foregroundStyle(RQColors.textSecondary)

                Text("Plateaus.")
                    .font(WrappedFonts.cover)
                    .foregroundStyle(RQColors.textPrimary)

                Text("They're part of the path. The next breakthrough comes after the longest pause.")
                    .font(RQTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RQColors.textSecondary)
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
                .font(RQTypography.label)
                .tracking(3)
                .foregroundStyle(RQColors.textSecondary)

            Text(name)
                .font(RQTypography.largeTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Text("\(formatVolume(volume)) lbs of total volume on it")
                .font(RQTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textSecondary)
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
    var onViewReport: () -> Void
    var onViewHistory: () -> Void

    var body: some View {
        VStack(spacing: RQSpacing.lg) {
            Spacer()

            Image(systemName: archetype.systemImageName)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(RQColors.accent)
                .padding(.bottom, RQSpacing.md)

            Text("YOU ARE A")
                .font(RQTypography.label)
                .tracking(3)
                .foregroundStyle(RQColors.textSecondary)

            Text(archetype.displayName.uppercased())
                .font(WrappedFonts.archetypeName)
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(2)

            Text(archetype.headline)
                .font(RQTypography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(RQColors.textSecondary)
                .padding(.horizontal, RQSpacing.xl)
                .padding(.top, RQSpacing.md)

            Spacer()

            VStack(spacing: RQSpacing.sm) {
                Button(action: onViewReport) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Full Report")
                    }
                    .font(RQTypography.headline)
                    .foregroundStyle(RQColors.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.accent, in: Capsule())
                }

                Button(action: onShare) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share my Wrapped")
                    }
                    .font(RQTypography.headline)
                    .foregroundStyle(RQColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RQSpacing.md)
                    .background(RQColors.surfaceTertiary, in: Capsule())
                }

                Button(action: onViewHistory) {
                    Text("View past months")
                        .font(RQTypography.caption)
                        .foregroundStyle(RQColors.textTertiary)
                }
            }
            .padding(.horizontal, RQSpacing.xl)
            .padding(.bottom, RQSpacing.xxl)
        }
        .padding(.horizontal, RQSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
