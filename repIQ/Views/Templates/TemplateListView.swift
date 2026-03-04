import SwiftUI

struct TemplateListView: View {
    @State private var viewModel = TemplateListViewModel()
    @State private var showCreateTemplate = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.templates.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.templates.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            icon: "rectangle.stack.badge.plus",
                            title: "No Templates Yet",
                            message: "Create a workout template to get started with structured training.",
                            buttonTitle: "Create Template"
                        ) {
                            showCreateTemplate = true
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: RQSpacing.md) {
                            ForEach(viewModel.templates) { template in
                                NavigationLink {
                                    TemplateDetailView(template: template) {
                                        Task { await viewModel.deleteTemplate(template) }
                                    }
                                } label: {
                                    templateCard(template)
                                }
                            }
                        }
                        .padding(.horizontal, RQSpacing.screenHorizontal)
                        .padding(.top, RQSpacing.lg)
                        .padding(.bottom, RQSpacing.xxxl)
                    }
                }
            }
            .background(RQColors.background)
            .navigationTitle("Templates")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTemplate = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(RQColors.accent)
                    }
                }
            }
            .navigationDestination(isPresented: $showCreateTemplate) {
                TemplateEditorView(viewModel: TemplateEditorViewModel())
            }
            .task {
                await viewModel.loadTemplates()
            }
            .refreshable {
                await viewModel.loadTemplates()
            }
        }
    }

    private func templateCard(_ template: Template) -> some View {
        RQCard {
            HStack {
                VStack(alignment: .leading, spacing: RQSpacing.sm) {
                    Text(template.name)
                        .font(RQTypography.headline)
                        .foregroundColor(RQColors.textPrimary)
                    if let desc = template.description, !desc.isEmpty {
                        Text(desc)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(2)
                    }
                    let dayCount = template.workoutDays?.count ?? 0
                    let totalExercises = template.workoutDays?.reduce(0) { $0 + ($1.exercises?.count ?? 0) } ?? 0
                    HStack(spacing: RQSpacing.sm) {
                        Text("\(dayCount) day\(dayCount == 1 ? "" : "s")")
                            .font(RQTypography.footnote)
                            .foregroundColor(RQColors.textSecondary)
                        Text("·")
                            .foregroundColor(RQColors.textTertiary)
                        Text("\(totalExercises) exercise\(totalExercises == 1 ? "" : "s")")
                            .font(RQTypography.footnote)
                            .foregroundColor(RQColors.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(RQColors.textTertiary)
            }
        }
    }
}
