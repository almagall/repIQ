import SwiftUI

/// Structured monthly training report — same schema every month so it can
/// be scanned, compared month-over-month, and eventually placed side by
/// side in a comparison view. Pushed from the archetype slide of the
/// Wrapped story flow.
///
/// Pass 1 is a placeholder; Pass 2 fills in the real sections.
struct MonthlyReportView: View {
    let wrapped: MonthlyWrapped

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.xl) {
                Text("Full report coming soon.")
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textSecondary)
                    .padding(.top, RQSpacing.xxxl)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RQSpacing.screenHorizontal)
        }
        .background(RQColors.background)
        .navigationTitle(monthLabel(wrapped.monthStart) + " Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}
