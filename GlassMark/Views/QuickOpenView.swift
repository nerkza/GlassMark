import SwiftUI

struct QuickOpenView: View {
    let files: [WorkspaceFile]
    let onOpen: (WorkspaceFile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var searchableFiles: [WorkspaceFile] {
        files.flattenedEditableFiles()
    }

    private var results: [WorkspaceFile] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return Array(searchableFiles.prefix(30))
        }

        let terms = trimmedQuery
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        return searchableFiles
            .filter { file in
                let haystack = "\(file.name) \(file.relativePath)".lowercased()
                return terms.allSatisfy { haystack.contains($0) }
            }
            .prefix(40)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search files by name or path…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit {
                        openFirstResult()
                    }
            }
            .padding(14)

            Divider()

            if results.isEmpty {
                ContentUnavailableView("No Files Found", systemImage: "doc.text.magnifyingglass")
                    .frame(height: 220)
            } else {
                List(results) { file in
                    Button {
                        open(file)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.name)
                                .font(.headline)
                                .lineLimit(1)

                            Text(file.relativePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 620, height: 460)
        .onAppear {
            isSearchFocused = true
        }
    }

    private func openFirstResult() {
        guard let firstResult = results.first else { return }
        open(firstResult)
    }

    private func open(_ file: WorkspaceFile) {
        onOpen(file)
        dismiss()
    }
}

private extension Array where Element == WorkspaceFile {
    func flattenedEditableFiles() -> [WorkspaceFile] {
        flatMap { file -> [WorkspaceFile] in
            var files: [WorkspaceFile] = file.isEditable ? [file] : []
            if let children = file.children {
                files.append(contentsOf: children.flattenedEditableFiles())
            }
            return files
        }
        .sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }
}
