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
| `./build.sh package` | Release build zipped to `dist/NiteLite.zip`, copied into `site/` for the download page |
| `./build.sh clean` | Delete `build/` and `dist/` |

### Code signing
Builds are ad-hoc signed by default, so macOS asks for Automation permission again after every reinstall. To keep that permission across rebuilds, sign with a stable identity from your keychain:

```bash
NITELITE_SIGN_IDENTITY="Your Cert Name" ./build.sh install
```

List available identities with `security find-identity -v -p codesigning`.

### Launch at login
System Settings → General → Login Items → add NiteLite.

## Website

The download page lives in `site/` and is published at **https://nitelite.space.fast** (Spacefast, in Shaun's Team, public). It's plain HTML with no build step. The page replays all five transitions in the browser on a `<canvas>` overlay, ported from the Swift shapes and timing, so keep the two in sync when either changes.

### Publish an update
```bash
./build.sh package    # rebuilds NiteLite.zip into site/
sf publish site       # publishes a new version to the same space
```

- `site/.spacefast/space.json` links the folder to the space; `state.json` next to it is local-only and gitignored.
- `site/NiteLite.zip` is gitignored. Always run `./build.sh package` before publishing, or the page links to a stale build.
- When the app version changes, update the version and size in `site/index.html` (hero text and the JSON-LD block).
- Public access is a Spacefast grant on `/**`. A `/*` pattern does not cover the homepage.

### The bedroom scene
The page's hero is a 3D bedroom rendered in Blender (`scene/`). Light mode is a sunny morning; dark mode is night with the bedside lamp on. Each NiteLite transition is an object in the room: curtains, blinds, the TV, the floor projector (iris) and the door (wipe). Clicking one plays a short clip, and the page flips theme at its black frame.

```bash
python3 -I scene/fetch_assets.py   # CC0 models, textures and skies from Poly Haven (~150 MB, gitignored)
scene/render_clips.sh              # renders all 5 clips (~30 min on an M4 Pro), then runs scene/encode.sh
```

- `scene/build_scene.py` builds the room. Render a still with `--state day|night --cam wide|corner|nightstand|low`.
- `scene/animate.py` keys one clip: close → black → swap day/night → open. Every clip is symmetric, so `scene/encode.sh` makes the night → day video by reversing the frames.
- `scene/encode.sh` writes `site/room/` (MP4 + WebM per direction, plus `day.jpg`/`night.jpg` from the first and last frames). It's generated and gitignored, like the zip.
- `scene/hotspots.py` projects each object into the camera and writes `site/room/hotspots.json`. Copy the numbers into the `--x`/`--y` of the hotspots in `site/index.html` if the camera or layout changes.
- The duvet and throw are cloth simulations, cached in `scene/cache/`. Delete it after changing the bed to re-simulate.

### SEO files
`robots.txt`, `sitemap.xml`, `404.html`, and the canonical/Open Graph URLs in `index.html` all point at `https://nitelite.space.fast/`. Update them together if the domain changes.

## App icon

The icon is a gold film iris around a crescent moon on navy. It was generated with ChatGPT as full-bleed 1024px square artwork; macOS applies the rounded-square mask itself, so don't add corners or padding. The sizes live in `NiteLite/Assets.xcassets/AppIcon.appiconset/`. To replace the artwork, regenerate them from a new square PNG:

```bash
cd NiteLite/Assets.xcassets/AppIcon.appiconset
for s in 16 32 128 256 512; do
  sips -s format png -z $s $s source.png --out icon_${s}x${s}.png
  sips -s format png -z $((s*2)) $((s*2)) source.png --out icon_${s}x${s}@2x.png
done
```

The website icons (`site/icon-64.png`, `site/icon-512.png`) are the masked version macOS renders, exported from the built app.

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

**Timing**: macOS reports the new appearance well before other apps finish redrawing, so NiteLite holds on black for 400ms after the switch before revealing. Without that hold you see the old theme come back, then flip. A full toggle takes about a second. The details and the measurement script are in [docs/04-animation-system.md](docs/04-animation-system.md).

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
build.sh                         # Build / install / package script
scripts/measure-toggle.swift     # Screen-recording timing harness
scene/                           # Blender bedroom for the website (build, animate, encode)
site/                            # Download page (nitelite.space.fast)
NiteLite/
├── NiteLiteApp.swift            # Main app entry point
├── AppDelegate.swift            # Menubar setup, hotkey, and event handling
├── DarkModeManager.swift        # Dark mode toggle logic
├── OverlayAnimationWindow.swift # Transition animations (all styles)
├── Assets.xcassets              # App icon
├── Info.plist                   # App metadata
└── NiteLite.entitlements        # Required permissions
docs/                            # Architecture notes
marketing/                       # Original placeholder demo page
```