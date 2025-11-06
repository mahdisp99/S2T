import Cocoa
import AVFoundation
import ApplicationServices

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dashboardWindow: DashboardWindow?
    private var floatingWindow: FloatingWindow?
    private var settingsWindow: SettingsWindow?
    private var historyWindow: HistoryWindow?
    private var audioRecorder: AudioRecorder?
    private var webSocketManager: WebSocketManager?
    private let hotkeyManager = HotkeyManager()
    
    private var isRecording = false
    private var recordMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    
    private var didSetupHotkey = false
    
    // Session-based recording
    private var currentSessionId: String?
    private var recordingStartTime: Date?
    private var accumulatedPersianText: String = ""
    private var accumulatedEnglishText: String = ""
    private var lastFinalPersianText: String = ""
    private var lastFinalEnglishText: String = ""
    private var chunkCounter: Int = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎤 Speech to Text started")
        
        // ✅ تنظیم برنامه به عنوان Regular app (Dock + Menu Bar)
        NSApplication.shared.setActivationPolicy(.regular)
        
        // 🔐 درخواست همه دسترسی‌ها از اول
        requestAllPermissions()
        
        // ساخت Menu Bar item
        setupMenuBar()
        
        // ساخت Dashboard Window
        setupDashboardWindow()
        
        // ساخت Settings Window
        settingsWindow = SettingsWindow()
        settingsWindow?.onSave = { [weak self] _, _, _ in
            self?.initializeApp()
            self?.dashboardWindow?.updateAPIKeyStatus()
        }
        
        // بررسی API Key
        if !Config.hasAPIKey() {
            print("⚠️  No API Key found - opening Settings")
            showSettings()
        } else {
            initializeApp()
        }
        
        // نمایش Dashboard Window
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func initializeApp() {
        guard Config.hasAPIKey() else {
            print("❌ Cannot initialize without API Key")
            return
        }
        
        print("✅ API Key configured")
        
        // ساخت Floating Window
        if floatingWindow == nil {
            floatingWindow = FloatingWindow()
            floatingWindow?.onMicToggle = { [weak self] in
                self?.toggleRecording()
            }
        }
        
        // راه‌اندازی Audio Recorder
        if audioRecorder == nil {
            audioRecorder = AudioRecorder()
        }
        
        // راه‌اندازی WebSocket
        if webSocketManager == nil {
            webSocketManager = WebSocketManager()
            webSocketManager?.onTextReceived = { [weak self] text, isFinal in
                self?.handleTextReceived(text, isFinal: isFinal)
            }
            webSocketManager?.onTranslationReceived = { [weak self] text, isFinal in
                self?.handleTranslationReceived(text, isFinal: isFinal)
            }
        }
        
        // راه‌اندازی Global Hotkey
        if !didSetupHotkey {
            setupGlobalHotkey()
        } else {
            refreshHotkeyRegistration()
        }
        
        // درخواست دسترسی میکروفون
        requestMicrophoneAccess()
        
        print("✅ Ready! Hotkey: \(Config.hotkeyDisplayName)")
        
        // نمایش Alert راهنما (فقط اولین بار)
        if !UserDefaults.standard.bool(forKey: "HasSeenWelcome") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showStartupAlert()
                UserDefaults.standard.set(true, forKey: "HasSeenWelcome")
            }
        }
    }
    
    // MARK: - Setup Methods
    private func setupDashboardWindow() {
        dashboardWindow = DashboardWindow()
        
        dashboardWindow?.onRecordToggle = { [weak self] in
            self?.toggleRecording()
        }
        
        dashboardWindow?.onSettingsClick = { [weak self] in
            self?.showSettings()
        }
        
        dashboardWindow?.onHistoryClick = { [weak self] in
            self?.showHistory()
        }
        
        dashboardWindow?.onQuit = { [weak self] in
            self?.quit()
        }
    }
    
    private func showHistory() {
        if historyWindow == nil {
            historyWindow = HistoryWindow()
            historyWindow?.onRefresh = { [weak self] in
                self?.dashboardWindow?.refreshStats()
            }
        }
        historyWindow?.loadSessions()
        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func showStartupAlert() {
        let alert = NSAlert()
        let hotkeyDescription = Config.hotkeyDisplayName
        alert.messageText = "✅ Welcome!"
        alert.informativeText = """
        🎤 Speech to Text is ready!
        
        📊 Dashboard Window:
        • From Dock: Click the icon
        • From Menu Bar: Cmd+D
        
        ⌨️ Recording Hotkey:
        • \(hotkeyDescription)
        
        🔍 Menu Bar:
        • "🎤STT" icon in top-right corner
        • Quick access to Start/Stop
        
        🎯 Click the Dock Icon to get started!
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Let's Go!")
        alert.runModal()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else {
            print("❌ Menu Bar button failed!")
            return
        }
        
        button.title = "🎤STT"
        button.toolTip = "Speech to Text (\(Config.hotkeyDisplayName))"
        
        let menu = NSMenu()
        
        recordMenuItem = NSMenuItem(
            title: "🎤 Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        recordMenuItem?.target = self
        menu.addItem(recordMenuItem!)
        
        statusMenuItem = NSMenuItem(title: "Status: Ready", action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
        // Dashboard Menu Item
        let dashboardMenuItem = NSMenuItem(title: "📊 Dashboard", action: #selector(showDashboard), keyEquivalent: "d")
        dashboardMenuItem.target = self
        menu.addItem(dashboardMenuItem)
        
        // Settings Menu Item
        let settingsMenuItem = NSMenuItem(title: "⚙️ Settings", action: #selector(showSettings), keyEquivalent: ",")
        settingsMenuItem.target = self
        menu.addItem(settingsMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        statusItem?.menu = menu
        statusItem?.isVisible = true
        
        print("✅ Menu Bar: '🎤STT' created")
    }
    
    @objc private func showDashboard() {
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showSettings() {
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func refreshHotkeyRegistration() {
        let option = Config.currentHotkeyOption()
        print("⌨️  Applying hotkey:", option.displayName)
        
        hotkeyManager.register(option: option) { [weak self] in
            self?.toggleRecording()
        }
        
        dashboardWindow?.updateHotkey(option: option)
        statusItem?.button?.toolTip = "Speech to Text (\(option.displayName))"
    }
    
    private func setupGlobalHotkey() {
        refreshHotkeyRegistration()
        didSetupHotkey = true
        
        let hasShownAlert = UserDefaults.standard.bool(forKey: "HasShownAccessibilityAlert")
        if !hasShownAlert && !checkAccessibilityPermission() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.requestAccessibilityPermissionWithPrompt()
            }
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    private func requestAllPermissions() {
        print("🔐 Requesting permissions...")
        
        // 1. Microphone (for audio recording)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("   ✅ Microphone: Granted")
                } else {
                    print("   ❌ Microphone: Denied")
                }
            }
        }
        
        // 2. Accessibility (for auto-paste with CGEvent)
        let hasAccessibility = checkAccessibilityPermission()
        if !hasAccessibility {
            // Show alert only once
            if !UserDefaults.standard.bool(forKey: "HasShownAccessibilityAlert") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.requestAccessibilityPermissionWithPrompt()
                }
            } else {
                print("   ⚠️  Accessibility: Not granted (Alert already shown)")
            }
        } else {
            print("   ✅ Accessibility: Granted")
        }
    }
    
    private func requestAccessibilityPermissionWithPrompt() {
        // Save that alert was shown
        UserDefaults.standard.set(true, forKey: "HasShownAccessibilityAlert")
        
        let alert = NSAlert()
        let hotkeyDescription = Config.hotkeyDisplayName
        alert.messageText = "🔐 Accessibility Permission Needed"
        alert.informativeText = """
        For Auto-Paste (automatic text insertion), the app needs Accessibility permission.
        
        ⚙️ Steps:
        1. Click "Open System Settings"
        2. Go to Privacy & Security → Accessibility
        3. Find "Speech to Text"
        4. If not there: Click + and add the app
        5. Enable the checkbox ✅
        6. QUIT the app (Cmd+Q)
        7. Reopen the app
        
        💡 Without this permission:
        • Hotkey (\(hotkeyDescription)) works ✅
        • Text gets copied ✅
        • But Auto-Paste doesn't work ❌
        
        📝 After enabling, you must Quit and reopen the app once.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // باز کردن System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Recording Actions
    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // Start new session
        currentSessionId = UUID().uuidString
        recordingStartTime = Date()
        accumulatedPersianText = ""
        accumulatedEnglishText = ""
        lastFinalPersianText = ""
        lastFinalEnglishText = ""
        chunkCounter = 0
        
        print("🎬 New session started: \(currentSessionId ?? "unknown")")
        
        // تغییر UI - Menu Bar
        statusItem?.button?.title = "🔴REC"
        recordMenuItem?.title = "⏹️ Stop Recording"
        statusMenuItem?.title = "Status: Recording..."
        
        // تغییر UI - Dashboard
        dashboardWindow?.updateStatus(isRecording: true)
        floatingWindow?.updateRecordingState(isRecording: true)
        
        print("🔴 Recording...")
        
        floatingWindow?.orderFront(nil)
        webSocketManager?.connect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.audioRecorder?.startRecording(
                onAudioData: { [weak self] audioData in
                    self?.webSocketManager?.sendAudioData(audioData)
                },
                onLevelUpdate: { [weak self] level in
                    self?.floatingWindow?.updateLevel(level)
                }
            )
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        // تغییر UI - Menu Bar
        statusItem?.button?.title = "🎤STT"
        recordMenuItem?.title = "🎤 Start Recording"
        statusMenuItem?.title = "Status: Ready"
        
        // تغییر UI - Dashboard
        dashboardWindow?.updateStatus(isRecording: false)
        floatingWindow?.updateRecordingState(isRecording: false)
        
        print("⏸️ Stopped")
        
        // Save complete session to database
        saveCurrentSession()
        
        floatingWindow?.orderOut(nil)
        audioRecorder?.stopRecording()
        webSocketManager?.disconnect()
    }
    
    private func saveCurrentSession() {
        guard let sessionId = currentSessionId,
              let startTime = recordingStartTime,
              !accumulatedPersianText.isEmpty else {
            print("⚠️ No session data to save")
            return
        }
        
        let endTime = Date()
        let languagePasted = Config.currentPasteLanguage().rawValue
        
        // Save to database
        DatabaseManager.shared.saveRecordingSession(
            sessionId: sessionId,
            fullPersianText: accumulatedPersianText,
            fullEnglishText: accumulatedEnglishText,
            languagePasted: languagePasted,
            startedAt: startTime,
            endedAt: endTime,
            hotkeyUsed: Config.hotkeyDisplayName
        )
        
        // Update dashboard
        dashboardWindow?.refreshStats()
        
        // Reset session
        currentSessionId = nil
        accumulatedPersianText = ""
        accumulatedEnglishText = ""
        
        print("✅ Session saved successfully")
    }
    
    private func handleTextReceived(_ text: String, isFinal: Bool) {
        let cleanText = text.replacingOccurrences(of: "<end>", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return }
        
        // Accumulate Persian text for session
        if isFinal {
            accumulatedPersianText += (accumulatedPersianText.isEmpty ? "" : " ") + cleanText
            lastFinalPersianText = cleanText
            print("✅ Persian (final): \(cleanText)")
            print("📝 Accumulated: \(accumulatedPersianText.count) chars")
            
            // Save chunk to database
            saveChunk(text: cleanText, isFinal: true, translationStatus: "original")
        } else {
            // Save non-final chunks too (for debugging)
            saveChunk(text: cleanText, isFinal: false, translationStatus: "original")
        }
        
        // نمایش در Floating Window
        floatingWindow?.updateText(cleanText, isFinal: isFinal)
        
        // Paste: فقط اگه Persian انتخاب شده
        if isFinal && Config.currentPasteLanguage() == .persian {
            print("📋 Pasting Persian immediately...")
            pasteText(lastFinalPersianText)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.floatingWindow?.clearText()
            }
        }
    }
    
    private func handleTranslationReceived(_ text: String, isFinal: Bool) {
        let cleanText = text.replacingOccurrences(of: "<end>", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return }
        
        // Accumulate English text for session
        if isFinal {
            accumulatedEnglishText += (accumulatedEnglishText.isEmpty ? "" : " ") + cleanText
            lastFinalEnglishText = cleanText
            print("✅ English (final): \(cleanText)")
            print("🌐 Accumulated: \(accumulatedEnglishText.count) chars")
            
            // Save chunk to database
            saveChunk(text: cleanText, isFinal: true, translationStatus: "translation")
            
            // Paste: اگه English انتخاب شده، الان paste کن
            if Config.currentPasteLanguage() == .english {
                print("📋 Pasting English translation...")
                pasteText(lastFinalEnglishText)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.floatingWindow?.clearText()
                }
            }
        } else {
            // Save non-final chunks too (for debugging)
            saveChunk(text: cleanText, isFinal: false, translationStatus: "translation")
        }
        
        // نمایش در Floating Window
        floatingWindow?.updateTranslation(cleanText, isFinal: isFinal)
    }
    
    private func pasteText(_ text: String) {
        guard !text.isEmpty else { return }
        PasteManager.pasteText(text + " ")
    }
    
    private func saveChunk(text: String, isFinal: Bool, translationStatus: String) {
        guard let sessionId = currentSessionId else { return }
        
        chunkCounter += 1
        
        DatabaseManager.shared.saveTranscriptionChunk(
            sessionId: sessionId,
            chunkText: text,
            chunkOrder: chunkCounter,
            isFinal: isFinal,
            translationStatus: translationStatus
        )
        
        if isFinal {
            print("💾 Chunk #\(chunkCounter) saved: \(translationStatus) (\(text.count) chars)")
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Dock Icon Click Handler
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // وقتی روی Dock icon کلیک میشه، Dashboard رو نشون بده
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    // MARK: - Window Delegate
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // وقتی Dashboard بسته میشه، برنامه terminate نشه (فقط پنهان بشه)
        return false
    }
}
