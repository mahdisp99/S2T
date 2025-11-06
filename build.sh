#!/bin/bash

echo "🔨 Building Speech to Text App..."
echo ""

# پاک کردن bundle قبلی
rm -rf SpeechToTextApp.app

# ساخت App Bundle structure
mkdir -p SpeechToTextApp.app/Contents/MacOS

# کامپایل Swift app با همه فایل‌های جدید (+ SQLite)
echo "📦 Compiling source files..."
swiftc -framework Cocoa -framework AVFoundation -framework Foundation -framework Carbon \
    -lsqlite3 \
    -o SpeechToTextApp.app/Contents/MacOS/SpeechToTextApp \
    Sources/Models/HotkeyOption.swift \
    Sources/Models/Config.swift \
    Sources/Views/FloatingWindow.swift \
    Sources/Views/DashboardWindow.swift \
    Sources/Views/SettingsWindow.swift \
    Sources/Views/HistoryWindow.swift \
    Sources/Views/WaveformView.swift \
    Sources/Services/AudioRecorder.swift \
    Sources/Services/WebSocketManager.swift \
    Sources/Services/PasteManager.swift \
    Sources/Services/KeychainManager.swift \
    Sources/Services/HotkeyManager.swift \
    Sources/Services/DatabaseManager.swift \
    Sources/App/AppDelegate.swift \
    Sources/App/main.swift

if [ $? -eq 0 ]; then
    # کپی Info.plist
    cp Info.plist SpeechToTextApp.app/Contents/
    
    # کپی آیکون (اگه وجود داره)
    if [ -f AppIcon.icns ]; then
        mkdir -p SpeechToTextApp.app/Contents/Resources
        cp AppIcon.icns SpeechToTextApp.app/Contents/Resources/
    fi
    
    # ساخت symlink برای اجرای راحت‌تر
    ln -sf SpeechToTextApp.app/Contents/MacOS/SpeechToTextApp SpeechToTextApp
    
    echo ""
    echo "✅ Build موفقیت‌آمیز بود!"
    echo "✅ App Bundle: SpeechToTextApp.app"
    echo "📁 Architecture: Modular (10 files, Dual-mode UI)"
    echo ""
    echo "🚀 برای اجرا:"
    echo "  ./SpeechToTextApp"
    echo "  یا: open SpeechToTextApp.app"
    echo ""
else
    echo ""
    echo "❌ Build ناموفق بود!"
    exit 1
fi
