import Cocoa
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var darkModeManager = DarkModeManager()
    private var animationManager = OverlayAnimationManager()
    private var hotKeyRef: EventHotKeyRef?
    private var isToggling = false  // Debounce flag to prevent rapid toggles
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the app from the dock
        NSApp.setActivationPolicy(.accessory)
        
        // Request automation permissions upfront
        requestAutomationPermissions()
        
        // Create the status bar item
        createStatusBarItem()
        
        // Register global keyboard shortcut
        setupGlobalKeyboardShortcut()
        
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
        NSAppleScript(source: testScript)?.executeAndReturnError(&error)
        if let error = error {
            print("Automation permission request failed: \(error)")
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
        // Check which mouse button was pressed
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right-click: show context menu
            showContextMenu()
        } else {
            // Left-click: toggle dark mode
            performDarkModeToggle()
        }
    }
    
    private func performDarkModeToggle() {
        // Debounce: prevent rapid toggles while animation is in progress
        guard !isToggling else { return }
        isToggling = true

        let switchingToDarkMode = !darkModeManager.isDarkModeEnabled()

        // Start the animation immediately, toggle dark mode when black is reached, then fade out
        animationManager.showTransitionAnimation(isDarkMode: switchingToDarkMode, onBlackReached: { [weak self] in
            // Screen is now fully black - toggle dark mode
            self?.darkModeManager.toggleDarkMode()
        }) { [weak self] in
            // Animation and fade completed - update icon and reset debounce
            self?.updateStatusBarIcon()
            self?.isToggling = false
        }
    }
    
    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Add animation type submenu
        let animationItem = NSMenuItem(title: "Animation Style", action: nil, keyEquivalent: "")
        let animationSubmenu = NSMenu()
        
        for animationType in AnimationType.allCases {
            let menuItem = NSMenuItem(
                title: animationType.displayName,
                action: #selector(changeAnimationType(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = animationType
            
            // Check current selection
            if AnimationPreferences.shared.animationType == animationType {
                menuItem.state = .on
            }
            
            animationSubmenu.addItem(menuItem)
        }
        
        animationItem.submenu = animationSubmenu
        menu.addItem(animationItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add the quit item
        let quitItem = NSMenuItem(title: "Quit NiteLite", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Use the status item's menu property for proper rendering
        statusItem?.menu = menu
        
        // Trigger the menu to appear
        button.performClick(nil)
        
        // Clear the menu after use to restore click behavior
        DispatchQueue.main.async {
            self.statusItem?.menu = nil
        }
    }
    
    @objc private func changeAnimationType(_ sender: NSMenuItem) {
        guard let animationType = sender.representedObject as? AnimationType else { return }
        AnimationPreferences.shared.animationType = animationType
    }
    
    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
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
    
    private func setupGlobalKeyboardShortcut() {
        let hotKeyID = EventHotKeyID(signature: 1, id: 1)
        let keyCode = UInt32(kVK_ANSI_D)
        let modifiers = UInt32(cmdKey + shiftKey)
        
        var eventHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &eventHotKey)
        
        if status == noErr {
            self.hotKeyRef = eventHotKey
        } else {
            print("Failed to register global keyboard shortcut (status \(status))")
        }
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            appDelegate.handleHotKeyPressed()
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
    
    private func handleHotKeyPressed() {
        // Toggle directly — statusBarButtonClicked() inspects NSApp.currentEvent,
        // which isn't a mouse event when the hotkey fires.
        performDarkModeToggle()
    }
    
    deinit {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        DistributedNotificationCenter.default.removeObserver(self)
    }
}
