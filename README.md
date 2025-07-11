# NiteLite
Tagline: Let there be night.

NiteLite is a lightweight, elegant macOS menubar app that does exactly one thing perfectly: toggles system Dark Mode with a single click.

It lives in your menu bar with a subtle icon indicating your current mode, making it frictionless to switch between Light and Dark.

## Features
- **Minimal**: Lives only in your menubar, no main window or dock icon
- **Smart Icons**: Shows a moon in Dark Mode, sun in Light Mode  
- **One-Click Toggle**: Simply click the menubar icon to switch modes
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
xcodebuild -project NiteLite.xcodeproj -scheme NiteLite -configuration Debug build
open build/Debug/NiteLite.app
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
NiteLite uses multiple methods to reliably toggle Dark Mode:

1. **AppleScript Integration**: Primary method using System Events to control appearance preferences
2. **Command Line osascript**: Fallback using the osascript command-line tool  
3. **Direct UserDefaults**: Last resort method modifying system preferences directly

**Permission Handling**: The app requests automation permissions automatically on first launch, eliminating the need to wait for user interaction. All methods include verification to ensure the toggle actually worked.

**Smart Icon Updates**: The menubar icon automatically reflects the current system appearance and updates when Dark Mode is toggled from other sources (System Preferences, Control Center, etc.)

## Project Structure
```
NiteLite/
├── NiteLiteApp.swift      # Main app entry point
├── AppDelegate.swift      # Menubar setup and event handling  
├── DarkModeManager.swift  # Dark mode toggle logic
├── Info.plist            # App metadata
└── NiteLite.entitlements # Required permissions
```