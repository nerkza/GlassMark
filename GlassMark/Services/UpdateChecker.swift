#if DIRECT_DISTRIBUTION
import Foundation

/// A newer release found on GitHub.
struct GlassmarkRelease: Equatable {
    let version: String
    let name: String
    let notes: String
    let url: URL
}

enum UpdateCheckError: Error {
    case network
    case decoding
}

/// Checks GitHub Releases for a newer version. Dependency-free; only compiled into
/// the direct-download build (the App Store build updates itself), so the App Store
/// build makes no such network request.
struct UpdateChecker {
    var owner = "nerkza"
    var repo = "GlassMark"

    /// The running app's marketing version.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Splits a dotted version (tolerating a leading "v") into numeric components.
    static func components(of version: String) -> [Int] {
        let trimmed = version.first.map { $0 == "v" || $0 == "V" } == true ? String(version.dropFirst()) : version
        return trimmed.split(separator: ".").map { part in
            Int(part.prefix { $0.isNumber }) ?? 0
        }
    }

    /// True when `latest` is a strictly higher version than `current`.
    static func isVersion(_ latest: String, newerThan current: String) -> Bool {
        var a = components(of: latest)
        var b = components(of: current)
        let count = max(a.count, b.count)
        a += Array(repeating: 0, count: count - a.count)
        b += Array(repeating: 0, count: count - b.count)
        for index in 0..<count where a[index] != b[index] {
            return a[index] > b[index]
        }
        return false
    }

    /// Fetches the latest non-draft, non-prerelease release from GitHub.
    func latestRelease() async throws -> GlassmarkRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            throw UpdateCheckError.network
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Glassmark", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateCheckError.network
        }
        return try Self.parse(data)
    }

    /// Parses the GitHub `releases/latest` payload. Exposed for testing.
    static func parse(_ data: Data) throws -> GlassmarkRelease {
        struct Payload: Decodable {
            let tag_name: String
            let name: String?
            let body: String?
            let html_url: String
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let link = URL(string: payload.html_url) else {
            throw UpdateCheckError.decoding
        }
        return GlassmarkRelease(
            version: payload.tag_name,
            name: payload.name?.isEmpty == false ? payload.name! : payload.tag_name,
            notes: payload.body ?? "",
            url: link
        )
    }
}
#endif
