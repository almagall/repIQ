import SwiftUI

// MARK: - Info Button

/// A compact (ⓘ) button that opens an explanatory sheet when tapped.
/// Place next to section headers to provide context-sensitive explanations.
struct InfoButton: View {
    let topic: ProgressExplainer.Topic
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(RQColors.textTertiary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            InfoSheet(topic: topic)
        }
    }
}

// MARK: - Multi-Topic Info Button

/// A compact (ⓘ) button that opens a sheet covering multiple topics at once.
struct MultiInfoButton: View {
    let topics: [ProgressExplainer.Topic]
    let title: String
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(RQColors.textTertiary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            MultiInfoSheet(topics: topics, title: title)
        }
    }
}

// MARK: - Multi-Topic Info Sheet

/// A sheet that explains multiple related topics in a single scrollable view.
struct MultiInfoSheet: View {
    let topics: [ProgressExplainer.Topic]
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RQSpacing.xl) {
                    ForEach(Array(topics.enumerated()), id: \.offset) { index, topic in
                        if index > 0 {
                            Divider().background(RQColors.surfaceTertiary)
                        }

                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            // Icon + title
                            HStack(spacing: RQSpacing.sm) {
                                Image(systemName: topic.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(RQColors.accent)
                                    .frame(width: 28)
                                Text(topic.title)
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                            }

                            // Explanation
                            Text(topic.explanation)
                                .font(RQTypography.callout)
                                .foregroundColor(RQColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)

                            // Key points
                            if !topic.keyPoints.isEmpty {
                                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                                    ForEach(Array(topic.keyPoints.enumerated()), id: \.offset) { _, point in
                                        HStack(alignment: .top, spacing: RQSpacing.sm) {
                                            Circle()
                                                .fill(RQColors.accent)
                                                .frame(width: 4, height: 4)
                                                .padding(.top, 6)
                                            Text(point)
                                                .font(RQTypography.caption)
                                                .foregroundColor(RQColors.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Info Sheet

/// A presentation sheet that explains a specific analytics concept.
/// Designed to be concise, scannable, and actionable.
struct InfoSheet: View {
    let topic: ProgressExplainer.Topic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RQSpacing.xl) {
                    // Icon + title
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: topic.icon)
                            .font(.system(size: 24))
                            .foregroundColor(RQColors.accent)
                        Text(topic.title)
                            .font(RQTypography.title3)
                            .foregroundColor(RQColors.textPrimary)
                    }

                    // Main explanation
                    Text(topic.explanation)
                        .font(RQTypography.body)
                        .foregroundColor(RQColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)

                    // Key points
                    if !topic.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Text("KEY POINTS")
                                .font(RQTypography.label)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textTertiary)

                            ForEach(Array(topic.keyPoints.enumerated()), id: \.offset) { _, point in
                                HStack(alignment: .top, spacing: RQSpacing.sm) {
                                    Circle()
                                        .fill(RQColors.accent)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 7)
                                    Text(point)
                                        .font(RQTypography.callout)
                                        .foregroundColor(RQColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // How to use this (actionable)
                    if let howToUse = topic.howToUse {
                        VStack(alignment: .leading, spacing: RQSpacing.sm) {
                            Text("HOW TO USE THIS")
                                .font(RQTypography.label)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textTertiary)
                            Text(howToUse)
                                .font(RQTypography.callout)
                                .foregroundColor(RQColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.lg)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .background(RQColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Progress Explainer (all topic definitions)

enum ProgressExplainer {

    struct Topic {
        let title: String
        let icon: String
        let explanation: String
        let keyPoints: [String]
        let howToUse: String?
    }

    // MARK: - Dashboard Topics

    static let volumeTrend = Topic(
        title: "Volume Trend",
        icon: "chart.bar.fill",
        explanation: "Training volume (weight × reps) is the primary driver of muscle growth and strength gains. This chart shows your total weekly volume over the past 8 weeks so you can spot trends.",
        keyPoints: [
            "Gradually increasing volume over time is the foundation of progressive overload.",
            "A sudden drop may signal fatigue, missed sessions, or a needed deload.",
            "Aim for 5–10% increases per week to avoid overreaching.",
        ],
        howToUse: "If the bars are trending up, you're on track. If they've been flat or declining, consider adding sets or increasing weight. A planned dip every 4–6 weeks (deload) helps recovery."
    )

    static let muscleBalance = Topic(
        title: "Muscle Balance",
        icon: "chart.pie.fill",
        explanation: "This chart breaks down your training volume by muscle group over the past 30 days. Balanced development reduces injury risk and builds a well-rounded physique.",
        keyPoints: [
            "Most lifters unknowingly neglect hamstrings, rear delts, and calves.",
            "A muscle group taking up less than 5% of your volume may need more attention.",
            "Use the Direct/Adjusted toggle to include compound synergist credit.",
        ],
        howToUse: "Look for any muscle group that's significantly smaller than others. Consider adding 2–3 direct sets per week for underrepresented groups. The 'Adjusted' view adds 0.5× credit for muscles hit indirectly by compound lifts."
    )

    static let effectiveReps = Topic(
        title: "Effective Reps",
        icon: "gauge.with.dots.needle.67percent",
        explanation: "Not all reps are created equal. Research shows that the last ~5 reps before failure produce the most muscle-building stimulus. These are your 'effective reps.'",
        keyPoints: [
            "Based on the Beardsley framework: effective reps = reps within 5 reps of failure.",
            "RPE 7 (3 RIR) gives ~2 effective reps per set. RPE 9 (1 RIR) gives ~4.",
            "A higher effective rep ratio means more stimulus per set — more efficient training.",
            "Very low ratios (<15%) suggest most sets are too easy to stimulate growth.",
        ],
        howToUse: "Aim for an overall effective rep ratio of 25–50%. If yours is below 25%, try pushing closer to failure on your working sets (RPE 7–9). If it's very high (>50%), make sure you're recovering adequately."
    )

    static let fractionalVolume = Topic(
        title: "Fractional Volume",
        icon: "arrow.triangle.branch",
        explanation: "Compound exercises like bench press don't just work the primary muscle — they also stimulate synergist muscles (e.g., triceps and shoulders). Fractional volume accounts for this by adding partial credit.",
        keyPoints: [
            "Primary muscle gets 100% volume credit. Synergists get 50% credit.",
            "Based on Pelland et al. (2024) research on indirect volume contribution.",
            "Gives a more accurate picture of total stimulus each muscle receives.",
            "Useful for determining if isolation work is truly needed.",
        ],
        howToUse: "Toggle between 'Direct' (only counting primary muscle) and 'Adjusted' (including synergist credit) to see how compound movements affect your overall volume distribution."
    )

    static let trainingFrequency = Topic(
        title: "Training Frequency",
        icon: "calendar",
        explanation: "This heatmap shows your workout consistency over the past 12 weeks. Each square represents one day — brighter squares mean you trained that day.",
        keyPoints: [
            "Consistency is the strongest predictor of long-term results.",
            "Most research suggests 3–5 sessions per week for optimal progress.",
            "Look for patterns: are weekends always blank? Are you taking too many consecutive rest days?",
        ],
        howToUse: "Scan for gaps and patterns. If you see consistent blank stretches, consider scheduling workouts at the same time each day to build a habit. An occasional rest day is good — extended gaps may slow your progress."
    )

    static let milestones = Topic(
        title: "Milestones",
        icon: "trophy.fill",
        explanation: "Milestones are achievement markers that celebrate your training journey. They're based on objective metrics like total sessions, volume lifted, streaks, and PRs.",
        keyPoints: [
            "Five categories: Sessions, Volume, Streaks, Personal Records, and Exercises.",
            "Focus on the 'next up' milestones — the ones closest to completion.",
            "Each milestone represents a meaningful training accomplishment.",
        ],
        howToUse: "Use milestones as micro-goals to stay motivated. The progress ring shows how close you are. Don't obsess over them — they'll come naturally with consistent training."
    )

    // MARK: - Phase Then Topics

    static let pushPullBalance = Topic(
        title: "Push/Pull Balance",
        icon: "arrow.left.arrow.right",
        explanation: "Push/pull balance compares volume between pushing movements (chest, shoulders, triceps) and pulling movements (back, biceps). An imbalanced ratio can lead to postural issues and increased injury risk.",
        keyPoints: [
            "Push muscles: chest, shoulders, triceps. Pull muscles: back, biceps.",
            "An ideal push:pull ratio is roughly 1:1 to 1:1.3 (slightly more pull).",
            "Most gym-goers overtrain push (bench press bias) and undertrain pull.",
            "Balanced push/pull supports shoulder health and good posture.",
        ],
        howToUse: "If your ratio is heavily push-dominant (>1.5:1), add more rowing and pulling movements. If pull-dominant, you may want more pressing volume. A slight pull emphasis is actually ideal for shoulder health."
    )

    static let volumeLandmarks = Topic(
        title: "Volume Landmarks",
        icon: "ruler.fill",
        explanation: "Volume landmarks define how much weekly training volume each muscle group needs. Based on Renaissance Periodization (Dr. Mike Israetel) research, there are three key thresholds.",
        keyPoints: [
            "MEV (Minimum Effective Volume): The minimum sets per week to make progress. Below this, you're maintaining or losing.",
            "MAV (Maximum Adaptive Volume): The sweet spot — the volume range where you make the best gains relative to effort.",
            "MRV (Maximum Recoverable Volume): The upper limit. Beyond this, you can't recover and performance declines.",
            "These are general guidelines — individual recovery varies based on training age, sleep, nutrition, and stress.",
        ],
        howToUse: "Compare your current weekly set count per muscle group against these landmarks. If you're below MEV, you need more sets. If you're within MAV, you're in the sweet spot. If approaching MRV, consider whether you're recovering well."
    )

    static let strengthPrediction = Topic(
        title: "Strength Prediction",
        icon: "chart.line.uptrend.xyaxis",
        explanation: "Strength predictions project your estimated 1-rep max (E1RM) forward based on your recent trend. This helps set realistic goals and track whether your programming is working.",
        keyPoints: [
            "Uses linear regression on your last several sessions' E1RM values.",
            "The projection extends 4 weeks into the future based on current trajectory.",
            "More data points = more reliable predictions.",
            "Predictions assume consistent training — missed sessions will alter the trajectory.",
        ],
        howToUse: "Use the projected E1RM as a goal to work toward, not an expectation. If the projection is flat, your training stimulus may need adjustment. If it's climbing, keep doing what you're doing."
    )

    // MARK: - Phase Later Topics

    static let consistencyScore = Topic(
        title: "Consistency Score",
        icon: "gauge.with.needle.fill",
        explanation: "Your consistency score is a 0–100 composite metric that measures how reliably you're training. It combines four factors: training frequency, volume stability, current streak, and recency.",
        keyPoints: [
            "Frequency (40%): How often you train per week relative to your goal.",
            "Volume Stability (25%): How consistent your weekly volume is (low variance is better).",
            "Streak (20%): Your current training streak rewards sustained consistency.",
            "Recency (15%): Training recently counts more than gaps followed by bursts.",
        ],
        howToUse: "A score above 80 means you're highly consistent. 60–80 is good but could improve. Below 60, focus on establishing a regular training schedule before worrying about advanced programming."
    )

    static let velocity = Topic(
        title: "Progress Velocity",
        icon: "speedometer",
        explanation: "Velocity measures how quickly your estimated 1-rep max (E1RM) is changing week over week. It tells you whether your strength is accelerating, maintaining, or declining.",
        keyPoints: [
            "Accelerating (>2%/wk): Fast gains — common in beginners or after a peak.",
            "Progressing (0.5–2%/wk): Steady, sustainable progress.",
            "Maintaining (±0.5%/wk): Holding strength — may need new stimulus.",
            "Stalling/Regressing: Time to reassess programming, recovery, or nutrition.",
        ],
        howToUse: "Check velocity alongside plateau detection. If you're stalling but training hard, the issue is likely recovery or programming. If you're progressing, don't change what's working."
    )

    static let plateauDetection = Topic(
        title: "Plateau Detection",
        icon: "exclamationmark.triangle",
        explanation: "A plateau is detected when your estimated 1RM hasn't changed by more than 2% across 3 or more consecutive sessions. The system analyzes potential root causes and provides specific recommendations.",
        keyPoints: [
            "Low Volume: Fewer than 3 working sets per session may be insufficient stimulus.",
            "High Fatigue: Average RPE above 8.5 suggests accumulated fatigue limiting performance.",
            "Low Frequency: Training a movement less than once every 10 days reduces skill and stimulus.",
            "Needs Variety: When other factors look fine, a variation or accessory may break the plateau.",
        ],
        howToUse: "Address the identified root cause(s) first. Don't change everything at once — adjust one variable, train for 2–3 weeks, then reassess."
    )

    // MARK: - Template Topics

    static let trainingMode = Topic(
        title: "Training Mode",
        icon: "figure.strengthtraining.traditional",
        explanation: "Training mode determines the rep range and RPE target the progression engine uses for this exercise. Choose the mode that matches your goal for this movement.",
        keyPoints: [
            "Hypertrophy (10–15 reps, RPE 7–8): Optimized for muscle growth. Higher reps with moderate weight maximize time under tension and metabolic stress.",
            "Strength (3–5 reps, RPE 8–9): Optimized for max force production. Lower reps with heavier weight build neural efficiency and peak strength.",
            "You can mix modes within a workout — e.g., strength for compounds, hypertrophy for accessories.",
        ],
        howToUse: "Pick Hypertrophy for most exercises if your goal is building muscle. Use Strength for big compounds (squat, bench, deadlift) if you want to get stronger. Changing the mode resets any rep cap you've set."
    )

    static let targetSets = Topic(
        title: "Target Sets",
        icon: "number.circle",
        explanation: "Target sets is the number of working sets the app will create for this exercise when you start a workout. This doesn't include warm-up or drop sets — those can be added during the workout.",
        keyPoints: [
            "3–4 sets per exercise is a good starting point for most lifters.",
            "More sets = more volume = more stimulus, but also more fatigue.",
            "Advanced lifters may benefit from 4–5 sets. Beginners often progress well on 2–3.",
            "Total weekly sets per muscle group matters more than sets per session.",
        ],
        howToUse: "Start with 3–4 sets. If you're consistently completing all sets with good form and manageable effort, consider adding a set. If you're struggling to finish or quality drops on the last sets, reduce by one."
    )

    static let repRange = Topic(
        title: "Rep Range",
        icon: "arrow.left.and.right",
        explanation: "The rep range is automatically set by the training mode and determines the target reps the progression engine aims for. When you hit the top of the range at manageable effort, the engine increases weight.",
        keyPoints: [
            "Hypertrophy mode: 10–15 reps. Strength mode: 3–5 reps.",
            "The progression engine uses this range to decide when to increase weight, add reps, maintain, or deload.",
            "Hitting the top of the range at or below target RPE triggers a weight increase.",
            "If a rep cap is set, the effective range will be narrower (e.g., 10–12 instead of 10–15).",
        ],
        howToUse: "You don't need to manually adjust this — it follows the training mode. If you want a narrower range (e.g., you don't want to go above 12 reps on bench), use the Rep Cap setting below."
    )

    static let repCap = Topic(
        title: "Rep Cap",
        icon: "arrow.up.to.line",
        explanation: "Rep cap limits the maximum reps the progression engine will target for this exercise. Without a cap, the engine uses the full rep range of the training mode (e.g., up to 15 for hypertrophy). With a cap, it triggers a weight increase sooner.",
        keyPoints: [
            "Off (default): The engine uses the full mode range. For hypertrophy, it won't suggest a weight increase until you hit 15 reps.",
            "When set (e.g., 12): The engine treats 12 as the top of the range. Hit 12 reps at manageable effort → weight goes up.",
            "Useful for heavy compounds where high reps feel inefficient or risky (e.g., barbell squats at 15 reps).",
            "The cap must be within the mode's valid range. Changing modes resets the cap.",
        ],
        howToUse: "Leave it Off for most exercises. Turn it on for heavy compounds where you'd rather increase weight sooner. For example, cap hypertrophy bench press at 12 so the engine adds weight once you hit 12 reps instead of waiting until 15."
    )

    static let supersets = Topic(
        title: "Supersets",
        icon: "link",
        explanation: "A superset pairs two or more exercises performed back-to-back with no rest between them. You rest only after completing all exercises in the superset. This saves time and increases training density.",
        keyPoints: [
            "Tap the link icon on an exercise to pair it with other exercises in the same workout day.",
            "Superset members are labeled (A, B, C...) and highlighted with an orange accent bar.",
            "Antagonist supersets (e.g., biceps + triceps) are most effective — opposing muscles recover while the other works.",
            "Avoid supersetting two exercises that compete for the same muscle group, as fatigue will limit performance on the second.",
        ],
        howToUse: "Use supersets to cut workout time without sacrificing volume. Pair exercises that use different muscle groups or equipment. During the workout, the app will guide you through each superset member in order before starting the rest timer."
    )
}
