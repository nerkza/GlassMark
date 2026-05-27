import AppKit
import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var documentStore: DocumentStore
    @State private var pendingEditorAction: EditorActionRequest?

    var body: some View {
        VStack(spacing: 0) {
            EditorHeaderView()
            Divider()
            EditorFormattingToolbarView { action in
                pendingEditorAction = EditorActionRequest(action: action)
            }
            Divider()

            if let document = documentStore.document {
                MarkdownTextView(text: Binding(
                    get: { documentStore.document?.text ?? document.text },
                    set: { documentStore.updateText($0) }
                ), pendingAction: $pendingEditorAction)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct EditorFormattingToolbarView: View {
    let perform: (EditorAction) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                toolbarButton("Undo", systemImage: "arrow.uturn.backward") {
                    perform(.undo)
                }

                toolbarButton("Redo", systemImage: "arrow.uturn.forward") {
                    perform(.redo)
                }

                Divider()
                    .frame(height: 20)

                toolbarButton("Copy", systemImage: "doc.on.doc") {
                    perform(.copy)
                }

                toolbarButton("Paste", systemImage: "doc.on.clipboard") {
                    perform(.paste)
                }

                Divider()
                    .frame(height: 20)

                toolbarButton("H1") {
                    perform(.heading(level: 1))
                }

                toolbarButton("H2") {
                    perform(.heading(level: 2))
                }

                toolbarButton("H3") {
                    perform(.heading(level: 3))
                }

                Divider()
                    .frame(height: 20)

                toolbarButton("Bold", systemImage: "bold") {
                    perform(.bold)
                }

                toolbarButton("Italic", systemImage: "italic") {
                    perform(.italic)
                }

                toolbarButton("Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                    perform(.inlineCode)
                }

                toolbarButton("Bullet", systemImage: "list.bullet") {
                    perform(.bulletList)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }

    private func toolbarButton(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .labelStyle(.iconOnly)
            } else {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 28)
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help(title)
    }
}

private struct EditorHeaderView: View {
    @EnvironmentObject private var documentStore: DocumentStore

    var body: some View {
        HStack(spacing: 8) {
            Text(documentStore.document?.file.name ?? "Editor")
                .font(.headline)
                .lineLimit(1)

            if documentStore.document?.isDirty == true {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                    .help("Unsaved changes")
            }

            Spacer()

            if let saveMessage = documentStore.saveMessage {
                Text(saveMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var pendingAction: EditorActionRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 20, height: 18)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.text = $text

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        if let pendingAction, context.coordinator.lastHandledActionID != pendingAction.id {
            context.coordinator.lastHandledActionID = pendingAction.id
            context.coordinator.perform(pendingAction.action)
            DispatchQueue.main.async {
                self.pendingAction = nil
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        var lastHandledActionID: UUID?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        func perform(_ action: EditorAction) {
            guard let textView else { return }

            textView.window?.makeFirstResponder(textView)

            switch action {
            case .undo:
                textView.undoManager?.undo()
            case .redo:
                textView.undoManager?.redo()
            case .copy:
                textView.copy(nil)
            case .paste:
                textView.paste(nil)
            case .bold:
                wrapSelection(prefix: "**", suffix: "**", placeholder: "bold text")
            case .italic:
                wrapSelection(prefix: "_", suffix: "_", placeholder: "italic text")
            case .inlineCode:
                wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
            case .heading(let level):
                applyLinePrefix(String(repeating: "#", count: level) + " ")
            case .bulletList:
                applyLinePrefix("- ")
            }

            text.wrappedValue = textView.string
        }

        private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
            guard let textView else { return }

            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let selectedText = selectedRange.length > 0 ? nsString.substring(with: selectedRange) : placeholder
            let replacement = "\(prefix)\(selectedText)\(suffix)"

            textView.insertText(replacement, replacementRange: selectedRange)

            if selectedRange.length == 0 {
                textView.setSelectedRange(NSRange(location: selectedRange.location + prefix.count, length: placeholder.count))
            } else {
                textView.setSelectedRange(NSRange(location: selectedRange.location, length: replacement.count))
            }
        }

        private func applyLinePrefix(_ prefix: String) {
            guard let textView else { return }

            let string = textView.string as NSString
            let selectedRange = textView.selectedRange()
            let lineRange = string.lineRange(for: selectedRange)
            let selectedLines = string.substring(with: lineRange)
            let lineComponents = selectedLines.components(separatedBy: .newlines)
            let replacement = selectedLines
                .components(separatedBy: .newlines)
                .enumerated()
                .map { index, line in
                    guard !line.isEmpty || index < lineComponents.count - 1 else {
                        return line
                    }

                    let trimmedLine = line.replacingOccurrences(
                        of: #"^(#{1,6}\s+|-\s+)"#,
                        with: "",
                        options: .regularExpression
                    )
                    return prefix + trimmedLine
                }
                .joined(separator: "\n")

            textView.insertText(replacement, replacementRange: lineRange)
            textView.setSelectedRange(NSRange(location: lineRange.location, length: replacement.count))
        }
    }
}

private struct EditorActionRequest: Identifiable, Equatable {
    let id = UUID()
    let action: EditorAction
}

private enum EditorAction: Equatable {
    case undo
    case redo
    case copy
    case paste
    case bold
    case italic
    case inlineCode
    case heading(level: Int)
    case bulletList
}
