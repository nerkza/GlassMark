import SwiftUI

@MainActor
final class PreferencesStore: ObservableObject {
    @AppStorage("viewMode") var viewMode: ViewMode = .split
    @AppStorage("appearancePreference") var appearancePreference: AppearancePreference = .system
    @AppStorage("autosaveEnabled") var autosaveEnabled = false
    @AppStorage("previewTheme") var previewTheme: PreviewTheme = .system
    @AppStorage("customPreviewCSS") var customPreviewCSS = ""
    @AppStorage("focusModeEnabled") var focusModeEnabled = false
    @AppStorage("typewriterModeEnabled") var typewriterModeEnabled = false
    /// Direct-download build only: check GitHub for a newer release on launch.
    @AppStorage("automaticUpdateChecks") var automaticUpdateChecks = true

    var resolvedColorScheme: ColorScheme? {
        switch appearancePreference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Preview stylesheet themes layered on top of the base GitHub-style CSS.
enum PreviewTheme: String, CaseIterable, Codable, Identifiable {
    case system
    case sepia
    case highContrast
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .sepia: "Sepia"
        case .highContrast: "High Contrast"
        case .dark: "Dark"
        }
    }

    /// CSS overrides applied after the base stylesheet.
    var css: String {
        switch self {
        case .system:
            return ""
        case .sepia:
            return """
            body { background: #f4ecd8; color: #5b4636; }
            a { color: #8a5a2b; }
            pre, code { background: #eadfc4; }
            th { background: #eadfc4; }
            """
        case .highContrast:
            return """
            body { background: #ffffff; color: #000000; }
            a { color: #0000ee; }
            pre, code { background: #f0f0f0; border-color: #000; }
            h2 { border-bottom-color: #000; }
            """
        case .dark:
            return """
            body { background: #1e1e1e; color: #e6e6e6; }
            a { color: #6cb6ff; }
            pre { background: #2a2a2a; border-color: #3a3a3a; }
            code { background: #2a2a2a; }
            th { background: #2a2a2a; }
            """
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
