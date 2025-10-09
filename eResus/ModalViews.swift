//
//  ModalViews.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

struct SummaryView: View {
    let events: [Event]
    let totalTime: TimeInterval
    
    @Environment(\.dismiss) private var dismiss
    
    // Sort events chronologically to ensure correct order
    private var sortedEvents: [Event] {
        events.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Total Arrest Time: \(TimeFormatter.format(totalTime))")
                        .font(.headline)
                        .padding(.bottom)
                    
                    // Iterate over the correctly sorted events
                    ForEach(sortedEvents) { event in
                        HStack(alignment: .firstTextBaseline) {
                            Text("[\(TimeFormatter.format(event.timestamp))]")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(event.type.color)
                            
                            Text(event.message)
                                .font(.system(size: 14, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding()
            }
            .navigationTitle("Event Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy to Clipboard") {
                        copySummary()
                    }
                }
            }
        }
    }
    
    private func copySummary() {
        // Use the sorted events for the clipboard text as well
        let summaryText = """
        eResus Event Summary
        Total Arrest Time: \(TimeFormatter.format(totalTime))
        
        --- Event Log ---
        \(sortedEvents.map { "[\(TimeFormatter.format($0.timestamp))] \($0.message)" }.joined(separator: "\n"))
        """
        UIPasteboard.general.string = summaryText
        HapticManager.shared.impact(style: .medium)
    }
}

struct ResetModalView: View {
    @Binding var isPresented: Bool
    let onCopyAndReset: () -> Void
    let onResetAnyway: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Reset Arrest Log?")
                .font(.title).bold()
            
            Text("This will save the current log. This action cannot be undone.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { onCopyAndReset(); isPresented = false }) {
                Text("Copy, Save & Reset")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button(action: { onResetAnyway(); isPresented = false }) {
                Text("Reset & Save")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.large)
            
            Button("Cancel") {
                isPresented = false
            }
            .padding(.top)
            
        }
        .padding()
        .presentationDetents([.height(380)])
    }
}


struct HypothermiaModal: View {
    @Binding var isPresented: Bool
    let onConfirm: (HypothermiaStatus) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Set Hypothermia Status")
                .font(.title2).bold()
            
            Text("Select the patient's temperature range to apply the correct guidelines.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button { onConfirm(.severe); isPresented = false } label: {
                Text("Severe (< 30°C)")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(.blue)
            
            Button { onConfirm(.moderate); isPresented = false } label: {
                Text("Moderate (30-35°C)")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(.orange)

            Button { onConfirm(.normothermic); isPresented = false } label: {
                Text("Clear / Normothermic")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
            
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .presentationDetents([.height(420)])
    }
}


struct OtherDrugsModal: View {
    @Binding var isPresented: Bool
    let onSelectDrug: (String) -> Void
    
    var body: some View {
        NavigationView {
            List(AppConstants.otherDrugs, id: \.self) { drug in
                Button(drug) {
                    onSelectDrug(drug)
                    isPresented = false
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Log Other Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct Etco2ModalView: View {
    @Binding var isPresented: Bool
    let onConfirm: (String) -> Void
    
    @State private var value: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Log ETCO2 Value")
                .font(.title2).bold()
            
            Text("Enter the current end-tidal CO2 reading in mmHg.")
                .foregroundColor(.secondary)
            
            TextField("e.g., 35", text: $value)
                .keyboardType(.numberPad)
                .font(.title)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .multilineTextAlignment(.center)
                .focused($isFocused)
            
            Button(action: confirm) {
                Text("Log Value")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(value.isEmpty)
        }
        .padding()
        .onAppear {
            isFocused = true
        }
        .presentationDetents([.height(250)])
    }
    
    private func confirm() {
        onConfirm(value)
        isPresented = false
    }
}

// MARK: - Dosage Modals

struct DosageEntryModal: View {
    let drug: DrugToLog
    let amiodaroneDoseCount: Int
    let onConfirm: (String, PatientAgeCategory?) -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                switch drug {
                case .adrenaline:
                    AgeBasedDosageView(
                        drugName: "Adrenaline",
                        calculatedDose: DosageCalculator.calculateAdrenalineDose(for: age)
                    )
                case .amiodarone:
                    AgeBasedDosageView(
                        drugName: "Amiodarone",
                        calculatedDose: DosageCalculator.calculateAmiodaroneDose(for: age, doseNumber: amiodaroneDoseCount + 1)
                    )
                case .lidocaine, .other:
                    ManualDosageView(drugName: drug.title)
                }
            }
            .navigationTitle("Log \(drug.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    @State private var age: PatientAgeCategory = .adult

    private func confirm(dosage: String, age: PatientAgeCategory?) {
        onConfirm(dosage, age)
        dismiss()
    }
    
    // View for Adrenaline and Amiodarone
    @ViewBuilder
    private func AgeBasedDosageView(drugName: String, calculatedDose: String?) -> some View {
        Form {
            Section(header: Text("Patient Age")) {
                Picker("Age Category", selection: $age) {
                    ForEach(PatientAgeCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            }
            
            Section(header: Text("Calculated Dose")) {
                if let dose = calculatedDose {
                    VStack(alignment: .center, spacing: 12) {
                        Text(dose)
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .center)

                        Button(action: { confirm(dosage: dose, age: self.age) }) {
                            Text("Log Calculated Dose")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.vertical, 8)
                } else {
                    Text("N/A for this age group.")
                        .foregroundColor(.secondary)
                }
            }
            
            ManualDosageSection { manualDose in
                confirm(dosage: manualDose, age: self.age)
            }
        }
    }
    
    // View for Lidocaine and Other Drugs
    @ViewBuilder
    private func ManualDosageView(drugName: String) -> some View {
        Form {
            ManualDosageSection { manualDose in
                confirm(dosage: manualDose, age: nil)
            }
        }
    }

    // Reusable Manual Entry Section
    @ViewBuilder
    private func ManualDosageSection(onConfirm: @escaping (String) -> Void) -> some View {
        Section(header: Text("Manual Override")) {
            HStack {
                TextField("Amount", text: $manualAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Picker("Unit", selection: $manualUnit) {
                    ForEach(["mg", "mcg", "g", "ml"], id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.menu)
            }

            Button(action: { onConfirm("\(manualAmount)\(manualUnit)") }) {
                Text("Log Manual Dose")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(manualAmount.isEmpty)
        }
    }

    @State private var manualAmount: String = ""
    @State private var manualUnit: String = "mg"
}
