import AppKit

class CapsuleWindow {
    private var panel: NSPanel!
    private var viewController: CapsuleViewController!

    init() {
        viewController = CapsuleViewController()

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 56),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.contentViewController = viewController
    }

    func show() {
        positionAtBottomCenter()

        // Start below and transparent for entrance animation
        let frame = panel.frame
        panel.setFrame(
            NSRect(x: frame.origin.x, y: frame.origin.y - 20,
                   width: frame.width, height: frame.height),
            display: false
        )
        panel.alphaValue = 0
        panel.orderFront(nil)

        // Spring entrance animation (0.35s)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.275)
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1.0
            var targetFrame = panel.frame
            targetFrame.origin.y += 20
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    func hide(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0
            // Scale down effect via shrinking frame
            var frame = panel.frame
            let shrink: CGFloat = 8
            frame.origin.x += shrink
            frame.origin.y += shrink / 2
            frame.size.width -= shrink * 2
            frame.size.height -= shrink
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
            self?.viewController.updateText("")
            self?.viewController.waveformView.reset()
            completion?()
        })
    }

    func updateText(_ text: String) {
        viewController.updateText(text)
        let newWidth = viewController.calculateWidth(for: text)
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.origin.x + (screenFrame.width - newWidth) / 2
        let y = panel.frame.origin.y

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(
                NSRect(x: x, y: y, width: newWidth, height: 56),
                display: true
            )
        }
    }

    func updateRMS(_ level: Float) {
        viewController.waveformView.updateLevel(level)
    }

    func showRefining() {
        viewController.updateText("Refining...")
    }

    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let width = panel.frame.width
        let x = screenFrame.origin.x + (screenFrame.width - width) / 2
        let y = screenFrame.origin.y + 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
