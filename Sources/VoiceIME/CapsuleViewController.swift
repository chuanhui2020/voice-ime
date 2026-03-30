import AppKit

class CapsuleViewController: NSViewController {
    let waveformView = WaveformView(frame: NSRect(x: 0, y: 0, width: 44, height: 32))
    private let textLabel = NSTextField(labelWithString: "")
    private let effectView = NSVisualEffectView()

    private let minWidth: CGFloat = 160
    private let maxWidth: CGFloat = 560
    private let waveformLeftPad: CGFloat = 16
    private let waveformWidth: CGFloat = 44
    private let gap: CGFloat = 8
    private let rightPad: CGFloat = 16

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: minWidth, height: 56))
        container.wantsLayer = true

        effectView.frame = container.bounds
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 28
        effectView.layer?.masksToBounds = true
        container.addSubview(effectView)

        waveformView.frame = NSRect(x: waveformLeftPad, y: 12, width: waveformWidth, height: 32)
        container.addSubview(waveformView)

        let labelX = waveformLeftPad + waveformWidth + gap
        textLabel.frame = NSRect(x: labelX, y: 0, width: minWidth - labelX - rightPad, height: 56)
        textLabel.font = .systemFont(ofSize: 14, weight: .medium)
        textLabel.textColor = .white
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1
        textLabel.cell?.truncatesLastVisibleLine = true
        textLabel.autoresizingMask = [.width]
        container.addSubview(textLabel)

        self.view = container
    }

    func updateText(_ text: String) {
        textLabel.stringValue = text
    }

    func calculateWidth(for text: String) -> CGFloat {
        let textWidth = (text as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium)]
        ).width
        let totalWidth = waveformLeftPad + waveformWidth + gap + textWidth + rightPad
        return min(maxWidth, max(minWidth, totalWidth))
    }
}
