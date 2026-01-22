import Foundation
import Cocoa

class DarkModeManager {

    // Cached compiled AppleScripts to avoid recompilation on each toggle
    private lazy var darkModeOnScript: NSAppleScript? = {
        let source = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to true
            end tell
        end tell
        """
        return NSAppleScript(source: source)
    }()

    private lazy var darkModeOffScript: NSAppleScript? = {
        let source = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to false
            end tell
        end tell
        """
        return NSAppleScript(source: source)
    }()

    /// Check if Dark Mode is currently enabled
    func isDarkModeEnabled() -> Bool {
        // Check the effective appearance
        if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
            return appearance == .darkAqua
        }
        
        // Fallback to UserDefaults check
        let appearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return appearance == "Dark"
    }
    
    /// Toggle the system Dark Mode setting
    func toggleDarkMode() {
        let currentMode = isDarkModeEnabled()
        let newMode = currentMode ? "Light" : "Dark"
        
        print("Attempting to switch from \(currentMode ? "Dark" : "Light") to \(newMode) mode")
        
        // Try methods in order of reliability
        if toggleUsingAppleScript(!currentMode) {
            print("Successfully switched using AppleScript")
            return
        }
        
        if toggleUsingOsascript(!currentMode) {
            print("Successfully switched using osascript")
            return
        }
        
        if toggleUsingShellCommand(!currentMode) {
            print("Successfully switched using shell command")
            return
        }
        
        print("All toggle methods failed")
    }
    
    /// Method 1: Use shell command to modify UserDefaults directly
    private func toggleUsingShellCommand(_ toDarkMode: Bool) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"

        if toDarkMode {
            task.arguments = ["write", "-g", "AppleInterfaceStyle", "Dark"]
        } else {
            task.arguments = ["delete", "-g", "AppleInterfaceStyle"]
        }

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                print("Shell command failed with status: \(task.terminationStatus)")
                return false
            }

            // Notify the system of the change
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                deliverImmediately: true
            )

            // No blocking verification - animation system handles polling
            return true
        } catch {
            print("Shell command error: \(error)")
            return false
        }
    }
    
    /// Method 2: Use cached AppleScript for fast execution
    private func toggleUsingAppleScript(_ toDarkMode: Bool) -> Bool {
        // Use pre-compiled cached script for faster execution
        guard let script = toDarkMode ? darkModeOnScript : darkModeOffScript else {
            print("Failed to get cached AppleScript")
            return false
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error = error {
            print("AppleScript error: \(error)")
            if let errorMessage = error["NSAppleScriptErrorMessage"] as? String {
                print("Error description: \(errorMessage)")
            }
            return false
        }

        print("AppleScript executed successfully: \(result)")
        return true
    }
    
    /// Method 3: Use osascript command line tool
    private func toggleUsingOsascript(_ toDarkMode: Bool) -> Bool {
        let script = "tell app \"System Events\" to tell appearance preferences to set dark mode to \(toDarkMode)"

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                print("Osascript failed with status: \(task.terminationStatus)")
                return false
            }

            // No blocking verification - animation system handles polling
            return true
        } catch {
            print("Osascript error: \(error)")
            return false
        }
    }
}
