# Animation System - Overlay Transitions

## Overview

`OverlayAnimationWindow.swift` contains the complete animation system for NiteLite's dark mode transitions. It creates full-screen overlay windows that animate to black, trigger the mode change, then reveal the new appearance.

## Components

### 1. AnimationType Enum

```swift
enum AnimationType: String, CaseIterable {
    case iris = "iris"    // Classic film iris circle effect
    case wipe = "wipe"    // Left-to-right wipe effect

    var displayName: String {
        switch self {
        case .iris: return "Classic Film Iris"
        case .wipe: return "Left-Right Wipe"
        }
    }
}
```

### 2. AnimationPreferences (Singleton)

```swift
class AnimationPreferences {
    static let shared = AnimationPreferences()

    var animationType: AnimationType {
        get { /* Read from UserDefaults */ }
        set { /* Write to UserDefaults */ }
    }
}
```

Persists user's animation preference using key `NiteLite_AnimationType`.

### 3. OverlayAnimationWindow (NSWindow)

Custom window configured for full-screen overlay:

```swift
init(...) {
    // Key properties:
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
    self.ignoresMouseEvents = true
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    self.isReleasedWhenClosed = false
}
```

| Property | Value | Purpose |
|----------|-------|---------|
| `level` | `.maximumWindow` | Display above all other windows |
| `ignoresMouseEvents` | `true` | Click-through during animation |
| `collectionBehavior` | `canJoinAllSpaces, fullScreenAuxiliary` | Works with Spaces and fullscreen apps |

### 4. OverlayAnimationView (SwiftUI)

The actual animation implementation using SwiftUI animations.

### 5. OverlayAnimationManager

Coordinates multi-monitor support by creating overlay windows for each screen.

## Animation Flow

```
┌──────────────────────────────────────────────────────────────────┐
│ showTransitionAnimation(isDarkMode, onBlackReached, completion)  │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ For each NSScreen.screens:                                       │
│   1. Create OverlayAnimationWindow                               │
│   2. Set frame to screen.frame                                   │
│   3. Start animation                                             │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ Animation Phase 1: Transition TO black                           │
│   - Iris: Circle shrinks to center                               │
│   - Wipe: Black bar sweeps left to right                         │
│   Duration: 0.12 - 0.2 seconds                                   │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ onBlackReached() callback fires                                  │
│   → DarkModeManager.toggleDarkMode() executes                    │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ waitForDarkModeChange() polling                                  │
│   - Check NSApp.effectiveAppearance every 16ms                   │
│   - Timeout: 15 attempts (240ms)                                 │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ Animation Phase 2: Reveal FROM black                             │
│   - Iris: Circle expands from center                             │
│   - Wipe: Black bar continues off-screen                         │
│   Duration: 0.08 - 0.25 seconds                                  │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ completion() callback fires                                      │
│   → Icon updated, overlays cleaned up                            │
└──────────────────────────────────────────────────────────────────┘
```

## Iris Animation Details

### Dark Mode (Switching TO Dark)

```swift
private func startIrisDarkModeAnimation() {
    let maxRadius = sqrt(width² + height²) / 2  // Corner-to-corner
    irisRadius = maxRadius
    overlayOpacity = 1.0

    // Phase 1: Close iris (0.15s)
    withAnimation(.easeInOut(duration: 0.15)) {
        irisRadius = 0.0
    }

    // After 0.15s: trigger toggle
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        self.onBlackReached()

        // Wait for system response
        self.waitForDarkModeChange(expectedDarkMode: true) {
            // Phase 2: Fade out black (0.08s)
            withAnimation(.easeOut(duration: 0.08)) {
                self.overlayOpacity = 0.0
            }
        }
    }
}
```

**Visual Effect**: Black background with white circle cutout that shrinks.

Uses `blendMode(.destinationOut)` with `compositingGroup()` for proper masking.

### Light Mode (Switching TO Light)

```swift
private func startIrisLightModeAnimation() {
    fadeOpacity = 0.0  // Start transparent
    irisRadius = 0.0

    // Phase 1: Fade to black (0.12s)
    withAnimation(.easeOut(duration: 0.12)) {
        fadeOpacity = 1.0
    }

    // After 0.12s: trigger toggle
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        self.onBlackReached()

        // Wait for system response
        self.waitForDarkModeChange(expectedDarkMode: false) {
            // Phase 2: Open iris (0.15s)
            withAnimation(.easeOut(duration: 0.15)) {
                self.irisRadius = maxRadius
            }
        }
    }
}
```

**Visual Effect**: Fade to black, then iris opens to reveal light mode.

## Wipe Animation Details

### Both Directions

```swift
private func startWipeAnimation(expectedDarkMode: Bool) {
    wipeProgress = 0.0
    overlayOpacity = 1.0

    // Phase 1: Wipe to full coverage (0.2s)
    withAnimation(.easeInOut(duration: 0.2)) {
        wipeProgress = 0.6  // 60% covers screen
    }

    // After 0.2s: trigger toggle
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.onBlackReached()

        // Wait for system response
        self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
            // Phase 2: Complete wipe (0.25s)
            withAnimation(.easeInOut(duration: 0.25)) {
                self.wipeProgress = 1.1  // Off-screen
            }
        }
    }
}
```

**Visual Effect**: Gradient-edged black bar sweeps across screen.

```swift
// Gradient mask creates soft edges
LinearGradient(
    gradient: Gradient(stops: [
        .init(color: .clear, location: 0.0),
        .init(color: .white, location: 0.05),  // 5% soft edge
        .init(color: .white, location: 0.95),
        .init(color: .clear, location: 1.0)   // 5% soft edge
    ]),
    startPoint: .leading,
    endPoint: .trailing
)
```

## Appearance Change Polling

```swift
private func waitForDarkModeChange(expectedDarkMode: Bool, completion: @escaping () -> Void) {
    let checkAppearance = {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark == expectedDarkMode
    }

    // Immediate check
    if checkAppearance() {
        completion()
        return
    }

    // Poll every 16ms (60fps), max 15 attempts (240ms timeout)
    // System typically responds in ~50-100ms
    var attempts = 0
    let maxAttempts = 15

    Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
        attempts += 1
        if checkAppearance() || attempts >= maxAttempts {
            timer.invalidate()
            completion()
        }
    }
}
```

## Multi-Monitor Support

```swift
func showTransitionAnimation(...) {
    let screens = NSScreen.screens

    // Track completions from all screens
    var completedScreens = 0
    var blackReachedCallbackFired = false

    for screen in screens {
        let overlayWindow = OverlayAnimationWindow(...)

        overlayWindow.showAnimation(..., onBlackReached: {
            // Only fire ONCE for all screens
            if !blackReachedCallbackFired {
                blackReachedCallbackFired = true
                onBlackReached()
            }
        }, completion: {
            completedScreens += 1
            if completedScreens == totalScreens {
                self.cleanupOverlays()
                completion()
            }
        })
    }
}
```

## Animation Timings

| Animation | Phase | Duration | Cumulative |
|-----------|-------|----------|------------|
| **Iris Dark** | Close | 0.15s | 0.15s |
| | Toggle + Wait | 0-0.24s | 0.15-0.39s |
| | Fade out | 0.08s | 0.23-0.47s |
| **Iris Light** | Fade in | 0.12s | 0.12s |
| | Toggle + Wait | 0-0.24s | 0.12-0.36s |
| | Open | 0.15s | 0.27-0.51s |
| **Wipe** | Cover | 0.2s | 0.2s |
| | Toggle + Wait | 0-0.24s | 0.2-0.44s |
| | Complete | 0.25s | 0.45-0.69s |

**Note**: The system typically responds in ~50-100ms, so real-world timings are usually at the lower end of these ranges.