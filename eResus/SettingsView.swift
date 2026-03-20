//
//  SettingsView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    @AppStorage("cprCycleDuration") private var cprCycleDuration: TimeInterval = 120
    @AppStorage("adrenalineInterval") private var adrenalineInterval: TimeInterval = 240
    @AppStorage("metronomeBPM") private var metronomeBPM: Int = 110
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("showDosagePrompts") private var showDosagePrompts: Bool = false
    
    // Research mode states
    @AppStorage("researchModeEnabled") private var researchModeEnabled: Bool = true
    @AppStorage("userOrganization") private var userOrganization: String = ""
    @AppStorage("askForPatientInfo") private var askForPatientInfo: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Account & Sync Section
                Section(header: Text("Account & Sync")) {
                    NavigationLink(destination: AuthView()) {
                        Text(firebaseManager.isAuthenticated ? "Account Profile" : "Sign In")
                    }
                }
                
                // MARK: - Research Section
                Section(header: Text("Research & Data"), footer: Text("When enrolled, eResus securely uploads anonymised logs to help improve cardiac arrest outcomes.")) {
                    Toggle("Enroll in Research", isOn: $researchModeEnabled)
                        .onChange(of: researchModeEnabled) { _ in
                            firebaseManager.syncSettingsToCloud()
                        }
                    
                    if researchModeEnabled {
                        Picker("Organization / Trust", selection: $userOrganization) {
                            ForEach(firebaseManager.availableOrganizations, id: \.self) { org in
                                Text(org).tag(org)
                            }
                        }
                        .onChange(of: userOrganization) { _ in
                            firebaseManager.syncSettingsToCloud()
                        }
                    } else {
                        Toggle("Ask for Patient Info Locally", isOn: $askForPatientInfo)
                            .onChange(of: askForPatientInfo) { _ in
                                firebaseManager.syncSettingsToCloud()
                            }
                    }
                    
                    Link("View Data Policy", destination: URL(string: "https://tech.aegismedicalsolutions.co.uk/eresus/data-policy")!)
                        .foregroundColor(.blue)
                }
                
                Section(header: Text("Timers")) {
                    Stepper("CPR Cycle: \(Int(cprCycleDuration)) seconds", value: $cprCycleDuration, in: 60...300, step: 10)
                    Stepper("Adrenaline Interval: \(Int(adrenalineInterval / 60)) minutes", value: $adrenalineInterval, in: 120...600, step: 60)
                }
                
                Section(header: Text("Metronome")) {
                    Stepper("BPM: \(metronomeBPM)", value: $metronomeBPM, in: 80...140, step: 5)
                }
                
                Section(header: Text("Medications"), footer: Text("When enabled, the app will ask for patient age or a manual dose when you log Adrenaline, Amiodarone, or other drugs.")) {
                    Toggle("Show Dosage Prompts", isOn: $showDosagePrompts)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Developer Footer
                Section {
                    EmptyView()
                } footer: {
                    VStack(spacing: 6) {
                        Text("eResus is developed and maintained by")
                        Link("Aegis Medical Solutions", destination: URL(string: "https://tech.aegismedicalsolutions.co.uk")!)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            if userOrganization.isEmpty { userOrganization = "Independent / None" }
            firebaseManager.fetchOrganizations()
        }
    }
}
