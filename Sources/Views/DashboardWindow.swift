import Cocoa

// MARK: - Dashboard Window
class DashboardWindow: NSWindow {
    private var statusLabel: NSTextField!
    private var recordButton: NSButton!
    private var settingsButton: NSButton!
    private var hotkeyLabel: NSTextField!
    private var apiKeyStatusLabel: NSTextField!
    
    // Statistics labels
    private var todayStatsLabel: NSTextField!
    private var allTimeStatsLabel: NSTextField!
    private var languageBreakdownLabel: NSTextField!
    
    var onRecordToggle: (() -> Void)?
    var onSettingsClick: (() -> Void)?
    var onHistoryClick: (() -> Void)?
    var onQuit: (() -> Void)?
    
    init() {
        let rect = NSRect(x: 0, y: 0, width: 450, height: 550)  // Taller for stats
        
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Speech to Text"
        self.center()
        self.isReleasedWhenClosed = false
        
        setupUI()
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Header - App Title
        let headerLabel = NSTextField(labelWithString: "🎤 Speech to Text")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 24)
        headerLabel.frame = NSRect(x: 20, y: 480, width: 410, height: 40)
        headerLabel.alignment = .center
        contentView.addSubview(headerLabel)
        
        // API Key Status
        apiKeyStatusLabel = NSTextField(labelWithString: "")
        apiKeyStatusLabel.font = NSFont.systemFont(ofSize: 12)
        apiKeyStatusLabel.frame = NSRect(x: 20, y: 450, width: 410, height: 20)
        apiKeyStatusLabel.alignment = .center
        contentView.addSubview(apiKeyStatusLabel)
        
        // Status Label
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = NSFont.systemFont(ofSize: 18)
        statusLabel.frame = NSRect(x: 20, y: 400, width: 410, height: 30)
        statusLabel.alignment = .center
        statusLabel.textColor = .systemGreen
        contentView.addSubview(statusLabel)
        
        // Record Button (Large)
        recordButton = NSButton(frame: NSRect(x: 150, y: 320, width: 150, height: 60))
        recordButton.title = "🎤 Start Recording"
        recordButton.bezelStyle = .rounded
        recordButton.font = NSFont.boldSystemFont(ofSize: 16)
        recordButton.target = self
        recordButton.action = #selector(recordButtonClicked)
        recordButton.keyEquivalent = "\r" // Enter key
        contentView.addSubview(recordButton)
        
        // Hotkey Info
        hotkeyLabel = NSTextField(labelWithString: "⌨️ Hotkey: \(Config.hotkeyDisplayName)")
        hotkeyLabel.font = NSFont.systemFont(ofSize: 11)
        hotkeyLabel.frame = NSRect(x: 20, y: 290, width: 410, height: 20)
        hotkeyLabel.alignment = .center
        hotkeyLabel.textColor = .secondaryLabelColor
        contentView.addSubview(hotkeyLabel)
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // STATISTICS SECTION
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        // Statistics Header
        let statsHeader = NSTextField(labelWithString: "📊 Statistics")
        statsHeader.font = NSFont.boldSystemFont(ofSize: 16)
        statsHeader.frame = NSRect(x: 20, y: 250, width: 410, height: 25)
        statsHeader.alignment = .center
        contentView.addSubview(statsHeader)
        
        // Separator line
        let separator1 = NSBox(frame: NSRect(x: 30, y: 245, width: 390, height: 1))
        separator1.boxType = .separator
        contentView.addSubview(separator1)
        
        // Today's Stats (multi-line)
        todayStatsLabel = NSTextField(labelWithString: "📅 Today: Loading...")
        todayStatsLabel.font = NSFont.systemFont(ofSize: 13)
        todayStatsLabel.frame = NSRect(x: 30, y: 190, width: 390, height: 50)
        todayStatsLabel.alignment = .left
        todayStatsLabel.maximumNumberOfLines = 3
        todayStatsLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(todayStatsLabel)
        
        // All-Time Stats (multi-line)
        allTimeStatsLabel = NSTextField(labelWithString: "🌍 All Time: Loading...")
        allTimeStatsLabel.font = NSFont.systemFont(ofSize: 13)
        allTimeStatsLabel.frame = NSRect(x: 30, y: 140, width: 390, height: 50)
        allTimeStatsLabel.alignment = .left
        allTimeStatsLabel.maximumNumberOfLines = 3
        allTimeStatsLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(allTimeStatsLabel)
        
        // Language Breakdown
        languageBreakdownLabel = NSTextField(labelWithString: "🌐 Language: Loading...")
        languageBreakdownLabel.font = NSFont.systemFont(ofSize: 13)
        languageBreakdownLabel.frame = NSRect(x: 30, y: 105, width: 390, height: 30)
        languageBreakdownLabel.alignment = .left
        languageBreakdownLabel.maximumNumberOfLines = 2
        languageBreakdownLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(languageBreakdownLabel)
        
        // Separator line 2
        let separator2 = NSBox(frame: NSRect(x: 30, y: 95, width: 390, height: 1))
        separator2.boxType = .separator
        contentView.addSubview(separator2)
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // BUTTONS
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        // History Button
        let historyButton = NSButton(frame: NSRect(x: 50, y: 50, width: 160, height: 32))
        historyButton.title = "📚 View History"
        historyButton.bezelStyle = .rounded
        historyButton.target = self
        historyButton.action = #selector(historyButtonClicked)
        historyButton.keyEquivalent = "h"
        contentView.addSubview(historyButton)
        
        // Settings Button
        settingsButton = NSButton(frame: NSRect(x: 240, y: 50, width: 160, height: 32))
        settingsButton.title = "⚙️ Settings"
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(settingsButtonClicked)
        settingsButton.keyEquivalent = ","
        contentView.addSubview(settingsButton)
        
        // Quit Button
        let quitButton = NSButton(frame: NSRect(x: 175, y: 15, width: 100, height: 28))
        quitButton.title = "Quit"
        quitButton.bezelStyle = .rounded
        quitButton.target = self
        quitButton.action = #selector(quitButtonClicked)
        quitButton.keyEquivalent = "q"
        contentView.addSubview(quitButton)
        
        // بعد از ساخت همه UI elements، وضعیت API Key رو آپدیت کن
        updateAPIKeyStatus()
        
        // Load initial statistics
        refreshStats()
    }
    
    // MARK: - Public Methods
    func updateStatus(isRecording: Bool) {
        if isRecording {
            statusLabel.stringValue = "🔴 Recording..."
            statusLabel.textColor = .systemRed
            recordButton.title = "⏹ Stop Recording"
        } else {
            statusLabel.stringValue = "✅ Ready"
            statusLabel.textColor = .systemGreen
            recordButton.title = "🎤 Start Recording"
        }
    }
    
    func updateAPIKeyStatus() {
        if Config.hasAPIKey() {
            apiKeyStatusLabel.stringValue = "✅ API Key configured"
            apiKeyStatusLabel.textColor = .systemGreen
            recordButton.isEnabled = true
        } else {
            apiKeyStatusLabel.stringValue = "⚠️ API Key not configured - click Settings"
            apiKeyStatusLabel.textColor = .systemOrange
            recordButton.isEnabled = false
        }
    }
    
    func updateHotkey(option: HotkeyOption) {
        hotkeyLabel.stringValue = "⌨️ Hotkey: \(option.displayName)"
    }
    
    func refreshStats() {
        // Get statistics from database
        let todayStats = DatabaseManager.shared.getTodayStats()
        let allTimeStats = DatabaseManager.shared.getAllTimeStats()
        let languageBreakdown = DatabaseManager.shared.getLanguageBreakdown()
        
        // Format duration
        let todayDuration = formatDuration(todayStats.duration)
        let allTimeDuration = formatDuration(allTimeStats.duration)
        
        // Update Today's Stats
        todayStatsLabel.stringValue = """
        📅 Today:
        • \(todayStats.count) recordings
        • \(todayStats.words) words transcribed
        • \(todayDuration) recording time
        """
        
        // Update All-Time Stats
        allTimeStatsLabel.stringValue = """
        🌍 All Time:
        • \(allTimeStats.count) recordings
        • \(allTimeStats.words) words transcribed
        • \(allTimeDuration) total time
        """
        
        // Update Language Breakdown
        let total = languageBreakdown.persian + languageBreakdown.english
        if total > 0 {
            let persianPercent = Int((Double(languageBreakdown.persian) / Double(total)) * 100)
            let englishPercent = 100 - persianPercent
            languageBreakdownLabel.stringValue = """
            🌐 Paste Language:
            🇮🇷 Persian: \(languageBreakdown.persian) (\(persianPercent)%)  •  🇬🇧 English: \(languageBreakdown.english) (\(englishPercent)%)
            """
        } else {
            languageBreakdownLabel.stringValue = "🌐 Paste Language: No data yet"
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    // MARK: - Actions
    @objc private func recordButtonClicked() {
        onRecordToggle?()
    }
    
    @objc private func settingsButtonClicked() {
        onSettingsClick?()
    }
    
    @objc private func historyButtonClicked() {
        onHistoryClick?()
    }
    
    @objc private func quitButtonClicked() {
        onQuit?()
    }
}
