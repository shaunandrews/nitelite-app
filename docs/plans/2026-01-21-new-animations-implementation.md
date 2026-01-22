# New Animations Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add five new animation styles (Old TV, Camera Shutter, Venetian Blinds, Curtain, Drip) to NiteLite's dark mode toggle.

**Architecture:** All changes are in `OverlayAnimationWindow.swift`. Each animation follows the existing pattern: close to black → fire `onBlackReached` → wait for system → reveal. No test framework exists, so verify by building and running.

**Tech Stack:** Swift, SwiftUI, macOS AppKit

---

### Task 1: Extend AnimationType Enum

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift:4-16`

**Step 1: Add new enum cases and display names**

Replace lines 4-16 with:

```swift
enum AnimationType: String, CaseIterable {
    case iris = "iris"
    case wipe = "wipe"
    case tv = "tv"
    case shutter = "shutter"
    case blinds = "blinds"
    case curtain = "curtain"
    case drip = "drip"

    var displayName: String {
        switch self {
        case .iris:
            return "Classic Film Iris"
        case .wipe:
            return "Left-Right Wipe"
        case .tv:
            return "Old TV Turn-off"
        case .shutter:
            return "Camera Shutter"
        case .blinds:
            return "Venetian Blinds"
        case .curtain:
            return "Curtain Call"
        case .drip:
            return "Drip"
        }
    }
}
```

**Step 2: Build to verify syntax**

Run: `./build.sh`
Expected: Build succeeds (warnings about unhandled switch cases are OK for now)

**Step 3: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: add enum cases for five new animation types"
```

---

### Task 2: Add State Variables

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift` (OverlayAnimationView struct)

**Step 1: Add @State variables for new animations**

After line 84 (`@State private var wipeProgress: CGFloat = 0.0`), add:

```swift
    // TV animation state
    @State private var tvScaleX: CGFloat = 1.0
    @State private var tvScaleY: CGFloat = 1.0
    @State private var tvDotOpacity: Double = 0.0

    // Shutter animation state
    @State private var shutterProgress: CGFloat = 0.0

    // Blinds animation state
    @State private var blindsProgress: CGFloat = 0.0

    // Curtain animation state
    @State private var curtainProgress: CGFloat = 0.0

    // Drip animation state
    @State private var dripProgress: CGFloat = 0.0
```

**Step 2: Build to verify**

Run: `./build.sh`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: add state variables for new animations"
```

---

### Task 3: Update Body Switch and startAnimation

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift` (body and startAnimation)

**Step 1: Update body switch statement**

Replace the body computed property (around lines 86-98) with:

```swift
    var body: some View {
        Group {
            switch animationType {
            case .iris:
                irisAnimationView
            case .wipe:
                wipeAnimationView
            case .tv:
                tvAnimationView
            case .shutter:
                shutterAnimationView
            case .blinds:
                blindsAnimationView
            case .curtain:
                curtainAnimationView
            case .drip:
                dripAnimationView
            }
        }
        .onAppear {
            startAnimation()
        }
    }
```

**Step 2: Update startAnimation method**

Replace the startAnimation function (around lines 172-187) with:

```swift
    func startAnimation() {
        switch animationType {
        case .iris:
            if isDarkMode {
                startIrisDarkModeAnimation()
            } else {
                startIrisLightModeAnimation()
            }
        case .wipe:
            startWipeAnimation(expectedDarkMode: isDarkMode)
        case .tv:
            startTvAnimation(expectedDarkMode: isDarkMode)
        case .shutter:
            startShutterAnimation(expectedDarkMode: isDarkMode)
        case .blinds:
            startBlindsAnimation(expectedDarkMode: isDarkMode)
        case .curtain:
            startCurtainAnimation(expectedDarkMode: isDarkMode)
        case .drip:
            startDripAnimation(expectedDarkMode: isDarkMode)
        }
    }
```

**Step 3: Add placeholder views and methods**

Add these placeholder implementations after the wipe animation code (before `waitForDarkModeChange`):

```swift
    // MARK: - TV Animation
    @ViewBuilder
    private var tvAnimationView: some View {
        Color.black.ignoresSafeArea()
    }

    private func startTvAnimation(expectedDarkMode: Bool) {
        onBlackReached()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onComplete()
        }
    }

    // MARK: - Shutter Animation
    @ViewBuilder
    private var shutterAnimationView: some View {
        Color.black.ignoresSafeArea()
    }

    private func startShutterAnimation(expectedDarkMode: Bool) {
        onBlackReached()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onComplete()
        }
    }

    // MARK: - Blinds Animation
    @ViewBuilder
    private var blindsAnimationView: some View {
        Color.black.ignoresSafeArea()
    }

    private func startBlindsAnimation(expectedDarkMode: Bool) {
        onBlackReached()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onComplete()
        }
    }

    // MARK: - Curtain Animation
    @ViewBuilder
    private var curtainAnimationView: some View {
        Color.black.ignoresSafeArea()
    }

    private func startCurtainAnimation(expectedDarkMode: Bool) {
        onBlackReached()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onComplete()
        }
    }

    // MARK: - Drip Animation
    @ViewBuilder
    private var dripAnimationView: some View {
        Color.black.ignoresSafeArea()
    }

    private func startDripAnimation(expectedDarkMode: Bool) {
        onBlackReached()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.onComplete()
        }
    }
```

**Step 4: Build and test**

Run: `./build.sh`
Expected: Build succeeds. Run app, right-click menu shows all 7 animations. New animations just flash black.

**Step 5: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: add placeholder views for new animations"
```

---

### Task 4: Implement Old TV Animation

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift`

**Step 1: Replace tvAnimationView**

Replace the placeholder `tvAnimationView` with:

```swift
    // MARK: - TV Animation
    @ViewBuilder
    private var tvAnimationView: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // The "screen" that shrinks - white rectangle that gets masked out
            Rectangle()
                .fill(Color.white)
                .scaleEffect(x: tvScaleX, y: tvScaleY)
                .blendMode(.destinationOut)

            // CRT dot glow in center (appears when fully collapsed)
            Ellipse()
                .fill(Color.white)
                .frame(width: 8, height: 4)
                .blur(radius: 3)
                .opacity(tvDotOpacity)
        }
        .compositingGroup()
        .opacity(overlayOpacity)
    }
```

**Step 2: Replace startTvAnimation**

Replace the placeholder `startTvAnimation` with:

```swift
    private func startTvAnimation(expectedDarkMode: Bool) {
        // Reset state
        tvScaleX = 1.0
        tvScaleY = 1.0
        tvDotOpacity = 0.0
        overlayOpacity = 1.0

        // Phase 1: Squeeze vertically to a line (0.1s)
        withAnimation(.easeIn(duration: 0.1)) {
            tvScaleY = 0.005
        }

        // Phase 2: Collapse horizontally to dot + show glow (0.08s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.08)) {
                self.tvScaleX = 0.0
            }
            withAnimation(.easeIn(duration: 0.04)) {
                self.tvDotOpacity = 1.0
            }
        }

        // Phase 3: Fade dot, trigger mode change (0.05s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.05)) {
                self.tvDotOpacity = 0.0
            }
        }

        // Now fully black - trigger the toggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
            self.onBlackReached()

            // Wait for system, then reverse the animation
            self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
                // Show dot briefly
                withAnimation(.easeOut(duration: 0.03)) {
                    self.tvDotOpacity = 0.8
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    // Expand to line
                    withAnimation(.easeOut(duration: 0.06)) {
                        self.tvScaleX = 1.0
                        self.tvDotOpacity = 0.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        // Expand to full
                        withAnimation(.easeOut(duration: 0.08)) {
                            self.tvScaleY = 1.0
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            // Fade out overlay
                            withAnimation(.easeOut(duration: 0.05)) {
                                self.overlayOpacity = 0.0
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                self.onComplete()
                            }
                        }
                    }
                }
            }
        }
    }
```

**Step 3: Build and test**

Run: `./build.sh`
Expected: Build succeeds. Select "Old TV Turn-off" from menu, toggle dark mode. Screen squishes to line, then dot, then reverses.

**Step 4: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: implement Old TV turn-off animation"
```

---

### Task 5: Implement Camera Shutter Animation

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift`

**Step 1: Add ShutterBlade shape**

Add this struct before `OverlayAnimationView` (around line 74):

```swift
struct ShutterBlade: Shape {
    let bladeIndex: Int
    let totalBlades: Int
    var progress: CGFloat // 0 = open, 1 = closed

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = sqrt(rect.width * rect.width + rect.height * rect.height)

        let anglePerBlade = (2 * .pi) / CGFloat(totalBlades)
        let startAngle = CGFloat(bladeIndex) * anglePerBlade - .pi / 2
        let endAngle = startAngle + anglePerBlade

        // Blade rotates inward as progress increases
        let rotationAmount = progress * anglePerBlade * 0.6
        let adjustedStart = startAngle + rotationAmount
        let adjustedEnd = endAngle + rotationAmount

        path.move(to: center)
        path.addArc(center: center, radius: maxRadius, startAngle: .radians(adjustedStart), endAngle: .radians(adjustedEnd), clockwise: false)
        path.closeSubpath()

        return path
    }
}
```

**Step 2: Replace shutterAnimationView**

Replace the placeholder with:

```swift
    // MARK: - Shutter Animation
    @ViewBuilder
    private var shutterAnimationView: some View {
        ZStack {
            // Each blade
            ForEach(0..<6, id: \.self) { index in
                ShutterBlade(bladeIndex: index, totalBlades: 6, progress: shutterProgress)
                    .fill(Color.black)
            }
        }
        .opacity(overlayOpacity)
    }
```

**Step 3: Replace startShutterAnimation**

```swift
    private func startShutterAnimation(expectedDarkMode: Bool) {
        // Reset state
        shutterProgress = 0.0
        overlayOpacity = 1.0

        // Close shutter
        withAnimation(.easeInOut(duration: 0.2)) {
            shutterProgress = 1.0
        }

        // Fully closed - trigger toggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.onBlackReached()

            self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
                // Open shutter
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.shutterProgress = 0.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.05)) {
                        self.overlayOpacity = 0.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.onComplete()
                    }
                }
            }
        }
    }
```

**Step 4: Build and test**

Run: `./build.sh`
Expected: Build succeeds. "Camera Shutter" shows 6 blades rotating closed.

**Step 5: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: implement Camera Shutter animation"
```

---

### Task 6: Implement Venetian Blinds Animation

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift`

**Step 1: Replace blindsAnimationView**

```swift
    // MARK: - Blinds Animation
    @ViewBuilder
    private var blindsAnimationView: some View {
        let blindCount = 14
        let blindHeight = screenSize.height / CGFloat(blindCount)

        ZStack {
            ForEach(0..<blindCount, id: \.self) { index in
                let isFromLeft = index % 2 == 0
                let staggerDelay = CGFloat(index) * 0.02
                let adjustedProgress = max(0, min(1, (blindsProgress - staggerDelay) / (1 - staggerDelay * CGFloat(blindCount - 1) / CGFloat(blindCount))))

                Rectangle()
                    .fill(Color.black)
                    .frame(width: screenSize.width, height: blindHeight + 1) // +1 to avoid gaps
                    .offset(
                        x: isFromLeft
                            ? -screenSize.width * (1 - adjustedProgress)
                            : screenSize.width * (1 - adjustedProgress),
                        y: CGFloat(index) * blindHeight - screenSize.height / 2 + blindHeight / 2
                    )
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .opacity(overlayOpacity)
    }
```

**Step 2: Replace startBlindsAnimation**

```swift
    private func startBlindsAnimation(expectedDarkMode: Bool) {
        // Reset state
        blindsProgress = 0.0
        overlayOpacity = 1.0

        // Close blinds
        withAnimation(.easeInOut(duration: 0.25)) {
            blindsProgress = 1.0
        }

        // Fully closed - trigger toggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.onBlackReached()

            self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
                // Open blinds (reverse direction)
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.blindsProgress = 0.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeOut(duration: 0.05)) {
                        self.overlayOpacity = 0.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.onComplete()
                    }
                }
            }
        }
    }
```

**Step 3: Build and test**

Run: `./build.sh`
Expected: Build succeeds. "Venetian Blinds" shows horizontal bars sliding in from alternating sides.

**Step 4: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: implement Venetian Blinds animation"
```

---

### Task 7: Implement Curtain Animation

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift`

**Step 1: Replace curtainAnimationView**

```swift
    // MARK: - Curtain Animation
    @ViewBuilder
    private var curtainAnimationView: some View {
        ZStack {
            // Left curtain
            Rectangle()
                .fill(Color.black)
                .frame(width: screenSize.width / 2 + 2) // +2 for overlap
                .offset(x: -screenSize.width / 4 - screenSize.width / 2 * (1 - curtainProgress))

            // Right curtain
            Rectangle()
                .fill(Color.black)
                .frame(width: screenSize.width / 2 + 2)
                .offset(x: screenSize.width / 4 + screenSize.width / 2 * (1 - curtainProgress))
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .opacity(overlayOpacity)
    }
```

**Step 2: Replace startCurtainAnimation**

```swift
    private func startCurtainAnimation(expectedDarkMode: Bool) {
        // Reset state
        curtainProgress = 0.0
        overlayOpacity = 1.0

        // Close curtains
        withAnimation(.easeInOut(duration: 0.2)) {
            curtainProgress = 1.0
        }

        // Fully closed - trigger toggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.onBlackReached()

            self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
                // Open curtains
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.curtainProgress = 0.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeOut(duration: 0.05)) {
                        self.overlayOpacity = 0.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.onComplete()
                    }
                }
            }
        }
    }
```

**Step 3: Build and test**

Run: `./build.sh`
Expected: Build succeeds. "Curtain Call" shows two panels sliding from edges to center.

**Step 4: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: implement Curtain Call animation"
```

---

### Task 8: Implement Drip Animation

**Files:**
- Modify: `NiteLite/OverlayAnimationWindow.swift`

**Step 1: Add DripEdge shape**

Add this struct near `ShutterBlade`:

```swift
struct DripEdge: Shape {
    var progress: CGFloat // 0 = above screen, 1 = covering screen
    let dripCount: Int
    let screenHeight: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // The base Y position moves down as progress increases
        let baseY = -screenHeight + (screenHeight * 2 * progress)

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: baseY))

        // Create wavy bottom edge with drips
        let dripWidth = rect.width / CGFloat(dripCount)
        for i in 0..<dripCount {
            let x = CGFloat(i) * dripWidth
            let nextX = CGFloat(i + 1) * dripWidth
            let midX = x + dripWidth / 2

            // Vary drip depth based on position (pseudo-random but deterministic)
            let dripDepth = dripWidth * 0.5 * (1 + sin(CGFloat(i) * 1.3)) * 0.5

            path.addQuadCurve(
                to: CGPoint(x: nextX, y: baseY),
                control: CGPoint(x: midX, y: baseY + dripDepth)
            )
        }

        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.closeSubpath()

        return path
    }
}
```

**Step 2: Replace dripAnimationView**

```swift
    // MARK: - Drip Animation
    @ViewBuilder
    private var dripAnimationView: some View {
        DripEdge(progress: dripProgress, dripCount: 20, screenHeight: screenSize.height)
            .fill(Color.black)
            .frame(width: screenSize.width, height: screenSize.height)
            .opacity(overlayOpacity)
    }
```

**Step 3: Replace startDripAnimation**

```swift
    private func startDripAnimation(expectedDarkMode: Bool) {
        // Reset state
        dripProgress = 0.0
        overlayOpacity = 1.0

        // Drip down to cover screen
        withAnimation(.easeIn(duration: 0.25)) {
            dripProgress = 1.0
        }

        // Fully covered - trigger toggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.onBlackReached()

            self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
                // Continue dripping off bottom
                withAnimation(.easeOut(duration: 0.25)) {
                    self.dripProgress = 2.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeOut(duration: 0.05)) {
                        self.overlayOpacity = 0.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.onComplete()
                    }
                }
            }
        }
    }
```

**Step 4: Build and test**

Run: `./build.sh`
Expected: Build succeeds. "Drip" shows black dripping from top with wavy edge.

**Step 5: Commit**

```bash
git add NiteLite/OverlayAnimationWindow.swift
git commit -m "feat: implement Drip animation"
```

---

### Task 9: Final Testing and Polish

**Step 1: Test all animations**

Run app and test each animation in both directions (light→dark and dark→light):
- Classic Film Iris
- Left-Right Wipe
- Old TV Turn-off
- Camera Shutter
- Venetian Blinds
- Curtain Call
- Drip

**Step 2: Adjust timing if needed**

If any animation feels too slow or fast, adjust the duration values.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete implementation of five new animations

Adds Old TV Turn-off, Camera Shutter, Venetian Blinds, Curtain Call,
and Drip animations to NiteLite's dark mode toggle."
```
