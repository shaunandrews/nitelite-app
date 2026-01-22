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

/// A camera aperture blade that pivots from its outer edge anchor point.
/// Each blade is a curved trapezoidal shape that rotates inward to close the aperture.
struct ApertureBlade: Shape {
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
        let maxRadius = sqrt(rect.width * rect.width + rect.height * rect.height) / 2 * 1.3

        // Each blade is positioned around the circle
        let anglePerBlade = (2 * .pi) / CGFloat(totalBlades)
        let baseAngle = CGFloat(bladeIndex) * anglePerBlade - .pi / 2

        // The pivot point is on the outer edge of the aperture ring
        let pivotRadius = maxRadius * 0.95
        let pivotAngle = baseAngle
        let pivotPoint = CGPoint(
            x: center.x + cos(pivotAngle) * pivotRadius,
            y: center.y + sin(pivotAngle) * pivotRadius
        )

        // Blade rotation: when open (progress=0), blade points outward
        // When closed (progress=1), blade rotates to cover the center
        let maxRotation: CGFloat = .pi * 0.42 // How much the blade rotates when closing
        let bladeRotation = baseAngle + .pi + (progress * maxRotation)

        // Blade dimensions
        let bladeLength = maxRadius * 1.1
        let bladeWidthBase = maxRadius * 0.55 // Width at pivot end
        let bladeWidthTip = maxRadius * 0.25  // Width at inner end

        // Calculate blade corners relative to pivot, then rotate
        // The blade extends from the pivot toward the center
        let tipDistance = bladeLength

        // Four corners of the blade (roughly trapezoidal with curved edges)
        // Corner 1: base left (at pivot)
        let corner1Offset = CGPoint(
            x: cos(bladeRotation + .pi/2) * bladeWidthBase/2,
            y: sin(bladeRotation + .pi/2) * bladeWidthBase/2
        )
        let corner1 = CGPoint(x: pivotPoint.x + corner1Offset.x, y: pivotPoint.y + corner1Offset.y)

        // Corner 2: base right (at pivot)
        let corner2Offset = CGPoint(
            x: cos(bladeRotation - .pi/2) * bladeWidthBase/2,
            y: sin(bladeRotation - .pi/2) * bladeWidthBase/2
        )
        let corner2 = CGPoint(x: pivotPoint.x + corner2Offset.x, y: pivotPoint.y + corner2Offset.y)

        // Tip center (extends toward center)
        let tipCenter = CGPoint(
            x: pivotPoint.x + cos(bladeRotation) * tipDistance,
            y: pivotPoint.y + sin(bladeRotation) * tipDistance
        )

        // Corner 3: tip right
        let corner3Offset = CGPoint(
            x: cos(bladeRotation - .pi/2) * bladeWidthTip/2,
            y: sin(bladeRotation - .pi/2) * bladeWidthTip/2
        )
        let corner3 = CGPoint(x: tipCenter.x + corner3Offset.x, y: tipCenter.y + corner3Offset.y)

        // Corner 4: tip left
        let corner4Offset = CGPoint(
            x: cos(bladeRotation + .pi/2) * bladeWidthTip/2,
            y: sin(bladeRotation + .pi/2) * bladeWidthTip/2
        )
        let corner4 = CGPoint(x: tipCenter.x + corner4Offset.x, y: tipCenter.y + corner4Offset.y)

        // Draw the blade with slightly curved edges for realism
        path.move(to: corner1)

        // Left edge (from base to tip) - slight curve
        let leftMid = CGPoint(
            x: (corner1.x + corner4.x) / 2 + cos(bladeRotation + .pi/2) * bladeLength * 0.03,
            y: (corner1.y + corner4.y) / 2 + sin(bladeRotation + .pi/2) * bladeLength * 0.03
        )
        path.addQuadCurve(to: corner4, control: leftMid)

        // Tip edge
        path.addLine(to: corner3)

        // Right edge (from tip to base) - slight curve
        let rightMid = CGPoint(
            x: (corner3.x + corner2.x) / 2 + cos(bladeRotation - .pi/2) * bladeLength * 0.03,
            y: (corner3.y + corner2.y) / 2 + sin(bladeRotation - .pi/2) * bladeLength * 0.03
        )
        path.addQuadCurve(to: corner2, control: rightMid)

        // Base edge
        path.addLine(to: corner1)
        path.closeSubpath()

        return path
    }
}

/// The aperture opening shape - a shrinking polygon that represents the hole in the center
struct ApertureOpening: Shape {
    let bladeCount: Int
    var progress: CGFloat // 0 = fully open, 1 = fully closed

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = sqrt(rect.width * rect.width + rect.height * rect.height) / 2

        // The opening shrinks as progress increases
        // At progress=0, the opening is large; at progress=1, it's nearly zero
        let openingRadius = maxRadius * 0.85 * (1 - progress)

        guard openingRadius > 1 else {
            // When fully closed, just return empty path
            return path
        }

        // Create a polygon with bladeCount sides, slightly rotated based on progress
        // This creates the characteristic aperture rotation effect
        let rotationOffset = progress * .pi / CGFloat(bladeCount) * 0.5

        let anglePerVertex = (2 * .pi) / CGFloat(bladeCount)

        for i in 0..<bladeCount {
            let angle = CGFloat(i) * anglePerVertex - .pi/2 + rotationOffset
            let point = CGPoint(
                x: center.x + cos(angle) * openingRadius,
                y: center.y + sin(angle) * openingRadius
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

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

    // MARK: - Shutter Animation
    @ViewBuilder
    private var shutterAnimationView: some View {
        let bladeCount = 8

        ZStack {
            // Black background (visible through the aperture opening)
            Color.black
                .ignoresSafeArea()

            // The aperture opening (transparent hole) - uses destination out to punch through
            ApertureOpening(bladeCount: bladeCount, progress: shutterProgress)
                .fill(Color.white)
                .blendMode(.destinationOut)

            // Draw blade outlines/edges for visual definition
            // This creates subtle visible blade edges around the opening
            ForEach(0..<bladeCount, id: \.self) { index in
                ApertureBlade(bladeIndex: index, totalBlades: bladeCount, progress: shutterProgress)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            }
        }
        .compositingGroup()
        .opacity(overlayOpacity)
    }

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

    // MARK: - Drip Animation
    @ViewBuilder
    private var dripAnimationView: some View {
        DripEdge(progress: dripProgress, dripCount: 20, screenHeight: screenSize.height)
            .fill(Color.black)
            .frame(width: screenSize.width, height: screenSize.height)
            .opacity(overlayOpacity)
    }

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