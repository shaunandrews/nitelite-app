# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NiteLite is a macOS menubar application that toggles system Dark Mode with cinematic transition animations. Built with Swift and SwiftUI, it runs as an LSUIElement (menubar-only app) that requires automation permissions to control system appearance settings.

## Development Commands

```bash
# Build and run (preferred)
./build.sh

# Manual build
xcodebuild -project NiteLite.xcodeproj -scheme NiteLite -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NiteLite.app

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

Two animation styles selectable via right-click context menu (stored in `AnimationPreferences`):
- **Classic Film Iris** - Circle shrinks/expands from center using `blendMode(.destinationOut)` with `compositingGroup()`
- **Left-Right Wipe** - Gradient mask wipe across screen

Animation timing: ~0.15-0.25 second transitions. The dark mode toggle fires at `onBlackReached` callback (when screen is fully black), then animation reveals the new appearance.

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