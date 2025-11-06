import Cocoa

// MARK: - Hotkey Manager
class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var systemGlobalMonitor: Any?
    private var systemLocalMonitor: Any?
    private var handler: (() -> Void)?
    private(set) var currentOption: HotkeyOption?
    
    private var lastControlTapTime: Date?
    private let controlTapThreshold: TimeInterval = 0.5
    
    deinit {
        unregister()
    }
    
    func register(option: HotkeyOption, handler: @escaping () -> Void) {
        unregister()
        
        currentOption = option
        self.handler = handler
        
        let eventMask: NSEvent.EventTypeMask = (option == .controlControl) ? .flagsChanged : .keyDown
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            guard let self = self else { return }
            if self.matches(event, option: option) {
                self.trigger()
            }
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            guard let self = self else { return event }
            if self.matches(event, option: option) {
                self.trigger()
                return option == .controlControl ? event : nil
            }
            return event
        }
        
        if option.systemKeyCode != nil {
            systemGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
                guard let self = self else { return }
                if self.matchesSystemEvent(event, option: option) {
                    self.trigger()
                }
            }
            
            systemLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
                guard let self = self else { return event }
                if self.matchesSystemEvent(event, option: option) {
                    self.trigger()
                    return nil
                }
                return event
            }
        }
    }
    
    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let systemGlobalMonitor {
            NSEvent.removeMonitor(systemGlobalMonitor)
        }
        if let systemLocalMonitor {
            NSEvent.removeMonitor(systemLocalMonitor)
        }
        
        globalMonitor = nil
        localMonitor = nil
        systemGlobalMonitor = nil
        systemLocalMonitor = nil
        lastControlTapTime = nil
    }
    
    // MARK: - Helpers
    private func trigger() {
        DispatchQueue.main.async { [weak self] in
            self?.handler?()
        }
    }
    
    private func matches(_ event: NSEvent, option: HotkeyOption) -> Bool {
        if option == .controlControl {
            return matchesDoubleControl(event)
        }
        
        guard event.type == .keyDown else { return false }
        guard !event.isARepeat else { return false }
        guard event.keyCode == option.keyCode else { return false }
        
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredFlags = option.modifierFlags
        
        guard requiredFlags.isSubset(of: flags) else { return false }
        
        let extraFlags = flags.subtracting(requiredFlags)
        if !extraFlags.subtracting(option.allowedExtraFlags).isEmpty {
            return false
        }
        
        return true
    }
    
    private func matchesSystemEvent(_ event: NSEvent, option: HotkeyOption) -> Bool {
        guard let systemKeyCode = option.systemKeyCode else { return false }
        guard event.type == .systemDefined else { return false }
        guard event.subtype.rawValue == 8 else { return false } // NX_SUBTYPE_AUX_CONTROL_BUTTONS
        
        let data1 = UInt32(bitPattern: Int32(event.data1))
        let keyCode = Int((data1 & 0xFFFF0000) >> 16)
        let keyFlags = (data1 & 0x0000FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0x0A || keyState == 0x09 || (keyFlags & 0x1) == 1
        
        return isKeyDown && keyCode == systemKeyCode
    }
    
    private func matchesDoubleControl(_ event: NSEvent) -> Bool {
        guard event.type == .flagsChanged else { return false }
        guard event.keyCode == 59 || event.keyCode == 62 else { return false } // left/right control
        
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isControlPressed = flags.contains(.control)
        guard flags.subtracting([.control, .capsLock]).isEmpty else { return false }
        
        let now = Date()
        
        if isControlPressed {
            defer { lastControlTapTime = now }
            
            if let lastTap = lastControlTapTime, now.timeIntervalSince(lastTap) <= controlTapThreshold {
                lastControlTapTime = nil
                return true
            }
        }
        
        return false
    }
}
