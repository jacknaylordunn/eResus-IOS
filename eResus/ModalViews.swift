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
    let startTime: Date?
    let shockCount: Int
    let adrenalineCount: Int
    let amiodaroneCount: Int
    let lidocaineCount: Int
    let roscTime: TimeInterval?
    let patientAge: String?
    let patientGender: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isCopied: Bool = false
    
    // Sort events chronologically to ensure correct order
    private var sortedEvents: [Event] {
        events.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Extracted Real-World Times (No Seconds)
    private var firstAirwayTime: String {
        guard let start = startTime, let ev = sortedEvents.first(where: { $0.type == .airway && $0.message.contains("Advanced Airway") }) else { return "None" }
        return DateFormatter.localizedString(from: start.addingTimeInterval(ev.timestamp), dateStyle: .none, timeStyle: .short)
    }
    
    private var firstAccessTime: String {
        guard let start = startTime, let ev = sortedEvents.first(where: { $0.message.contains("Access") && $0.message.contains("Successful") }) else { return "None" }
        return DateFormatter.localizedString(from: start.addingTimeInterval(ev.timestamp), dateStyle: .none, timeStyle: .short)
    }
    
    private var firstAdrenalineTime: String {
        guard let start = startTime, let ev = sortedEvents.first(where: { $0.message.contains("Adrenaline") && $0.message.contains("Given") }) else { return "None" }
        return DateFormatter.localizedString(from: start.addingTimeInterval(ev.timestamp), dateStyle: .none, timeStyle: .short)
    }
    
    private var finalOutcomeTime: String {
        guard let start = startTime, let ev = sortedEvents.last(where: { $0.message.contains("ROSC") || $0.message.contains("Termination") || $0.message.contains("Deceased") }) else { return "Unknown" }
        let type = ev.message.contains("ROSC") ? "ROSC" : "TOR"
        return "\(type) at: " + DateFormatter.localizedString(from: start.addingTimeInterval(ev.timestamp), dateStyle: .none, timeStyle: .short)
    }
    
    private var vodTime: String {
        guard let start = startTime, let ev = sortedEvents.first(where: { $0.message.contains("Verification of Death") }) else { return "None" }
        return DateFormatter.localizedString(from: start.addingTimeInterval(ev.timestamp), dateStyle: .none, timeStyle: .short)
    }
    
    private var initialRhythmExtracted: String {
        guard let ev = sortedEvents.first(where: { $0.type == .rhythm }) else { return "Unknown" }
        return ev.message.replacingOccurrences(of: "Rhythm is ", with: "")
    }
    
    private var demographicsString: String {
        let ageText = patientAge?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let genderText = patientGender?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let a = ageText.isEmpty ? "" : "\(ageText) y/o"
        let g = genderText.isEmpty ? "" : genderText
        let combined = [a, g].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? "Not Recorded" : combined
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Top Overview Banner
                    VStack(alignment: .leading, spacing: 6) {
                        // Date & Demographics
                        Text(startTime.map { DateFormatter.localizedString(from: $0, dateStyle: .long, timeStyle: .none) } ?? "Unknown Date")
                            .font(.title3).bold()
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.text.rectangle.fill")
                            Text(demographicsString)
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.bottom, 6)
                        
                        // Times & Outcomes
                        Text("Start Time: \(startTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "Unknown")")
                        Text(finalOutcomeTime)
                            .foregroundColor(finalOutcomeTime.contains("ROSC") ? .green : .red)
                        if vodTime != "None" {
                            Text("VOD at: \(vodTime)")
                                .foregroundColor(.red)
                        }
                        Text("Total Duration: \(TimeFormatter.format(totalTime))")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Critical Interventions Box
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Critical Interventions (Real-World Time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Grid(horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow { Text("Initial Rhythm:").foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading); Text(initialRhythmExtracted).bold() }
                            GridRow { Text("First IV / IO:").foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading); Text(firstAccessTime).bold() }
                            GridRow { Text("First Airway:").foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading); Text(firstAirwayTime).bold() }
                            GridRow { Text("First Adrenaline:").foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading); Text(firstAdrenalineTime).bold() }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Medication Counts
                    HStack {
                        Spacer()
                        VStack { Text("\(shockCount)").font(.title3.bold()); Text("Shocks").font(.caption).foregroundColor(.secondary) }
                        Spacer()
                        VStack { Text("\(adrenalineCount)").font(.title3.bold()); Text("Adrenaline").font(.caption).foregroundColor(.secondary) }
                        Spacer()
                        VStack { Text("\(amiodaroneCount)").font(.title3.bold()); Text("Amiodarone").font(.caption).foregroundColor(.secondary) }
                        Spacer()
                        VStack { Text("\(lidocaineCount)").font(.title3.bold()); Text("Lidocaine").font(.caption).foregroundColor(.secondary) }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // The Full Event Log
                    Text("Event Log")
                        .font(.headline)
                        .padding(.top, 4)
                    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        copySummary()
                        withAnimation { isCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { isCopied = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isCopied ? "Copied!" : "Copy")
                            Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                        }
                        .font(.body.bold())
                    }
                    .tint(isCopied ? .green : .blue)
                }
            }
        }
    }
    
    private func copySummary() {
        let dateText = startTime.map { DateFormatter.localizedString(from: $0, dateStyle: .long, timeStyle: .none) } ?? "Unknown Date"
        let startText = startTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short) } ?? "Unknown Time"
        let vodLine = vodTime != "None" ? "\nVOD at: \(vodTime)" : ""
        let header = """
        eResus Event Summary
        Date: \(dateText)
        Patient: \(demographicsString)
        
        Start Time (clock): \(startText)
        \(finalOutcomeTime)\(vodLine)
        Total Duration: \(TimeFormatter.format(totalTime))
        
        Initial Rhythm: \(initialRhythmExtracted)
        First IV/IO: \(firstAccessTime)
        First Airway: \(firstAirwayTime)
        First Adrenaline: \(firstAdrenalineTime)
        
        Shocks: \(shockCount)  |  Adrenaline: \(adrenalineCount)  |  Amiodarone: \(amiodaroneCount)  |  Lidocaine: \(lidocaineCount)
        """
        let log = sortedEvents.map { "[\(TimeFormatter.format($0.timestamp))] \($0.message)" }.joined(separator: "\n")
        UIPasteboard.general.string = header + "\n\n--- Event Log ---\n" + log
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Vascular Access Modal
struct VascularAccessModal: View {
    @Binding var isPresented: Bool
    let onConfirm: (String, String, String, Bool) -> Void

    @State private var type: String = "IV"
    @State private var location: String = ""
    @State private var gauge: String = ""
    @State private var isSuccessful: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Access Details")) {
                    Picker("Type", selection: $type) {
                        Text("IV").tag("IV")
                        Text("IO").tag("IO")
                    }
                    .pickerStyle(.segmented)

                    TextField("Location (e.g. Left AC, Tibia) - Optional", text: $location)
                    TextField("Gauge (e.g. 18G, Pink) - Optional", text: $gauge)

                    Toggle("Successful Placement", isOn: $isSuccessful)
                        .tint(.green)
                }
            }
            .navigationTitle("Log Vascular Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onConfirm(type, location, gauge, isSuccessful)
                        isPresented = false
                    }
                }
            }
        }
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

// MARK: - JRCALC TOR Guidance Modal
struct TORGuidanceModal: View {
    @ObservedObject var viewModel: ArrestViewModel
    @Binding var isPresented: Bool

    var body: some View {
        let isPaediatric: Bool = {
            if viewModel.arrestType == .newborn { return true }
            if let age = Int(viewModel.patientAgeStr.trimmingCharacters(in: .whitespacesAndNewlines)), age <= 18 { return true }
            let catDesc = String(describing: viewModel.patientAgeCategory).lowercased()
            return catDesc.contains("infant") || catDesc.contains("child") || catDesc.contains("birth") || catDesc.contains("ped") || catDesc.contains("paed")
        }()
        let thresholdTime: TimeInterval = isPaediatric ? 3600 : 2700 // 60 mins vs 45 mins
        
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Warning Header
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Termination of Resuscitation")
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                        
                        Text("Current Duration: \(TimeFormatter.format(viewModel.totalArrestTime))")
                            .font(.headline)
                            .foregroundColor(viewModel.totalArrestTime >= thresholdTime ? .red : .primary)
                    }
                    .padding(.top)

                    if viewModel.arrestType == .general {
                        if isPaediatric {
                            // PAEDIATRIC GUIDANCE
                            VStack(alignment: .leading, spacing: 16) {
                                Text("JRCALC Guidelines (Paediatric)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text("• Consider termination after **60 minutes** of resuscitation.\n• Ceasing resuscitation on scene should ONLY be considered if senior clinicians are present or senior advice has been sought.\n• The child must still be conveyed to an ED (unless care plan states otherwise).\n• Resuscitation should ALWAYS be continued in: hypothermia, suspected overdose/poisoning, or pregnancy.")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            
                        } else {
                            // ADULT GUIDANCE
                            VStack(alignment: .leading, spacing: 16) {
                                Text("JRCALC Guidelines (Adult)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                let rhythm = viewModel.initialRhythm ?? "Unknown"

                                GuidelineCard(
                                    rhythm: "Asystole",
                                    text: "Discontinue at any point if inappropriate. At 45 mins, cessation is appropriate unless there is a compelling reason to continue.",
                                    isHighlighted: rhythm == "Asystole"
                                )
                                GuidelineCard(
                                    rhythm: "PEA",
                                    text: "At 45 mins, consider cessation if rate <40 bpm and QRS width >120msecs. Otherwise, seek advice.",
                                    isHighlighted: rhythm == "PEA"
                                )
                                GuidelineCard(
                                    rhythm: "VF / VT",
                                    text: "Follow local pathway for refractory arrest. Seek advice at 45 mins. Cessation may be appropriate.",
                                    isHighlighted: rhythm == "VF" || rhythm == "VT"
                                )

                                Divider()

                                Text("ROSC Considerations")
                                    .font(.subheadline).bold()
                                Text("• Transient (<10 mins): Disregard and consider TOR based on guidance above.\n• Sustained (>10 mins) then re-arrest: Discuss with a senior clinician.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    } else {
                        Text("Ensure local newborn termination guidelines have been met before concluding resuscitation.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            viewModel.endArrest()
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "xmark.seal.fill")
                                Text("Confirm TOR (Stop CPR)")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)

                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel & Continue Resuscitation")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
            .navigationTitle("Clinical Guidance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

struct GuidelineCard: View {
    let rhythm: String
    let text: String
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(rhythm)
                    .font(.subheadline).bold()
                    .foregroundColor(isHighlighted ? .blue : .primary)
                
                if isHighlighted {
                    Text("LOGGED INITIAL RHYTHM")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            Text(text)
                .font(.footnote)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(isHighlighted ? 12 : 0)
        .background(isHighlighted ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - PLIIE Guidance Modal
struct PLIIEGuidanceModal: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Breaking Bad News (PLIIE)")
                        .font(.title2).bold()
                    
                    Text("When it becomes clear that the resuscitation attempt is unlikely to have a successful outcome, take time to prepare relatives. Anticipate varying grief reactions.")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        PLIIESection(letter: "P", title: "Prepare", bullets: [
                            "Check and tidy uniform/clothing, remove gloves, wash hands.",
                            "Talk to staff prior to going to the family.",
                            "Ensure you have the patient's details."
                        ])
                        PLIIESection(letter: "L", title: "Location", bullets: [
                            "Find somewhere private.",
                            "Turn down radios and ignore mobile phones."
                        ])
                        PLIIESection(letter: "I", title: "Introduce", bullets: [
                            "Introduce your name/role and other staff.",
                            "Confirm the name of the deceased before speaking.",
                            "Ask family to introduce themselves and establish relationship."
                        ])
                        PLIIESection(letter: "I", title: "Information", bullets: [
                            "Adopt a position at the same level as the relative.",
                            "Use simple language, avoid jargon.",
                            "Ensure the word 'dead' or 'died' is introduced early.",
                            "Allow periods of silence to absorb information.",
                            "Check understanding; repeat if necessary."
                        ])
                        PLIIESection(letter: "E", title: "End", bullets: [
                            "Answer any questions.",
                            "Offer support.",
                            "Document discussion in clinical record."
                        ])
                    }
                }
                .padding()
            }
            .navigationTitle("Clinical Guidance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

struct PLIIESection: View {
    let letter: String
    let title: String
    let bullets: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(letter)
                    .font(.title3).bold()
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .clipShape(Circle())
                Text(title)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
            }
            
            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top) {
                    Text("•")
                    Text(bullet)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
            }
        }
    }
}

// MARK: - Dosage Modals
struct DosageEntryModal: View {
    let drug: DrugToLog
    let amiodaroneDoseCount: Int
    @Binding var patientAgeStr: String
    let onConfirm: (String, PatientAgeCategory?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // We use a local state for the picker so it scrolls smoothly without infinite loops
    @State private var localAge: PatientAgeCategory

    init(drug: DrugToLog, amiodaroneDoseCount: Int, patientAgeStr: Binding<String>, initialAgeCategory: PatientAgeCategory?, onConfirm: @escaping (String, PatientAgeCategory?) -> Void) {
        self.drug = drug
        self.amiodaroneDoseCount = amiodaroneDoseCount
        self._patientAgeStr = patientAgeStr
        self.onConfirm = onConfirm
        
        // 1. SMART INIT: Default to Adult if nothing was entered at the start of the arrest
        var defaultCategory: PatientAgeCategory = .adult
        let ageString = patientAgeStr.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let ageInt = Int(ageString) {
            if ageInt >= 12 {
                if let adultCase = PatientAgeCategory.allCases.first(where: { $0.rawValue.lowercased().contains("adult") || $0.rawValue.contains("12") }) {
                    defaultCategory = adultCase
                }
            } else {
                if let childCase = PatientAgeCategory.allCases.first(where: { Int($0.rawValue.filter { $0.isNumber }) == ageInt }) {
                    defaultCategory = childCase
                }
            }
        } else if let initial = initialAgeCategory {
            defaultCategory = initial
        }
        
        _localAge = State(initialValue: defaultCategory)
    }

    var body: some View {
        NavigationView {
            Group {
                switch drug {
                case .adrenaline:
                    AgeBasedDosageView(
                        drugName: "Adrenaline",
                        calculatedDose: DosageCalculator.calculateAdrenalineDose(for: localAge)
                    )
                case .amiodarone:
                    AgeBasedDosageView(
                        drugName: "Amiodarone",
                        calculatedDose: DosageCalculator.calculateAmiodaroneDose(for: localAge, doseNumber: amiodaroneDoseCount + 1)
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

    private func confirm(dosage: String, age: PatientAgeCategory?) {
        // 2. SMART SYNC ON SAVE: Update the master string ONLY when they actually log the drug!
        if let confirmedAge = age {
            let rawStr = confirmedAge.rawValue.lowercased()
            if !rawStr.contains("adult") && !rawStr.contains("12") {
                let extractedNumber = confirmedAge.rawValue.filter { $0.isNumber }
                if !extractedNumber.isEmpty {
                    patientAgeStr = extractedNumber
                }
            }
        }
        
        onConfirm(dosage, age)
        dismiss()
    }
    
    // View for Adrenaline and Amiodarone
    @ViewBuilder
    private func AgeBasedDosageView(drugName: String, calculatedDose: String?) -> some View {
        Form {
            Section(header: Text("Patient Age")) {
                Picker("Age Category", selection: $localAge) {
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

                        Button(action: { confirm(dosage: dose, age: self.localAge) }) {
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
                confirm(dosage: manualDose, age: self.localAge)
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
            HStack(spacing: 12) {
                TextField("Amount", text: $manualAmount)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .multilineTextAlignment(.center)
                
                Picker("Unit", selection: $manualUnit) {
                    ForEach(["mg", "mcg", "g", "ml"], id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .padding(.vertical, 4)

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
