import Foundation

enum URLSecurityScope {
    static func withAccess<T>(to url: URL, perform work: () throws -> T) rethrows -> T {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try work()
    }
}
