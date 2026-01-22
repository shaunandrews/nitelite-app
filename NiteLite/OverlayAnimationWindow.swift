import Cocoa
import SwiftUI

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

    // Shutter animation state
    @State private var shutterProgress: CGFloat = 0.0

    // Blinds animation state
    @State private var blindsProgress: CGFloat = 0.0

    // Curtain animation state
    @State private var curtainProgress: CGFloat = 0.0

    // Drip animation state
    @State private var dripProgress: CGFloat = 0.0

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