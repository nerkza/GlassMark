import SwiftUI

struct SettingsView: View {
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
        .frame(width: 420)
    }
}
