import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem!
    private let llmSettingsWindow = LLMSettingsWindow()
    var onLanguageChanged: ((String) -> Void)?

    private let languages: [(title: String, code: String)] = [
        ("English", "en-US"),
        ("简体中文", "zh-CN"),
        ("繁體中文", "zh-TW"),
        ("日本語", "ja-JP"),
        ("한국어", "ko-KR"),
    ]

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceIME")
            button.image?.size = NSSize(width: 16, height: 16)
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Language submenu
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        let currentLocale = Settings.shared.selectedLocale
        for lang in languages {
            let item = NSMenuItem(title: lang.title, action: #selector(languageSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.code
            item.state = (lang.code == currentLocale) ? .on : .off
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        // LLM submenu
        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()

        let toggleItem = NSMenuItem(
            title: Settings.shared.llmEnabled ? "Disable" : "Enable",
            action: #selector(toggleLLM(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        llmMenu.addItem(toggleItem)

        llmMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openLLMSettings), keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)

        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func languageSelected(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        Settings.shared.selectedLocale = code
        onLanguageChanged?(code)
        // Rebuild menu to update checkmarks
        statusItem.menu = buildMenu()
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        Settings.shared.llmEnabled = !Settings.shared.llmEnabled
        statusItem.menu = buildMenu()
    }

    @objc private func openLLMSettings() {
        llmSettingsWindow.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
