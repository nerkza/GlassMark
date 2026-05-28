#if DIRECT_DISTRIBUTION
import Foundation

/// Drives the "Check for Updates" flow in the direct-download build. Compiled out
/// of the App Store build, which updates through the App Store instead.
@MainActor
final class UpdateStore: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(GlassmarkRelease)
        case failed
    }

    @Published private(set) var state: State = .idle
    /// Set when there's a result worth showing the user (drives the alert).
    @Published var isResultPresented = false

    private let checker = UpdateChecker()

    /// `userInitiated` checks always report the outcome; background (launch)
    /// checks stay silent unless an update is actually available.
    func check(userInitiated: Bool) {
        guard state != .checking else { return }
        state = .checking

        Task {
            do {
                let release = try await checker.latestRelease()
                if UpdateChecker.isVersion(release.version, newerThan: UpdateChecker.currentVersion) {
                    state = .available(release)
                    isResultPresented = true
                } else {
                    state = .upToDate
                    isResultPresented = userInitiated
                }
            } catch {
                state = .failed
                isResultPresented = userInitiated
            }
        }
    }
}
#endif
