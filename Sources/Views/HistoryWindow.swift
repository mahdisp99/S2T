import Cocoa

// MARK: - History Window
class HistoryWindow: NSWindow, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var sessions: [DatabaseManager.RecordingSession] = []
    
    var onRefresh: (() -> Void)?
    
    init() {
        let rect = NSRect(x: 0, y: 0, width: 900, height: 500)
        
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "📚 Recording History"
        self.center()
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 700, height: 400)
        
        setupUI()
        loadSessions()
    }
    
    private func setupUI() {
        guard let contentView = self.contentView else { return }
        
        // Header
        let headerLabel = NSTextField(labelWithString: "📚 Recording History")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 20)
        headerLabel.frame = NSRect(x: 20, y: 450, width: 860, height: 30)
        headerLabel.alignment = .center
        contentView.addSubview(headerLabel)
        
        // Refresh Button
        let refreshButton = NSButton(frame: NSRect(x: 750, y: 450, width: 130, height: 32))
        refreshButton.title = "🔄 Refresh"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        contentView.addSubview(refreshButton)
        
        // Table View
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 20, width: 860, height: 420))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.autoresizingMask = [.width, .height]
        tableView.headerView = NSTableHeaderView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked)
        
        // Columns
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "📅 Date"
        dateColumn.width = 140
        tableView.addTableColumn(dateColumn)
        
        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "⏱️ Duration"
        durationColumn.width = 80
        tableView.addTableColumn(durationColumn)
        
        let wordsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("words"))
        wordsColumn.title = "📝 Words"
        wordsColumn.width = 70
        tableView.addTableColumn(wordsColumn)
        
        let languageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("language"))
        languageColumn.title = "🌐 Language"
        languageColumn.width = 90
        tableView.addTableColumn(languageColumn)
        
        let previewColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preview"))
        previewColumn.title = "💬 Preview (Persian)"
        previewColumn.width = 480
        tableView.addTableColumn(previewColumn)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Instructions
        let instructionsLabel = NSTextField(labelWithString: "💡 Double-click a row to view full text and copy")
        instructionsLabel.font = NSFont.systemFont(ofSize: 11)
        instructionsLabel.frame = NSRect(x: 20, y: 5, width: 500, height: 15)
        instructionsLabel.textColor = .secondaryLabelColor
        contentView.addSubview(instructionsLabel)
        
        // Delete button
        let deleteButton = NSButton(frame: NSRect(x: 750, y: 0, width: 130, height: 28))
        deleteButton.title = "🗑️ Delete Selected"
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteClicked)
        contentView.addSubview(deleteButton)
    }
    
    func loadSessions() {
        sessions = DatabaseManager.shared.getRecentSessions(limit: 100)
        tableView?.reloadData()
        print("📚 Loaded \(sessions.count) sessions")
    }
    
    // MARK: - TableView DataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return sessions.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let session = sessions[row]
        
        let cellView = NSTextField(labelWithString: "")
        cellView.isEditable = false
        cellView.isBordered = false
        cellView.backgroundColor = .clear
        cellView.font = NSFont.systemFont(ofSize: 12)
        
        guard let columnId = tableColumn?.identifier.rawValue else { return cellView }
        
        switch columnId {
        case "date":
            cellView.stringValue = formatDate(session.startedAt)
        case "duration":
            cellView.stringValue = formatDuration(session.duration)
        case "words":
            cellView.stringValue = "\(session.wordCount)"
        case "language":
            cellView.stringValue = session.languagePasted == "fa" ? "🇮🇷 Persian" : "🇬🇧 English"
        case "preview":
            let preview = session.persianText.prefix(80)
            cellView.stringValue = String(preview) + (session.persianText.count > 80 ? "..." : "")
        default:
            break
        }
        
        return cellView
    }
    
    // MARK: - Actions
    
    @objc private func rowDoubleClicked() {
        let row = tableView.selectedRow
        guard row >= 0 && row < sessions.count else { return }
        
        let session = sessions[row]
        showSessionDetail(session)
    }
    
    private func showSessionDetail(_ session: DatabaseManager.RecordingSession) {
        let alert = NSAlert()
        alert.messageText = "📄 Recording Session"
        
        let languageName = session.languagePasted == "fa" ? "Persian" : "English"
        let dateFormatted = formatDate(session.startedAt)
        let durationFormatted = formatDuration(session.duration)
        
        alert.informativeText = """
        📅 Date: \(dateFormatted)
        ⏱️ Duration: \(durationFormatted)
        📝 Words: \(session.wordCount)
        🔤 Sentences: \(session.sentenceCount)
        🌐 Pasted: \(languageName)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        🇮🇷 PERSIAN TEXT:
        \(session.persianText)
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        🇬🇧 ENGLISH TRANSLATION:
        \(session.englishText.isEmpty ? "(No translation)" : session.englishText)
        """
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "📋 Copy Persian")
        alert.addButton(withTitle: "📋 Copy English")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Copy Persian
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(session.persianText, forType: .string)
            print("📋 Persian text copied to clipboard")
        } else if response == .alertSecondButtonReturn {
            // Copy English
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(session.englishText, forType: .string)
            print("📋 English text copied to clipboard")
        }
    }
    
    @objc private func refreshClicked() {
        loadSessions()
        onRefresh?()
    }
    
    @objc private func deleteClicked() {
        let row = tableView.selectedRow
        guard row >= 0 && row < sessions.count else {
            let alert = NSAlert()
            alert.messageText = "No selection"
            alert.informativeText = "Please select a row to delete"
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let session = sessions[row]
        
        let alert = NSAlert()
        alert.messageText = "Delete Recording?"
        alert.informativeText = "Are you sure you want to delete this recording session?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            DatabaseManager.shared.deleteSession(id: session.id)
            loadSessions()
            onRefresh?()
            print("🗑️ Session deleted")
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
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
}

