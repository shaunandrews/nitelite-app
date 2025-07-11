import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var darkModeManager = DarkModeManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the dock
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status bar item
        createStatusBarItem()
        
        // Update the icon based on current dark mode state
        updateStatusBarIcon()
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
        // Toggle dark mode
        darkModeManager.toggleDarkMode()
        
        // Update the icon to reflect the new state
        updateStatusBarIcon()
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
    }
}
