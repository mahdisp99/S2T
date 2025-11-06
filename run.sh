#!/bin/bash

echo "🚀 Speech to Text - Swift Edition"
echo ""

# خواندن API Key از .env (اختیاری)
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "✅ API Key loaded from .env"
else
    echo "ℹ️  No .env file (will use Keychain or Settings)"
fi

echo ""
echo "🔨 Building..."
./build.sh

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "🎤 Starting App..."
echo ""
echo "=================================================="
echo "  📊 Dashboard opens automatically!"
echo "  🖱️  Click Dock icon to bring back Dashboard"
echo "  🔍 Menu Bar: '🎤STT' (top-right)"
echo "  ⌨️  Hotkey: Mic Key (F5) - configurable (Option+Shift+Space, Cmd+Option+R, Cmd+Shift+R, Ctrl+Option+Space, Control twice)"
echo "  ⚙️  Settings: Cmd+,"
echo "=================================================="
echo ""

# اجرا
./SpeechToTextApp
