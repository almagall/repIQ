import SwiftUI

struct TemplateManagementView: View {
    @Bindable var viewModel: TemplateListViewModel
    @State private var showCreateTemplate = false
    @State private var showProgramBrowser = false
    @State private var showNewTemplateOptions = false

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.md) {
                ForEach(viewModel.templates) { template in
                    NavigationLink {
                        TemplateDetailView(
                            template: template,
                            onDelete: {
                                Task { await viewModel.deleteTemplate(template) }
                            },
                            onDuplicate: {
                                await viewModel.duplicateTemplate(template)
                            }
                        )
                    } label: {
                        templateCard(template)
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("My Templates")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewTemplateOptions = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(RQColors.accent)
                }
            }
        }
        .confirmationDialog("New Template", isPresented: $showNewTemplateOptions, titleVisibility: .visible) {
            Button("Custom Template") {
                showCreateTemplate = true
            }
            Button("Browse Programs") {
                showProgramBrowser = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Create your own template or choose from proven workout programs.")
        }
        .navigationDestination(isPresented: $showCreateTemplate) {
            TemplateEditorView(viewModel: TemplateEditorViewModel())
        }
        .navigationDestination(isPresented: $showProgramBrowser) {
            ProgramBrowserView(onProgramCreated: {
                showProgramBrowser = false
                Task { await viewModel.loadTemplates() }
            })
        }
        .task {
            await viewModel.loadTemplates()
        }
        .refreshable {
            await viewModel.loadTemplates()
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
                        Text("\u{00B7}")
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
