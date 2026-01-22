# DarkModeManager - System Toggle Logic

## Overview

`DarkModeManager.swift` handles the actual system dark mode toggle, implementing a three-tier fallback strategy to ensure reliable switching across different macOS configurations and permission states.

## State Detection

### isDarkModeEnabled()

Two-method detection with fallback:

```swift
func isDarkModeEnabled() -> Bool {
    // Primary: Check effective appearance
    if let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
        return appearance == .darkAqua
    }

    // Fallback: UserDefaults check
    let appearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
    return appearance == "Dark"
}
```

**Note**: The primary method uses `NSApp.effectiveAppearance` which reflects the actual rendered appearance. The fallback reads `AppleInterfaceStyle` from global UserDefaults.

## Cached AppleScripts

For performance, AppleScripts are pre-compiled once and cached as lazy properties:

```swift
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
    // Similar for false
}()
```

This avoids script recompilation on each toggle.

## Toggle Strategy

### Three-Tier Fallback

```
┌─────────────────────────────────────┐
│ Method 1: AppleScript (NSAppleScript)│
│ ✓ Most reliable                      │
│ ✓ Uses proper macOS APIs             │
│ ✓ Pre-compiled for speed             │
│ ✗ Requires automation permission     │
└────────────────┬────────────────────┘
                 │ fails?
                 ▼
┌─────────────────────────────────────┐
│ Method 2: osascript (shell command) │
│ ✓ Bypasses some permission issues    │
│ ✗ Shell overhead                     │
│ ✗ Still needs System Events access   │
└────────────────┬────────────────────┘
                 │ fails?
                 ▼
┌─────────────────────────────────────┐
│ Method 3: UserDefaults (defaults)   │
│ ✓ No permissions required            │
│ ✗ May not update all apps            │
│ ✗ Requires notification broadcast    │
└─────────────────────────────────────┘
```

### Method 1: Cached AppleScript (Primary)

```swift
private func toggleUsingAppleScript(_ toDarkMode: Bool) -> Bool {
    guard let script = toDarkMode ? darkModeOnScript : darkModeOffScript else {
        return false
    }

    var error: NSDictionary?
    script.executeAndReturnError(&error)

    if let error = error {
        print("AppleScript error: \(error)")
        return false
    }
    return true
}
```

Uses pre-compiled cached script for fast execution. No blocking verification - the animation system handles appearance change detection.

### Method 2: osascript Command Line

```swift
private func toggleUsingOsascript(_ toDarkMode: Bool) -> Bool {
    let script = "tell app \"System Events\" to tell appearance preferences to set dark mode to \(toDarkMode)"

    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]

    try task.run()
    task.waitUntilExit()

    return task.terminationStatus == 0
}
```

### Method 3: Direct UserDefaults

```swift
private func toggleUsingShellCommand(_ toDarkMode: Bool) -> Bool {
    let task = Process()
    task.launchPath = "/usr/bin/defaults"

    if toDarkMode {
        task.arguments = ["write", "-g", "AppleInterfaceStyle", "Dark"]
    } else {
        task.arguments = ["delete", "-g", "AppleInterfaceStyle"]
    }

    try task.run()
    task.waitUntilExit()

    // Broadcast notification manually
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("AppleInterfaceThemeChangedNotification"),
        object: nil,
        deliverImmediately: true
    )

    return true
}
```

## Design Notes

### Non-Blocking Execution

Toggle methods return immediately after executing the system command. Verification that the appearance actually changed is delegated to the animation system's `waitForDarkModeChange()` polling, which runs asynchronously without blocking the main thread.

### Fail-Fast Fallback

Methods cascade quickly without artificial delays. If AppleScript fails (e.g., permissions not granted), it immediately tries osascript, then shell defaults.
