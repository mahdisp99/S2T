import Cocoa
import Carbon.HIToolbox

// MARK: - Paste Manager
class PasteManager {
    static func pasteText(_ text: String) {
        print("📋 Pasting text (\(text.count) chars)...")
        
        // کپی به clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("   ✅ Copied to clipboard")
        
        // استراتژی: CGEvent اول، AppleScript fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // چک کردن Accessibility permission
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
            let hasAccess = AXIsProcessTrustedWithOptions(options)
            
            if hasAccess {
                // روش 1: CGEvent (قابل اطمینان‌تر با Accessibility)
                print("   ✅ Has Accessibility - using CGEvent...")
                self.pasteWithCGEvent()
            } else {
                // روش 2: AppleScript (برای زمانی که Accessibility نیست)
                print("   ⚠️  No Accessibility - using AppleScript...")
                self.pasteWithAppleScript()
            }
        }
    }
    
    private static func pasteWithCGEvent() {
        let cmdKey = CGEventFlags.maskCommand
        
        if let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        ) {
            keyDownEvent.flags = cmdKey
            keyDownEvent.post(tap: .cghidEventTap)
            
            if let keyUpEvent = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            ) {
                keyUpEvent.flags = cmdKey
                keyUpEvent.post(tap: .cghidEventTap)
                
                print("   ✅ CGEvent Cmd+V posted!")
            }
        } else {
            print("   ❌ Failed to create CGEvent")
        }
    }
    
    private static func pasteWithAppleScript() {
        let script = """
        tell application "System Events"
            delay 0.05
            keystroke "v" using command down
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("   ❌ AppleScript error: \(error["NSAppleScriptErrorMessage"] ?? "unknown")")
            } else {
                print("   ✅ Pasted with AppleScript!")
            }
        } else {
            print("   ❌ Failed to create AppleScript")
        }
    }
}

