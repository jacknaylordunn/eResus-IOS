import SwiftUI
import FirebaseCore
import SwiftData

// MARK: - App State for Quick Actions & Deep Links
class AppState: ObservableObject {
    enum Action {
        case startArrest
        case showGuideline(String)
    }
    @Published var pendingAction: Action?
}

@main
struct eResusApp: App {
    // Create the AppState so the rest of the app can read it
    @StateObject private var appState = AppState()
    
    // The init() block runs before absolutely EVERYTHING else in SwiftUI
    init() {
        FirebaseApp.configure()
        
        // Now that Firebase is definitively running, start the Auth listener
        FirebaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState) // Inject it back into the app!
        }
        // SwiftData configuration
        .modelContainer(for: [SavedArrestLog.self, Event.self])
    }
}
