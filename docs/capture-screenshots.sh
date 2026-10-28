#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CAPTURE_DIR=$(mktemp -d)
trap 'rm -rf "$CAPTURE_DIR"' EXIT
python3 - "$CAPTURE_DIR/main.swift" <<'PY'
import sys
from pathlib import Path
source = Path('Sources/main.swift').read_text().split('// MARK: - Entry point')[0]
source = source.replace('let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!', 'let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)')
source += r'''
extension AppDelegate {
    func captureExamples() throws {
        buildMenu()
        buildWindow()
        let examples = [
            ("Welcome.txt", """
            NotepadMac
            A small space for your thoughts.

            Write a quick note, keep a few tabs open, and pick up
            where you left off the next time you launch the app.

            Everyday shortcuts

              Command + T       New tab
              Command + S       Save to a file
              Command + 1–9     Switch to a tab
              Command + 0       Jump to the last tab
              Command + F       Find in your note

            Close the window when you're done.
            Your open notes will be here when you return.
            """),
            ("Ideas.txt", "Ideas for the weekend\n\n• Take a walk\n• Try a new recipe\n• Write something just for fun"),
            ("Checklist.txt", "Today\n\n[ ] Review notes\n[ ] Plan the next step\n[ ] Make time for a break")
        ]
        isRestoringSession = true
        for (name, content) in examples {
            let tab = makeTab(id: UUID().uuidString, fileURL: Autosave.dir.appendingPathComponent(name), content: content)
            addTab(tab, select: false)
        }
        selectTab(tabs[0])
        window.setIsVisible(true)
        for theme in ["light", "dark"] {
            applyTheme(theme)
            window.contentView!.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            let view = window.contentView!.superview!
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let data = bitmap.representation(using: .png, properties: [:])!
            try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("\(theme).png"))
        }
        window.orderOut(nil)
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let delegate = AppDelegate()
try delegate.captureExamples()
'''
Path(sys.argv[1]).write_text(source)
PY
swiftc -target "$(uname -m)-apple-macosx11.0" "$CAPTURE_DIR/main.swift" -framework Cocoa -o "$CAPTURE_DIR/capture"
"$CAPTURE_DIR/capture" "$CAPTURE_DIR/data" "$PWD/docs/screenshots"
