# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NiteLite is a macOS menubar application that toggles system Dark Mode with cinematic transition animations. Built with Swift and SwiftUI, it runs as an LSUIElement (menubar-only app) that requires automation permissions to control system appearance settings.

## Development Commands

```bash
./build.sh            # Debug build + launch (development)
./build.sh release    # Release build → dist/NiteLite.app
./build.sh install    # Release build → /Applications/NiteLite.app, then launch
./build.sh clean      # Remove build/ and dist/

# Optional: sign with a stable keychain identity so Automation permission survives reinstalls
NITELITE_SIGN_IDENTITY="Cert Name" ./build.sh install

# Open in Xcode
open NiteLite.xcodeproj
```

## Architecture

### Core Components

- **AppDelegate.swift** - Menubar lifecycle, status item, keyboard shortcut (⌘⇧D), coordinates toggle with animation
- **DarkModeManager.swift** - Three-tier fallback for dark mode toggle: AppleScript → osascript → shell defaults command
- **OverlayAnimationWindow.swift** - Full-screen overlay animations with multi-monitor support, contains `AnimationType` enum and `AnimationPreferences` singleton

### Dark Mode Toggle Strategy

Each method includes verification polling to confirm the toggle succeeded:
1. **AppleScript via NSAppleScript** - Primary method using System Events
2. **Command-line osascript** - Fallback using shell execution
3. **Direct UserDefaults** - Last resort using `defaults write/delete -g AppleInterfaceStyle`

### Animation System

Five animation styles selectable via right-click context menu (`AnimationType`, stored in `AnimationPreferences`):
- **Classic Film Iris** - Circle shrinks/expands from center using `blendMode(.destinationOut)` with `compositingGroup()`
- **Left-Right Wipe** - Gradient mask wipe across screen
- **Old TV Turn-off** - Screen squeezes to a line, then a glowing dot
- **Venetian Blinds** - Staggered horizontal slats slide in from alternating sides
- **Curtain Call** - Two `CurtainShape` curtains with wavy, spring-animated edges

Animation timing: ~0.15-0.25 second transitions (Curtain Call is slower, ~0.7s). The dark mode toggle fires at `onBlackReached` callback (when screen is fully black), then animation reveals the new appearance.

### Key Implementation Details

- Uses Carbon `RegisterEventHotKey` for global ⌘⇧D shortcut
- `DistributedNotificationCenter` listens for `AppleInterfaceThemeChangedNotification` to sync icon with external changes
- `OverlayAnimationManager` creates overlay windows for all screens (`NSScreen.screens`) for multi-display support
- Animation uses 16ms polling (`waitForDarkModeChange`) to detect when system appearance actually changes

## Permission Requirements

- **Automation Permissions**: Required for controlling System Events via AppleScript
- **Entitlements**: `com.apple.security.automation.apple-events` enabled, app sandbox disabled
- **Info.plist**: `LSUIElement` set to true for menubar-only operation

## Troubleshooting

If dark mode toggle fails, check System Preferences → Security & Privacy → Privacy → Automation for NiteLite permissions. The app requests these on first launch via a test AppleScript.