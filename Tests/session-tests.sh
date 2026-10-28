#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
python3 - "$TEST_DIR/main.swift" <<'PY'
import sys
from pathlib import Path
source = Path('Sources/main.swift').read_text().split('// MARK: - Entry point')[0]
source = source.replace('let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!', 'let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)')
source += r'''
extension AppDelegate {
    static func runSessionTests() throws {
        Autosave.ensureDir()
        let original = AppDelegate()
        original.buildMenu()
        original.buildWindow()
        original.restoreSession()
        let emptyID = original.activeTab!.id
        original.activeTab!.isDirty = true
        original.closeCurrentTab(nil)
        precondition(original.activeTab!.id != emptyID, "Empty dirty note should close without a prompt")

        for index in 1...10 {
            original.newTab(nil)
            original.activeTab!.textView.string = "Unsaved note \(index) — café\nSecond line"
            original.textDidChange(Notification(name: NSText.didChangeNotification, object: original.activeTab!.textView))
        }
        let item = NSMenuItem()
        item.tag = 9
        original.selectNumberedTab(item)
        precondition(original.activeTab === original.tabs[8])
        item.tag = 0
        original.selectNumberedTab(item)
        precondition(original.activeTab === original.tabs.last, "Command+0 selects last even with more than ten tabs")
        item.tag = 1
        original.selectNumberedTab(item)
        precondition(original.activeTab === original.tabs.first)
        item.tag = 99
        original.selectNumberedTab(item)
        precondition(original.activeTab === original.tabs.first, "Missing tab shortcut should do nothing")
        item.tag = 9
        original.selectNumberedTab(item)

        let savedURL = Autosave.dir.appendingPathComponent("saved.txt")
        precondition(original.write(tab: original.tabs[1], to: savedURL))
        original.tabs[1].textView.string = "Unsaved changes to saved file"
        original.tabs[1].isDirty = true
        let expected = original.tabs.map { $0.textView.string }
        let selectedID = original.activeTab!.id
        precondition(original.windowShouldClose(original.window))
        precondition(original.applicationShouldTerminate(NSApp) == .terminateNow)
        let savedContent = try String(contentsOf: savedURL, encoding: .utf8)
        precondition(savedContent != original.tabs[1].textView.string,
                     "Session recovery must not overwrite explicitly saved files")

        let restored = AppDelegate()
        restored.buildWindow()
        restored.restoreSession()
        precondition(restored.tabs.map { $0.textView.string } == expected)
        precondition(restored.activeTab!.id == selectedID)
        precondition(restored.tabs[1].fileURL == savedURL)
        precondition(restored.tabs[1].isDirty)
        precondition(!restored.tabs[0].isDirty)
        precondition(restored.tabs.last!.isDirty)

        // Clicking an inactive tab's X must close that tab without changing selection.
        let selectedBeforeClose = restored.activeTab!.id
        let inactive = restored.tabs[0]
        let close = inactive.tabButton.subviews.compactMap { $0 as? NSButton }.first!
        let hover = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!
        inactive.tabButton.mouseExited(with: hover)
        precondition(close.isHidden)
        inactive.tabButton.mouseEntered(with: hover)
        precondition(!close.isHidden)
        inactive.tabButton.mouseExited(with: hover)
        precondition(close.isHidden)
        let activeClose = restored.activeTab!.tabButton.subviews.compactMap { $0 as? NSButton }.first!
        restored.activeTab!.tabButton.mouseExited(with: hover)
        precondition(!activeClose.isHidden)
        close.performClick(nil)
        precondition(!restored.tabs.contains { $0 === inactive })
        precondition(restored.activeTab!.id == selectedBeforeClose)

        let view = NSApp.mainMenu!.items.last!.submenu!
        for number in 0...9 {
            let shortcut = view.items.first { $0.keyEquivalent == String(number) }!
            precondition(shortcut.keyEquivalentModifierMask == [.command])
        }
        print("PASS: empty close, numbered shortcuts, close/quit persistence, content/order/selection restoration, saved-file protection, hover visibility, and closing an inactive tab")
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
try AppDelegate.runSessionTests()
'''
Path(sys.argv[1]).write_text(source)
PY
swiftc -target "$(uname -m)-apple-macosx11.0" "$TEST_DIR/main.swift" -framework Cocoa -o "$TEST_DIR/session-tests"
"$TEST_DIR/session-tests" "$TEST_DIR/data"
