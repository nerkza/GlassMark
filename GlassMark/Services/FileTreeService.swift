import Foundation

struct FileTreeService {
    private let ignoredNames: Set<String> = [
        ".git",
        ".build",
        "DerivedData",
        "node_modules",
        "vendor",
        ".cache",
        ".swiftpm"
    ]

    func loadTree(rootURL: URL) throws -> [WorkspaceFile] {
        try children(of: rootURL, rootURL: rootURL)
    }

    private func children(of directory: URL, rootURL: URL) throws -> [WorkspaceFile] {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey, .nameKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants]
        )

        return try urls
            .filter { url in
                let values = try? url.resourceValues(forKeys: resourceKeys)
                guard values?.isHidden != true else { return false }
                return !ignoredNames.contains(url.lastPathComponent)
            }
            .sorted { left, right in
                let leftIsDirectory = (try? left.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                let rightIsDirectory = (try? right.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if leftIsDirectory != rightIsDirectory {
                    return leftIsDirectory && !rightIsDirectory
                }
                return left.lastPathComponent.localizedStandardCompare(right.lastPathComponent) == .orderedAscending
            }
            .compactMap { url in
                let values = try? url.resourceValues(forKeys: resourceKeys)
                let isDirectory = values?.isDirectory == true

                if isDirectory {
                    let nestedChildren = try children(of: url, rootURL: rootURL)
                    if nestedChildren.isEmpty { return nil }
                    return WorkspaceFile(url: url, rootURL: rootURL, kind: .folder, children: nestedChildren)
                }

                guard let fileType = FileType(url: url), fileType.shouldShowInSidebar else { return nil }
                return WorkspaceFile(url: url, rootURL: rootURL, kind: fileType.workspaceKind)
            }
    }
}
