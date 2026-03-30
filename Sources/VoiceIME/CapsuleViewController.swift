import AppKit
import QuartzCore

class CapsuleViewController: NSViewController {
    let waveformView = WaveformView(frame: NSRect(x: 0, y: 0, width: 44, height: 32))
    private let textLabel = NSTextField(labelWithString: "")
    private let effectView = NSVisualEffectView()
    private let spinnerView = AISpinnerView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))

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

        spinnerView.frame = NSRect(x: waveformLeftPad + 6, y: 12, width: 32, height: 32)
        spinnerView.isHidden = true
        container.addSubview(spinnerView)

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
        hideRefiningMode()
    }

    func showRefiningMode() {
        textLabel.stringValue = "AI 润色中..."
        waveformView.isHidden = true
        spinnerView.isHidden = false
        spinnerView.startAnimating()
    }

    func hideRefiningMode() {
        spinnerView.stopAnimating()
        spinnerView.isHidden = true
        waveformView.isHidden = false
    }

    func calculateWidth(for text: String) -> CGFloat {
        let textWidth = (text as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium)]
        ).width
        let totalWidth = waveformLeftPad + waveformWidth + gap + textWidth + rightPad
        return min(maxWidth, max(minWidth, totalWidth))
    }
}

// MARK: - AI Spinner

class AISpinnerView: NSView {
    private var rotationAnimation: CABasicAnimation?
    private var pulseAnimation: CABasicAnimation?
    private let arcLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()
    private let dotLayer = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 12

        // Glow ring
        let glowPath = CGMutablePath()
        glowPath.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        glowLayer.path = glowPath
        glowLayer.fillColor = nil
        glowLayer.strokeColor = NSColor(calibratedRed: 0.3, green: 0.7, blue: 1.0, alpha: 0.15).cgColor
        glowLayer.lineWidth = 3
        layer?.addSublayer(glowLayer)

        // Arc
        let arcPath = CGMutablePath()
        arcPath.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 1.2, clockwise: false)
        arcLayer.path = arcPath
        arcLayer.fillColor = nil
        arcLayer.strokeColor = NSColor(calibratedRed: 0.3, green: 0.7, blue: 1.0, alpha: 0.9).cgColor
        arcLayer.lineWidth = 2.5
        arcLayer.lineCap = .round
        arcLayer.shadowColor = NSColor(calibratedRed: 0.3, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        arcLayer.shadowRadius = 4
        arcLayer.shadowOpacity = 0.8
        arcLayer.shadowOffset = .zero
        layer?.addSublayer(arcLayer)

        // Center dot
        let dotSize: CGFloat = 5
        dotLayer.path = CGPath(ellipseIn: CGRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2, width: dotSize, height: dotSize), transform: nil)
        dotLayer.fillColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 1.0, alpha: 1.0).cgColor
        dotLayer.shadowColor = NSColor(calibratedRed: 0.3, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        dotLayer.shadowRadius = 3
        dotLayer.shadowOpacity = 1.0
        dotLayer.shadowOffset = .zero
        layer?.addSublayer(dotLayer)
    }

    func startAnimating() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Rotation
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 1.2
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        arcLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        arcLayer.position = center
        arcLayer.bounds = bounds
        arcLayer.add(rotation, forKey: "spin")

        // Pulse on dot
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotLayer.add(pulse, forKey: "pulse")

        // Glow pulse
        let glowPulse = CABasicAnimation(keyPath: "strokeColor")
        glowPulse.fromValue = NSColor(calibratedRed: 0.3, green: 0.7, blue: 1.0, alpha: 0.15).cgColor
        glowPulse.toValue = NSColor(calibratedRed: 0.3, green: 0.7, blue: 1.0, alpha: 0.35).cgColor
        glowPulse.duration = 1.0
        glowPulse.autoreverses = true
        glowPulse.repeatCount = .infinity
        glowPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(glowPulse, forKey: "glowPulse")
    }

    func stopAnimating() {
        arcLayer.removeAllAnimations()
        dotLayer.removeAllAnimations()
        glowLayer.removeAllAnimations()
    }
}
