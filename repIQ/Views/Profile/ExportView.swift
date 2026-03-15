import SwiftUI
import Supabase
import UniformTypeIdentifiers

struct ExportView: View {
    @State private var isExportingCSV = false
    @State private var isExportingPDF = false
    @State private var csvData: String?
    @State private var pdfData: Data?
    @State private var showCSVShare = false
    @State private var showPDFShare = false
    @State private var errorMessage: String?

    private let exportService = ExportService()

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // CSV Export
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        HStack {
                            Image(systemName: "tablecells")
                                .font(.system(size: 20))
                                .foregroundColor(RQColors.accent)

                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text("CSV Export")
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                                Text("Spreadsheet-compatible format for detailed analysis")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }

                        RQButton(title: "Export CSV", style: .secondary, isLoading: isExportingCSV) {
                            Task { await exportCSV() }
                        }
                    }
                }

                // PDF Export
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        HStack {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 20))
                                .foregroundColor(RQColors.accent)

                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text("PDF Report")
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                                Text("Formatted training log for printing or sharing with a coach")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }

                        RQButton(title: "Export PDF", style: .secondary, isLoading: isExportingPDF) {
                            Task { await exportPDF() }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(RQTypography.caption)
                        .foregroundColor(RQColors.error)
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showCSVShare) {
            if let csvData {
                let tempURL = saveToTemp(data: Data(csvData.utf8), filename: "repiq-export.csv")
                ShareSheet(items: [tempURL])
            }
        }
        .sheet(isPresented: $showPDFShare) {
            if let pdfData {
                let tempURL = saveToTemp(data: pdfData, filename: "repiq-training-log.pdf")
                ShareSheet(items: [tempURL])
            }
        }
    }

    private func exportCSV() async {
        isExportingCSV = true
        errorMessage = nil
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            csvData = try await exportService.generateCSV(userId: userId)
            showCSVShare = true
        } catch {
            errorMessage = "Failed to generate CSV."
        }
        isExportingCSV = false
    }

    private func exportPDF() async {
        isExportingPDF = true
        errorMessage = nil
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            pdfData = try await exportService.generatePDFData(userId: userId)
            showPDFShare = true
        } catch {
            errorMessage = "Failed to generate PDF."
        }
        isExportingPDF = false
    }

    private func saveToTemp(data: Data, filename: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}

// ShareSheet is defined in WorkoutSummaryView.swift and reused here.
