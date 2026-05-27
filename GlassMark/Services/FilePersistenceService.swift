import Foundation

struct FilePersistenceService {
    func readText(from url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func writeText(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func createMarkdownFile(in directory: URL) throws -> URL {
        let fileURL = uniqueFileURL(in: directory, baseName: "Untitled", extension: "md")
        try "# Untitled\n\n".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func createMarkdownFile(nextTo file: WorkspaceFile) throws -> URL {
        let directory = file.isDirectory ? file.url : file.url.deletingLastPathComponent()
        return try createMarkdownFile(in: directory)
    }

    func createFolder(nextTo file: WorkspaceFile) throws -> URL {
        let directory = file.isDirectory ? file.url : file.url.deletingLastPathComponent()
        let folderURL = uniqueFolderURL(in: directory, baseName: "New Folder")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return folderURL
    }

    func rename(_ file: WorkspaceFile, to proposedName: String) throws -> URL {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw CocoaError(.fileWriteInvalidFileName)
        }

        let destinationURL = file.url.deletingLastPathComponent().appendingPathComponent(trimmedName)
        guard destinationURL != file.url else {
            return file.url
        }

        guard !FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) else {
            throw CocoaError(.fileWriteFileExists)
        }

        try FileManager.default.moveItem(at: file.url, to: destinationURL)
        return destinationURL
    }

    func move(_ file: WorkspaceFile, to target: WorkspaceFile) throws -> URL {
        let destinationDirectory = target.isDirectory ? target.url : target.url.deletingLastPathComponent()
        let destinationURL = destinationDirectory.appendingPathComponent(file.name)

        guard file.url != destinationURL else {
            return file.url
        }

        guard !destinationURL.path.hasPrefix(file.url.path + "/") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }

        guard !FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) else {
            throw CocoaError(.fileWriteFileExists)
        }

        try FileManager.default.moveItem(at: file.url, to: destinationURL)
        return destinationURL
    }

    func duplicate(_ file: WorkspaceFile) throws -> URL {
        let destinationURL = uniqueCopyURL(for: file.url)
        try FileManager.default.copyItem(at: file.url, to: destinationURL)
        return destinationURL
    }

    func copy(_ file: WorkspaceFile, to target: WorkspaceFile) throws -> URL {
        let destinationDirectory = target.isDirectory ? target.url : target.url.deletingLastPathComponent()
        let destinationURL = uniqueFileOrFolderURL(
            in: destinationDirectory,
            originalName: file.url.deletingPathExtension().lastPathComponent,
            extension: file.url.pathExtension,
            isDirectory: file.isDirectory
        )

        try FileManager.default.copyItem(at: file.url, to: destinationURL)
        return destinationURL
    }

    func moveToTrash(_ file: WorkspaceFile) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: file.url, resultingItemURL: &resultingURL)
    }

    private func uniqueFileURL(in directory: URL, baseName: String, extension fileExtension: String) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent("\(baseName).\(fileExtension)")

        guard fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) else {
            return candidate
        }

        var index = 2
        repeat {
            candidate = directory.appendingPathComponent("\(baseName) \(index).\(fileExtension)")
            index += 1
        } while fileManager.fileExists(atPath: candidate.path(percentEncoded: false))

        return candidate
    }

    private func uniqueFolderURL(in directory: URL, baseName: String) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(baseName)

        guard fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) else {
            return candidate
        }

        var index = 2
        repeat {
            candidate = directory.appendingPathComponent("\(baseName) \(index)")
            index += 1
        } while fileManager.fileExists(atPath: candidate.path(percentEncoded: false))

        return candidate
    }

    private func uniqueCopyURL(for url: URL) -> URL {
        uniqueFileOrFolderURL(
            in: url.deletingLastPathComponent(),
            originalName: url.deletingPathExtension().lastPathComponent,
            extension: url.pathExtension,
            isDirectory: isDirectory(url)
        )
    }

    private func uniqueFileOrFolderURL(
        in directory: URL,
        originalName: String,
        extension fileExtension: String,
        isDirectory: Bool
    ) -> URL {
        let fileManager = FileManager.default

        func candidate(copyIndex: Int?) -> URL {
            let suffix = copyIndex.map { " Copy \($0)" } ?? " Copy"
            let name = originalName + suffix

            if isDirectory || fileExtension.isEmpty {
                return directory.appendingPathComponent(name)
            }

            return directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        }

        var nextCandidate = candidate(copyIndex: nil)
        guard fileManager.fileExists(atPath: nextCandidate.path(percentEncoded: false)) else {
            return nextCandidate
        }

        var index = 2
        repeat {
            nextCandidate = candidate(copyIndex: index)
            index += 1
        } while fileManager.fileExists(atPath: nextCandidate.path(percentEncoded: false))

        return nextCandidate
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
