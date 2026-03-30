import AppKit
import CoreGraphics

class TextInjector {

    func inject(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general

        // 1. Save original clipboard
        let originalChangeCount = pasteboard.changeCount
        var originalData: [(NSPasteboard.PasteboardType, Data)] = []
        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        originalData.append((type, data))
                    }
                }
            }
        }

        // 2. Detect CJK input method and switch if needed
        let originalInputSource = InputMethodUtils.currentInputSource()
        let needsSwitch = InputMethodUtils.isCJKInputSource(originalInputSource)
        if needsSwitch {
            InputMethodUtils.switchToASCII()
            usleep(50_000) // 50ms for input method to settle
        }

        // 3. Set text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 4. Simulate Cmd+V
        simulatePaste()

        // 5. Restore input method
        if needsSwitch {
            usleep(50_000)
            InputMethodUtils.switchTo(originalInputSource)
        }

        // 6. Restore original clipboard after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Only restore if nothing else has changed the clipboard
            if pasteboard.changeCount != originalChangeCount + 1 && originalData.isEmpty {
                return
            }
            pasteboard.clearContents()
            if !originalData.isEmpty {
                let item = NSPasteboardItem()
                for (type, data) in originalData {
                    item.setData(data, forType: type)
                }
                pasteboard.writeObjects([item])
            }
        }
    }

    private func simulatePaste() {
        let vKeyCode: CGKeyCode = 0x09

        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true)!
        cmdDown.flags = .maskCommand
        cmdDown.post(tap: .cgAnnotatedSessionEventTap)

        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false)!
        cmdUp.flags = .maskCommand
        cmdUp.post(tap: .cgAnnotatedSessionEventTap)

        usleep(50_000) // 50ms for paste to register
    }
}
