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
    
    func showAnimation(isDarkMode: Bool, completion: @escaping () -> Void) {
        // Set window to cover all screens
        if let screen = NSScreen.main {
            self.setFrame(screen.frame, display: true)
        }
        
        // Create and set the animation view
        let animationView = OverlayAnimationView(isDarkMode: isDarkMode) {
            completion()
        }
        
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
    
    @State private var irisScale: CGFloat = 0.0
    
    // Classic film iris timing
    private let irisAnimationDuration: Double = 0.4
    private let holdDuration: Double = 0.1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()
                
                // The iris cutout - this creates the "hole" in the black overlay
                Circle()
                    .frame(width: maxDimension(for: geometry.size), 
                           height: maxDimension(for: geometry.size))
                    .scaleEffect(irisScale)
                    .position(x: geometry.size.width / 2, 
                             y: geometry.size.height / 2)
                    .blendMode(.destinationOut)
            }
            .compositingGroup() // This is crucial for blend mode to work
            .onAppear {
                startIrisAnimation()
            }
        }
    }
    
    private func maxDimension(for size: CGSize) -> CGFloat {
        // Calculate the diagonal to ensure the iris covers the entire screen
        return sqrt(size.width * size.width + size.height * size.height)
    }
    
    private func startIrisAnimation() {
        if isDarkMode {
            // Switching TO dark mode: iris closes (hole shrinks, revealing more black)
            irisScale = 1.2 // Start with hole larger than screen (fully open)
            
            withAnimation(.easeInOut(duration: irisAnimationDuration)) {
                irisScale = 0.0 // Close to no hole (all black)
            }
        } else {
            // Switching TO light mode: iris opens (hole expands, revealing content behind)
            irisScale = 0.0 // Start with no hole (all black)
            
            withAnimation(.easeInOut(duration: irisAnimationDuration)) {
                irisScale = 1.2 // Open hole larger than screen (reveal everything)
            }
        }
        
        // Complete after animation + hold
        DispatchQueue.main.asyncAfter(deadline: .now() + irisAnimationDuration + holdDuration) {
            onComplete()
        }
    }
}

class OverlayAnimationManager {
    private var overlayWindow: OverlayAnimationWindow?
    
    func showTransitionAnimation(isDarkMode: Bool, completion: @escaping () -> Void) {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.performAnimation(isDarkMode: isDarkMode, completion: completion)
        }
    }
    
    private func performAnimation(isDarkMode: Bool, completion: @escaping () -> Void) {
        // Clean up any existing window first
        cleanupOverlay()
        
        // Create new overlay window for the main screen
        guard let screen = NSScreen.main else {
            completion()
            return
        }
        
        overlayWindow = OverlayAnimationWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Show animation with proper cleanup
        overlayWindow?.showAnimation(isDarkMode: isDarkMode) { [weak self] in
            DispatchQueue.main.async {
                self?.cleanupOverlay()
                completion()
            }
        }
    }
    
    private func cleanupOverlay() {
        overlayWindow?.orderOut(nil)
        overlayWindow?.close()
        overlayWindow = nil
    }
}
