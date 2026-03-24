import SwiftUI
import MapKit
import Supabase

struct GymSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var currentGymName: String?
    @State private var currentGymPlaceId: String?
    @State private var isSaving = false
    @State private var showRemoveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Current gym display
            if let gymName = currentGymName {
                RQCard {
                    HStack(spacing: RQSpacing.md) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 20))
                            .foregroundColor(RQColors.accent)

                        VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                            Text("Current Gym")
                                .font(RQTypography.label)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundColor(RQColors.textSecondary)

                            Text(gymName)
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                        }

                        Spacer()

                        Button {
                            showRemoveConfirmation = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(RQColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.md)
            }

            // Search bar
            HStack(spacing: RQSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(RQColors.textTertiary)

                TextField("Search for your gym", text: $searchText)
                    .font(RQTypography.body)
                    .foregroundColor(RQColors.textPrimary)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await performSearch() }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(RQColors.textTertiary)
                    }
                }
            }
            .padding(RQSpacing.md)
            .background(RQColors.surfaceTertiary)
            .cornerRadius(RQRadius.medium)
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.md)

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    if isSearching {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: RQColors.accent))
                            Text("Searching nearby gyms...")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        .padding(.top, RQSpacing.xl)
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        VStack(spacing: RQSpacing.md) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 28))
                                .foregroundColor(RQColors.textTertiary)
                            Text("No gyms found")
                                .font(RQTypography.headline)
                                .foregroundColor(RQColors.textPrimary)
                            Text("Try a different search term")
                                .font(RQTypography.caption)
                                .foregroundColor(RQColors.textTertiary)
                        }
                        .padding(.top, RQSpacing.xl)
                    } else {
                        ForEach(searchResults, id: \.self) { item in
                            gymResultRow(item)
                        }
                    }
                }
                .padding(.horizontal, RQSpacing.screenHorizontal)
                .padding(.top, RQSpacing.md)
            }
        }
        .background(RQColors.background)
        .navigationTitle("My Gym")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadCurrentGym()
        }
        .onChange(of: searchText) {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !searchText.isEmpty else {
                    searchResults = []
                    return
                }
                await performSearch()
            }
        }
        .confirmationDialog("Remove Gym", isPresented: $showRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task { await removeGym() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove your gym from your profile?")
        }
    }

    // MARK: - Gym Result Row

    @ViewBuilder
    private func gymResultRow(_ item: MKMapItem) -> some View {
        Button {
            Task { await selectGym(item) }
        } label: {
            HStack(spacing: RQSpacing.md) {
                Image(systemName: "building.2")
                    .font(.system(size: 16))
                    .foregroundColor(RQColors.accent)
                    .frame(width: 32, height: 32)
                    .background(RQColors.accent.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                    Text(item.name ?? "Unknown")
                        .font(RQTypography.body)
                        .fontWeight(.medium)
                        .foregroundColor(RQColors.textPrimary)

                    if let address = formatAddress(item) {
                        Text(address)
                            .font(RQTypography.caption)
                            .foregroundColor(RQColors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if item.placemark.title == currentGymPlaceId || item.name == currentGymName {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(RQColors.accent)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(RQColors.textTertiary)
                }
            }
            .padding(.vertical, RQSpacing.sm)
        }

        Divider().background(RQColors.surfaceTertiary)
    }

    // MARK: - Actions

    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText + " gym fitness"
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems.filter { item in
                // Filter to fitness-related POIs
                let name = (item.name ?? "").lowercased()
                let category = item.pointOfInterestCategory?.rawValue.lowercased() ?? ""
                return category.contains("fitness") ||
                       category.contains("gym") ||
                       name.contains("gym") ||
                       name.contains("fitness") ||
                       name.contains("crossfit") ||
                       name.contains("yoga") ||
                       name.contains("pilates") ||
                       name.contains("planet") ||
                       name.contains("equinox") ||
                       name.contains("anytime") ||
                       name.contains("gold") ||
                       name.contains("crunch") ||
                       name.contains("24 hour") ||
                       name.contains("la fitness") ||
                       name.contains("ymca") ||
                       !category.isEmpty // Include all POIs from the search
            }
        } catch {
            searchResults = []
        }

        isSearching = false
    }

    private func selectGym(_ item: MKMapItem) async {
        isSaving = true
        let name = item.name ?? "Unknown Gym"
        // Use a combination of name + coordinates as a stable identifier
        let placeId = "\(name)_\(item.placemark.coordinate.latitude)_\(item.placemark.coordinate.longitude)"

        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            try await GymService().updateGym(
                userId: userId,
                name: name,
                placeId: placeId,
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            currentGymName = name
            currentGymPlaceId = placeId
            searchText = ""
            searchResults = []
        } catch {}
        isSaving = false
    }

    private func removeGym() async {
        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            try await GymService().removeGym(userId: userId)
            currentGymName = nil
            currentGymPlaceId = nil
        } catch {}
    }

    private func loadCurrentGym() async {
        struct GymFields: Decodable {
            let gymName: String?
            let gymPlaceId: String?
            enum CodingKeys: String, CodingKey {
                case gymName = "gym_name"
                case gymPlaceId = "gym_place_id"
            }
        }

        do {
            guard let userId = try? await supabase.auth.session.user.id else { return }
            let fields: GymFields = try await supabase.from("profiles")
                .select("gym_name, gym_place_id")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            currentGymName = fields.gymName
            currentGymPlaceId = fields.gymPlaceId
        } catch {}
    }

    // MARK: - Helpers

    private func formatAddress(_ item: MKMapItem) -> String? {
        let placemark = item.placemark
        var parts: [String] = []
        if let street = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                parts.append("\(number) \(street)")
            } else {
                parts.append(street)
            }
        }
        if let city = placemark.locality { parts.append(city) }
        if let state = placemark.administrativeArea { parts.append(state) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
