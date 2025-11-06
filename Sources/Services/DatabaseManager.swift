import Foundation
import SQLite3

// MARK: - Database Manager (Session-based)
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        // Create Application Support directory
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDirectory = appSupportURL.appendingPathComponent("SpeechToText", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            print("📁 Created app directory: \(appDirectory.path)")
        }
        
        // Database path
        dbPath = appDirectory.appendingPathComponent("transcriptions.db").path
        print("💾 Database path: \(dbPath)")
        
        // Open/create database
        openDatabase()
        createTables()
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Error opening database")
        } else {
            print("✅ Database opened successfully")
        }
    }
    
    private func createTables() {
        // Drop old table if exists (clean start)
        executeSQL("DROP TABLE IF EXISTS transcriptions;")
        
        // Main table: Recording Sessions
        let createSessionsTable = """
        CREATE TABLE IF NOT EXISTS recording_sessions (
            id TEXT PRIMARY KEY,
            full_persian_text TEXT NOT NULL,
            full_english_text TEXT,
            language_pasted TEXT NOT NULL,
            started_at DATETIME NOT NULL,
            ended_at DATETIME NOT NULL,
            duration_seconds REAL NOT NULL,
            word_count_persian INTEGER,
            word_count_english INTEGER,
            character_count_persian INTEGER,
            character_count_english INTEGER,
            sentence_count INTEGER,
            hotkey_used TEXT
        );
        """
        
        // Secondary table: Transcription Chunks (for future debugging/analysis)
        let createChunksTable = """
        CREATE TABLE IF NOT EXISTS transcription_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            chunk_text TEXT NOT NULL,
            chunk_order INTEGER NOT NULL,
            is_final BOOLEAN NOT NULL,
            translation_status TEXT NOT NULL,
            received_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (session_id) REFERENCES recording_sessions(id)
        );
        """
        
        let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON recording_sessions(started_at);
        CREATE INDEX IF NOT EXISTS idx_chunks_session_id ON transcription_chunks(session_id);
        """
        
        executeSQL(createSessionsTable)
        executeSQL(createChunksTable)
        executeSQL(createIndexes)
        print("✅ Tables created: recording_sessions + transcription_chunks (ready for future use)")
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                // Success
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ SQL Error: \(errorMessage)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Insert Session
    func saveRecordingSession(
        sessionId: String,
        fullPersianText: String,
        fullEnglishText: String,
        languagePasted: String,
        startedAt: Date,
        endedAt: Date,
        hotkeyUsed: String?
    ) {
        let insertSQL = """
        INSERT INTO recording_sessions 
        (id, full_persian_text, full_english_text, language_pasted, 
         started_at, ended_at, duration_seconds,
         word_count_persian, word_count_english, 
         character_count_persian, character_count_english, 
         sentence_count, hotkey_used)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            let duration = endedAt.timeIntervalSince(startedAt)
            let persianWordCount = countWords(in: fullPersianText)
            let englishWordCount = countWords(in: fullEnglishText)
            let persianCharCount = fullPersianText.count
            let englishCharCount = fullEnglishText.count
            let sentenceCount = countSentences(in: fullPersianText)
            
            sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (fullPersianText as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (fullEnglishText as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (languagePasted as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 5, (formatDate(startedAt) as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 6, (formatDate(endedAt) as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 7, duration)
            sqlite3_bind_int(statement, 8, Int32(persianWordCount))
            sqlite3_bind_int(statement, 9, Int32(englishWordCount))
            sqlite3_bind_int(statement, 10, Int32(persianCharCount))
            sqlite3_bind_int(statement, 11, Int32(englishCharCount))
            sqlite3_bind_int(statement, 12, Int32(sentenceCount))
            
            if let hotkey = hotkeyUsed {
                sqlite3_bind_text(statement, 13, (hotkey as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 13)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("💾 Session saved: \(sessionId) (\(sentenceCount) sentences, \(persianWordCount + englishWordCount) words)")
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ Error saving session: \(errorMessage)")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Insert Chunk (for future debugging/analysis)
    func saveTranscriptionChunk(
        sessionId: String,
        chunkText: String,
        chunkOrder: Int,
        isFinal: Bool,
        translationStatus: String
    ) {
        let insertSQL = """
        INSERT INTO transcription_chunks 
        (session_id, chunk_text, chunk_order, is_final, translation_status)
        VALUES (?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (chunkText as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 3, Int32(chunkOrder))
            sqlite3_bind_int(statement, 4, isFinal ? 1 : 0)
            sqlite3_bind_text(statement, 5, (translationStatus as NSString).utf8String, -1, nil)
            
            sqlite3_step(statement)
        }
        
        sqlite3_finalize(statement)
    }
    
    // MARK: - Statistics
    
    func getTodayStats() -> (count: Int, words: Int, duration: Double) {
        let sql = """
        SELECT 
            COUNT(*) as count,
            SUM(word_count_persian + word_count_english) as total_words,
            SUM(duration_seconds) as total_duration
        FROM recording_sessions
        WHERE DATE(started_at) = DATE('now', 'localtime');
        """
        
        var statement: OpaquePointer?
        var count = 0
        var words = 0
        var duration = 0.0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
                words = Int(sqlite3_column_int(statement, 1))
                duration = sqlite3_column_double(statement, 2)
            }
        }
        
        sqlite3_finalize(statement)
        return (count, words, duration)
    }
    
    func getAllTimeStats() -> (count: Int, words: Int, duration: Double) {
        let sql = """
        SELECT 
            COUNT(*) as count,
            SUM(word_count_persian + word_count_english) as total_words,
            SUM(duration_seconds) as total_duration
        FROM recording_sessions;
        """
        
        var statement: OpaquePointer?
        var count = 0
        var words = 0
        var duration = 0.0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
                words = Int(sqlite3_column_int(statement, 1))
                duration = sqlite3_column_double(statement, 2)
            }
        }
        
        sqlite3_finalize(statement)
        return (count, words, duration)
    }
    
    func getLanguageBreakdown() -> (persian: Int, english: Int) {
        let sql = """
        SELECT 
            SUM(CASE WHEN language_pasted = 'fa' THEN 1 ELSE 0 END) as persian_count,
            SUM(CASE WHEN language_pasted = 'en' THEN 1 ELSE 0 END) as english_count
        FROM recording_sessions;
        """
        
        var statement: OpaquePointer?
        var persianCount = 0
        var englishCount = 0
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                persianCount = Int(sqlite3_column_int(statement, 0))
                englishCount = Int(sqlite3_column_int(statement, 1))
            }
        }
        
        sqlite3_finalize(statement)
        return (persianCount, englishCount)
    }
    
    // MARK: - Fetch Sessions (for History View)
    
    struct RecordingSession {
        let id: String
        let persianText: String
        let englishText: String
        let languagePasted: String
        let startedAt: String
        let endedAt: String
        let duration: Double
        let wordCount: Int
        let sentenceCount: Int
    }
    
    func getRecentSessions(limit: Int = 20) -> [RecordingSession] {
        let sql = """
        SELECT id, full_persian_text, full_english_text, language_pasted,
               started_at, ended_at, duration_seconds,
               word_count_persian + word_count_english as total_words,
               sentence_count
        FROM recording_sessions
        ORDER BY started_at DESC
        LIMIT ?;
        """
        
        var statement: OpaquePointer?
        var results: [RecordingSession] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let persian = String(cString: sqlite3_column_text(statement, 1))
                let english = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : ""
                let language = String(cString: sqlite3_column_text(statement, 3))
                let startedAt = String(cString: sqlite3_column_text(statement, 4))
                let endedAt = String(cString: sqlite3_column_text(statement, 5))
                let duration = sqlite3_column_double(statement, 6)
                let wordCount = Int(sqlite3_column_int(statement, 7))
                let sentenceCount = Int(sqlite3_column_int(statement, 8))
                
                let session = RecordingSession(
                    id: id,
                    persianText: persian,
                    englishText: english,
                    languagePasted: language,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    duration: duration,
                    wordCount: wordCount,
                    sentenceCount: sentenceCount
                )
                results.append(session)
            }
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func deleteSession(id: String) {
        let deleteSQL = "DELETE FROM recording_sessions WHERE id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_DONE {
                print("🗑️ Session deleted: \(id)")
            }
        }
        sqlite3_finalize(statement)
        
        // Also delete related chunks
        let deleteChunksSQL = "DELETE FROM transcription_chunks WHERE session_id = ?;"
        if sqlite3_prepare_v2(db, deleteChunksSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Helpers
    
    private func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    private func countSentences(in text: String) -> Int {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?؟"))
        return sentences.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
}
