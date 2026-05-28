import SwiftUI

extension Notification.Name {
    static let glassmarkCheckForUpdates = Notification.Name("glassmark.checkForUpdates")
}

extension View {
    /// Attaches the in-app updater (launch check, manual-check handling, and the
    /// result alert) in the direct-download build. A no-op in the App Store build,
    /// which updates through the App Store.
    func glassmarkUpdater() -> some View {
        #if DIRECT_DISTRIBUTION
        return modifier(UpdaterModifier())
        #else
        return self
        #endif
    }
}

#if DIRECT_DISTRIBUTION
private struct UpdaterModifier: ViewModifier {
    @EnvironmentObject private var preferencesStore: PreferencesStore
    @StateObject private var updateStore = UpdateStore()

    func body(content: Content) -> some View {
        content
            .task {
                if preferencesStore.automaticUpdateChecks {
                    updateStore.check(userInitiated: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .glassmarkCheckForUpdates)) { _ in
                updateStore.check(userInitiated: true)
            }
            .alert("Glassmark", isPresented: $updateStore.isResultPresented) {
                alertButtons
            } message: {
                alertMessage
            }
    }

    @ViewBuilder
    private var alertButtons: some View {
        switch updateStore.state {
        case .available(let release):
            Button("Download") { NSWorkspace.shared.open(release.url) }
            Button("Later", role: .cancel) {}
        default:
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var alertMessage: some View {
        switch updateStore.state {
        case .available(let release):
            Text("Glassmark \(release.version) is available. You have \(UpdateChecker.currentVersion).")
        case .upToDate:
            Text("You're on the latest version (\(UpdateChecker.currentVersion)).")
        case .failed:
            Text("Couldn't check for updates. Please try again later.")
        default:
            Text("")
        }
    }
}
#endif
