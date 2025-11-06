# 🎤 Speech to Text - macOS

Real-time speech-to-text application for macOS using Swift and Soniox API

---

## ✨ Features

- 🎙️ **Real-time transcription** with Soniox API
- 🌍 **Real-time Translation**: Persian → English (simultaneous)
- 🖥️ **Dual Mode**: Dock icon + Menu Bar
- 📊 **Dashboard Window** with statistics & history access
- ⌨️ **Global Hotkeys** – Multiple options (Mic Key, Option+Shift+Space, etc.)
- ✨ **Auto-Paste**: Text automatically inserted (Persian or English)
- 🪟 **Floating Window** shows both languages + live waveform
- 📚 **History Window**: Browse all recordings, copy text, delete sessions
- 💾 **SQLite Database**: Session-based storage with detailed statistics
- ⚙️ **Simple Settings** for API Key & language selection
- 🔐 **Local Storage** for API Key (no security popups)
- 🚀 **Native Swift** - fast and lightweight

---

## 🚀 Installation

### Requirements
- macOS 12.0+
- Xcode Command Line Tools
- Soniox API Key ([get one here](https://soniox.com))

### Installation Steps

#### 1️⃣ Build
```bash
./build.sh
```

#### 2️⃣ Install to Applications
```bash
sudo cp -R SpeechToTextApp.app /Applications/
```

#### 3️⃣ Run
```bash
open /Applications/SpeechToTextApp.app
```

---

## ⚙️ API Key Setup

### First Time:
1. Open the app
2. Settings window appears
3. Enter your API Key
4. Click Save

### Change API Key:
- From Menu Bar: `⚙️ Settings` (Cmd+,)
- Or from Dashboard: Click `Settings` button

### Hotkey Settings:
- وارد Settings (همان پنجرهٔ API Key) شو
- از لیست کشویی یکی از گزینه‌های آماده را انتخاب کن:
  - Mic Key (F5) – اگر «Use F1, F2… as standard function keys» را فعال کنی بدون Fn هم کار می‌کند
  - Option+Shift+Space
  - Cmd+Option+R
  - Cmd+Shift+R
  - Ctrl+Option+Space
  - Control twice (مدل Dictation قدیمی macOS)
- بعد از Save شورتکات جدید فوراً فعال می‌شود

---

## 📖 Usage

### Quick Start
1. Open the app → Dashboard appears
2. Enter API Key (if first time)
3. Click `🎤 Start Recording` یا یکی از شورتکات‌هایی که در Settings انتخاب شده (مثلاً Mic Key، Option+Shift+Space، Cmd+Option+R)
4. Speak naturally → Text appears in floating window
5. در حین ضبط می‌توانی روی دکمهٔ کوچک میکروفون (گوشهٔ بالا-راست پنجرهٔ شناور) کلیک کنی تا ضبط را متوقف/ادامه دهی؛ نوار موجي باریک زیر متن وضعیت صدا را زنده نشان می‌دهد
6. Text is automatically pasted! ✨

### Dashboard
- **Status**: Ready / Recording
- **API Key Status**: Configured / Not configured
- **Start/Stop Button**: Large button for recording control
- **Statistics**: Today's and all-time recording stats
- **Settings**: API Key & language management
- **History**: View all past recordings
- **Hotkey Info**: Reminder of shortcut

**Open Dashboard:**
- Click on **Dock icon**
- Menu Bar: `📊 Dashboard` (Cmd+D)

### History Window
- **View all recordings**: Browse all past sessions
- **Table view**: Date, duration, word count, language, preview
- **Double-click**: View full text (Persian + English)
- **Copy text**: Copy Persian or English to clipboard
- **Delete**: Remove unwanted sessions
- **Refresh**: Update statistics

**Open History:**
- From Dashboard: Click `📚 View History` button
- Keyboard: Cmd+H (from Dashboard)

### Translation & Language Selection
The app simultaneously transcribes Persian speech and translates it to English.

**Choose paste language:**
1. Open Settings (Cmd+,)
2. Select "Paste Language": Persian or English
3. Click Save
4. When recording, the selected language will be auto-pasted

### Keyboard Shortcuts
| Shortcut | Action |
|---------|--------|
| **Mic Key (F5)** | Start/Stop recording (default – بدون Fn وقتی «Use F1… as standard keys» فعال باشد) |
| **Option+Shift+Space** | Start/Stop (گزینهٔ سبک و آشنا) |
| **Cmd+Option+R** | Start/Stop (ترکیب رایج برای ضبط) |
| **Cmd+Shift+R** | Start/Stop (جایگزین دوم برای ضبط) |
| **Ctrl+Option+Space** | Start/Stop (بدون کلید Command) |
| **Control twice** | Start/Stop (دو بار Control پشت هم ≤ 0.5 ثانیه) |
| **Cmd+D** | Open Dashboard |
| **Cmd+H** | Open History (from Dashboard) |
| **Cmd+,** | Open Settings |
| **Cmd+Q** | Quit |
| **Enter** | Start/Stop (when Dashboard active) |

### Menu Bar
- Look for `🎤STT` icon in Menu Bar (top-right)
- Click for quick menu:
  - Start/Stop recording
  - Dashboard
  - Settings
  - Quit

---

## 🔐 Permissions

For full functionality, the app needs these permissions:

### 1️⃣ Microphone (Required)
- For audio recording
- Automatically requested on first run

### 2️⃣ Accessibility (For Auto-Paste)
**Without this:** Text is copied but not auto-pasted

**Setup:**
1. `System Settings` → `Privacy & Security` → `Accessibility`
2. Find: `Speech to Text`
3. If not listed: Click `+` and add the app
4. Enable the checkbox ✅
5. Quit the app (Cmd+Q) and reopen

**⚠️ Important Note After Each Build:**
- Every time you run `./build.sh`, a new binary is created
- macOS sees the new binary as a different app
- You must **re-grant** Accessibility permission:
  1. System Settings → Privacy & Security → Accessibility
  2. **Remove** old "Speech to Text" entry (click -)
  3. Click **+** and add the new version
  4. Enable the checkbox ✅

---

## 🎨 Changing App Icon

### Current Icon
The app includes an icon: `icon_1024x1024.png`

### To Change Icon
1. Create new PNG file (1024×1024)
2. Replace `icon_1024x1024.png`
3. Run:
```bash
./create_new_icon.sh
./build.sh
```

---

## 📁 Project Structure

```
Speech-to-Text/
├── Sources/                  # Swift source code (Modular)
│   ├── App/
│   │   ├── AppDelegate.swift        # Main app logic & coordination
│   │   └── main.swift               # Entry point
│   ├── Models/
│   │   ├── Config.swift             # Configuration (API Key, Settings)
│   │   └── HotkeyOption.swift       # Hotkey options
│   ├── Views/
│   │   ├── DashboardWindow.swift    # Main control window + statistics
│   │   ├── FloatingWindow.swift     # Real-time text display (dual language)
│   │   ├── HistoryWindow.swift      # Recording history browser
│   │   ├── SettingsWindow.swift     # Settings management
│   │   └── WaveformView.swift       # Live audio waveform visualization
│   └── Services/
│       ├── AudioRecorder.swift      # Audio capture & processing
│       ├── WebSocketManager.swift   # Soniox API communication + translation
│       ├── PasteManager.swift       # Auto-paste functionality
│       ├── KeychainManager.swift    # Local storage
│       ├── HotkeyManager.swift      # Global hotkey (Carbon API)
│       └── DatabaseManager.swift    # SQLite database management
├── Info.plist                # App configuration
├── build.sh                  # Build script
├── run.sh                    # Run script
├── icon_1024x1024.png        # Source icon (1024×1024 PNG)
├── AppIcon.icns              # macOS icon file
├── create_new_icon.sh        # Generate new icon
├── .gitignore                # Git ignore rules
└── README.md                 # This file
```

---

## 🛠 Development

### Build
```bash
./build.sh
```

### Run from Terminal
```bash
./run.sh
```

Or:
```bash
./SpeechToTextApp
```

### Run from Applications
```bash
open /Applications/SpeechToTextApp.app
```

---

## 🔧 Troubleshooting

### Hotkey not working
- در Settings بررسی کنید که کدام شورتکات فعال است
- اگر Mic Key (F5) را انتخاب کرده‌اید:
  - System Settings → Keyboard → Keyboard Shortcuts → Dictation → Shortcut را روی «Off» یا «Control Key twice» بگذارید تا macOS پاپ‌آپ دیکتیشن نشان ندهد
  - (اختیاری) اگر F5 را مثل کلیدهای استاندارد می‌خواهی، گزینهٔ «Use F1, F2… as standard function keys» را فعال کن؛ برنامه حتی بدون این گزینه هم Mic Key را می‌شناسد
- اگر Control twice را انتخاب کرده‌ای، در همان بخش Dictation شورتکات را روی حالت دیگری بگذار یا کلاً Off کن تا میانبر ما با دیکتیشن سیستم تداخل نداشته باشد
- اگر Cmd+Option+R یا Cmd+Shift+R را انتخاب کرده‌ای و برنامه‌ی دیگری همان شورتکات را مصرف می‌کند، ابتدا آن برنامه/سیستم (مثلاً Safari یا Xcode) را ببند یا شورتکاتش را تغییر بده و دوباره تست کن
- هنوز مشکل دارید؟ Option+Shift+Space را انتخاب کنید و تست بگیرید
- در نهایت، برنامه را کاملاً Quit کرده و دوباره باز کنید (در صورت لزوم ریستارت Mac)

### Auto-Paste not working
- Requires **Accessibility permission**
- See "Permissions" section above
- **Remember:** After each rebuild, re-grant permission

### Menu Bar icon not showing
- Menu Bar might be crowded
- Use configured **Hotkey** instead (Mic Key by default)
- Or use **Dock icon** to open the app

### API Key error
- Go to Settings (Cmd+,)
- Re-enter API Key
- Click Save

---

## 🎯 Sharing with Others

### Preparing for Distribution

#### Method 1: .app File (Simplest)
```bash
# 1. Build
./build.sh

# 2. Compress
zip -r SpeechToTextApp.zip SpeechToTextApp.app

# 3. Send SpeechToTextApp.zip
```

**Installation Guide for Recipient:**
1. Extract the zip file
2. Move `SpeechToTextApp.app` to `/Applications`
3. Double-click the app
4. Enter their own Soniox API Key
5. Grant Accessibility permission (for Auto-Paste)

#### Method 2: Full Project (For Developers)
```bash
# Compress entire folder
zip -r SpeechToText-Project.zip "Speech-to-Text"
```

**Installation Guide:**
1. Extract the zip file
2. `cd Speech-to-Text`
3. `./build.sh`
4. `./run.sh` or install to `/Applications`

---

## 📝 Technical Notes

- **Language:** Swift 5
- **Architecture:** Modular (MVC-inspired)
- **Frameworks:** 
  - `Cocoa` (UI)
  - `AVFoundation` (Audio)
  - `Foundation` (Core + UserDefaults)
  - `SQLite3` (Database)
  - `Carbon` (Hotkeys)
- **Audio:** 48kHz input → 16kHz PCM for Soniox
- **WebSocket:** Real-time streaming + translation
- **Storage:** 
  - UserDefaults with Base64 obfuscation (API Key)
  - SQLite database (Recording sessions + statistics)
- **Database Location:** `~/Library/Application Support/SpeechToText/transcriptions.db`
- **UI Mode:** Dual (Dock + Menu Bar)
- **Files:** 14 Swift files (~2000 lines total)

### Database Schema

**recording_sessions** (Main table)
- Stores complete recording sessions
- One row per recording session
- Includes full Persian text, English translation, statistics

**transcription_chunks** (Debugging table)
- Stores individual sentences/chunks
- Linked to sessions via session_id
- Tracks chunk order, finality, translation status

---

## 📄 License

Free to use and modify.
