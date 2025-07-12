import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var darkModeManager = DarkModeManager()
    private var animationManager = OverlayAnimationManager()
    
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
        
        // Determine what mode we're switching TO
        let switchingToDarkMode = !wasInDarkMode
        
        // Start the animation immediately, then toggle dark mode when animation completes
        animationManager.showTransitionAnimation(isDarkMode: switchingToDarkMode) { [weak self] in
            // Animation completed - now toggle dark mode and update icon
            self?.performDarkModeToggle(wasInDarkMode: wasInDarkMode)
            self?.updateStatusBarIcon()
        }
    }
    
    private func performDarkModeToggle(wasInDarkMode: Bool) {
        // Toggle dark mode
        darkModeManager.toggleDarkMode()
        
        // Verify the change after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let isNowInDarkMode = self.darkModeManager.isDarkModeEnabled()
            print("Mode after toggle: \(isNowInDarkMode ? "Dark" : "Light")")
            
            if wasInDarkMode != isNowInDarkMode {
                print("Toggle successful!")
            } else {
                print("Toggle may have failed - no change detected")
            }
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
