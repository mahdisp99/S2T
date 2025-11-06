import Cocoa
import QuartzCore

// MARK: - Waveform View
class WaveformView: NSView {
    private let barCount = 42  // بیشتر برای smooth تر بودن
    private var barLayers: [CALayer] = []
    private let minHeight: CGFloat = 3  // کوچیکتر
    private let maxHeight: CGFloat = 32  // کوچیکتر
    private var isActive = false
    
    private var barHeights: [CGFloat] = []
    private var lastTimestamp: CFTimeInterval = 0
    
    var level: CGFloat = 0 {
        didSet {
            update(with: level)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.12, alpha: 0.5).cgColor  // سبز تیره
        layer?.cornerRadius = frameRect.height / 2
        layer?.masksToBounds = true
        createBars()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        layoutBars(animated: false)
        update(with: level, animated: false)
    }
    
    func setActive(_ active: Bool) {
        isActive = active
        if !active {
            update(with: 0, animated: true)
        }
    }
    
    func update(with inputLevel: CGFloat, animated: Bool = true) {
        let clamped = max(0, min(inputLevel, 1))
        // افزایش حساسیت: amplify برای liveتر بودن
        let amplified = min(1.0, clamped * 2.5)  // 2.5x بیشتر حساس
        let eased = pow(amplified, 0.35)  // کمتر smooth = liveتر
        
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.08)  // سریع‌تر برای responsive بودن
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        
        let timestamp = CACurrentMediaTime()
        let timeDelta = CGFloat(max(0.0, min(1.0, timestamp - lastTimestamp)))
        lastTimestamp = timestamp
        
        if barHeights.count != barCount {
            barHeights = Array(repeating: minHeight, count: barCount)
        }
        
        for index in 0..<barCount {
            let positionRatio = CGFloat(index) / CGFloat(barCount - 1)
            let envelope = sin(positionRatio * .pi)
            
            // انیمیشن سریع‌تر و واضح‌تر
            let oscillation = CGFloat(abs(sin((timestamp * 6.5) + Double(index) * 0.8)))
            let dynamicFactor = 0.25 + 0.75 * oscillation  // تغییرات بیشتر
            
            let targetHeight = minHeight + (maxHeight - minHeight) * eased * envelope * dynamicFactor
            let cappedHeight = max(minHeight, min(targetHeight, maxHeight))
            
            // smoothing کمتر = liveتر
            let smoothing = max(0.4, min(0.75, 0.5 + timeDelta * 0.8))
            barHeights[index] += (cappedHeight - barHeights[index]) * smoothing
            let newHeight = barHeights[index]
            
            let barLayer = barLayers[index]
            var barFrame = barLayer.frame
            barFrame.origin.y = (bounds.height - newHeight) / 2
            barFrame.size.height = newHeight
            barLayer.frame = barFrame
            barLayer.backgroundColor = colorForLevel(positionRatio: positionRatio, level: eased).cgColor
        }
        
        CATransaction.commit()
    }
    
    private func createBars() {
        guard let parentLayer = layer else { return }
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        
        for _ in 0..<barCount {
            let barLayer = CALayer()
            barLayer.cornerRadius = 2.5
            barLayer.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.85, blue: 0.45, alpha: 0.7).cgColor  // سبز روشن
            parentLayer.addSublayer(barLayer)
            barLayers.append(barLayer)
        }
        
        barHeights = Array(repeating: minHeight, count: barCount)
        lastTimestamp = CACurrentMediaTime()
        
        layoutBars(animated: false)
    }
    
    private func layoutBars(animated: Bool) {
        guard barLayers.count == barCount else { return }
        let totalSpacing = CGFloat(barCount - 1) * 2.5  // فاصله کمتر
        let barWidth = max(2.5, (bounds.width - totalSpacing) / CGFloat(barCount))  // باریک‌تر
        
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(animated ? 0.18 : 0.0)
        
        for (index, layer) in barLayers.enumerated() {
            let x = CGFloat(index) * (barWidth + 2.5)
            layer.frame = CGRect(x: x,
                                 y: (bounds.height - minHeight) / 2,
                                 width: barWidth,
                                 height: minHeight)
            if barHeights.indices.contains(index) {
                barHeights[index] = minHeight
            }
        }
        
        CATransaction.commit()
    }
    
    private func colorForLevel(positionRatio: CGFloat, level: CGFloat) -> NSColor {
        if !isActive {
            return NSColor(calibratedRed: 0.2, green: 0.5, blue: 0.35, alpha: 0.3)  // سبز خاموش
        }
        
        let intensity = level * (0.5 + 0.5 * positionRatio)
        
        // گرادیانت سبز زنده و خوشگل
        if intensity > 0.75 {
            // سبز فسفری درخشان
            return NSColor(calibratedRed: 0.1, green: 0.95, blue: 0.4, alpha: 0.95)
        } else if intensity > 0.5 {
            // سبز روشن
            return NSColor(calibratedRed: 0.15, green: 0.85, blue: 0.45, alpha: 0.85)
        } else if intensity > 0.25 {
            // سبز متوسط
            return NSColor(calibratedRed: 0.2, green: 0.75, blue: 0.5, alpha: 0.75)
        } else {
            // سبز ملایم
            return NSColor(calibratedRed: 0.25, green: 0.65, blue: 0.5, alpha: 0.65)
        }
    }
}
