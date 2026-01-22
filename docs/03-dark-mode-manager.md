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

## Toggle Strategy

### Three-Tier Fallback

```
┌─────────────────────────────────────┐
│ Method 1: AppleScript (NSAppleScript)│
│ ✓ Most reliable                      │
│ ✓ Uses proper macOS APIs             │
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

### Method 1: AppleScript via NSAppleScript

```swift
private func toggleUsingAppleScript(_ toDarkMode: Bool) -> Bool {
    let script = """
    tell application "System Events"
        tell appearance preferences
            set dark mode to \(toDarkMode)
        end tell
    end tell
    """

    let success = executeAppleScript(script)
    if success {
        usleep(300000) // 0.3 second verification delay
        let actuallyChanged = isDarkModeEnabled() == toDarkMode
        if !actuallyChanged {
            return false
        }
    }
    return success
}
```

**Timing**: 300ms (`usleep(300000)`) verification delay after execution.

### Method 2: osascript Command Line

```swift
private func toggleUsingOsascript(_ toDarkMode: Bool) -> Bool {
    let script = "tell app \"System Events\" to tell appearance preferences to set dark mode to \(toDarkMode)"

    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]

    try task.run()
    task.waitUntilExit()

    // 300ms verification delay
    usleep(300000)
    return isDarkModeEnabled() == toDarkMode
}
```

**Timing**: 300ms (`usleep(300000)`) verification delay after execution.

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

    // 500ms verification delay
    usleep(500000)
    return isDarkModeEnabled() == toDarkMode
}
```

**Timing**: 500ms (`usleep(500000)`) verification delay after execution.

## Verification Polling

Each toggle method includes verification:

```swift
usleep(N) // Wait for system to respond
let actuallyChanged = isDarkModeEnabled() == toDarkMode
if !actuallyChanged {
    print("Method executed but change not detected")
    return false
}
```

This is **synchronous blocking** - the thread sleeps during verification.

## Critical Timing Analysis

### Current Delays

| Method | Verification Delay | Notes |
|--------|-------------------|-------|
| AppleScript | 300ms | `usleep(300000)` |
| osascript | 300ms | `usleep(300000)` |
| Shell defaults | 500ms | `usleep(500000)` |

### Problem Areas

1. **Synchronous Blocking**: All methods use `usleep()` which blocks the main thread during verification
2. **Sequential Fallback**: If method 1 fails, delays compound (could be 300ms + 300ms + 500ms = 1.1s worst case)
3. **Redundant Verification**: Animation system also polls for changes (`waitForDarkModeChange`), creating duplicate waits
4. **No Early Exit**: Verification waits full duration even if change happens immediately

## AppleScript Execution

```swift
private func executeAppleScript(_ script: String) -> Bool {
    var error: NSDictionary?

    guard let scriptObject = NSAppleScript(source: script) else {
        return false
    }

    let result = scriptObject.executeAndReturnError(&error)

    if let error = error {
        // Log error details
        return false
    }
    return true
}
```

**Note**: Script compilation happens at runtime for each execution. No caching.

## Current Performance Concerns

1. **Blocking Sleep Calls**: `usleep()` freezes the main thread, degrading UI responsiveness
2. **Overly Long Verification**: 300-500ms delays are conservative; actual system response is often much faster
3. **No Parallel Execution**: Methods run strictly sequentially with full delays
4. **Double Polling**: Both DarkModeManager and OverlayAnimationView poll for appearance changes
5. **Script Recompilation**: AppleScript is recompiled each toggle instead of being cached
