import SwiftUI

@MainActor
final class PreferencesStore: ObservableObject {
    @AppStorage("viewMode") var viewMode: ViewMode = .split
    @AppStorage("appearancePreference") var appearancePreference: AppearancePreference = .system
    @AppStorage("autosaveEnabled") var autosaveEnabled = false

    var resolvedColorScheme: ColorScheme? {
        switch appearancePreference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppearancePreference: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
