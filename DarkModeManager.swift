import Foundation
import Cocoa

class DarkModeManager {
    
    /// Check if Dark Mode is currently enabled
    func isDarkModeEnabled() -> Bool {
        let appearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return appearance == "Dark"
    }
    
    /// Toggle the system Dark Mode setting
    func toggleDarkMode() {
        let currentMode = isDarkModeEnabled()
        let newMode = currentMode ? "Light" : "Dark"
        
        // Use AppleScript to toggle the system appearance
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(!currentMode)
            end tell
        end tell
        """
        
        executeAppleScript(script)
    }
    
    /// Execute an AppleScript
    private func executeAppleScript(_ script: String) {
        var error: NSDictionary?
        
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
}
