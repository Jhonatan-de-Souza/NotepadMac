import Cocoa

// MARK: - Color helpers

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = CGFloat((value & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((value & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(value & 0x0000FF) / 255.0
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}

struct AppThemeColors {
    let background: NSColor
    let text: NSColor
    let tabBarBackground: NSColor
    let tabSelected: NSColor
    let tabUnselected: NSColor
}

let lightTheme = AppThemeColors(
    background: NSColor.white,
    text: NSColor(white: 0.1, alpha: 1),
    tabBarBackground: NSColor(white: 0.90, alpha: 1),
    tabSelected: NSColor.white,
    tabUnselected: NSColor(white: 0.82, alpha: 1)
)

let darkTheme = AppThemeColors(
    background: NSColor(hex: "#0f0f0f"),
    text: NSColor(white: 0.92, alpha: 1),
    tabBarBackground: NSColor(hex: "#0f0f0f"),
    tabSelected: NSColor(hex: "#232323"),
    tabUnselected: NSColor(hex: "#0f0f0f")
)

// MARK: - Autosave paths

enum Autosave {
    static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("NotepadMac", isDirectory: true)
    }()
    static let tabsDir = dir.appendingPathComponent("tabs", isDirectory: true)
    static let manifestFile = dir.appendingPathComponent("manifest.json")

    static func ensureDir() {
        try? FileManager.default.createDirectory(at: tabsDir, withIntermediateDirectories: true)
    }
    static func tabDraftFile(id: String) -> URL {
        tabsDir.appendingPathComponent("\(id).txt")
    }
}

struct ManifestEntry: Codable {
    let id: String
    let filePath: String?
}

// MARK: - Tab bar button

final class TabButtonView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6

        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        closeButton.isBordered = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(selectTapped))
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func selectTapped() { onSelect?() }
    @objc private func closeTapped() { onClose?() }

    func configure(title: String, textColor: NSColor) {
        titleLabel.stringValue = title
        titleLabel.textColor = textColor
        closeButton.attributedTitle = NSAttributedString(
            string: "\u{00D7}",
            attributes: [.foregroundColor: textColor, .font: NSFont.systemFont(ofSize: 13)]
        )
    }

    func setSelected(_ selected: Bool, theme: AppThemeColors) {
        layer?.backgroundColor = (selected ? theme.tabSelected : theme.tabUnselected).cgColor
    }
}

// MARK: - Tab model

final class Tab {
    let id: String
    let scrollView: NSScrollView
    let textView: NSTextView
    let tabViewItem: NSTabViewItem
    let tabButton: TabButtonView
    var debounceTimer: Timer?
    var onChange: (() -> Void)?

    var fileURL: URL? {
        didSet { onChange?() }
    }
    var isDirty: Bool = false {
        didSet { onChange?() }
    }

    init(id: String, scrollView: NSScrollView, textView: NSTextView, tabViewItem: NSTabViewItem, tabButton: TabButtonView) {
        self.id = id
        self.scrollView = scrollView
        self.textView = textView
        self.tabViewItem = tabViewItem
        self.tabButton = tabButton
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate {

    var window: NSWindow!
    var tabView: NSTabView!
    var tabStack: NSStackView!
    var tabBarContainer: NSView!
    var addTabButton: NSButton!
    var tabBarHeightConstraint: NSLayoutConstraint!

    var tabs: [Tab] = []
    var wordWrapOn = true
    var currentFontSize: CGFloat = 13
    private var keyMonitor: Any?

    var activeTab: Tab? {
        guard let selected = tabView.selectedTabViewItem else { return nil }
        return tabs.first { $0.tabViewItem === selected }
    }

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        Autosave.ensureDir()
        let savedFontSize = UserDefaults.standard.double(forKey: "FontSize")
        if savedFontSize > 0 { currentFontSize = CGFloat(savedFontSize) }
        buildMenu()
        buildWindow()
        applyTheme(UserDefaults.standard.string(forKey: "AppTheme") ?? "light")
        restoreSession()
        installFontSizeKeyMonitor()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: Window

    private func buildWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 760, height: 580)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.delegate = self
        window.title = "Untitled"
        window.minSize = NSSize(width: 420, height: 300)

        let content = window.contentView!

        tabBarContainer = NSView()
        tabBarContainer.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.wantsLayer = true
        content.addSubview(tabBarContainer)

        tabStack = NSStackView()
        tabStack.orientation = .horizontal
        tabStack.alignment = .centerY
        tabStack.spacing = 4
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(tabStack)

        addTabButton = NSButton()
        addTabButton.title = "+"
        addTabButton.isBordered = false
        addTabButton.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        addTabButton.target = self
        addTabButton.action = #selector(newTab(_:))
        addTabButton.translatesAutoresizingMaskIntoConstraints = false
        tabBarContainer.addSubview(addTabButton)

        tabView = NSTabView()
        tabView.tabViewType = .noTabsNoBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(tabView)

        let tabBarHeight = tabBarContainer.heightAnchor.constraint(equalToConstant: 0)
        tabBarHeightConstraint = tabBarHeight

        NSLayoutConstraint.activate([
            tabBarContainer.topAnchor.constraint(equalTo: content.topAnchor),
            tabBarContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabBarHeight,

            tabStack.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor, constant: 8),
            tabStack.centerYAnchor.constraint(equalTo: tabBarContainer.centerYAnchor),
            tabStack.trailingAnchor.constraint(lessThanOrEqualTo: addTabButton.leadingAnchor, constant: -4),

            addTabButton.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor, constant: -8),
            addTabButton.centerYAnchor.constraint(equalTo: tabBarContainer.centerYAnchor),
            addTabButton.widthAnchor.constraint(equalToConstant: 24),
            addTabButton.heightAnchor.constraint(equalToConstant: 24),

            tabView.topAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        tabBarContainer.isHidden = true
        window.makeKeyAndOrderFront(nil)
    }

    private func updateTabBarVisibility() {
        let shouldShow = tabs.count > 1
        tabBarHeightConstraint.constant = shouldShow ? 32 : 0
        tabBarContainer.isHidden = !shouldShow
    }

    private func updateTitle() {
        guard let tab = activeTab else { return }
        window.title = tab.fileURL?.lastPathComponent ?? "Untitled"
        window.representedURL = tab.fileURL
        window.isDocumentEdited = tab.isDirty
    }

    // MARK: Menu

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About NotepadMac", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let hide = appMenu.addItem(withTitle: "Hide NotepadMac", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.keyEquivalentModifierMask = [.command]
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: "Quit NotepadMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command]
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Tab", action: #selector(newTab(_:)), keyEquivalent: "t")
        let newTabAlt = fileMenu.addItem(withTitle: "New Tab (⌘N)", action: #selector(newTab(_:)), keyEquivalent: "n")
        newTabAlt.isHidden = true
        fileMenu.addItem(withTitle: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        let saveAs = fileMenu.addItem(withTitle: "Save As…", action: #selector(saveDocumentAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(closeCurrentTab(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        let find = editMenu.addItem(withTitle: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")
        let wrapItem = formatMenu.addItem(withTitle: "Word Wrap", action: #selector(toggleWordWrap(_:)), keyEquivalent: "")
        wrapItem.state = wordWrapOn ? .on : .off
        formatMenu.addItem(.separator())
        let increase = formatMenu.addItem(withTitle: "Increase Font Size", action: #selector(increaseFontSize(_:)), keyEquivalent: "+")
        increase.keyEquivalentModifierMask = [.command]
        let decrease = formatMenu.addItem(withTitle: "Decrease Font Size", action: #selector(decreaseFontSize(_:)), keyEquivalent: "-")
        decrease.keyEquivalentModifierMask = [.command]
        formatMenuItem.submenu = formatMenu
        mainMenu.addItem(formatMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let themeMenu = NSMenu(title: "Theme")
        let lightItem = themeMenu.addItem(withTitle: "Light", action: #selector(setLightTheme(_:)), keyEquivalent: "")
        lightItem.tag = 1
        let darkItem = themeMenu.addItem(withTitle: "Dark", action: #selector(setDarkTheme(_:)), keyEquivalent: "")
        darkItem.tag = 2
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        viewMenu.addItem(themeItem)
        viewMenu.addItem(.separator())
        let nextTab = viewMenu.addItem(withTitle: "Show Next Tab", action: #selector(selectNextTab(_:)), keyEquivalent: "}")
        nextTab.keyEquivalentModifierMask = [.command]
        let prevTab = viewMenu.addItem(withTitle: "Show Previous Tab", action: #selector(selectPreviousTab(_:)), keyEquivalent: "{")
        prevTab.keyEquivalentModifierMask = [.command]
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
        updateThemeMenuCheckmarks()
    }

    // MARK: Tabs

    private func makeTab(id: String, fileURL: URL?, content: String) -> Tab {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true

        let textView = scrollView.documentView as! NSTextView
        textView.delegate = self
        textView.isRichText = false
        textView.usesFontPanel = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont(name: "Menlo", size: currentFontSize) ?? NSFont.monospacedSystemFont(ofSize: currentFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = content

        let tabViewItem = NSTabViewItem(identifier: id)
        tabViewItem.view = scrollView

        let button = TabButtonView(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 160).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let tab = Tab(id: id, scrollView: scrollView, textView: textView, tabViewItem: tabViewItem, tabButton: button)
        tab.onChange = { [weak self] in self?.handleTabChange(tab) }
        tab.fileURL = fileURL

        button.onSelect = { [weak self] in self?.selectTab(tab) }
        button.onClose = { [weak self] in self?.closeTab(tab) }

        applyWordWrap(to: tab)
        applyThemeColors(to: tab)
        return tab
    }

    private func addTab(_ tab: Tab, select: Bool) {
        tabs.append(tab)
        tabView.addTabViewItem(tab.tabViewItem)
        tabStack.addArrangedSubview(tab.tabButton)
        refreshTabButton(tab)
        if select || tabs.count == 1 {
            selectTab(tab)
        } else {
            tab.tabButton.setSelected(false, theme: currentTheme())
        }
        updateTabBarVisibility()
    }

    private func selectTab(_ tab: Tab) {
        tabView.selectTabViewItem(tab.tabViewItem)
        let colors = currentTheme()
        for t in tabs { t.tabButton.setSelected(t === tab, theme: colors) }
        window.makeFirstResponder(tab.textView)
        updateTitle()
    }

    private func removeTab(_ tab: Tab) {
        guard let idx = tabs.firstIndex(where: { $0 === tab }) else { return }
        tab.debounceTimer?.invalidate()
        tabView.removeTabViewItem(tab.tabViewItem)
        tabStack.removeArrangedSubview(tab.tabButton)
        tab.tabButton.removeFromSuperview()
        tabs.remove(at: idx)
        try? FileManager.default.removeItem(at: Autosave.tabDraftFile(id: tab.id))

        if tabs.isEmpty {
            let fresh = makeTab(id: UUID().uuidString, fileURL: nil, content: "")
            addTab(fresh, select: true)
        } else {
            selectTab(tabs[max(0, idx - 1)])
            updateTabBarVisibility()
        }
        writeManifest()
    }

    private func closeTab(_ tab: Tab) {
        confirmDiscardIfNeeded(tab: tab) { [weak self] in
            self?.removeTab(tab)
        }
    }

    @objc private func closeCurrentTab(_ sender: Any?) {
        if let tab = activeTab { closeTab(tab) }
    }

    @objc private func newTab(_ sender: Any?) {
        let tab = makeTab(id: UUID().uuidString, fileURL: nil, content: "")
        addTab(tab, select: true)
        writeManifest()
    }

    @objc private func selectNextTab(_ sender: Any?) {
        guard let active = activeTab, let idx = tabs.firstIndex(where: { $0 === active }), tabs.count > 1 else { return }
        selectTab(tabs[(idx + 1) % tabs.count])
    }

    @objc private func selectPreviousTab(_ sender: Any?) {
        guard let active = activeTab, let idx = tabs.firstIndex(where: { $0 === active }), tabs.count > 1 else { return }
        selectTab(tabs[(idx - 1 + tabs.count) % tabs.count])
    }

    private func handleTabChange(_ tab: Tab) {
        refreshTabButton(tab)
        if tab === activeTab { updateTitle() }
    }

    private func refreshTabButton(_ tab: Tab) {
        tab.tabButton.configure(title: tabTitle(for: tab), textColor: currentTheme().text)
    }

    private func tabTitle(for tab: Tab) -> String {
        (tab.isDirty ? "\u{2022} " : "") + (tab.fileURL?.lastPathComponent ?? "Untitled")
    }

    // MARK: Word wrap

    private func applyWordWrap(to tab: Tab) {
        guard let container = tab.textView.textContainer else { return }
        if wordWrapOn {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: tab.scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            tab.textView.isHorizontallyResizable = false
            tab.scrollView.hasHorizontalScroller = false
        } else {
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            tab.textView.isHorizontallyResizable = true
            tab.scrollView.hasHorizontalScroller = true
        }
    }

    @objc private func toggleWordWrap(_ sender: NSMenuItem) {
        wordWrapOn.toggle()
        sender.state = wordWrapOn ? .on : .off
        for tab in tabs { applyWordWrap(to: tab) }
    }

    // MARK: Font size

    @objc private func increaseFontSize(_ sender: Any?) { setFontSize(currentFontSize + 1) }
    @objc private func decreaseFontSize(_ sender: Any?) { setFontSize(currentFontSize - 1) }

    private func setFontSize(_ size: CGFloat) {
        currentFontSize = min(48, max(8, size))
        for tab in tabs {
            let familyName = tab.textView.font?.fontName ?? "Menlo"
            tab.textView.font = NSFont(name: familyName, size: currentFontSize) ?? NSFont.monospacedSystemFont(ofSize: currentFontSize, weight: .regular)
        }
        UserDefaults.standard.set(Double(currentFontSize), forKey: "FontSize")
    }

    private func installFontSizeKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.option) else { return event }
            switch event.charactersIgnoringModifiers {
            case "+", "=":
                self.increaseFontSize(nil)
                return nil
            case "-", "_":
                self.decreaseFontSize(nil)
                return nil
            default:
                return event
            }
        }
    }

    // MARK: Theme

    private func currentTheme() -> AppThemeColors {
        (UserDefaults.standard.string(forKey: "AppTheme") ?? "light") == "dark" ? darkTheme : lightTheme
    }

    private func applyTheme(_ theme: String) {
        UserDefaults.standard.set(theme, forKey: "AppTheme")
        NSApp.appearance = NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
        let colors = currentTheme()
        window?.backgroundColor = colors.background
        window?.titlebarAppearsTransparent = true
        if #available(macOS 11.0, *) {
            window?.titlebarSeparatorStyle = .none
        }
        tabBarContainer?.layer?.backgroundColor = colors.tabBarBackground.cgColor
        for tab in tabs {
            applyThemeColors(to: tab)
        }
        for tab in tabs {
            tab.tabButton.setSelected(tab === activeTab, theme: colors)
        }
        updateThemeMenuCheckmarks()
    }

    private func applyThemeColors(to tab: Tab) {
        let colors = currentTheme()
        tab.textView.backgroundColor = colors.background
        tab.textView.textColor = colors.text
        tab.textView.insertionPointColor = colors.text
        tab.scrollView.backgroundColor = colors.background
        tab.tabButton.configure(title: tabTitle(for: tab), textColor: colors.text)
    }

    private func updateThemeMenuCheckmarks() {
        guard let themeMenu = (NSApp.mainMenu?.item(withTitle: "View")?.submenu)?.item(withTitle: "Theme")?.submenu else { return }
        let current = UserDefaults.standard.string(forKey: "AppTheme") ?? "light"
        themeMenu.item(withTag: 1)?.state = current == "light" ? .on : .off
        themeMenu.item(withTag: 2)?.state = current == "dark" ? .on : .off
    }

    @objc private func setLightTheme(_ sender: Any?) { applyTheme("light") }
    @objc private func setDarkTheme(_ sender: Any?) { applyTheme("dark") }

    // MARK: Text change / autosave

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView, let tab = tabs.first(where: { $0.textView === tv }) else { return }
        tab.isDirty = true
        tab.debounceTimer?.invalidate()
        tab.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.writeDraft(for: tab)
        }
    }

    private func writeDraft(for tab: Tab) {
        try? tab.textView.string.write(to: Autosave.tabDraftFile(id: tab.id), atomically: true, encoding: .utf8)
    }

    private func writeManifest() {
        let entries = tabs.map { ManifestEntry(id: $0.id, filePath: $0.fileURL?.path) }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: Autosave.manifestFile)
        }
    }

    private func restoreSession() {
        if let data = try? Data(contentsOf: Autosave.manifestFile),
           let entries = try? JSONDecoder().decode([ManifestEntry].self, from: data),
           !entries.isEmpty {
            for entry in entries {
                let content = (try? String(contentsOf: Autosave.tabDraftFile(id: entry.id), encoding: .utf8)) ?? ""
                let fileURL = entry.filePath.map { URL(fileURLWithPath: $0) }
                let tab = makeTab(id: entry.id, fileURL: fileURL, content: content)
                if let url = fileURL, let onDisk = try? String(contentsOf: url, encoding: .utf8) {
                    tab.isDirty = (onDisk != content)
                } else {
                    tab.isDirty = fileURL == nil && !content.isEmpty
                }
                addTab(tab, select: false)
            }
            if let first = tabs.first { selectTab(first) }
        } else {
            let tab = makeTab(id: UUID().uuidString, fileURL: nil, content: "")
            addTab(tab, select: true)
            writeManifest()
        }
    }

    // MARK: File actions

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        for url in panel.urls {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                let alert = NSAlert()
                alert.messageText = "Could not open file"
                alert.informativeText = url.lastPathComponent
                alert.runModal()
                continue
            }
            let tab = makeTab(id: UUID().uuidString, fileURL: url, content: content)
            addTab(tab, select: true)
        }
        writeManifest()
    }

    @discardableResult
    private func performSave(tab: Tab) -> Bool {
        if let url = tab.fileURL {
            return write(tab: tab, to: url)
        }
        return performSaveAs(tab: tab)
    }

    @discardableResult
    private func performSaveAs(tab: Tab) -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tab.fileURL?.lastPathComponent ?? "Untitled.txt"
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(tab: tab, to: url)
    }

    private func write(tab: Tab, to url: URL) -> Bool {
        do {
            try tab.textView.string.write(to: url, atomically: true, encoding: .utf8)
            tab.fileURL = url
            tab.isDirty = false
            writeDraft(for: tab)
            writeManifest()
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not save file"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    @objc func saveDocument(_ sender: Any?) { if let tab = activeTab { performSave(tab: tab) } }
    @objc func saveDocumentAs(_ sender: Any?) { if let tab = activeTab { performSaveAs(tab: tab) } }

    // MARK: Discard confirmation

    private func confirmDiscardIfNeeded(tab: Tab, proceed: @escaping () -> Void) {
        guard tab.isDirty else { proceed(); return }
        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to \(tab.fileURL?.lastPathComponent ?? "Untitled")?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if performSave(tab: tab) { proceed() }
        case .alertSecondButtonReturn:
            proceed()
        default:
            break
        }
    }

    // MARK: Quit / window close

    private func resolveAllDirtyTabs() -> Bool {
        for tab in tabs where tab.isDirty {
            selectTab(tab)
            let alert = NSAlert()
            alert.messageText = "Do you want to save changes to \(tab.fileURL?.lastPathComponent ?? "Untitled")?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                if !performSave(tab: tab) { return false }
            case .alertSecondButtonReturn:
                break
            default:
                return false
            }
        }
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        resolveAllDirtyTabs()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        resolveAllDirtyTabs() ? finishTerminate() : .terminateCancel
    }

    private func finishTerminate() -> NSApplication.TerminateReply {
        try? FileManager.default.removeItem(at: Autosave.manifestFile)
        for tab in tabs {
            try? FileManager.default.removeItem(at: Autosave.tabDraftFile(id: tab.id))
        }
        return .terminateNow
    }
}

// MARK: - Entry point

Autosave.ensureDir()
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
