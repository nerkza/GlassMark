import SwiftUI

/// Heading-based outline of the active document. Selecting an entry scrolls the
/// editor to that heading.
struct OutlineView: View {
    @EnvironmentObject private var documentStore: DocumentStore
    @EnvironmentObject private var commandStore: CommandStore

    var body: some View {
        let items = MarkdownOutline.items(from: documentStore.document?.text ?? "")

        Group {
            if documentStore.document == nil {
                ContentUnavailableView("No Document", systemImage: "list.bullet.indent")
            } else if items.isEmpty {
                ContentUnavailableView("No Headings", systemImage: "number")
            } else {
                List(items) { item in
                    Button {
                        commandStore.scrollToOutlineItem(characterIndex: item.characterIndex)
                    } label: {
                        Text(item.title)
                            .lineLimit(1)
                            .padding(.leading, CGFloat(item.level - 1) * 14)
                            .font(item.level <= 1 ? .body.weight(.semibold) : .body)
                            .foregroundStyle(item.level <= 2 ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Outline")
    }
}
