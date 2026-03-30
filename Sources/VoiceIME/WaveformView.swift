import AppKit

class WaveformView: NSView {
    private let barWeights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var currentLevel: CGFloat = 0
    private var smoothedLevel: CGFloat = 0
    private var barJitters: [CGFloat] = [0, 0, 0, 0, 0]
    private var animationTimer: Timer?

    private let attackRate: CGFloat = 0.40
    private let releaseRate: CGFloat = 0.15

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        startAnimation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        startAnimation()
    }

    func updateLevel(_ level: Float) {
        currentLevel = CGFloat(level)
    }

    func reset() {
        currentLevel = 0
        smoothedLevel = 0
    }

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func tick() {
        if currentLevel > smoothedLevel {
            smoothedLevel += (currentLevel - smoothedLevel) * attackRate
        } else {
            smoothedLevel += (currentLevel - smoothedLevel) * releaseRate
        }

        for i in 0..<5 {
            barJitters[i] = CGFloat.random(in: -0.04...0.04)
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let barWidth: CGFloat = 4
        let barSpacing: CGFloat = 4
        let totalBarsWidth = CGFloat(5) * barWidth + CGFloat(4) * barSpacing
        let startX = (bounds.width - totalBarsWidth) / 2
        let maxBarHeight = bounds.height - 4
        let minBarHeight: CGFloat = 4

        ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)

        for i in 0..<5 {
            let weight = barWeights[i]
            let jitter = barJitters[i]
            let effectiveLevel = smoothedLevel * weight * (1.0 + jitter)
            let barHeight = max(minBarHeight, effectiveLevel * maxBarHeight)

            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = (bounds.height - barHeight) / 2

            let rect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            path.fill()
        }
    }
}
