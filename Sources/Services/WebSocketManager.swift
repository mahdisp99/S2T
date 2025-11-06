import Foundation

// MARK: - WebSocket Manager
class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    var onTextReceived: ((String, Bool) -> Void)?
    var onTranslationReceived: ((String, Bool) -> Void)?
    
    private var audioBytesSent: Int = 0
    private var lastLogTime: Date = Date()
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket DID OPEN!")
        if let proto = `protocol` {
            print("   Protocol: \(proto)")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("⚠️  WebSocket DID CLOSE")
        print("   Close code: \(closeCode.rawValue)")
        if let reason = reason, let reasonString = String(data: reason, encoding: .utf8) {
            print("   Reason: \(reasonString)")
        }
    }
    
    // MARK: - Public Methods
    func connect() {
        print("🔌 Connecting to Soniox...")
        print("   URL: \(Config.sonioxURL)")
        print("   API Key: \(String(Config.sonioxAPIKey.prefix(10)))...")
        
        guard let url = URL(string: Config.sonioxURL) else {
            print("⚠️  خطا: URL نامعتبر!")
            return
        }
        
        // ساخت URLRequest با WebSocket protocol
        var request = URLRequest(url: url)
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 300
        
        session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session?.webSocketTask(with: request)
        
        print("🔌 WebSocket task created, calling resume()...")
        webSocketTask?.resume()
        
        // ارسال پیکربندی با Translation
        let sonioxConfig: [String: Any] = [
            "api_key": Config.sonioxAPIKey,
            "model": "stt-rt-preview",
            "audio_format": "pcm_s16le",
            "sample_rate": Int(Config.sampleRate),
            "num_channels": 1,
            "enable_endpoint_detection": true,
            "enable_streaming": true,
            "translation": [
                "type": "one_way",
                "target_language": "en"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: sonioxConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Sending config: \(jsonString)")
            sendMessage(jsonString)
        } else {
            print("⚠️  خطا: نتونستم config رو JSON کنم!")
        }
        
        // شروع دریافت پیام‌ها
        receiveMessage()
        
        print("✅ WebSocket connected!")
    }
    
    func sendAudioData(_ data: Data) {
        audioBytesSent += data.count
        
        // لاگ هر 5 ثانیه (کمتر spam!)
        let now = Date()
        if now.timeIntervalSince(lastLogTime) > 5.0 {
            print("📤 Audio: \(audioBytesSent / 1024) KB sent")
            lastLogTime = now
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error, let self = self {
                // فقط اولین error رو چاپ کن
                if self.audioBytesSent < 10000 {
                    print("⚠️  خطا در ارسال audio: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func disconnect() {
        // ارسال empty data برای پایان
        webSocketTask?.send(.data(Data())) { _ in }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        print("🔌 قطع اتصال از Soniox")
    }
    
    // MARK: - Private Methods
    private func sendMessage(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("⚠️  خطا در ارسال پیام: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleTextMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // ادامه دریافت
                self.receiveMessage()
                
            case .failure(let error):
                // فقط اگه واقعاً مشکل جدی باشه
                if (error as NSError).code != 57 {  // 57 = Socket not connected (normal at disconnect)
                    print("⚠️  خطا در WebSocket: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let jsonData = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let tokens = json["tokens"] as? [[String: Any]] else {
            return
        }
        
        // فقط اگه token داشت
        guard !tokens.isEmpty else { return }
        
        var finalText = ""
        var nonFinalText = ""
        var finalTranslation = ""
        var nonFinalTranslation = ""
        
        for token in tokens {
            guard let isFinal = token["is_final"] as? Bool,
                  let tokenText = token["text"] as? String else { continue }
            
            // چک کردن translation_status
            let translationStatus = token["translation_status"] as? String ?? "original"
            
            if translationStatus == "translation" {
                // این یک token ترجمه شده است
                if isFinal {
                    finalTranslation += tokenText
                } else {
                    nonFinalTranslation += tokenText
                }
            } else {
                // این متن اصلی (فارسی) است
                if isFinal {
                    finalText += tokenText
                } else {
                    nonFinalText += tokenText
                }
            }
        }
        
        // ارسال متن اصلی (فارسی)
        if !finalText.isEmpty {
            print("✅ FINAL (Persian): \(finalText)")
            DispatchQueue.main.async {
                self.onTextReceived?(finalText, true)
            }
        } else if !nonFinalText.isEmpty {
            if nonFinalText.count % 10 < 3 {
                print("💬 (Persian) \(nonFinalText.prefix(60))...")
            }
            DispatchQueue.main.async {
                self.onTextReceived?(nonFinalText, false)
            }
        }
        
        // ارسال ترجمه (انگلیسی)
        if !finalTranslation.isEmpty {
            print("✅ FINAL (English): \(finalTranslation)")
            DispatchQueue.main.async {
                self.onTranslationReceived?(finalTranslation, true)
            }
        } else if !nonFinalTranslation.isEmpty {
            if nonFinalTranslation.count % 10 < 3 {
                print("🌐 (English) \(nonFinalTranslation.prefix(60))...")
            }
            DispatchQueue.main.async {
                self.onTranslationReceived?(nonFinalTranslation, false)
            }
        }
    }
}

