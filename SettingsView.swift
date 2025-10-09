import SwiftUI

struct SettingsView: View {
    // You can use @AppStorage to save simple user settings
    @AppStorage("metronomeBPM") private var metronomeBPM: Double = 110.0

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Metronome Settings")) {
                    Stepper("BPM: \(Int(metronomeBPM))", value: $metronomeBPM, in: 80...140)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    Text("Developed by Jack Naylor")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
