#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PREVIEW_DIR=$(mktemp -d)
trap 'rm -rf "$PREVIEW_DIR"' EXIT
python3 - "$PREVIEW_DIR/main.swift" <<'PY'
import re
import sys
from pathlib import Path
source = Path('Sources/main.swift').read_text().split('// MARK: - Entry point')[0]
source = source.replace('let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!', 'let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)')
source = source.replace('final class TabButtonView: NSView {', 'final class TabButtonView: NSView {\n    var previewStyle = 1')
draw_body = re.search(r'override func draw\(_ dirtyRect: NSRect\) \{\n        super.draw\(dirtyRect\)\n(.*?)\n    }\n}', source, re.S).group(1)
source = source.replace(draw_body, r'''
        let width = bounds.width
        let height = bounds.height
        theme.tabUnselected.setFill()
        bounds.fill()
        let selectedColor = theme.tabSelected
        switch previewStyle {
        case 1:
            // Soft top corners, with a straight bottom joined to the editor.
            if isSelected || isHovered {
                tabBackground.setFill()
                let path = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
                path.fill()
                NSRect(x: 0, y: 0, width: width, height: height / 2).fill()
            }
        case 2:
            // Quiet labels with a narrow underline marking the active tab.
            if isHovered { selectedColor.withAlphaComponent(0.5).setFill(); bounds.fill() }
            if isSelected {
                theme.text.withAlphaComponent(0.8).setFill()
                NSRect(x: 12, y: 0, width: max(0, width - 24), height: 2).fill()
            }
        case 3:
            // A floating, softly rounded capsule, inset from the bar.
            if isSelected || isHovered {
                tabBackground.setFill()
                NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 4), xRadius: 7, yRadius: 7).fill()
                theme.text.withAlphaComponent(0.10).setStroke()
                let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 5.5, dy: 4.5), xRadius: 7, yRadius: 7)
                outline.lineWidth = 1
                outline.stroke()
            }
        default:
            // Sloping shoulders give a browser-style silhouette.
            if isSelected || isHovered {
                tabBackground.setFill()
                let path = NSBezierPath()
                path.move(to: .zero)
                path.curve(to: NSPoint(x: 13, y: height - 7),
                           controlPoint1: NSPoint(x: 8, y: 0),
                           controlPoint2: NSPoint(x: 9, y: height - 7))
                path.curve(to: NSPoint(x: 20, y: height - 3),
                           controlPoint1: NSPoint(x: 14, y: height - 3),
                           controlPoint2: NSPoint(x: 17, y: height - 3))
                path.line(to: NSPoint(x: width - 20, y: height - 3))
                path.curve(to: NSPoint(x: width - 13, y: height - 7),
                           controlPoint1: NSPoint(x: width - 17, y: height - 3),
                           controlPoint2: NSPoint(x: width - 14, y: height - 3))
                path.curve(to: NSPoint(x: width, y: 0),
                           controlPoint1: NSPoint(x: width - 9, y: height - 7),
                           controlPoint2: NSPoint(x: width - 8, y: 0))
                path.close()
                path.fill()
            }
        }''')
capture_script = Path('docs/capture-screenshots.sh').read_text()
harness = re.search(r"source \+= r'''(.*?)'''", capture_script, re.S).group(1)
harness = harness.replace('selectTab(tabs[0])', 'selectTab(tabs[1])')
harness = harness.replace('for theme in ["light", "dark"] {', '''for style in 1...4 {
            for tab in tabs { tab.tabButton.previewStyle = style }
            for theme in ["light", "dark"] {''')
harness = harness.replace('"\\(theme).png"', '"option-\\(style)-\\(theme).png"')
harness = harness.replace('''        window.orderOut(nil)''', '''        }
        window.orderOut(nil)''')
harness = harness.replace('''            try data.write(to:''', '''            let stripRect = NSRect(x: 0, y: view.bounds.height - 106, width: view.bounds.width, height: 106)
            let strip = view.bitmapImageRepForCachingDisplay(in: stripRect)!
            view.cacheDisplay(in: stripRect, to: strip)
            try strip.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("option-\\(style)-\\(theme)-tabs.png"))
            try data.write(to:''')
Path(sys.argv[1]).write_text(source + harness)
PY
swiftc -target "$(uname -m)-apple-macosx11.0" "$PREVIEW_DIR/main.swift" -framework Cocoa -o "$PREVIEW_DIR/tab-options"
"$PREVIEW_DIR/tab-options" "$PREVIEW_DIR/data" "$PWD/docs/tab-options"
