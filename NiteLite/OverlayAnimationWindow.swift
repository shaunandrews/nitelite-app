import Cocoa
import SwiftUI

enum AnimationType: String, CaseIterable {
    case iris = "iris"
    case wipe = "wipe"
    case tv = "tv"
    case blinds = "blinds"
    case curtain = "curtain"

    var displayName: String {
        switch self {
        case .iris:
            return "Classic Film Iris"
        case .wipe:
            return "Left-Right Wipe"
        case .tv:
            return "Old TV Turn-off"
        case .blinds:
            return "Venetian Blinds"
        case .curtain:
            return "Curtain Call"
        }
    }
}

class AnimationPreferences {
    static let shared = AnimationPreferences()
    private let userDefaults = UserDefaults.standard
    private let animationTypeKey = "NiteLite_AnimationType"
    
    var animationType: AnimationType {
        get {
            let storedValue = userDefaults.string(forKey: animationTypeKey) ?? AnimationType.iris.rawValue
            return AnimationType(rawValue: storedValue) ?? .iris
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: animationTypeKey)
        }
    }
}

class OverlayAnimationWindow: NSWindow {
    private var animationView: NSHostingView<OverlayAnimationView>?
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: backingStoreType, defer: flag)
        
        // Configure window properties
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
    }
    
    func showAnimation(isDarkMode: Bool, screen: NSScreen, animationType: AnimationType, onBlackReached: @escaping () -> Void, completion: @escaping () -> Void) {
        // Set window to cover the specific screen
        self.setFrame(screen.frame, display: true)
        
        // Create and set the animation view with screen size
        let animationView = OverlayAnimationView(
            isDarkMode: isDarkMode,
            animationType: animationType,
            onBlackReached: onBlackReached,
            onComplete: completion,
            screenSize: screen.frame.size
        )
        
        let hostingView = NSHostingView(rootView: animationView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        
        self.contentView = hostingView
        self.animationView = hostingView
        
        // Show the window and start animation
        self.makeKeyAndOrderFront(nil)
    }
}

/// A curtain shape with wavy leading edge to simulate fabric folds
/// The waves animate based on progress to create cloth-like motion
struct CurtainShape: Shape {
    var progress: CGFloat // 0 = off-screen, 1 = at center
    var wavePhase: CGFloat // Animates to create rippling effect
    let isLeftCurtain: Bool
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    // Number of wave peaks on the leading edge
    let waveCount: Int = 8
    // Amplitude of the waves (how deep the folds are)
    let waveAmplitude: CGFloat = 15

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, wavePhase) }
        set {
            progress = newValue.first
            wavePhase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let curtainWidth = screenWidth / 2 + 20 // Extra width for overlap

        // Calculate the curtain's position based on progress
        // At progress 0, curtain is fully off-screen
        // At progress 1, curtain's leading edge is at center
        let leadingEdgeX: CGFloat
        if isLeftCurtain {
            // Left curtain: leading edge moves from left edge toward center
            leadingEdgeX = -curtainWidth + (curtainWidth + screenWidth / 2) * progress
        } else {
            // Right curtain: leading edge moves from right edge toward center
            leadingEdgeX = screenWidth + curtainWidth - (curtainWidth + screenWidth / 2) * progress
        }

        // The trailing edge (attached to the "curtain rod")
        let trailingEdgeX = isLeftCurtain ? leadingEdgeX - curtainWidth : leadingEdgeX + curtainWidth

        // Start from top corner (trailing edge side), then top edge to leading edge
        path.move(to: CGPoint(x: trailingEdgeX, y: 0))
        path.addLine(to: CGPoint(x: leadingEdgeX, y: 0))

        // Create wavy leading edge going down
        // The waves simulate hanging fabric folds
        let segmentHeight = screenHeight / CGFloat(waveCount)

        for i in 0..<waveCount {
            let startY = CGFloat(i) * segmentHeight
            let endY = CGFloat(i + 1) * segmentHeight
            let midY = (startY + endY) / 2

            // Calculate wave offset with phase animation
            // The phase creates the rippling motion as curtain moves
            let phaseOffset = wavePhase + CGFloat(i) * 0.5
            let waveOffset = sin(phaseOffset) * waveAmplitude

            // Vary wave depth based on position for more natural look
            let depthVariation = 1.0 + 0.3 * sin(CGFloat(i) * 1.7)
            let adjustedWaveOffset = waveOffset * depthVariation

            // Direction of wave bulge (into the curtain for left, out for right)
            let bulgeDirection: CGFloat = isLeftCurtain ? -1 : 1

            // Control point for the curve (creates the wave bulge)
            let controlX = leadingEdgeX + adjustedWaveOffset * bulgeDirection

            path.addQuadCurve(
                to: CGPoint(x: leadingEdgeX, y: endY),
                control: CGPoint(x: controlX, y: midY)
            )
        }

        // Bottom edge back to trailing side
        path.addLine(to: CGPoint(x: trailingEdgeX, y: screenHeight))

        // Close the path (trailing edge going up)
        path.closeSubpath()

        return path
    }
}

struct OverlayAnimationView: View {
    let isDarkMode: Bool
    let animationType: AnimationType
    let onBlackReached: () -> Void
    let onComplete: () -> Void
    let screenSize: CGSize
    
    @State private var irisRadius: CGFloat = 0.0
    @State private var fadeOpacity: Double = 0.0
    @State private var overlayOpacity: Double = 1.0
    @State private var wipeProgress: CGFloat = 0.0

    // TV animation state
    @State private var tvScaleX: CGFloat = 1.0
    @State private var tvScaleY: CGFloat = 1.0
    @State private var tvDotOpacity: Double = 0.0

    // Blinds animation state
    @State private var blindsProgress: CGFloat = 0.0

    // Curtain animation state
    @State private var curtainProgress: CGFloat = 0.0
    @State private var curtainWavePhase: CGFloat = 0.0

    var body: some View {
        Group {
            switch animationType {
            case .iris:
                irisAnimationView
            case .wipe:
                wipeAnimationView
            case .tv:
                tvAnimationView
            case .blinds:
                blindsAnimationView
            case .curtain:
                curtainAnimationView
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    @ViewBuilder
    private var irisAnimationView: some View {
        Group {
            if isDarkMode {
                // Dark mode: Traditional iris close with black background that can fade away
                ZStack {
                    // Single black background with iris cutout
                    Color.black
                        .ignoresSafeArea()
                    
                    // White circle that shrinks (creates iris effect)
                    Circle()
                        .fill(Color.white)
                        .frame(width: irisRadius > 0 ? irisRadius * 2 : 0, height: irisRadius > 0 ? irisRadius * 2 : 0)
                        .position(x: screenSize.width / 2, y: screenSize.height / 2)
                        .blendMode(.destinationOut)
                        .opacity(irisRadius > 0 ? 1.0 : 0.0)  // Hide when radius goes negative
                }
                .compositingGroup()
                .opacity(overlayOpacity)
            } else {
                // Light mode: Fade to black, then iris opens to reveal
                ZStack {
                    // Black overlay that fades in, then has hole punched through it
                    Color.black
                        .ignoresSafeArea()
                        .opacity(fadeOpacity)
                        .mask(
                            // Create inverse of circle - everything BUT the circle
                            ZStack {
                                Rectangle()
                                    .fill(Color.white)
                                
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: irisRadius > 0 ? irisRadius * 2 : 0, height: irisRadius > 0 ? irisRadius * 2 : 0)
                                    .position(x: screenSize.width / 2, y: screenSize.height / 2)
                                    .blendMode(.destinationOut)
                                    .opacity(irisRadius > 0 ? 1.0 : 0.0)  // Hide when radius is zero
                            }
                            .compositingGroup()
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    private var wipeAnimationView: some View {
        // Black overlay with gradient wipe effect
        Color.black
            .ignoresSafeArea()
            .opacity(overlayOpacity)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white, location: 0.05),
                                .init(color: .white, location: 0.95),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: screenSize.width * 2.0, height: screenSize.height)
                    .offset(x: -screenSize.width * 1.0 + (screenSize.width * 2.0 * wipeProgress), y: 0)
            )
    }
    
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
        case .blinds:
            startBlindsAnimation(expectedDarkMode: isDarkMode)
        case .curtain:
            startCurtainAnimation(expectedDarkMode: isDarkMode)
        }
    }
    
    // MARK: - Iris Animation Methods
    private func startIrisDarkModeAnimation() {
        let maxRadius = sqrt(screenSize.width * screenSize.width + screenSize.height * screenSize.height) / 2
        irisRadius = maxRadius
        overlayOpacity = 1.0
        
        // Faster iris close - 0.15 seconds
        withAnimation(.easeInOut(duration: 0.15)) {
            irisRadius = 0.0
        }
        
        // Trigger dark mode after iris closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.onBlackReached()
            
            // Wait for system to switch, then quick fade out
            self.waitForDarkModeChange(expectedDarkMode: true) {
                withAnimation(.easeOut(duration: 0.08)) {
                    self.overlayOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    self.onComplete()
                }
            }
        }
    }
    
    private func startIrisLightModeAnimation() {
        let maxRadius = sqrt(screenSize.width * screenSize.width + screenSize.height * screenSize.height) / 2
        
        // Start with everything closed
        fadeOpacity = 0.0
        irisRadius = 0.0
        
        // Faster fade to black
        withAnimation(.easeOut(duration: 0.12)) {
            fadeOpacity = 1.0
        }
        
        // Trigger light mode change when fully black
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.onBlackReached()
            
            // Wait for system to switch, then open iris faster
            self.waitForDarkModeChange(expectedDarkMode: false) {
                withAnimation(.easeOut(duration: 0.15)) {
                    self.irisRadius = maxRadius
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.onComplete()
                }
            }
        }
    }
    
    // MARK: - Wipe Animation Methods
    private func startWipeAnimation(expectedDarkMode: Bool) {
        // Start with wipe completely off-screen to the left
        wipeProgress = 0.0
        overlayOpacity = 1.0

        // Much faster wipe to full coverage
        withAnimation(.easeInOut(duration: 0.2)) {
            wipeProgress = 0.6  // Screen fully covered
        }

        // Trigger mode change when screen is fully covered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.onBlackReached()

            // Wait for system appearance change, then quick completion
            self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.wipeProgress = 1.1  // Complete the wipe
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.onComplete()
                }
            }
        }
    }

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

    // MARK: - Curtain Animation
    @ViewBuilder
    private var curtainAnimationView: some View {
        ZStack {
            // Left curtain with cloth physics
            CurtainShape(
                progress: curtainProgress,
                wavePhase: curtainWavePhase,
                isLeftCurtain: true,
                screenWidth: screenSize.width,
                screenHeight: screenSize.height
            )
            .fill(Color.black)

            // Right curtain with cloth physics
            CurtainShape(
                progress: curtainProgress,
                wavePhase: curtainWavePhase + .pi, // Offset phase for variety
                isLeftCurtain: false,
                screenWidth: screenSize.width,
                screenHeight: screenSize.height
            )
            .fill(Color.black)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .opacity(overlayOpacity)
    }

    private func startCurtainAnimation(expectedDarkMode: Bool) {
        // Reset state
        curtainProgress = 0.0
        curtainWavePhase = 0.0
        overlayOpacity = 1.0

        // Close curtains with spring animation - slow and dramatic
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75, blendDuration: 0)) {
            curtainProgress = 1.0
        }

        // Animate wave phase to create rippling cloth effect during close
        withAnimation(.easeOut(duration: 0.8)) {
            curtainWavePhase = .pi * 2 // One full ripple cycle
        }

        // Fully closed - trigger toggle (timing accounts for spring settle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.onBlackReached()

            self.waitForDarkModeChange(expectedDarkMode: expectedDarkMode) {
                // Open curtains with spring for dramatic reveal
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                    self.curtainProgress = 0.0
                }

                // Continue wave animation during open
                withAnimation(.easeIn(duration: 0.7)) {
                    self.curtainWavePhase = .pi * 4 // Another cycle of ripples
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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

    private func waitForDarkModeChange(expectedDarkMode: Bool, completion: @escaping () -> Void) {
        let checkAppearance = {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark == expectedDarkMode
        }

        // If already in expected mode, complete immediately
        if checkAppearance() {
            completion()
            return
        }

        // Fast polling with shorter timeout - system typically responds in ~50-100ms
        var attempts = 0
        let maxAttempts = 15 // 240ms timeout at 16ms intervals (was 640ms)

        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            attempts += 1
            if checkAppearance() || attempts >= maxAttempts {
                timer.invalidate()
                completion()
            }
        }
    }
    
}


class OverlayAnimationManager {
    private var overlayWindows: [OverlayAnimationWindow] = []
    
    func showTransitionAnimation(isDarkMode: Bool, onBlackReached: @escaping () -> Void, completion: @escaping () -> Void) {
        // Called from UI event handlers, already on main thread
        let animationType = AnimationPreferences.shared.animationType
        performAnimation(isDarkMode: isDarkMode, animationType: animationType, onBlackReached: onBlackReached, completion: completion)
    }
    
    private func performAnimation(isDarkMode: Bool, animationType: AnimationType, onBlackReached: @escaping () -> Void, completion: @escaping () -> Void) {
        // Clean up any existing windows first
        cleanupOverlays()
        
        // Get all screens for multi-display support
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completion()
            return
        }
        
        // Track completions from all screens
        let totalScreens = screens.count
        var completedScreens = 0
        var blackReachedCallbackFired = false
        
        // Create overlay windows for all screens
        for screen in screens {
            let overlayWindow = OverlayAnimationWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            overlayWindows.append(overlayWindow)
            
            // Show animation with completion tracking
            overlayWindow.showAnimation(isDarkMode: isDarkMode, screen: screen, animationType: animationType, onBlackReached: {
                // Only fire the callback once for all screens
                if !blackReachedCallbackFired {
                    blackReachedCallbackFired = true
                    onBlackReached()
                }
            }, completion: { [weak self] in
                DispatchQueue.main.async {
                    completedScreens += 1
                    if completedScreens == totalScreens {
                        self?.cleanupOverlays()
                        completion()
                    }
                }
            })
        }
    }
    
    private func cleanupOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }
}