//
//  EditLogPatientInfoView.swift
//  eResus
//

import SwiftUI
import SwiftData

struct EditLogPatientInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Bindable allows us to directly edit the SwiftData model
    @Bindable var log: SavedArrestLog
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Demographics")) {
                    TextField("Approx Age (e.g. 45)", text: Binding(
                        get: { log.patientAge ?? "" },
                        set: { log.patientAge = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.numberPad)
                    
                    Picker("Gender", selection: Binding(
                        get: { log.patientGender ?? "" },
                        set: { log.patientGender = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Unknown").tag("")
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                }
                
                Section(header: Text("Arrest Details")) {
                    TextField("Initial Rhythm (e.g. VF, Asystole)", text: Binding(
                        get: { log.initialRhythm ?? "" },
                        set: { log.initialRhythm = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                if AppSettings.researchModeEnabled {
                    Section(footer: Text("Saving these details will securely update the anonymised record in the research database.")) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Edit Patient Info")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    saveAndSync()
                }
            )
        }
    }
    
    private func saveAndSync() {
        try? modelContext.save()
        if AppSettings.researchModeEnabled {
            FirebaseManager.shared.uploadLog(log, events: log.events)
        }
        dismiss()
    }
}
