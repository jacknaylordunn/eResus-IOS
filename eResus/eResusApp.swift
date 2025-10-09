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
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        // Injects the shared database container into the SwiftUI environment,
        // making it available to all views in the app.
        .modelContainer(sharedModelContainer)
    }
}
