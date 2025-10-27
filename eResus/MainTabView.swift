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
    
    var body: some View {
        // This wrapper view gets the model context from the environment
        // and uses it to create the ArrestViewModel for the implementation view.
        MainTabViewImplementation(modelContext: modelContext)
    }
}

// The main view logic is moved into this implementation struct.
fileprivate struct MainTabViewImplementation: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hasViewedIntro") private var hasViewedIntro: Bool = false
    @EnvironmentObject private var appState: AppState
    
    // Create the ArrestViewModel here as a StateObject so it persists
    // and can be controlled by the URL handler.
    @StateObject private var arrestViewModel: ArrestViewModel
    
    @State private var pdfToShow: PDFIdentifiable?
    @State private var showIntro: Bool = false
    
    // The initializer now receives the modelContext from the parent wrapper view.
    init(modelContext: ModelContext) {
        _arrestViewModel = StateObject(wrappedValue: ArrestViewModel(modelContext: modelContext))
    }

    var body: some View {
        TabView {
            // Pass the single instance of the view model to the ArrestView.
            ArrestView(viewModel: arrestViewModel, pdfToShow: $pdfToShow)
                .tabItem {
                    Label("Arrest", systemImage: "waveform.path.ecg")
                }

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book.closed.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .preferredColorScheme(colorScheme)
        .sheet(item: $pdfToShow) { pdfItem in
             NavigationView {
                PDFKitView(pdfName: pdfItem.pdfName)
                    .navigationTitle(pdfItem.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { pdfToShow = nil }
                        }
                    }
            }
        }
        // Use .onReceive on the appState's published property to avoid
        // requiring Equatable conformance on the Action enum.
        .onReceive(appState.$pendingAction) { action in
            guard let action = action else { return }
            
            switch action {
            case .startArrest:
                // If the arrest is not already active, start it.
                if arrestViewModel.arrestState == .pending {
                    arrestViewModel.startArrest()
                }
            case .showGuideline(let pdfName):
                // Show the corresponding PDF. The title can be empty.
                self.pdfToShow = PDFIdentifiable(pdfName: pdfName, title: "")
            }
            
            // Reset the pending action so it doesn't fire again.
            appState.pendingAction = nil
        }
        .onAppear {
            // If the user hasn't seen the intro, set our state variable to
            // true, which will trigger the sheet to be presented.
            if !hasViewedIntro {
                showIntro = true
            }
        }
        .sheet(isPresented: $showIntro) {
            // When the sheet is dismissed, we set hasViewedIntro to true
            // so it won't be shown again on the next app launch.
            hasViewedIntro = true
        } content: {
            IntroView(isPresented: $showIntro)
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}
