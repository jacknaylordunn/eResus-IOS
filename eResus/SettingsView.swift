//
//  SettingsView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("cprCycleDuration") private var cprCycleDuration: TimeInterval = 120
    @AppStorage("adrenalineInterval") private var adrenalineInterval: TimeInterval = 240
    @AppStorage("metronomeBPM") private var metronomeBPM: Int = 110
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("showDosagePrompts") private var showDosagePrompts: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
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
            }
            .navigationTitle("Settings")
        }
    }
}
