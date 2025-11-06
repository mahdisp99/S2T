import Foundation

// MARK: - Simple Storage Manager (بدون Keychain - بدون پاپ اپ امنیتی!)
class KeychainManager {
    static let shared = KeychainManager()
    
    private let storageKey = "SONIOX_API_KEY_STORAGE_v2"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // Obfuscation ساده برای جلوگیری از plain text
    // نکته: این امنیت کامل نیست، ولی از پاپ اپ Keychain جلوگیری می‌کنه
    private func obfuscate(_ text: String) -> String {
        return Data(text.utf8).base64EncodedString()
    }
    
    private func deobfuscate(_ text: String) -> String? {
        guard let data = Data(base64Encoded: text) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // ذخیره API Key
    func saveAPIKey(_ key: String) -> Bool {
        let obfuscated = obfuscate(key)
        defaults.set(obfuscated, forKey: storageKey)
        defaults.synchronize()
        return true
    }
    
    // خواندن API Key
    func getAPIKey() -> String? {
        guard let obfuscated = defaults.string(forKey: storageKey) else { return nil }
        return deobfuscate(obfuscated)
    }
    
    // حذف API Key
    func deleteAPIKey() {
        defaults.removeObject(forKey: storageKey)
        defaults.synchronize()
    }
    
    // بررسی وجود API Key
    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}
