import SwiftUI

/// Renders the user's weekly working-set count per muscle group against the
/// MEV (minimum effective), MAV (sweet spot), and MRV (max recoverable)
/// landmarks from Renaissance Periodization. Each row shows a horizontal
/// "track" with the user's current sets marked and a prescription chip when
/// they're outside the sweet spot.
struct VolumeLandmarksCard: View {
    let landmarks: [VolumeLandmarkData]

    var body: some View {
        VStack(alignment: .leading, spacing: RQSpacing.md) {
            RQSectionHeader(
                title: "WEEKLY VOLUME ZONES",
                infoTopic: ProgressExplainer.volumeLandmarks
            )

            RQCard {
                VStack(alignment: .leading, spacing: RQSpacing.md) {
                    legend
                    Divider().background(RQColors.surfaceTertiary)
                    ForEach(sortedLandmarks) { landmark in
                        landmarkRow(landmark)
                    }
                }
            }
        }
    }

    /// Sort by status urgency — below MEV first, above MRV second, then by
    /// progress through the range. Keeps action items at the top.
    private var sortedLandmarks: [VolumeLandmarkData] {
        landmarks.sorted { a, b in
            if a.status != b.status {
                return statusOrder(a.status) < statusOrder(b.status)
            }
            return a.displayName < b.displayName
        }
    }

    private func statusOrder(_ status: VolumeLandmarkStatus) -> Int {
        switch status {
        case .belowMEV: return 0
        case .aboveMRV: return 1
        case .approachingMRV: return 2
        case .withinMAV: return 3
        }
    }

    private var legend: some View {
        HStack(spacing: RQSpacing.md) {
            legendChip(color: RQColors.warning, label: "BELOW MEV")
            legendChip(color: RQColors.success, label: "SWEET SPOT")
            legendChip(color: RQColors.error, label: "OVER MRV")
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(RQColors.textTertiary)
        }
    }

    private func landmarkRow(_ landmark: VolumeLandmarkData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(landmark.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(landmark.color)
                Spacer()
                Text("\(landmark.currentWeeklySets) sets/wk")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(RQColors.textPrimary)
            }

            zoneTrack(landmark)

            HStack {
                Text("MEV \(landmark.mev) · MAV \(landmark.mav.lowerBound)–\(landmark.mav.upperBound) · MRV \(landmark.mrv)")
                    .font(.system(size: 9))
                    .foregroundColor(RQColors.textTertiary)
                Spacer()
                if let prescription = landmark.prescription {
                    Text(prescription.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(landmark.status.color)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Horizontal track showing the MEV→MRV range with the user's current
    /// sets marked. The sweet-spot segment (MAV range) is rendered slightly
    /// brighter than the surrounding under/over zones.
    private func zoneTrack(_ landmark: VolumeLandmarkData) -> some View {
        let scaleMax = Double(max(landmark.mrv + 4, landmark.currentWeeklySets + 2))
        let mev = Double(landmark.mev)
        let mavLower = Double(landmark.mav.lowerBound)
        let mavUpper = Double(landmark.mav.upperBound)
        let mrv = Double(landmark.mrv)
        let current = Double(landmark.currentWeeklySets)

        return GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Below MEV (warning hint)
                Rectangle()
                    .fill(RQColors.warning.opacity(0.15))
                    .frame(width: w * (mev / scaleMax), height: 8)
                    .offset(x: 0)

                // MEV → MAV lower (developing)
                Rectangle()
                    .fill(RQColors.info.opacity(0.20))
                    .frame(width: w * ((mavLower - mev) / scaleMax), height: 8)
                    .offset(x: w * (mev / scaleMax))

                // Sweet spot MAV range
                Rectangle()
                    .fill(RQColors.success.opacity(0.35))
                    .frame(width: w * ((mavUpper - mavLower) / scaleMax), height: 8)
                    .offset(x: w * (mavLower / scaleMax))

                // MAV upper → MRV (high but recoverable)
                Rectangle()
                    .fill(RQColors.warning.opacity(0.20))
                    .frame(width: w * ((mrv - mavUpper) / scaleMax), height: 8)
                    .offset(x: w * (mavUpper / scaleMax))

                // Above MRV (over-training)
                Rectangle()
                    .fill(RQColors.error.opacity(0.20))
                    .frame(width: w * ((scaleMax - mrv) / scaleMax), height: 8)
                    .offset(x: w * (mrv / scaleMax))

                // Current sets marker
                Rectangle()
                    .fill(landmark.status.color)
                    .frame(width: 2, height: 14)
                    .offset(x: max(0, min(w - 2, w * (current / scaleMax))))
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .frame(height: 14)
    }
}
