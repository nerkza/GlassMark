import SwiftUI

/// Heading-based outline of the active document. Selecting an entry scrolls the
/// editor to that heading, and the heading nearest the top of the editor is
/// highlighted as you scroll.
struct OutlineView: View {
    @EnvironmentObject private var documentStore: DocumentStore
    @EnvironmentObject private var commandStore: CommandStore

    var body: some View {
        let items = MarkdownOutline.items(from: documentStore.document?.text ?? "")
        let activeID = activeItemID(in: items)

        Group {
            if documentStore.document == nil {
                ContentUnavailableView("No Document", systemImage: "list.bullet.indent")
            } else if items.isEmpty {
                ContentUnavailableView("No Headings", systemImage: "number")
            } else {
                ScrollViewReader { proxy in
                    List(Array(items.enumerated()), id: \.element.id) { ordinal, item in
                        row(for: item, ordinal: ordinal, isActive: item.id == activeID)
                            .id(item.id)
                    }
                    .listStyle(.sidebar)
                    .onChange(of: activeID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func row(for item: MarkdownOutlineItem, ordinal: Int, isActive: Bool) -> some View {
        Button {
            commandStore.scrollToOutlineItem(characterIndex: item.characterIndex, headingOrdinal: ordinal)
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isActive ? Color.accentColor : Color.clear)
                    .frame(width: 2.5)
                    .padding(.trailing, 6)

                Text(item.title)
                    .lineLimit(1)
                    .padding(.leading, CGFloat(item.level - 1) * 14)
                    .font(font(for: item, isActive: isActive))
                    .foregroundStyle(foreground(for: item, isActive: isActive))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    private func font(for item: MarkdownOutlineItem, isActive: Bool) -> Font {
        if isActive { return .body.weight(.semibold) }
        return item.level <= 1 ? .body.weight(.semibold) : .body
    }

    private func foreground(for item: MarkdownOutlineItem, isActive: Bool) -> Color {
        if isActive { return .accentColor }
        return item.level <= 2 ? .primary : .secondary
    }

    /// The last heading at or above the current editor scroll position.
    private func activeItemID(in items: [MarkdownOutlineItem]) -> Int? {
        let location = commandStore.activeOutlineCharacterIndex
        return items.last(where: { $0.characterIndex <= location })?.id ?? items.first?.id
    }
}
