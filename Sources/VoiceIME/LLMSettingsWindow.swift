import AppKit

class LLMSettingsWindow {
    private var window: NSWindow?

    private let baseURLField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "LLM Settings"
        w.center()
        w.isReleasedWhenClosed = false

        let contentView = NSView(frame: w.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        w.contentView = contentView

        let padding: CGFloat = 20
        let labelWidth: CGFloat = 100
        let fieldHeight: CGFloat = 24
        var y: CGFloat = 230

        // API Base URL
        let urlLabel = NSTextField(labelWithString: "API Base URL:")
        urlLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: fieldHeight)
        urlLabel.alignment = .right
        contentView.addSubview(urlLabel)

        baseURLField.frame = NSRect(x: padding + labelWidth + 8, y: y, width: 330, height: fieldHeight)
        baseURLField.placeholderString = "https://api.openai.com/v1"
        baseURLField.stringValue = Settings.shared.llmBaseURL
        contentView.addSubview(baseURLField)

        y -= 40

        // API Key
        let keyLabel = NSTextField(labelWithString: "API Key:")
        keyLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: fieldHeight)
        keyLabel.alignment = .right
        contentView.addSubview(keyLabel)

        apiKeyField.frame = NSRect(x: padding + labelWidth + 8, y: y, width: 330, height: fieldHeight)
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.stringValue = Settings.shared.llmAPIKey
        contentView.addSubview(apiKeyField)

        y -= 40

        // Model
        let modelLabel = NSTextField(labelWithString: "Model:")
        modelLabel.frame = NSRect(x: padding, y: y, width: labelWidth, height: fieldHeight)
        modelLabel.alignment = .right
        contentView.addSubview(modelLabel)

        modelField.frame = NSRect(x: padding + labelWidth + 8, y: y, width: 330, height: fieldHeight)
        modelField.placeholderString = "gpt-4o-mini"
        modelField.stringValue = Settings.shared.llmModel
        contentView.addSubview(modelField)

        y -= 50

        // Buttons
        let testButton = NSButton(title: "Test", target: nil, action: nil)
        testButton.frame = NSRect(x: padding + labelWidth + 8, y: y, width: 80, height: 32)
        testButton.target = self
        testButton.action = #selector(testConnection)
        contentView.addSubview(testButton)

        let saveButton = NSButton(title: "Save", target: nil, action: nil)
        saveButton.frame = NSRect(x: padding + labelWidth + 8 + 90, y: y, width: 80, height: 32)
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        statusLabel.frame = NSRect(x: padding + labelWidth + 8 + 180, y: y + 6, width: 200, height: fieldHeight)
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func testConnection() {
        statusLabel.stringValue = "Testing..."
        statusLabel.textColor = .secondaryLabelColor

        let service = LLMService()
        service.testConnection(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue
        ) { [weak self] success, message in
            self?.statusLabel.stringValue = message
            self?.statusLabel.textColor = success ? .systemGreen : .systemRed
        }
    }

    @objc private func saveSettings() {
        Settings.shared.llmBaseURL = baseURLField.stringValue
        Settings.shared.llmAPIKey = apiKeyField.stringValue
        Settings.shared.llmModel = modelField.stringValue
        statusLabel.stringValue = "Saved!"
        statusLabel.textColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.window?.close()
        }
    }
}
