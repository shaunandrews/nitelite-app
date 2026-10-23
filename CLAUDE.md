# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NiteLite is a macOS menubar application that toggles system Dark Mode with cinematic transition animations. Built with Swift and SwiftUI, it runs as an LSUIElement (menubar-only app) that requires automation permissions to control system appearance settings.

## Development Commands

```bash
./build.sh            # Debug build + launch (development)
./build.sh release    # Release build → dist/NiteLite.app
./build.sh install    # Release build → /Applications/NiteLite.app, then launch
./build.sh package    # Release build → dist/NiteLite.zip, copied into site/
./build.sh clean      # Remove build/ and dist/

# Publish the download site (https://nitelite.space.fast, Spacefast, Shaun's Team)
./build.sh package && sf publish site

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

Every style goes through `toggleWhenCovered()`: cover eases in, the toggle fires one frame after full black, then the view holds on black for `repaintSettle` (400ms) after the appearance change is detected, then the reveal eases out. That hold is load-bearing: other apps repaint 70–500ms after macOS reports the change, and revealing sooner shows the old theme flipping after the transition. Don't shorten it without re-measuring with `scripts/measure-toggle.swift` (see `docs/04-animation-system.md`). The dark mode toggle fires at `onBlackReached` callback (when screen is fully black), then animation reveals the new appearance.

### Key Implementation Details

- Uses Carbon `RegisterEventHotKey` for global ⌘⇧D shortcut
- `DistributedNotificationCenter` listens for `AppleInterfaceThemeChangedNotification` to sync icon with external changes
- `OverlayAnimationManager` creates overlay windows for all screens (`NSScreen.screens`) for multi-display support
- Animation uses 16ms polling (`waitForDarkModeChange`) to detect when system appearance actually changes

## Website

`site/` is published to https://nitelite.space.fast via `sf publish site` (`site/.spacefast/space.json` links it). `site/NiteLite.zip` (`./build.sh package`) and `site/room/` (see below) are generated and gitignored; both must exist before publishing.

### Bedroom scene (`scene/` → `site/js/room.js`)

The site is a realtime three.js room. Pipeline: `python3 -I scene/fetch_assets.py` → `scene/export_web.py` (Blender, writes `site/room/room.glb`, textures, 1k skies) → `scene/posters.sh` (loading stills). Run Blender headless with `--factory-startup --disable-autoexec`. `site/js/room.js` owns materials (`MATERIALS`, keyed by the placeholder material names), lighting per state (`STATES`), and the transitions (`TRANSITIONS`); Blender (x, y, z) is three.js `b(x, y, z)` = (x, z, -y). Things that bit us:
- Box objects need `set_sharp_from_angle` (see `smooth()`); fully smooth-shaded boxes render bright gradient "light leaks".
- Read `matrix_world` only after `bpy.context.view_layer.update()`.
- glTF import names the mesh after the asset, so asset roots are `<name>_root`.
- `export_web.py` overwrites UVs with box UVs; objects with real UVs (`ArtPrint`) must be skipped.
- Transitions: let the object act in full light and dip to black only at the end, or the action is never seen.

## Permission Requirements

- **Automation Permissions**: Required for controlling System Events via AppleScript
- **Entitlements**: `com.apple.security.automation.apple-events` enabled, app sandbox disabled
- **Info.plist**: `LSUIElement` set to true for menubar-only operation

## Troubleshooting

If dark mode toggle fails, check System Preferences → Security & Privacy → Privacy → Automation for NiteLite permissions. The app requests these on first launch via a test AppleScript.