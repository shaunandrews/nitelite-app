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
    
    func showAnimation(isDarkMode: Bool, screen: NSScreen, completion: @escaping () -> Void) {
        // Set window to cover the specific screen
        self.setFrame(screen.frame, display: true)
        
        // Create and set the animation view with screen size
        let animationView = OverlayAnimationView(
            isDarkMode: isDarkMode,
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
    let onComplete: () -> Void
    let screenSize: CGSize
    
    @State private var irisRadius: CGFloat = 0.0
    @State private var animationTimer: Timer?
    
    // Slowed down timing to see the animation better
    private let irisAnimationDuration: Double = 2.0
    private let holdDuration: Double = 0.2
    private let targetFrameRate: Double = 60.0 // 60 FPS
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Iris cutout - optimized for smooth animation
            Circle()
                .fill(Color.white)
                .frame(width: irisRadius * 2, height: irisRadius * 2)
                .position(x: screenSize.width / 2, y: screenSize.height / 2)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .drawingGroup() // Force GPU acceleration for smoother animation
        .onAppear {
            startIrisAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
    
    private func startIrisAnimation() {
        let maxRadius = sqrt(screenSize.width * screenSize.width + screenSize.height * screenSize.height) / 2
        
        // Calculate animation parameters
        let frameInterval = 1.0 / targetFrameRate
        let totalFrames = Int(irisAnimationDuration * targetFrameRate)
        
        var currentFrame = 0
        _ = CACurrentMediaTime() // Track start time for debugging if needed
        
        if isDarkMode {
            // Switching TO dark mode: iris closes (hole shrinks, revealing more black)
            print("Starting iris CLOSE animation - radius from \(maxRadius) to 0")
            irisRadius = maxRadius
            
            // Custom timer-based animation for smooth frame rate
            animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { timer in
                currentFrame += 1
                let progress = Double(currentFrame) / Double(totalFrames)
                
                if progress >= 1.0 {
                    irisRadius = 0.0
                    timer.invalidate()
                    completeAnimation()
                } else {
                    // Linear interpolation from maxRadius to 0
                    irisRadius = maxRadius * (1.0 - progress)
                }
            }
        } else {
            // Switching TO light mode: iris opens (hole expands, revealing content behind)
            print("Starting iris OPEN animation - radius from 0 to \(maxRadius)")
            irisRadius = 0.0
            
            // Custom timer-based animation for smooth frame rate
            animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { timer in
                currentFrame += 1
                let progress = Double(currentFrame) / Double(totalFrames)
                
                if progress >= 1.0 {
                    irisRadius = maxRadius
                    timer.invalidate()
                    completeAnimation()
                } else {
                    // Linear interpolation from 0 to maxRadius
                    irisRadius = maxRadius * progress
                }
            }
        }
    }
    
    private func completeAnimation() {
        // Hold briefly then complete
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
            print("Iris animation completed")
            onComplete()
        }
    }
}

class OverlayAnimationManager {
    private var overlayWindows: [OverlayAnimationWindow] = []
    
    func showTransitionAnimation(isDarkMode: Bool, completion: @escaping () -> Void) {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.performAnimation(isDarkMode: isDarkMode, completion: completion)
        }
    }
    
    private func performAnimation(isDarkMode: Bool, completion: @escaping () -> Void) {
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
            overlayWindow.showAnimation(isDarkMode: isDarkMode, screen: screen) { [weak self] in
                DispatchQueue.main.async {
                    completedScreens += 1
                    if completedScreens == totalScreens {
                        self?.cleanupOverlays()
                        completion()
                    }
                }
            }
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
