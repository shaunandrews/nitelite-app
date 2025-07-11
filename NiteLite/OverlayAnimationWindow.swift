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
    
    // Optimized timing for smooth animation
    private let irisAnimationDuration: Double = 0.5
    private let holdDuration: Double = 0.1
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Iris cutout - simplified approach
            Circle()
                .fill(Color.white)
                .frame(width: irisRadius * 2, height: irisRadius * 2)
                .position(x: screenSize.width / 2, y: screenSize.height / 2)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .onAppear {
            startIrisAnimation()
        }
    }
    
    private func startIrisAnimation() {
        let maxRadius = sqrt(screenSize.width * screenSize.width + screenSize.height * screenSize.height) / 2
        
        if isDarkMode {
            // Switching TO dark mode: iris closes (hole shrinks, revealing more black)
            print("Starting iris CLOSE animation - radius from \(maxRadius) to 0")
            irisRadius = maxRadius
            
            withAnimation(.easeInOut(duration: irisAnimationDuration)) {
                irisRadius = 0.0 // Close completely to no hole (all black)
            }
        } else {
            // Switching TO light mode: iris opens (hole expands, revealing content behind)
            print("Starting iris OPEN animation - radius from 0 to \(maxRadius)")
            irisRadius = 0.0 // Start with no hole (all black)
            
            withAnimation(.easeInOut(duration: irisAnimationDuration)) {
                irisRadius = maxRadius // Open hole to reveal everything
            }
        }
        
        // Complete after animation + hold
        DispatchQueue.main.asyncAfter(deadline: .now() + irisAnimationDuration + holdDuration) {
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
