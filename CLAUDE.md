# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NiteLite is a macOS menubar application that toggles system Dark Mode with a classic film iris transition animation. Built with Swift and SwiftUI, it runs as an LSUIElement (menubar-only app) that requires automation permissions to control system appearance settings.

## Development Commands

### Building
```bash
# Quick build and run (preferred)
./build.sh

# Manual build
xcodebuild -project NiteLite.xcodeproj -scheme NiteLite -configuration Debug build

# Open built app
open build/Debug/NiteLite.app
```

### Marketing & Demo
```bash
# Open interactive demo page in browser
open marketing/index.html

# View marketing folder contents
ls marketing/
```

### Development in Xcode
```bash
# Open project in Xcode
open NiteLite.xcodeproj

# Build and run in Xcode: ⌘+R
```

## Architecture

### Project Structure
```
NiteLite/
├── NiteLiteApp.swift            # Main app entry point
├── AppDelegate.swift            # Menubar setup and event handling  
├── DarkModeManager.swift        # Dark mode toggle logic
├── OverlayAnimationWindow.swift # Classic film iris transition animation
├── Info.plist                  # App metadata
├── NiteLite.entitlements       # Required permissions
└── marketing/                  # Demo and marketing materials
    ├── index.html              # Interactive demo page with light/dark mode
    └── [demo assets]           # Recorded videos (mov/gif) for marketing
```

### Core Components

- **NiteLiteApp.swift** - Main app entry point using `@NSApplicationDelegateAdaptor`
- **AppDelegate.swift** - Handles menubar lifecycle, status item creation, and coordinates dark mode toggle with iris animation
- **DarkModeManager.swift** - Implements multiple fallback methods for toggling system Dark Mode (AppleScript, osascript, shell commands)
- **OverlayAnimationWindow.swift** - Creates fullscreen overlay with classic film iris transition using SwiftUI compositing

### Dark Mode Toggle Strategy

The app uses a three-tier fallback approach for reliable dark mode switching:

1. **AppleScript via NSAppleScript** - Primary method using System Events
2. **Command-line osascript** - Fallback using shell execution
3. **Direct UserDefaults modification** - Last resort using `defaults` command

Each method includes verification to ensure the toggle actually worked before considering it successful.

### Animation Timing Coordination

The iris animation and dark mode toggle are carefully coordinated:
- **Animation First**: Classic film iris transition plays immediately when clicked
- **Toggle After**: Dark mode toggles immediately after animation completes
- **Animation Duration**: 2.0 second iris animation with 0.2 second hold

### Permission Requirements

- **Automation Permissions**: Required for controlling System Events via AppleScript
- **Entitlements**: `com.apple.security.automation.apple-events` enabled, app sandbox disabled
- **Info.plist**: `LSUIElement` set to true, includes `NSAppleEventsUsageDescription`

### Key Implementation Details

- Uses `NSStatusItem` for menubar presence with SF Symbol icons (`moon.fill` / `sun.max.fill`)
- Listens for `AppleInterfaceThemeChangedNotification` to update icon when dark mode changes externally
- Uses `DistributedNotificationCenter` for system-wide appearance change notifications
- Animation uses SwiftUI's `blendMode(.destinationOut)` with `compositingGroup()` for iris effect
- Multiple screen support via `NSScreen.main` frame detection

## Marketing & Demo Materials

The `/marketing` folder contains materials for promoting NiteLite:

### Interactive Demo
- **index.html**: A responsive web page that demonstrates the light/dark mode concept
- Automatically adapts to system appearance using `prefers-color-scheme` media queries
- Features smooth transitions and the "Let there be NiteLite!" tagline
- Useful for screenshots, social media posts, and live demonstrations

### Demo Videos
- Recorded mov/gif files showing the actual app in action
- Captures the classic film iris transition animation
- Demonstrates the menubar icon changes and smooth mode switching
- Used for marketing on platforms like Gumroad, Reddit, and X (Twitter)

### Usage in Marketing
These materials are designed for:
- Product listings and store pages
- Social media demonstrations
- Documentation and tutorials
- Press kits and review materials

## Troubleshooting

### Permission Issues
If dark mode toggle fails, check automation permissions in System Preferences → Security & Privacy → Privacy → Automation. The app automatically requests these permissions on first launch.

### Build Issues
- Requires macOS 13.0+ and Xcode 15.0+
- Ensure bundle identifier matches entitlements configuration
- Check that `LSUIElement` is properly set to prevent dock icon appearance