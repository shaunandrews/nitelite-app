import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var darkModeManager = DarkModeManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the dock
        NSApp.setActivationPolicy(.accessory)
        
        // Request automation permissions upfront
        requestAutomationPermissions()
        
        // Create the status bar item
        createStatusBarItem()
        
        // Update the icon based on current dark mode state
        updateStatusBarIcon()
        
        // Listen for appearance changes
        setupAppearanceObserver()
    }
    
    private func requestAutomationPermissions() {
        // Try to run a simple AppleScript to trigger the permission dialog
        let testScript = """
        tell application "System Events"
            return name
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: testScript) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Permission request failed: \(error)")
            } else {
                print("Automation permissions granted or already available")
            }
        }
    }
    
    private func createStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let statusButton = statusItem?.button else { return }
        
        // Set the target and action for the button
        statusButton.target = self
        statusButton.action = #selector(statusBarButtonClicked)
        
        // Make the button look clickable
        statusButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    @objc private func statusBarButtonClicked() {
        print("Status bar button clicked")
        
        // Get current state before toggle
        let wasInDarkMode = darkModeManager.isDarkModeEnabled()
        print("Current mode: \(wasInDarkMode ? "Dark" : "Light")")
        
        // Toggle dark mode
        darkModeManager.toggleDarkMode()
        
        // Update the icon after a delay to allow the system to change
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let isNowInDarkMode = self.darkModeManager.isDarkModeEnabled()
            print("Mode after toggle: \(isNowInDarkMode ? "Dark" : "Light")")
            
            if wasInDarkMode != isNowInDarkMode {
                print("Toggle successful!")
            } else {
                print("Toggle may have failed - no change detected")
            }
            
            self.updateStatusBarIcon()
        }
    }
    
    private func updateStatusBarIcon() {
        guard let statusButton = statusItem?.button else { return }
        
        let isDarkMode = darkModeManager.isDarkModeEnabled()
        
        // Use SF Symbols for the icons
        let iconName = isDarkMode ? "moon.fill" : "sun.max.fill"
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        
        // Configure the image
        image?.isTemplate = true
        statusButton.image = image
        
        // Set tooltip
        statusButton.toolTip = isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode"
        
        print("Updated icon for \(isDarkMode ? "Dark" : "Light") mode")
    }
    
    private func setupAppearanceObserver() {
        // Listen for system appearance changes
        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Update icon when system appearance changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.updateStatusBarIcon()
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
}
