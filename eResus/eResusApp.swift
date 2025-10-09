//
//  eResusApp.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import SwiftData

@main
struct eResusApp: App {
    // This state will be used to communicate actions from URLs to our main view.
    @StateObject private var appState = AppState()
    
    // Provides the shared database container to the entire app.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedArrestLog.self,
            Event.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .onOpenURL { url in
                    // This block runs when the app is opened by a URL from a widget.
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme, scheme == "eresus" else { return }
        guard let host = url.host else { return }

        if host == "start-arrest" {
            // Set the action to be handled by the view.
            appState.pendingAction = .startArrest
        } else if host == "show-guideline" {
            let pdfName = url.lastPathComponent
            if !pdfName.isEmpty {
                appState.pendingAction = .showGuideline(pdfName)
            }
        }
    }
}

// A simple observable object to pass actions from the app delegate to the UI.
@MainActor
class AppState: ObservableObject {
    enum Action {
        case startArrest
        case showGuideline(String)
    }
    
    @Published var pendingAction: Action?
}
