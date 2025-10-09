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
    @AppStorage("metronomeBPM") private var metronomeBPM: Double = 110
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Timer Settings"), footer: Text("Changes will apply to the next new arrest.")) {
                    VStack(alignment: .leading) {
                        Text("CPR Cycle Duration")
                        Slider(value: Binding(
                            get: { cprCycleDuration },
                            set: { cprCycleDuration = round($0 / 15) * 15 }
                        ), in: 60...180, step: 15)
                        Text("\(Int(cprCycleDuration)) seconds")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Adrenaline Interval")
                        Slider(value: Binding(
                            get: { adrenalineInterval },
                            set: { adrenalineInterval = round($0 / 30) * 30 }
                        ), in: 180...300, step: 30)
                        Text("\(Int(adrenalineInterval / 60)) minutes (\(Int(adrenalineInterval))s)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("Metronome")) {
                    VStack(alignment: .leading) {
                        Text("Beats Per Minute (BPM)")
                        Slider(value: $metronomeBPM, in: 100...120, step: 1)
                        Text("\(Int(metronomeBPM)) BPM")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    if let url = URL(string: "https://www.aegismedicalsolutions.co.uk") {
                        Link("Developer Website", destination: url)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
