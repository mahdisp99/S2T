import Cocoa

// MARK: - Settings Window
class SettingsWindow: NSWindow {
    private var apiKeyField: NSSecureTextField!
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    private var statusLabel: NSTextField!
    private var hotkeyPopup: NSPopUpButton!
    private var pasteLanguagePopup: NSPopUpButton!
    
    var onSave: ((String, HotkeyOption, Config.PasteLanguage) -> Void)?
    
    init() {
        let rect = NSRect(x: 0, y: 0, width: 580, height: 360)  // عریض‌تر برای API key
        
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Settings"
        self.level = .floating
        self.center()
        self.isReleasedWhenClosed = false
        
        setupUI()
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Title Label
        let titleLabel = NSTextField(labelWithString: "🔐 Soniox API Key")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: 300, width: 540, height: 30)
        titleLabel.alignment = .center
        contentView.addSubview(titleLabel)
        
        // Info Label
        let infoLabel = NSTextField(labelWithString: "Enter your Soniox API key to use speech-to-text")
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.frame = NSRect(x: 20, y: 275, width: 540, height: 20)
        infoLabel.alignment = .center
        contentView.addSubview(infoLabel)
        
        // API Key Field (عریض‌تر و single-line)
        apiKeyField = NSSecureTextField(frame: NSRect(x: 40, y: 230, width: 500, height: 30))
        apiKeyField.placeholderString = "Enter API Key here..."
        apiKeyField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        apiKeyField.maximumNumberOfLines = 1  // فقط یک خط
        apiKeyField.usesSingleLineMode = true  // حتماً single-line
        apiKeyField.lineBreakMode = .byTruncatingTail  // اگه طولانی شد، آخرش رو ... بکن
        
        // بارگذاری key موجود (اگه هست)
        if let existingKey = KeychainManager.shared.getAPIKey() {
            apiKeyField.stringValue = existingKey
        }
        
        contentView.addSubview(apiKeyField)
        
        // Status Label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.frame = NSRect(x: 40, y: 200, width: 500, height: 20)
        statusLabel.alignment = .center
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)
        
        // Hotkey Selector
        let hotkeyLabel = NSTextField(labelWithString: "⌨️ Recording Hotkey")
        hotkeyLabel.font = NSFont.systemFont(ofSize: 12)
        hotkeyLabel.textColor = .secondaryLabelColor
        hotkeyLabel.alignment = .center
        hotkeyLabel.frame = NSRect(x: 20, y: 165, width: 540, height: 18)
        contentView.addSubview(hotkeyLabel)
        
        hotkeyPopup = NSPopUpButton(frame: NSRect(x: 190, y: 135, width: 200, height: 26), pullsDown: false)
        hotkeyPopup.autoenablesItems = false
        for option in HotkeyOption.allCases {
            hotkeyPopup.addItem(withTitle: option.menuTitle)
            hotkeyPopup.lastItem?.representedObject = option.rawValue
        }
        if let currentIndex = HotkeyOption.allCases.firstIndex(of: Config.currentHotkeyOption()) {
            hotkeyPopup.selectItem(at: currentIndex)
        }
        contentView.addSubview(hotkeyPopup)
        
        // Paste Language Selector
        let pasteLanguageLabel = NSTextField(labelWithString: "🌐 Paste Language")
        pasteLanguageLabel.font = NSFont.systemFont(ofSize: 12)
        pasteLanguageLabel.textColor = .secondaryLabelColor
        pasteLanguageLabel.alignment = .center
        pasteLanguageLabel.frame = NSRect(x: 20, y: 100, width: 540, height: 18)
        contentView.addSubview(pasteLanguageLabel)
        
        pasteLanguagePopup = NSPopUpButton(frame: NSRect(x: 190, y: 70, width: 200, height: 26), pullsDown: false)
        pasteLanguagePopup.autoenablesItems = false
        pasteLanguagePopup.addItem(withTitle: "🇮🇷 Persian")
        pasteLanguagePopup.lastItem?.representedObject = Config.PasteLanguage.persian.rawValue
        pasteLanguagePopup.addItem(withTitle: "🇬🇧 English")
        pasteLanguagePopup.lastItem?.representedObject = Config.PasteLanguage.english.rawValue
        
        let currentLanguage = Config.currentPasteLanguage()
        pasteLanguagePopup.selectItem(at: currentLanguage == .persian ? 0 : 1)
        contentView.addSubview(pasteLanguagePopup)
        
        // نمایش وضعیت فعلی
        if Config.hasAPIKey() {
            statusLabel.stringValue = "✅ API Key is configured"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "⚠️ No API Key configured"
            statusLabel.textColor = .systemOrange
        }
        
        // Buttons Container
        let buttonY: CGFloat = 20
        
        // Cancel Button
        cancelButton = NSButton(frame: NSRect(x: 360, y: buttonY, width: 100, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        contentView.addSubview(cancelButton)
        
        // Save Button
        saveButton = NSButton(frame: NSRect(x: 470, y: buttonY, width: 100, height: 32))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enter key
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        contentView.addSubview(saveButton)
        
        // Get API Key Link
        let linkButton = NSButton(frame: NSRect(x: 20, y: buttonY, width: 220, height: 32))
        linkButton.title = "Get API Key from Soniox"
        linkButton.bezelStyle = .rounded
        linkButton.target = self
        linkButton.action = #selector(openSonioxWebsite)
        contentView.addSubview(linkButton)
    }
    
    @objc private func saveClicked() {
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !apiKey.isEmpty else {
            statusLabel.stringValue = "❌ API Key cannot be empty"
            statusLabel.textColor = .systemRed
            return
        }
        
        // ذخیره در Keychain
        if Config.saveAPIKey(apiKey) {
            let selectedOption = currentHotkeySelection()
            let selectedLanguage = currentPasteLanguageSelection()
            
            Config.saveHotkeyOption(selectedOption)
            Config.savePasteLanguage(selectedLanguage)
            
            statusLabel.stringValue = "✅ Settings saved! Hotkey: \(selectedOption.displayName) | Paste: \(selectedLanguage.displayName)"
            statusLabel.textColor = .systemGreen
            
            onSave?(apiKey, selectedOption, selectedLanguage)
            
            // بستن پنجره بعد از 1 ثانیه
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.close()
            }
        } else {
            statusLabel.stringValue = "❌ Failed to save API Key"
            statusLabel.textColor = .systemRed
        }
    }
    
    private func currentHotkeySelection() -> HotkeyOption {
        if let rawValue = hotkeyPopup.selectedItem?.representedObject as? String,
           let option = HotkeyOption(rawValue: rawValue) {
            return option
        }
        return .microphoneKey
    }
    
    private func currentPasteLanguageSelection() -> Config.PasteLanguage {
        if let rawValue = pasteLanguagePopup.selectedItem?.representedObject as? String,
           let language = Config.PasteLanguage(rawValue: rawValue) {
            return language
        }
        return .persian
    }
    
    @objc private func cancelClicked() {
        close()
    }
    
    @objc private func openSonioxWebsite() {
        if let url = URL(string: "https://soniox.com") {
            NSWorkspace.shared.open(url)
        }
    }
}
