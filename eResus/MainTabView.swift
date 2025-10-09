//
//  ContentView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ArrestViewModel
    
    // Custom initializer to correctly create the ViewModel with the database context.
    init() {
        let context = sharedModelContainer.mainContext
        _viewModel = StateObject(wrappedValue: ArrestViewModel(modelContext: context))
    }

    var body: some View {
        TabView {
            ArrestView(viewModel: viewModel)
                .tabItem {
                    Label("Arrest", systemImage: "bolt.heart.fill")
                }

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
