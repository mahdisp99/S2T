import AppKit

// MARK: - Hotkey Options
enum HotkeyOption: String, CaseIterable {
    case microphoneKey
    case optionShiftSpace
    case commandOptionR
    case commandShiftR
    case controlOptionSpace
    case controlControl
    
    var displayName: String {
        switch self {
        case .microphoneKey:
            return "Mic Key (F5)"
        case .optionShiftSpace:
            return "Option+Shift+Space"
        case .commandOptionR:
            return "Cmd+Option+R"
        case .commandShiftR:
            return "Cmd+Shift+R"
        case .controlOptionSpace:
            return "Ctrl+Option+Space"
        case .controlControl:
            return "Control twice"
        }
    }
    
    var menuTitle: String {
        switch self {
        case .microphoneKey:
            return "🎙️ Mic Key (F5)"
        case .optionShiftSpace:
            return "⌨️ Option+Shift+Space"
        case .commandOptionR:
            return "⌘⌥R (Cmd+Option+R)"
        case .commandShiftR:
            return "⌘⇧R (Cmd+Shift+R)"
        case .controlOptionSpace:
            return "⌃⌥Space (Ctrl+Option+Space)"
        case .controlControl:
            return "⌃⌃ (Control ×2)"
        }
    }
    
    var keyCode: UInt16 {
        switch self {
        case .microphoneKey:
            return 96 // F5 / microphone key
        case .optionShiftSpace:
            return 49 // Space bar
        case .commandOptionR, .commandShiftR:
            return 15 // R key
        case .controlOptionSpace:
            return 49 // Space bar
        case .controlControl:
            return 59 // Left Control key (handled specially)
        }
    }
    
    var modifierFlags: NSEvent.ModifierFlags {
        switch self {
        case .microphoneKey:
            return []
        case .optionShiftSpace:
            return [.option, .shift]
        case .commandOptionR:
            return [.command, .option]
        case .commandShiftR:
            return [.command, .shift]
        case .controlOptionSpace:
            return [.control, .option]
        case .controlControl:
            return [.control]
        }
    }
    
    var allowedExtraFlags: NSEvent.ModifierFlags {
        switch self {
        case .microphoneKey:
            return [.function, .capsLock]
        case .optionShiftSpace, .controlOptionSpace:
            return [.function, .capsLock]
        case .commandOptionR, .commandShiftR:
            return [.capsLock]
        case .controlControl:
            return [.capsLock, .function]
        }
    }
    
    var systemKeyCode: Int? {
        switch self {
        case .microphoneKey:
            return HotkeyOption.dictationKeyCode
        case .optionShiftSpace:
            return nil
        case .commandOptionR:
            return nil
        case .commandShiftR:
            return nil
        case .controlOptionSpace:
            return nil
        case .controlControl:
            return nil
        }
    }
    
    private static let dictationKeyCode = 0x11 // NX_KEYTYPE_DICTATION (dictation/mic button)
}
