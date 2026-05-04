import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://yuwtotiahdmnjplrumdu.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1d3RvdGlhaGRtbmpwbHJ1bWR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1MTkwNjQsImV4cCI6MjA4ODA5NTA2NH0.sSR0SRUMSJ6Oe69nbkZNd71_jgNxJ3N1fsB7nTt7V4k"
    static let redirectURL = URL(string: "repiq://auth/callback")!
}

/// JSON decoder used for every Postgrest query response. Postgres returns
/// DATE columns as bare "yyyy-MM-dd" strings and TIMESTAMPTZ columns as
/// ISO8601 with varying fractional-second precision. The default decoder
/// chokes on the bare DATE form (e.g. monthly_wrapped.month_start), so we
/// install a permissive `.custom` strategy that tries each format in turn.
private let postgrestDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
    let plainTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        // ISO8601DateFormatter handles most TIMESTAMPTZ variants natively.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: str) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: str) { return date }
        if let date = plainTimestamp.date(from: str) { return date }
        if let date = dateOnly.date(from: str) { return date }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unrecognized date string from Postgrest: \(str)"
        )
    }
    return decoder
}()

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(
        db: SupabaseClientOptions.DatabaseOptions(
            decoder: postgrestDecoder
        )
    )
)
