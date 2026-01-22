# New Animation Styles for NiteLite

## Overview

Add five new transition animations to NiteLite's dark mode toggle, expanding the current two options (iris, wipe) to seven total.

## New Animations

### 1. Old TV Turn-off
Three-phase CRT-style animation:
1. **Squeeze** (0.08s): Screen compresses vertically to a thin horizontal line
2. **Collapse** (0.05s): Line shrinks horizontally to a center dot
3. **Flash**: Brief white dot glow mimicking phosphor afterglow

Reveal reverses the sequence.

### 2. Camera Shutter
Six triangular blades arranged radially, rotating inward to close:
- Each blade is a 60° pie slice
- Blades rotate around their outer edge toward center
- Slight stagger (0.01s per blade) for mechanical feel
- All blades meet at center = full black

### 3. Venetian Blinds
12-16 horizontal bars sliding in from alternating sides:
- Even-indexed bars from left
- Odd-indexed bars from right
- Staggered timing (0.01s between bars) for cascade effect

### 4. Curtain Call
Two panels sliding from edges to center:
- Left curtain from off-screen left
- Right curtain from off-screen right
- Meet in middle with slight overlap to avoid seam

### 5. Drip
Black "paint" dripping from top edge:
- Rectangle with wavy bottom edge mask (overlapping circles)
- Moves from above screen to covering screen
- Randomized circle sizes for organic feel
- Reveal: drip falls off bottom edge

## Implementation

### File Changes

All changes in `OverlayAnimationWindow.swift`:

**AnimationType enum:**
```swift
enum AnimationType: String, CaseIterable {
    case iris = "iris"
    case wipe = "wipe"
    case tv = "tv"
    case shutter = "shutter"
    case blinds = "blinds"
    case curtain = "curtain"
    case drip = "drip"
}
```

**New @State variables in OverlayAnimationView:**
- TV: `scaleX`, `scaleY`, `dotOpacity`
- Shutter: `shutterRotation`
- Blinds: `blindsProgress`
- Curtain: `curtainProgress`
- Drip: `dripOffset`

**New @ViewBuilder properties:**
- `tvAnimationView`
- `shutterAnimationView`
- `blindsAnimationView`
- `curtainAnimationView`
- `dripAnimationView`

**New animation methods (dark/light variants for each):**
- `startTvDarkModeAnimation()` / `startTvLightModeAnimation()`
- `startShutterAnimation(expectedDarkMode:)`
- `startBlindsAnimation(expectedDarkMode:)`
- `startCurtainAnimation(expectedDarkMode:)`
- `startDripAnimation(expectedDarkMode:)`

### No Changes Needed
- `AppDelegate.swift` - menu auto-populates from `AnimationType.allCases`
- `DarkModeManager.swift` - unchanged
- `NiteLiteApp.swift` - unchanged

## Timing

All animations target ~0.15-0.25s total duration to match existing animations:
- Close phase: ~0.12-0.15s
- Reveal phase: ~0.12-0.15s
- System response polling: up to 240ms timeout (existing behavior)
