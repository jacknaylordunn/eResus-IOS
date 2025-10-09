//
//  Persistence.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import SwiftData

@MainActor
let sharedModelContainer: ModelContainer = {
    // Defines the schema for the database, including all models to be stored.
    let schema = Schema([
        SavedArrestLog.self,
        Event.self,
    ])
    
    // Configures how the data is stored.
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        // Attempts to create the database container.
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        // If creation fails, the app will crash with a detailed error.
        // This usually happens after a model change and can be fixed by deleting the app from the simulator.
        fatalError("Could not create ModelContainer: \(error)")
    }
}()


