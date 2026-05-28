import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            EditorSettingsView()
                .tabItem { Label("Editor", systemImage: "square.and.pencil") }
            PreviewSettingsView()
                .tabItem { Label("Preview", systemImage: "doc.richtext") }
        }
        .frame(width: 460)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Picker("Appearance", selection: $preferencesStore.appearancePreference) {
                ForEach(AppearancePreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }

            Picker("Default View", selection: $preferencesStore.viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle("Autosave", isOn: $preferencesStore.autosaveEnabled)
            Text("When on, edits are written to disk automatically a moment after you stop typing. Manual save (⌘S) is always available.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

private struct EditorSettingsView: View {
    @EnvironmentObject private var preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Toggle("Focus mode", isOn: $preferencesStore.focusModeEnabled)
            Text("Dims all but the paragraph you're editing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Typewriter scrolling", isOn: $preferencesStore.typewriterModeEnabled)
            Text("Keeps the line you're editing vertically centered.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

private struct PreviewSettingsView: View {
    @EnvironmentObject private var preferencesStore: PreferencesStore

    var body: some View {
        Form {
            Picker("Theme", selection: $preferencesStore.previewTheme) {
                ForEach(PreviewTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }

            Section("Custom CSS") {
                TextEditor(text: $preferencesStore.customPreviewCSS)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 140)
                    .border(Color.secondary.opacity(0.3))
                Text("Applied on top of the selected theme. Targets standard elements (h1, p, code, table…).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}
