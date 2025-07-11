import SwiftUI

@main
struct NiteLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - this is a menubar-only app
        Settings {
            EmptyView()
        }
    }
}
