# NiteLite Architecture Overview

## Application Summary

NiteLite is a macOS menubar application that provides a cinematic transition animation when toggling between Dark Mode and Light Mode. The app runs as a menubar-only application (LSUIElement) without a dock icon or main window.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        NiteLiteApp.swift                         │
│                     (@main entry point)                          │
│                              │                                   │
│                              ▼                                   │
│                      ┌──────────────┐                            │
│                      │ AppDelegate  │                            │
│                      └──────┬───────┘                            │
│                             │                                    │
│            ┌────────────────┼────────────────┐                   │
│            ▼                ▼                ▼                   │
│   ┌────────────────┐ ┌─────────────────┐ ┌────────────────┐      │
│   │ Status Item    │ │ DarkModeManager │ │ Animation      │      │
│   │ (Menubar Icon) │ │                 │ │ Manager        │      │
│   └────────────────┘ └─────────────────┘ └────────┬───────┘      │
│                                                   │              │
│                                                   ▼              │
│                                          ┌────────────────┐      │
│                                          │ Overlay Windows│      │
│                                          │ (per screen)   │      │
│                                          └────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. NiteLiteApp.swift
The app entry point using SwiftUI's `@main` attribute. Uses `@NSApplicationDelegateAdaptor` to bridge to the AppDelegate for menubar functionality.

### 2. AppDelegate.swift
Manages the application lifecycle and coordinates all major operations:
- Creates and manages the status bar item
- Handles left-click (toggle) and right-click (menu) events
- Registers global keyboard shortcut (⌘⇧D) using Carbon APIs
- Coordinates the toggle flow: animation start → mode change → animation complete
- Listens for external appearance changes via `DistributedNotificationCenter`

### 3. DarkModeManager.swift
Handles the actual system dark mode toggle with a three-tier fallback strategy:
1. **AppleScript via NSAppleScript** - Uses System Events to set `dark mode`
2. **Command-line osascript** - Falls back to shell execution of AppleScript
3. **Direct UserDefaults** - Last resort using `defaults write/delete`

Each method includes verification polling to confirm the toggle succeeded.

### 4. OverlayAnimationWindow.swift
Contains the animation system with three main components:
- **AnimationType enum** - Defines available animation styles (iris, wipe)
- **AnimationPreferences** - Singleton storing user's animation preference
- **OverlayAnimationWindow** - NSWindow subclass for full-screen overlays
- **OverlayAnimationView** - SwiftUI view implementing the animations
- **OverlayAnimationManager** - Coordinates multi-monitor animation

## Toggle Flow Sequence

```
User Click/Shortcut
        │
        ▼
┌───────────────────┐
│ Get current mode  │
│ (isDarkModeEnabled)│
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Start animation   │
│ (showTransition)  │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Animation reaches │
│ full black        │
│ (onBlackReached)  │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Toggle dark mode  │
│ (toggleDarkMode)  │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Poll for system   │
│ appearance change │
│ (16ms interval)   │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Complete animation│
│ reveal new mode   │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Update status icon│
│ Cleanup overlays  │
└───────────────────┘
```

## File Structure

```
NiteLite/
├── NiteLiteApp.swift          # App entry point
├── AppDelegate.swift          # Menubar & coordination
├── DarkModeManager.swift      # System toggle logic
├── OverlayAnimationWindow.swift # Animation system
├── Info.plist                 # App configuration (LSUIElement)
└── NiteLite.entitlements      # Automation permissions
```

## Key Dependencies

- **Cocoa/AppKit** - Native macOS framework for window management
- **SwiftUI** - Used for animation views
- **Carbon** - Low-level API for global keyboard shortcuts
- **System Events** - AppleScript target for appearance control

## Permission Requirements

| Permission | Purpose |
|-----------|---------|
| Automation (Apple Events) | Control System Events for dark mode toggle |
| No App Sandbox | Required for system-wide appearance changes |
