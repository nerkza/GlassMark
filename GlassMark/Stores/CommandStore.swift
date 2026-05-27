import Foundation

@MainActor
final class CommandStore: ObservableObject {
    @Published var isQuickOpenPresented = false

    func presentQuickOpen() {
        isQuickOpenPresented = true
    }
}
