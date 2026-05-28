# GlassMark

GlassMark is a fast, native macOS Markdown editor that does one thing well: **edit Markdown with a beautiful live preview.**

It is a calm, local, folder-based writing surface — not a publishing platform, IDE, or PKM system. Open a folder, browse your `.md` files, write, and watch the rendered document update as you type.

## Features

- **Live preview** that updates as you type, with smooth, flicker-free rendering and preserved scroll position.
- **GitHub-flavored Markdown** rendering: headings, bold/italic/strikethrough, links, images, fenced code blocks, blockquotes, nested lists, task lists, tables, and autolinks — all rendered with a clean, GitHub-style stylesheet that adapts to light and dark mode.
- **In-editor syntax highlighting** for headings, emphasis, code, links, blockquotes, and list markers.
- **Editor / Split / Preview** view modes.
- **Outline panel** that lists document headings and jumps the editor to any of them.
- **Smart editing**: bold/italic/link keyboard shortcuts, a formatting toolbar, automatic list continuation, and a formatting menu.
- **Export** the current document to **HTML** or **PDF**.
- **YAML frontmatter** rendered as a tidy metadata block in the preview.
- **Live document statistics**: word count, character count, line count, and estimated reading time.
- **Multiple workspaces** with security-scoped bookmarks, a workspace rail, and per-workspace colours.
- **File management** from the sidebar: create, rename, duplicate, cut/copy/paste, drag-and-drop move, delete-to-Trash, and reveal in Finder.
- **Quick Open** (`⌘P`) for fast file switching.
- **Session restore**: reopens the files you had open per workspace.
- **Autosave** (optional) with manual save (`⌘S`) always available.
- **Find & replace** via the native editor find bar (`⌘F`).

Markdown is rendered entirely natively with no third-party dependencies, and the preview never loads remote resources — generated HTML is escaped and unsafe URL schemes are neutralized.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New Markdown file | `⌘N` |
| Open workspace | `⇧⌘O` |
| Quick Open | `⌘P` |
| Save | `⌘S` |
| Refresh workspace | `⌘R` |
| Toggle outline | `⌥⌘0` |
| Bold / Italic / Inline code | `⌘B` / `⌘I` / `⌘E` |
| Strikethrough | `⇧⌘X` |
| Insert link | `⌘K` |
| Heading 1–3 | `⌃⌘1` / `⌃⌘2` / `⌃⌘3` |
| Find | `⌘F` |

## Development

Open the Xcode project:

```bash
open GlassMark.xcodeproj
```

Build from the command line:

```bash
xcodebuild -project GlassMark.xcodeproj -scheme GlassMark -configuration Debug -derivedDataPath DerivedData build
```

Run the test suite:

```bash
xcodebuild -project GlassMark.xcodeproj -scheme GlassMark -derivedDataPath DerivedData test
```

Run through the project helper:

```bash
script/build_and_run.sh
```

The project is generated with [XcodeGen](https://github.com/yonyz/XcodeGen) from `project.yml`. After changing `project.yml`, regenerate with `xcodegen generate`.

## Architecture

- SwiftUI app shell with a `NavigationSplitView` (workspace rail + file tree, editor/preview detail, outline inspector).
- AppKit `NSTextView` bridge for the editor (syntax highlighting, list continuation, find bar).
- `WKWebView` preview using a persistent HTML shell updated via JavaScript.
- Dependency-free Markdown-to-HTML renderer (`MarkdownHTMLRenderer`).
- Stores own workspace, document, command, and preference state; services handle file I/O, the file tree, rendering, and export.

## Requirements

- macOS 15 or later.

## License

GlassMark is released under the [MIT License](LICENSE).

## Planning documents

- [Product Plan](docs/product-plan.md)
- [Architecture Plan](docs/architecture-plan.md)
- [Roadmap](docs/roadmap.md)
