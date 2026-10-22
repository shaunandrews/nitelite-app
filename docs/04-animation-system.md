# Animation System - Overlay Transitions

## Overview

`OverlayAnimationWindow.swift` contains the complete animation system for NiteLite's dark mode transitions. It creates full-screen overlay windows that animate to black, trigger the mode change, then reveal the new appearance.

## Components

### 1. AnimationType Enum

```swift
enum AnimationType: String, CaseIterable {
    case iris      // "Classic Film Iris"
    case wipe      // "Left-Right Wipe"
    case tv        // "Old TV Turn-off"
    case blinds    // "Venetian Blinds"
    case curtain   // "Curtain Call"
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
│ Cover: animate TO black (ease-in, 0.12–0.42s by style)           │
└────────────────────────────────┬─────────────────────────────────┘
                                 │  toggleWhenCovered(after:)
                                 │  waits cover duration + frameBuffer (30ms)
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ onBlackReached() → DarkModeManager.toggleDarkMode()              │
│   (synchronous AppleScript, ~30–200ms, screen is black)          │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ waitForDarkModeChange()                                          │
│   - Poll NSApp.effectiveAppearance every 16ms (240ms timeout)    │
│   - Once seen: hold on black for repaintSettle (400ms)           │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ Reveal: animate FROM black (ease-out)                            │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│ completion() → icon updated, overlays cleaned up                 │
└──────────────────────────────────────────────────────────────────┘
```

## Timing rules

Every style follows the same shape, enforced by `toggleWhenCovered(after:expectedDarkMode:reveal:)`:

1. **Covers ease in, reveals ease out.** The cover accelerates into black so the switch is hidden crisply; the reveal decelerates as the new appearance settles.
2. **Toggle one frame late.** `frameBuffer` (30ms) is added to each cover duration so the fully-black frame is on screen before the blocking AppleScript call stalls the main thread.
3. **Hold on black until apps repaint.** This is the important one. See below.
4. **Don't fade an overlay that's already clear.** TV, Blinds and Curtain end with nothing on screen, so they call `onComplete()` directly.

### Why the 400ms hold exists

macOS reports the new appearance (the `AppleInterfaceThemeChangedNotification`, and our own `NSApp.effectiveAppearance`) long before other apps have actually redrawn. Measured with a screen recording on macOS 27:

| Event | Time after the toggle call |
|-------|----------------------------|
| AppleScript returns | 26–207ms |
| Appearance notification | 30–293ms |
| Screen visibly changes | 159–735ms (slowest on the first toggle after a while) |

The visible change lands **70–500ms after the notification**. Revealing as soon as the notification arrived showed the old theme, which then flipped after the transition finished. `repaintSettle` holds on black for 400ms after the change is detected. If a future macOS repaints faster, lower it; the measurement script below tells you by how much.

There is no API that reports "all apps finished repainting". The only exact signal is watching the screen itself, which would need Screen Recording permission (and shows the purple recording indicator on every toggle), so the app uses the fixed hold instead.

### Measuring it yourself

`scripts/measure-toggle.swift` presses ⌘⇧D and records the screen's average brightness frame by frame with ScreenCaptureKit, so you can see exactly when the overlay covers, when the theme flips, and whether the old theme leaks through the reveal:

```bash
swiftc -o /tmp/measure-toggle scripts/measure-toggle.swift
/tmp/measure-toggle 4    # toggles 4 times; an even number ends where you started
```

It needs Screen Recording and Accessibility permission for your terminal app. Each line is `ms:brightness`. A good run goes old value → `0.00` (black) → straight to the new value. A bad run climbs back toward the old value during the reveal, then jumps.

## Styles

| Style | Cover | Toggle fires | Reveal | Notes |
|-------|-------|--------------|--------|-------|
| Iris (to dark) | radius → 0, easeIn 0.18s | 0.21s | overlay fade, easeOut 0.12s | `blendMode(.destinationOut)` circle in a `compositingGroup()` |
| Iris (to light) | fade to black, easeIn 0.12s | 0.15s | radius → max, easeOut 0.2s | Hole punched in a mask |
| Wipe | band 0 → 0.5, easeIn 0.2s | 0.23s | band 0.5 → 1, easeOut 0.25s | Feathered band; 0 = off-screen left, 0.5 = covering, 1 = off-screen right |
| Old TV | squeeze Y (0.1s), then X (0.08s), dot glow | 0.26s | dot, expand X (0.06s), expand Y (0.1s) | |
| Blinds | 14 slats, 0.02 stagger, easeIn 0.25s | 0.28s | easeOut 0.28s | Every slat lands exactly at progress 1 |
| Curtain | spring (response 0.7, damping 0.75) | 0.45s | spring (0.6, 0.7) over 0.6s | Spring first reaches center at ~0.41s and stays closed through its overshoot |

Add the toggle time, the AppleScript call, and the 400ms hold, then the reveal: a full toggle takes about a second.

## Appearance Change Polling

```swift
private func waitForDarkModeChange(expectedDarkMode: Bool, completion: @escaping () -> Void) {
    let checkAppearance = {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark == expectedDarkMode
    }

    // Once the switch is seen, hold on black until other apps finish repainting
    let settleThenComplete = { self.after(Self.repaintSettle, completion) }

    if checkAppearance() { settleThenComplete(); return }

    // Poll every 16ms, 240ms timeout. On timeout (e.g. permission denied, so
    // nothing changed) reveal immediately.
    ...
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
