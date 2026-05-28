import AppKit
import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var documentStore: DocumentStore
    @EnvironmentObject private var commandStore: CommandStore

    var body: some View {
        VStack(spacing: 0) {
            EditorFormattingToolbarView { command in
                commandStore.run(command)
            }
            Divider()

            if let document = documentStore.document {
                MarkdownTextView(
                    text: Binding(
                        get: { documentStore.document?.text ?? document.text },
                        set: { documentStore.updateText($0) }
                    ),
                    pendingCommand: pendingCommandBinding,
                    scrollRequest: scrollRequestBinding,
                    activeLocation: activeLocationBinding,
                    scrollSync: commandStore.scrollSync,
                    onScroll: { commandStore.publishScroll(fraction: $0, source: .editor) }
                )
            }

            Divider()
            EditorStatusBarView()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var pendingCommandBinding: Binding<EditorCommandRequest?> {
        Binding(
            get: { commandStore.pendingEditorCommand },
            set: { commandStore.pendingEditorCommand = $0 }
        )
    }

    private var scrollRequestBinding: Binding<OutlineScrollRequest?> {
        Binding(
            get: { commandStore.outlineScrollRequest },
            set: { commandStore.outlineScrollRequest = $0 }
        )
    }

    private var activeLocationBinding: Binding<Int> {
        Binding(
            get: { commandStore.activeOutlineCharacterIndex },
            set: { commandStore.activeOutlineCharacterIndex = $0 }
        )
    }
}

private struct EditorStatusBarView: View {
    @EnvironmentObject private var documentStore: DocumentStore

    var body: some View {
        let statistics = DocumentStatistics(text: documentStore.document?.text ?? "")

        HStack(spacing: 10) {
            Text(documentStore.document?.file.relativePath ?? "")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            saveStatus

            Text("\(statistics.words) words")
            Text("\(statistics.characters) chars")
            Text("\(statistics.lines) lines")
            if statistics.readingMinutes > 0 {
                Text("~\(statistics.readingMinutes) min read")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(.bar)
    }

    @ViewBuilder
    private var saveStatus: some View {
        if documentStore.document?.isDirty == true {
            HStack(spacing: 5) {
                Circle().fill(.orange).frame(width: 7, height: 7)
                Text("Unsaved")
            }
        } else if let saveMessage = documentStore.saveMessage {
            Text(saveMessage)
        } else if documentStore.document != nil {
            Text("Saved")
        }
    }
}

private struct EditorFormattingToolbarView: View {
    let perform: (EditorCommand) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                button("Undo", systemImage: "arrow.uturn.backward") { perform(.undo) }
                button("Redo", systemImage: "arrow.uturn.forward") { perform(.redo) }

                divider

                textButton("H1") { perform(.heading(level: 1)) }
                textButton("H2") { perform(.heading(level: 2)) }
                textButton("H3") { perform(.heading(level: 3)) }

                divider

                button("Bold", systemImage: "bold") { perform(.bold) }
                button("Italic", systemImage: "italic") { perform(.italic) }
                button("Strikethrough", systemImage: "strikethrough") { perform(.strikethrough) }
                button("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right") { perform(.inlineCode) }
                button("Link", systemImage: "link") { perform(.link) }

                divider

                button("Bulleted List", systemImage: "list.bullet") { perform(.bulletList) }
                button("Numbered List", systemImage: "list.number") { perform(.numberList) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }

    private var divider: some View {
        Divider().frame(height: 20)
    }

    private func button(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage).labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help(title)
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.semibold)).frame(minWidth: 28)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help("Heading \(title.dropFirst())")
    }
}

private struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var pendingCommand: EditorCommandRequest?
    @Binding var scrollRequest: OutlineScrollRequest?
    @Binding var activeLocation: Int
    let scrollSync: ScrollSync?
    let onScroll: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, activeLocation: $activeLocation)
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
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
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

        textView.string = text
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.onScroll = onScroll
        context.coordinator.observeScrolling(of: scrollView)
        context.coordinator.applyHighlighting()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        context.coordinator.text = $text
        context.coordinator.activeLocation = $activeLocation
        context.coordinator.onScroll = onScroll

        if let scrollSync, scrollSync.source == .preview,
           context.coordinator.lastHandledSyncToken != scrollSync.token {
            context.coordinator.lastHandledSyncToken = scrollSync.token
            context.coordinator.applyExternalScroll(fraction: scrollSync.fraction)
        }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting()
        }

        if let pendingCommand, context.coordinator.lastHandledCommandID != pendingCommand.id {
            context.coordinator.lastHandledCommandID = pendingCommand.id
            context.coordinator.perform(pendingCommand.command)
            DispatchQueue.main.async { self.pendingCommand = nil }
        }

        if let scrollRequest, context.coordinator.lastHandledScrollID != scrollRequest.id {
            context.coordinator.lastHandledScrollID = scrollRequest.id
            context.coordinator.scroll(toCharacterIndex: scrollRequest.characterIndex)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var activeLocation: Binding<Int>
        var onScroll: ((Double) -> Void)?
        weak var textView: NSTextView?
        var lastHandledCommandID: UUID?
        var lastHandledScrollID: UUID?
        var lastHandledSyncToken: Int?

        private let highlighter = MarkdownSyntaxHighlighter()
        private let baseFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        private var isObservingScrolling = false
        private var isApplyingExternalScroll = false

        init(text: Binding<String>, activeLocation: Binding<Int>) {
            self.text = text
            self.activeLocation = activeLocation
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func observeScrolling(of scrollView: NSScrollView) {
            guard !isObservingScrolling else { return }
            isObservingScrolling = true
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBoundsChange),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }

        @objc private func handleBoundsChange() {
            updateActiveLocation()
            guard !isApplyingExternalScroll else { return }
            publishScrollFraction()
        }

        private func publishScrollFraction() {
            guard let textView,
                  let scrollView = textView.enclosingScrollView,
                  let documentView = scrollView.documentView else { return }
            let clipView = scrollView.contentView
            let maxY = max(0, documentView.frame.height - clipView.bounds.height)
            let fraction = maxY > 0 ? clipView.bounds.origin.y / maxY : 0
            onScroll?(Double(fraction))
        }

        func applyExternalScroll(fraction: Double) {
            guard let textView,
                  let scrollView = textView.enclosingScrollView,
                  let documentView = scrollView.documentView else { return }
            let clipView = scrollView.contentView
            let maxY = max(0, documentView.frame.height - clipView.bounds.height)
            isApplyingExternalScroll = true
            clipView.setBoundsOrigin(NSPoint(x: 0, y: CGFloat(fraction) * maxY))
            scrollView.reflectScrolledClipView(clipView)
            DispatchQueue.main.async { [weak self] in
                self?.isApplyingExternalScroll = false
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            applyHighlighting()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateActiveLocation()
        }

        // MARK: - List continuation

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            return continueListIfNeeded(in: textView)
        }

        private func continueListIfNeeded(in textView: NSTextView) -> Bool {
            let nsString = textView.string as NSString
            let selectedRange = textView.selectedRange()
            let lineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let line = nsString.substring(with: lineRange).trimmingCharacters(in: .newlines)

            guard let marker = listContinuation(for: line) else { return false }

            if marker.isItemEmpty {
                // Empty list item: remove the marker and break out of the list.
                textView.insertText("", replacementRange: lineRange)
                return true
            }

            textView.insertText("\n\(marker.next)", replacementRange: selectedRange)
            return true
        }

        private func listContinuation(for line: String) -> (next: String, isItemEmpty: Bool)? {
            let indentCount = line.prefix(while: { $0 == " " }).count
            let indent = String(repeating: " ", count: indentCount)
            let trimmed = line.dropFirst(indentCount)

            // Task item.
            for token in ["- [ ] ", "- [x] ", "* [ ] ", "* [x] "] where trimmed.hasPrefix(token) {
                let isEmpty = trimmed.count == token.count
                return ("\(indent)- [ ] ", isEmpty)
            }

            // Unordered.
            for bullet in ["- ", "* ", "+ "] where trimmed.hasPrefix(bullet) {
                let isEmpty = trimmed.count == bullet.count
                return ("\(indent)\(bullet)", isEmpty)
            }

            // Ordered.
            let chars = Array(trimmed)
            var cursor = 0
            while cursor < chars.count, chars[cursor].isNumber { cursor += 1 }
            if cursor > 0, cursor < chars.count, chars[cursor] == "." || chars[cursor] == ")",
               cursor + 1 < chars.count, chars[cursor + 1] == " " {
                let number = Int(String(chars[0..<cursor])) ?? 1
                let separator = chars[cursor]
                let isEmpty = chars.count == cursor + 2
                return ("\(indent)\(number + 1)\(separator) ", isEmpty)
            }

            return nil
        }

        // MARK: - Commands

        func perform(_ command: EditorCommand) {
            guard let textView else { return }
            textView.window?.makeFirstResponder(textView)

            switch command {
            case .undo: textView.undoManager?.undo()
            case .redo: textView.undoManager?.redo()
            case .copy: textView.copy(nil)
            case .paste: textView.paste(nil)
            case .bold: wrapSelection(prefix: "**", suffix: "**", placeholder: "bold text")
            case .italic: wrapSelection(prefix: "_", suffix: "_", placeholder: "italic text")
            case .inlineCode: wrapSelection(prefix: "`", suffix: "`", placeholder: "code")
            case .strikethrough: wrapSelection(prefix: "~~", suffix: "~~", placeholder: "text")
            case .link: insertLink()
            case .heading(let level): applyLinePrefix(String(repeating: "#", count: level) + " ")
            case .bulletList: applyLinePrefix("- ")
            case .numberList: applyLinePrefix("1. ")
            }

            text.wrappedValue = textView.string
            applyHighlighting()
        }

        private func insertLink() {
            guard let textView else { return }
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let selectedText = selectedRange.length > 0 ? nsString.substring(with: selectedRange) : "link text"
            let replacement = "[\(selectedText)](url)"
            textView.insertText(replacement, replacementRange: selectedRange)

            // Select the "url" placeholder for quick replacement.
            let urlLocation = selectedRange.location + selectedText.utf16.count + 3
            textView.setSelectedRange(NSRange(location: urlLocation, length: 3))
        }

        private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
            guard let textView else { return }
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let selectedText = selectedRange.length > 0 ? nsString.substring(with: selectedRange) : placeholder
            let replacement = "\(prefix)\(selectedText)\(suffix)"
            textView.insertText(replacement, replacementRange: selectedRange)

            if selectedRange.length == 0 {
                textView.setSelectedRange(NSRange(location: selectedRange.location + prefix.utf16.count, length: placeholder.utf16.count))
            } else {
                textView.setSelectedRange(NSRange(location: selectedRange.location, length: replacement.utf16.count))
            }
        }

        private func applyLinePrefix(_ prefix: String) {
            guard let textView else { return }
            let string = textView.string as NSString
            let selectedRange = textView.selectedRange()
            let lineRange = string.lineRange(for: selectedRange)
            let selectedLines = string.substring(with: lineRange)
            let lineComponents = selectedLines.components(separatedBy: .newlines)
            let replacement = lineComponents
                .enumerated()
                .map { index, line -> String in
                    guard !line.isEmpty || index < lineComponents.count - 1 else { return line }
                    let trimmedLine = line.replacingOccurrences(
                        of: #"^(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+)"#,
                        with: "",
                        options: .regularExpression
                    )
                    return prefix + trimmedLine
                }
                .joined(separator: "\n")

            textView.insertText(replacement, replacementRange: lineRange)
            textView.setSelectedRange(NSRange(location: lineRange.location, length: (replacement as NSString).length))
        }

        // MARK: - Navigation

        func scroll(toCharacterIndex index: Int) {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let length = (textView.string as NSString).length
            let location = min(max(0, index), length)
            let selection = NSRange(location: location, length: 0)

            layoutManager.ensureLayout(for: textContainer)

            // Use a one-character probe to get the heading line's fragment rect.
            let probe = NSRange(location: location, length: min(1, max(0, length - location)))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: probe, actualCharacterRange: nil)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let targetY = max(0, lineRect.minY + textView.textContainerInset.height - 12)

            if let clipView = textView.enclosingScrollView?.contentView {
                clipView.setBoundsOrigin(NSPoint(x: 0, y: targetY))
                textView.enclosingScrollView?.reflectScrolledClipView(clipView)
            }

            textView.setSelectedRange(selection)
            textView.window?.makeFirstResponder(textView)
        }

        /// Reports the heading nearest the top of the viewport so the outline can
        /// highlight the active section.
        func updateActiveLocation() {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let visibleRect = textView.visibleRect
            let containerY = max(0, visibleRect.minY - textView.textContainerInset.height + 1)
            let point = NSPoint(x: 0, y: containerY)
            let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            guard activeLocation.wrappedValue != characterIndex else { return }
            let binding = activeLocation
            DispatchQueue.main.async { binding.wrappedValue = characterIndex }
        }

        // MARK: - Highlighting

        func applyHighlighting() {
            guard let textView, let textStorage = textView.textStorage else { return }
            guard !textView.hasMarkedText() else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            textStorage.beginEditing()
            textStorage.setAttributes([.font: baseFont, .foregroundColor: NSColor.textColor], range: fullRange)

            // Skip detailed highlighting for very large documents to stay responsive.
            if textStorage.length <= 200_000 {
                for token in highlighter.tokens(in: textView.string) {
                    guard token.range.location + token.range.length <= textStorage.length else { continue }
                    apply(token, to: textStorage)
                }
            }

            textStorage.endEditing()
        }

        private func apply(_ token: MarkdownToken, to storage: NSTextStorage) {
            switch token.style {
            case .heading(let level):
                let size = NSFont.systemFontSize + CGFloat(max(0, 5 - level)) * 1.5
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: size, weight: .bold), range: token.range)
            case .strong:
                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold), range: token.range)
            case .emphasis:
                storage.addAttribute(.obliqueness, value: 0.18, range: token.range)
            case .strikethrough:
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: token.range)
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: token.range)
            case .inlineCode, .codeBlock:
                storage.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: token.range)
            case .blockquote:
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: token.range)
            case .listMarker:
                storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: token.range)
            case .link:
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: token.range)
            case .delimiter:
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: token.range)
            }
        }
    }
}
