import SwiftUI

struct ProgramBrowserView: View {
    @State private var viewModel = ProgramBrowserViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RQSpacing.sm) {
                        filterChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                            viewModel.filterByCategory(nil)
                        }
                        ForEach(ProgramCategory.allCases, id: \.self) { category in
                            filterChip(title: category.displayName, isSelected: viewModel.selectedCategory == category) {
                                viewModel.filterByCategory(category)
                            }
                        }
                    }
                    .padding(.horizontal, RQSpacing.screenHorizontal)
                }

                // Program cards
                VStack(spacing: RQSpacing.md) {
                    ForEach(viewModel.programs) { program in
                        NavigationLink {
                            ProgramDetailView(program: program)
                        } label: {
                            programCard(program)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.bottom, RQSpacing.xxxl)
            }
            .padding(.top, RQSpacing.lg)
        }
        .background(RQColors.background)
        .navigationTitle("Browse Programs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func programCard(_ program: ProgramDefinition) -> some View {
        RQCard {
            VStack(alignment: .leading, spacing: RQSpacing.sm) {
                HStack {
                    Text(program.name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(RQColors.textTertiary)
                }

                Text(program.description)
                    .font(RQTypography.caption)
                    .foregroundColor(RQColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: RQSpacing.sm) {
                    categoryBadge(program.category)
                    difficultyBadge(program.difficulty)
                    Text("\(program.daysPerWeek) days/wk")
                        .font(RQTypography.footnote)
                        .foregroundColor(RQColors.textSecondary)
                }
            }
        }
    }

    private func categoryBadge(_ category: ProgramCategory) -> some View {
        let color: Color = {
            switch category {
            case .hypertrophy: return RQColors.hypertrophy
            case .strength: return RQColors.strength
            case .hybrid: return RQColors.accent
            }
        }()

        return Text(category.displayName.uppercased())
            .font(RQTypography.label)
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, RQSpacing.sm)
            .padding(.vertical, RQSpacing.xxs)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.small)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }

    private func difficultyBadge(_ difficulty: ProgramDifficulty) -> some View {
        Text(difficulty.displayName.uppercased())
            .font(RQTypography.label)
            .tracking(0.5)
            .foregroundColor(RQColors.textTertiary)
            .padding(.horizontal, RQSpacing.sm)
            .padding(.vertical, RQSpacing.xxs)
            .overlay(
                RoundedRectangle(cornerRadius: RQRadius.small)
                    .stroke(RQColors.textTertiary.opacity(0.5), lineWidth: 1)
            )
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(RQTypography.label)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundColor(isSelected ? RQColors.background : RQColors.textSecondary)
                .padding(.horizontal, RQSpacing.md)
                .padding(.vertical, RQSpacing.sm)
                .background(isSelected ? RQColors.accent : Color.clear)
                .cornerRadius(RQRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: RQRadius.small)
                        .stroke(isSelected ? RQColors.accent : RQColors.textTertiary, lineWidth: 1)
                )
        }
    }
}
