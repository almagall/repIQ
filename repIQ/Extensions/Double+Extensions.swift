import Foundation

extension Double {
    var weightDisplay: String {
        if self == floor(self) {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }

    var rpeDisplay: String {
        if self == floor(self) {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }

    var volumeDisplay: String {
        if self >= 1000 {
            return String(format: "%.1fk", self / 1000)
        }
        return String(format: "%.0f", self)
    }
}
