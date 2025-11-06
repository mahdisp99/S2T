import Cocoa
import QuartzCore

// MARK: - Floating Window
class FloatingWindow: NSPanel {
    private var textField: NSTextField?
    private var translationField: NSTextField?
    private var micButton: NSButton?
    private var statusLabel: NSTextField?
    private var waveformView: WaveformView?
    private var micPulseLayer: CAShapeLayer?
    private var micInnerDot: CALayer?
    
    var onMicToggle: (() -> Void)?
    private var isRecording: Bool = false
    
    init() {
        // محاسبه مختصات (وسط بالای صفحه)
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let windowWidth: CGFloat = 720
        let windowHeight: CGFloat = 180  // ارتفاع بیشتر برای فضای بهتر
        let x = (screenWidth - windowWidth) / 2
        let y = screenHeight - windowHeight - 60
        
        let rect = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // تنظیمات window
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.22, alpha: 0.96)
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        
        configureSubviews(windowWidth: windowWidth, windowHeight: windowHeight)
    }
    
    private func configureSubviews(windowWidth: CGFloat, windowHeight: CGFloat) {
        let contentBounds = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        
        // پس‌زمینهٔ Blur ساده
        let backgroundView = NSVisualEffectView(frame: contentBounds)
        backgroundView.material = .hudWindow
        backgroundView.state = .active
        backgroundView.blendingMode = .behindWindow
        self.contentView = backgroundView
        
        // دکمه میکروفون + انیمیشن
        let micContainerSize: CGFloat = 54
        let micContainer = NSView(frame: NSRect(x: windowWidth - micContainerSize - 24, y: windowHeight - micContainerSize - 24, width: micContainerSize, height: micContainerSize))
        micContainer.wantsLayer = true
        micContainer.layer?.cornerRadius = micContainerSize / 2
        micContainer.layer?.masksToBounds = false
        micContainer.layer?.backgroundColor = NSColor.clear.cgColor
        backgroundView.addSubview(micContainer)
        
        let pulseLayer = CAShapeLayer()
        pulseLayer.frame = micContainer.bounds
        pulseLayer.path = CGPath(ellipseIn: micContainer.bounds, transform: nil)
        pulseLayer.fillColor = NSColor(calibratedRed: 0.95, green: 0.2, blue: 0.35, alpha: 0.2).cgColor
        pulseLayer.opacity = 0
        micContainer.layer?.addSublayer(pulseLayer)
        micPulseLayer = pulseLayer
        
        let button = NSButton(frame: micContainer.bounds.insetBy(dx: 8, dy: 8))
        button.wantsLayer = true
        button.layer?.cornerRadius = (micContainerSize - 16) / 2
        button.layer?.masksToBounds = true
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.title = ""
        button.target = self
        button.action = #selector(micButtonTapped)
        micContainer.addSubview(button)
        micButton = button
        
        let dotLayer = CALayer()
        let dotSize: CGFloat = 12
        dotLayer.bounds = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        dotLayer.position = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
        dotLayer.cornerRadius = dotSize / 2
        dotLayer.backgroundColor = NSColor(calibratedWhite: 0.9, alpha: 0.8).cgColor
        dotLayer.shadowColor = NSColor.black.withAlphaComponent(0.3).cgColor
        dotLayer.shadowOpacity = 0.3
        dotLayer.shadowRadius = 1.5
        dotLayer.shadowOffset = .zero
        button.layer?.addSublayer(dotLayer)
        micInnerDot = dotLayer
        updateMicButtonAppearance(isActive: false, animated: false)
        
        // برچسب وضعیت
        let status = NSTextField(labelWithString: "Ready")
        status.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        status.textColor = NSColor.secondaryLabelColor
        status.alignment = .center
        status.frame = NSRect(x: micContainer.frame.minX - 8, y: micContainer.frame.minY - 22, width: micContainer.frame.width + 16, height: 18)
        backgroundView.addSubview(status)
        statusLabel = status
        
        // فیلد متن
        let contentWidth = max(180, micContainer.frame.minX - 48)
        
        // Persian text field
        let transcriptionField = NSTextField(frame: NSRect(x: 24, y: windowHeight - 75, width: contentWidth, height: 40))
        transcriptionField.isEditable = false
        transcriptionField.isBordered = false
        transcriptionField.drawsBackground = false
        transcriptionField.alignment = .center
        transcriptionField.font = NSFont.systemFont(ofSize: 16)
        transcriptionField.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.95)
        transcriptionField.stringValue = "🎤 Ready to start..."
        transcriptionField.maximumNumberOfLines = 2
        backgroundView.addSubview(transcriptionField)
        textField = transcriptionField
        
        // فیلد ترجمه انگلیسی
        let translationTextField = NSTextField(frame: NSRect(x: 24, y: windowHeight - 115, width: contentWidth, height: 35))
        translationTextField.isEditable = false
        translationTextField.isBordered = false
        translationTextField.drawsBackground = false
        translationTextField.alignment = .center
        translationTextField.font = NSFont.systemFont(ofSize: 14)
        translationTextField.textColor = NSColor(calibratedRed: 0.5, green: 0.85, blue: 1.0, alpha: 0.85)
        translationTextField.stringValue = ""
        translationTextField.maximumNumberOfLines = 2
        backgroundView.addSubview(translationTextField)
        translationField = translationTextField
        
        // Waveform view (بزرگتر و قشنگ‌تر)
        let waveform = WaveformView(frame: NSRect(x: 32, y: 18, width: contentWidth - 16, height: 26))
        waveform.level = 0
        backgroundView.addSubview(waveform)
        waveformView = waveform
    }
    
    func updateText(_ text: String, isFinal: Bool) {
        let emoji = isFinal ? "✅" : "💬"
        textField?.stringValue = "\(emoji) \(text)"
        textField?.textColor = isFinal ? NSColor(calibratedRed: 0.2, green: 0.9, blue: 0.5, alpha: 1.0) : NSColor(calibratedWhite: 1.0, alpha: 0.95)
        textField?.font = isFinal ? NSFont.boldSystemFont(ofSize: 18) : NSFont.systemFont(ofSize: 16)
    }
    
    func updateTranslation(_ text: String, isFinal: Bool) {
        let emoji = isFinal ? "🌐" : "🔄"
        translationField?.stringValue = "\(emoji) \(text)"
        translationField?.textColor = isFinal ? NSColor(calibratedRed: 0.3, green: 0.8, blue: 1.0, alpha: 1.0) : NSColor(calibratedRed: 0.5, green: 0.85, blue: 1.0, alpha: 0.85)
        translationField?.font = isFinal ? NSFont.boldSystemFont(ofSize: 15) : NSFont.systemFont(ofSize: 14)
    }
    
    func clearText() {
        textField?.stringValue = "🎤 Ready..."
        textField?.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.95)
        textField?.font = NSFont.systemFont(ofSize: 16)
        translationField?.stringValue = ""
    }
    
    func updateRecordingState(isRecording: Bool) {
        self.isRecording = isRecording
        updateMicButtonAppearance(isActive: isRecording)
        statusLabel?.stringValue = isRecording ? "Listening…" : "Ready"
        statusLabel?.textColor = isRecording ? NSColor.systemRed : NSColor.secondaryLabelColor
        waveformView?.setActive(isRecording)
        
        if !isRecording {
            updateLevel(0)
        }
    }
    
    func updateLevel(_ level: Float) {
        waveformView?.update(with: CGFloat(level))
    }
    
    @objc private func micButtonTapped() {
        onMicToggle?()
    }
    
    private func updateMicButtonAppearance(isActive: Bool, animated: Bool = true) {
        let targetColor = isActive
            ? NSColor(calibratedRed: 0.88, green: 0.17, blue: 0.24, alpha: 0.96)
            : NSColor(calibratedWhite: 0.22, alpha: 0.85)
        
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        micButton?.layer?.backgroundColor = targetColor.cgColor
        CATransaction.commit()
        
        guard let buttonLayer = micButton?.layer else { return }
        buttonLayer.shadowColor = (isActive ? NSColor(calibratedRed: 0.95, green: 0.25, blue: 0.35, alpha: 0.9) : NSColor.black.withAlphaComponent(0.35)).cgColor
        buttonLayer.shadowOpacity = isActive ? 0.7 : 0.3
        buttonLayer.shadowRadius = isActive ? 9 : 4
        buttonLayer.shadowOffset = .zero
        buttonLayer.masksToBounds = false
        micInnerDot?.backgroundColor = (isActive ? NSColor.white : NSColor(calibratedWhite: 0.75, alpha: 0.9)).cgColor
        micInnerDot?.opacity = isActive ? 1.0 : 0.7
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        micInnerDot?.setAffineTransform(CGAffineTransform(scaleX: isActive ? 1.2 : 1.0, y: isActive ? 1.2 : 1.0))
        CATransaction.commit()

        if isActive {
            startPulseAnimation()
            startButtonBounce(on: buttonLayer)
        } else {
            stopPulseAnimation()
            resetButtonTransform(on: buttonLayer, animated: animated)
        }
    }
    
    private func startPulseAnimation() {
        guard let pulseLayer = micPulseLayer, pulseLayer.animation(forKey: "pulse") == nil else { return }
        
        pulseLayer.opacity = 1
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.45
        pulse.duration = 1.2
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulse.repeatCount = .infinity
        pulse.autoreverses = false
        pulseLayer.add(pulse, forKey: "pulse")
        
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.6
        fade.toValue = 0.0
        fade.duration = 1.2
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.repeatCount = .infinity
        fade.autoreverses = false
        pulseLayer.add(fade, forKey: "fade")
    }
    
    private func stopPulseAnimation() {
        micPulseLayer?.removeAnimation(forKey: "pulse")
        micPulseLayer?.removeAnimation(forKey: "fade")
        micPulseLayer?.opacity = 0
    }
    
    private func startButtonBounce(on layer: CALayer) {
        if layer.animation(forKey: "micBounce") != nil { return }
        let bounce = CABasicAnimation(keyPath: "transform.scale")
        bounce.fromValue = 1.0
        bounce.toValue = 1.08
        bounce.duration = 0.45
        bounce.autoreverses = true
        bounce.repeatCount = .infinity
        bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(bounce, forKey: "micBounce")
    }
    
    private func resetButtonTransform(on layer: CALayer, animated: Bool) {
        layer.removeAnimation(forKey: "micBounce")
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        layer.setAffineTransform(.identity)
        micInnerDot?.setAffineTransform(.identity)
        CATransaction.commit()
    }
}
