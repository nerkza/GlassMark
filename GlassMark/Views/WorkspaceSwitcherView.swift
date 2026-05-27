import SwiftUI

struct WorkspaceSwitcherView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workspaceStore.activeWorkspace?.displayName ?? "GlassMark")
                        .font(.headline)
                        .lineLimit(1)
                    Text(workspaceStore.activeWorkspace?.rootURL.path(percentEncoded: false) ?? "Local Markdown workspace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button {
                    workspaceStore.presentWorkspacePicker()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .help("Open Workspace")
            }
        }
    }
}
