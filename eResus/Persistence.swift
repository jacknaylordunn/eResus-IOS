//
//  Persistence.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import SwiftData

// Actor to ensure thread-safe access to the data container.
@MainActor
let sharedModelContainer: ModelContainer = {
    // Define the schema for our database. We are telling it to store `SavedArrestLog` objects.
    let schema = Schema([
        SavedArrestLog.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        // Create the database container.
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        // If the database can't be created, something is seriously wrong.
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
