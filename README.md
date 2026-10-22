# NiteLite
Tagline: Let there be night.

NiteLite is a lightweight, elegant macOS menubar app that does exactly one thing perfectly: toggles system Dark Mode with a single click.

It lives in your menu bar with a subtle icon indicating your current mode, making it frictionless to switch between Light and Dark.

## Features
- **Minimal**: Lives only in your menubar, no main window or dock icon
- **Smart Icons**: Shows a moon in Dark Mode, sun in Light Mode
- **One-Click Toggle**: Click the menubar icon or press ⌘⇧D anywhere
- **Five Transition Styles** (right-click the icon to choose):
  - Classic Film Iris
  - Left-Right Wipe
  - Old TV Turn-off
  - Venetian Blinds
  - Curtain Call
- **Native**: Built with Swift and SwiftUI for macOS

## Building & Installing

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later

### Install to /Applications
```bash
./build.sh install
```
Builds a Release copy, quits any running NiteLite, installs it to `/Applications/NiteLite.app`, and launches it.

### Other commands
| Command | What it does |
| --- | --- |
| `./build.sh` | Debug build and launch (for development) |
| `./build.sh release` | Release build to `dist/NiteLite.app` (universal: Apple silicon + Intel) |
| `./build.sh clean` | Delete `build/` and `dist/` |

### Code signing
Builds are ad-hoc signed by default, so macOS asks for Automation permission again after every reinstall. To keep that permission across rebuilds, sign with a stable identity from your keychain:

```bash
NITELITE_SIGN_IDENTITY="Your Cert Name" ./build.sh install
```

List available identities with `security find-identity -v -p codesigning`.

### Launch at login
System Settings → General → Login Items → add NiteLite.

## Permissions
On first run, macOS asks for permission to control System Events. This is required for NiteLite to toggle Dark Mode.

### Troubleshooting
If the toggle doesn't work:

1. **Check Automation permission**: System Settings → Privacy & Security → Automation → make sure NiteLite can control "System Events".
2. **Reset a stale permission** (e.g. after reinstalling an ad-hoc signed build):
   ```bash
   tccutil reset AppleEvents com.shaunandrews.nitelite
   ```
   Then relaunch NiteLite and approve the prompt.
3. **Check Console.app** for NiteLite error messages.

## How it Works
When you toggle, NiteLite covers every display with a full-screen overlay, plays the transition until the screen is fully black, flips the system appearance, waits for macOS to confirm the change, then plays the reveal.

**Dark Mode toggle methods** (tried in order):
1. **AppleScript** via `NSAppleScript` and System Events
2. **`osascript`** command-line fallback
3. **`defaults write -g AppleInterfaceStyle`** as a last resort

The menubar icon also updates when Dark Mode is changed elsewhere (System Settings, Control Center, etc.), and your animation choice persists between launches.

## Demo & Marketing

Check out the `/marketing` folder for:
- **Live Demo**: Interactive HTML page showcasing the app's light/dark mode toggling
- **Marketing Assets**: Recorded demo videos (mov/gif) showing the classic film iris transition in action

The marketing materials demonstrate the smooth animation and instant dark mode switching that makes NiteLite special.

## Project Structure
```
build.sh                         # Build / install script
NiteLite/
├── NiteLiteApp.swift            # Main app entry point
├── AppDelegate.swift            # Menubar setup, hotkey, and event handling
├── DarkModeManager.swift        # Dark mode toggle logic
├── OverlayAnimationWindow.swift # Transition animations (all styles)
├── Info.plist                   # App metadata
└── NiteLite.entitlements        # Required permissions
docs/                            # Architecture notes
marketing/                       # Demo page
```