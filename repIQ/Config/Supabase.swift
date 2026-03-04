import Foundation
import Supabase

enum SupabaseConfig {
    // TODO: Replace with your Supabase project credentials
    static let url = URL(string: "https://yuwtotiahdmnjplrumdu.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1d3RvdGlhaGRtbmpwbHJ1bWR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1MTkwNjQsImV4cCI6MjA4ODA5NTA2NH0.sSR0SRUMSJ6Oe69nbkZNd71_jgNxJ3N1fsB7nTt7V4k"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
