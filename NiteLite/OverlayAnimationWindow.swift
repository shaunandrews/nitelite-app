import Cocoa
import SwiftUI

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
    
    func showAnimation(isDarkMode: Bool, screen: NSScreen, onBlackReached: @escaping () -> Void, completion: @escaping () -> Void) {
        // Set window to cover the specific screen
        self.setFrame(screen.frame, display: true)
        
        // Create and set the animation view with screen size
        let animationView = OverlayAnimationView(
            isDarkMode: isDarkMode,
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
    let onBlackReached: () -> Void
    let onComplete: () -> Void
    let screenSize: CGSize
    
    @State private var irisRadius: CGFloat = 0.0
    @State private var fadeOpacity: Double = 0.0
    @State private var overlayOpacity: Double = 1.0
    
    var body: some View {
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
                        .frame(width: irisRadius * 2, height: irisRadius * 2)
                        .position(x: screenSize.width / 2, y: screenSize.height / 2)
                        .blendMode(.destinationOut)
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
                                    .frame(width: irisRadius * 2, height: irisRadius * 2)
                                    .position(x: screenSize.width / 2, y: screenSize.height / 2)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        )
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    func startAnimation() {
        if isDarkMode {
            startDarkModeAnimation()
        } else {
            startLightModeAnimation()
        }
    }
    
    private func startDarkModeAnimation() {
        let maxRadius = sqrt(screenSize.width * screenSize.width + screenSize.height * screenSize.height) / 2
        irisRadius = maxRadius
        overlayOpacity = 1.0
        
        // Iris closes over 1.2 seconds
        withAnimation(.easeInOut(duration: 1.2)) {
            irisRadius = 0
        }
        
        // After iris closes, hold black and toggle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.onBlackReached()
            
            // Hold black briefly, then fade out the entire overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Fade the entire overlay away to reveal dark mode desktop
                withAnimation(.easeOut(duration: 0.4)) {
                    self.overlayOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.onComplete()
                }
            }
        }
    }
    
    private func startLightModeAnimation() {
        let maxRadius = sqrt(screenSize.width * screenSize.width + screenSize.height * screenSize.height) / 2
        
        // Start with no black overlay and iris closed
        fadeOpacity = 0.0
        irisRadius = 0.0
        
        // 1. Fade to black over 400ms
        withAnimation(.easeOut(duration: 0.4)) {
            fadeOpacity = 1.0
        }
        
        // 2. After fade, toggle dark mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.onBlackReached()
            
            // 3. Brief hold, then iris opens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 1.2)) {
                    self.irisRadius = maxRadius
                }
                
                // 4. Complete when iris fully opens
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.onComplete()
                }
            }
        }
    }
}


class OverlayAnimationManager {
    private var overlayWindows: [OverlayAnimationWindow] = []
    
    func showTransitionAnimation(isDarkMode: Bool, onBlackReached: @escaping () -> Void, completion: @escaping () -> Void) {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.performAnimation(isDarkMode: isDarkMode, onBlackReached: onBlackReached, completion: completion)
        }
    }
    
    private func performAnimation(isDarkMode: Bool, onBlackReached: @escaping () -> Void, completion: @escaping () -> Void) {
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
            overlayWindow.showAnimation(isDarkMode: isDarkMode, screen: screen, onBlackReached: {
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