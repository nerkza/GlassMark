# GlassMark

GlassMark is a native macOS Markdown workspace editor.

The app is intentionally scoped around a simple, calm writing surface:

- Multiple local workspaces.
- Sidebar file tree.
- Markdown editing and rendered preview.
- Editor-only, preview-only, and split editor/preview modes.
- Light and dark appearance.
- SwiftUI-first macOS interface using Liquid Glass where it helps the app feel native rather than decorative.

The current implementation is an early development build. It already supports multiple local workspaces, a recursive file explorer, tabbed Markdown editing, manual save, a WKWebView preview, Quick Open, and common file operations.

## Development

Open the Xcode project:

```bash
open GlassMark.xcodeproj
```

Build from the command line:

```bash
xcodebuild -project GlassMark.xcodeproj -scheme GlassMark -configuration Debug -derivedDataPath DerivedData build
```

Run through the project helper:

```bash
script/build_and_run.sh
```

The project is generated with XcodeGen from `project.yml`.

## Current Implementation Status

- Xcode macOS app target using SwiftUI for the app shell.
- AppKit `NSTextView` bridge for Markdown editing.
- `WKWebView` Markdown preview.
- Multiple remembered workspaces with security-scoped bookmarks.
- Left workspace rail, workspace colours, and active workspace switching.
- Recursive file tree with expansion/collapse, selection highlighting, context menus, drag/drop moves, rename, new file/folder, duplicate, cut/copy/paste, reveal in Finder, and move to Trash.
- File tabs across the editor area.
- Quick Open via the toolbar or `⌘P`.
- Manual save and dirty-state indication.

## Planning Documents

- [Product Plan](docs/product-plan.md)
- [Architecture Plan](docs/architecture-plan.md)
- [Roadmap](docs/roadmap.md)
