# AppDelegate - Menubar & Lifecycle Management

## Overview

`AppDelegate.swift` is the central coordinator for NiteLite, managing the menubar interface, user interactions, keyboard shortcuts, and orchestrating the dark mode toggle with animations.

## Class Properties

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?          // Menubar status item
    private var darkModeManager = DarkModeManager() // Toggle logic
    private var animationManager = OverlayAnimationManager() // Animation coordinator
    private var hotKeyRef: EventHotKeyRef?         // Global shortcut reference
    private var isToggling = false                 // Debounce flag
}
```

## Initialization Flow

### applicationDidFinishLaunching

```
┌─────────────────────────────────────────┐
│ 1. Hide from dock                       │
│    NSApp.setActivationPolicy(.accessory)│
├─────────────────────────────────────────┤
│ 2. Request automation permissions       │
│    (test AppleScript execution)         │
├─────────────────────────────────────────┤
│ 3. Create status bar item               │
│    (menubar icon)                       │
├─────────────────────────────────────────┤
│ 4. Register global keyboard shortcut    │
│    (⌘⇧D using Carbon API)              │
├─────────────────────────────────────────┤
│ 5. Update icon for current mode         │
│    (sun.max.fill or moon.fill)          │
├─────────────────────────────────────────┤
│ 6. Setup appearance change observer     │
│    (DistributedNotificationCenter)      │
└─────────────────────────────────────────┘
```

## Status Bar Management

### createStatusBarItem()

Creates the menubar icon with these properties:
- **Length**: `NSStatusItem.squareLength` (standard icon width)
- **Target/Action**: Self, `statusBarButtonClicked`
- **Mouse Events**: Responds to both left and right mouse up

### updateStatusBarIcon()

Updates the icon based on current dark mode state:
- **Dark Mode**: `moon.fill` SF Symbol
- **Light Mode**: `sun.max.fill` SF Symbol
- **Image Mode**: `isTemplate = true` for automatic tinting

## Click Handling

### Left Click - Toggle Dark Mode

```swift
private func performDarkModeToggle() {
    // Debounce: prevent rapid toggles while animation is in progress
    guard !isToggling else { return }
    isToggling = true

    // Capture current state
    let wasInDarkMode = darkModeManager.isDarkModeEnabled()
    let switchingToDarkMode = !wasInDarkMode

    // Start animation with callbacks
    animationManager.showTransitionAnimation(
        isDarkMode: switchingToDarkMode,
        onBlackReached: { /* toggle happens here */ },
        completion: {
            self.updateStatusBarIcon()
            self.isToggling = false  // Reset debounce flag
        }
    )
}
```

**Debouncing**: The `isToggling` flag prevents rapid double-clicks from stacking multiple animations. The flag is set at the start and cleared when the animation completes.

**Critical Timing**:
- Animation starts immediately on click
- Dark mode toggle fires at `onBlackReached` (when screen is fully black)
- Icon updates on `completion` (after animation reveals new mode)

### Right Click - Context Menu

Shows menu with:
1. **Animation Style** submenu (Iris / Wipe options)
2. **Quit NiteLite** option

Menu handling uses a temporary assignment pattern:
```swift
statusItem?.menu = menu        // Assign menu
button.performClick(nil)       // Trigger display
statusItem?.menu = nil         // Clear for normal clicks
```

## Global Keyboard Shortcut

### Setup (Carbon API)

```swift
// Register ⌘⇧D
let hotKeyID = EventHotKeyID(signature: 1, id: 1)
let keyCode = UInt32(kVK_ANSI_D)
let modifiers = UInt32(cmdKey + shiftKey)
RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &eventHotKey)
```

### Event Handler

Uses an event handler installed via `InstallEventHandler`:
```swift
InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
    let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
    appDelegate.handleHotKeyPressed()
    return noErr
}, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), nil)
```

The handler simply calls `statusBarButtonClicked()` as if the user clicked the menubar icon.

## Appearance Change Observer

Listens for external dark mode changes (System Preferences, other apps):

```swift
DistributedNotificationCenter.default.addObserver(
    forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
    object: nil,
    queue: .main
) { [weak self] _ in
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self?.updateStatusBarIcon()
    }
}
```

**Note**: The 0.1 second delay exists because the notification fires slightly before the actual appearance change takes effect.

## Cleanup

```swift
deinit {
    if let hotKeyRef = hotKeyRef {
        UnregisterEventHotKey(hotKeyRef)  // Unregister shortcut
    }
    DistributedNotificationCenter.default.removeObserver(self)
}
```

