# NiteLite
Tagline: Let there be night.

NiteLite is a lightweight, elegant macOS menubar app that does exactly one thing perfectly: toggles system Dark Mode with a single click.

It lives in your menu bar with a subtle icon indicating your current mode, making it frictionless to switch between Light and Dark.

## Features
- **Minimal**: Lives only in your menubar, no main window or dock icon
- **Smart Icons**: Shows a moon in Dark Mode, sun in Light Mode  
- **One-Click Toggle**: Simply click the menubar icon to switch modes
- **Multiple Transition Styles**: Choose between Classic Film Iris or Left-Right Wipe animations
- **Classic Film Iris Transition**: Beautiful iris opening/closing animation during mode switches
- **Left-Right Wipe Transition**: Smooth left-to-right fade-wipe through black for a cinematic effect
- **Native**: Built with Swift and SwiftUI for macOS

## Tech stack
Built using Swift and SwiftUI.

## Building & Running

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later

### Quick Start
1. Clone this repository
2. Open `NiteLite.xcodeproj` in Xcode
3. Build and run (⌘+R)

Or use the build script:
```bash
./build.sh
```

### Manual Build
```bash
xcodebuild -project NiteLite.xcodeproj -scheme NiteLite -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NiteLite.app
```

## Permissions
On first run, macOS will ask for permission to control your system preferences. This is required for NiteLite to toggle Dark Mode.

### Troubleshooting
If the toggle doesn't work:

1. **Grant Automation Permissions**: Go to System Preferences → Security & Privacy → Privacy → Automation, and ensure NiteLite has permission to control "System Events"

2. **Manual Permission Setup**: You can also manually grant permissions by running this in Terminal:
   ```bash
   sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "INSERT OR REPLACE INTO access VALUES('kTCCServiceAppleEvents','com.yourname.nitelite',0,2,2,1,NULL,NULL,0,'UNUSED',NULL,0,1541440109);"
   ```

3. **Try Different Methods**: NiteLite uses multiple fallback methods:
   - Shell command to modify UserDefaults directly  
   - AppleScript via NSAppleScript
   - Command line osascript

4. **Check Console**: Look for error messages in Console.app that might indicate permission issues

## How it Works
NiteLite uses multiple methods to reliably toggle Dark Mode with beautiful classic film-style transitions:

**Visual Transitions**: When switching modes, choose from two cinematic animation styles:
- **Classic Film Iris**: Traditional iris opening/closing animation
  - **To Dark Mode**: Iris closes (circular hole shrinks to black)
  - **To Light Mode**: Iris opens (circular hole expands from black)
- **Left-Right Wipe**: Smooth fade-wipe transition through black
  - **To Dark Mode**: Screen wipes from left to right to black
  - **To Light Mode**: Fade to black, then wipe from left to right revealing content
- **Timing**: 0.3-0.4 second animations with optimized dark mode toggle coordination
- **Context Menu**: Right-click the menubar icon to choose your preferred animation style

**Dark Mode Toggle Methods**:
1. **AppleScript Integration**: Primary method using System Events to control appearance preferences
2. **Command Line osascript**: Fallback using the osascript command-line tool  
3. **Direct UserDefaults**: Last resort method modifying system preferences directly

**Permission Handling**: The app requests automation permissions automatically on first launch, eliminating the need to wait for user interaction. All methods include verification to ensure the toggle actually worked.

**Smart Icon Updates**: The menubar icon automatically reflects the current system appearance and updates when Dark Mode is toggled from other sources (System Preferences, Control Center, etc.)

**Animation Preferences**: Your preferred animation style is saved automatically and persists between app launches.

## Demo & Marketing

Check out the `/marketing` folder for:
- **Live Demo**: Interactive HTML page showcasing the app's light/dark mode toggling
- **Marketing Assets**: Recorded demo videos (mov/gif) showing the classic film iris transition in action

The marketing materials demonstrate the smooth animation and instant dark mode switching that makes NiteLite special.

## Project Structure
```
NiteLite/
├── NiteLiteApp.swift            # Main app entry point
├── AppDelegate.swift            # Menubar setup and event handling  
├── DarkModeManager.swift        # Dark mode toggle logic
├── OverlayAnimationWindow.swift # Classic film iris transition animation
├── Info.plist                  # App metadata
├── NiteLite.entitlements       # Required permissions
└── marketing/                  # Demo page and marketing assets
    ├── index.html              # Interactive demo page
    └── [demo videos]           # Recorded demo materials (mov/gif)
```