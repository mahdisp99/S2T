import Foundation

// MARK: - Configuration
struct Config {
    // اولویت: 1. Storage → 2. Environment Variable
    static var sonioxAPIKey: String {
        // 1. چک کردن Storage (UserDefaults با obfuscation)
        if let storedKey = KeychainManager.shared.getAPIKey(), !storedKey.isEmpty {
            return storedKey
        }
        
        // 2. چک کردن Environment Variable (.env file)
        if let envKey = ProcessInfo.processInfo.environment["SONIOX_API_KEY"], !envKey.isEmpty {
            // اگه از .env خوندیم، بذاریم توی Storage برای دفعات بعد
            _ = KeychainManager.shared.saveAPIKey(envKey)
            return envKey
        }
        
        return ""
    }
    
    private static let defaults = UserDefaults.standard
    private static let hotkeyStorageKey = "STT_HOTKEY_OPTION"
    private static let pasteLanguageKey = "STT_PASTE_LANGUAGE"
    
    static let sonioxURL = "wss://stt-rt.soniox.com/transcribe-websocket"
    static let sampleRate: Double = 16000
    
    // ذخیره API Key جدید
    static func saveAPIKey(_ key: String) -> Bool {
        return KeychainManager.shared.saveAPIKey(key)
    }
    
    // حذف API Key
    static func deleteAPIKey() {
        KeychainManager.shared.deleteAPIKey()
    }
    
    // چک کردن وجود API Key
    static func hasAPIKey() -> Bool {
        return !sonioxAPIKey.isEmpty
    }
    
    // MARK: - Hotkey Preference
    static func currentHotkeyOption() -> HotkeyOption {
        if let storedValue = defaults.string(forKey: hotkeyStorageKey),
           let option = HotkeyOption(rawValue: storedValue) {
            return option
        }
        return .microphoneKey
    }
    
    static func saveHotkeyOption(_ option: HotkeyOption) {
        defaults.set(option.rawValue, forKey: hotkeyStorageKey)
        defaults.synchronize()
    }
    
    static var hotkeyDisplayName: String {
        return currentHotkeyOption().displayName
    }
    
    // MARK: - Paste Language Preference
    enum PasteLanguage: String {
        case persian = "fa"
        case english = "en"
        
        var displayName: String {
            switch self {
            case .persian: return "Persian"
            case .english: return "English"
            }
        }
    }
    
    static func currentPasteLanguage() -> PasteLanguage {
        if let storedValue = defaults.string(forKey: pasteLanguageKey),
           let language = PasteLanguage(rawValue: storedValue) {
            return language
        }
        return .persian // Default: paste Persian text
    }
    
    static func savePasteLanguage(_ language: PasteLanguage) {
        defaults.set(language.rawValue, forKey: pasteLanguageKey)
        defaults.synchronize()
    }
}
