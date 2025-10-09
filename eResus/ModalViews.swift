//
//  ModalViews.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

// MARK: - Summary Modal
struct SummaryView: View {
    let events: [Event]
    @Environment(\.dismiss) private var dismiss

    private var summaryText: String {
        var text = "eResus Event Summary\n"
        if let lastEvent = events.first {
            text += "Total Arrest Time: \(formatTime(lastEvent.timestamp))\n\n"
        }
        text += "--- Event Log ---\n"
        text += events.reversed().map { event in
            "[\(formatTime(event.timestamp))] \(event.message)"
        }.joined(separator: "\n")
        return text
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    Text(summaryText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                
                ShareLink(item: summaryText) {
                    Label("Copy & Share", systemImage: "square.and.arrow.up")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Event Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reset Modal
struct ResetModalView: View {
    @Binding var isPresented: Bool
    let onCopyAndReset: () -> Void
    let onResetAnyway: () -> Void
    
    @State private var copied = false

    var body: some View {
        VStack(spacing: 15) {
            Text("Reset Arrest Log?").font(.title2.bold())
            Text("This action cannot be undone. The current log will be saved automatically before resetting.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom)
            
            ActionButton(title: copied ? "Copied!" : "Copy Log & Reset", icon: "doc.on.doc.fill", color: .blue, disabled: copied) {
                onCopyAndReset()
                copied = true
                // Give user feedback, then dismiss and reset
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isPresented = false
                }
            }
            
            ActionButton(title: "Reset Anyway", icon: "trash.fill", color: .red.opacity(0.8)) {
                onResetAnyway()
                isPresented = false
            }
            
            Button("Cancel") { isPresented = false }.padding(.top)
        }
        .padding()
    }
}

// MARK: - Hypothermia Modal
struct HypothermiaModalView: View {
    @Binding var isPresented: Bool
    let onConfirm: (HypothermiaStatus) -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Set Hypothermia Status").font(.title2.bold())
                .padding(.bottom)
            
            ActionButton(title: "Severe (< 30°C)", icon: "thermometer.snowflake", color: .blue) {
                onConfirm(.severe); isPresented = false
            }
            ActionButton(title: "Moderate (30-35°C)", icon: "thermometer.low", color: .yellow) {
                onConfirm(.moderate); isPresented = false
            }
            ActionButton(title: "Clear / Normothermic", icon: "checkmark.circle", color: .green) {
                onConfirm(.normothermic); isPresented = false
            }
            
            Button("Cancel") { isPresented = false }.padding(.top)
        }
        .padding()
    }
}

// MARK: - Other Drugs Modal
struct OtherDrugsModalView: View {
    @Binding var isPresented: Bool
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationView {
            List(AppConstants.otherMedications, id: \.self) { drug in
                Button(action: {
                    HapticManager.shared.impact(.light)
                    onSelect(drug)
                    isPresented = false
                }) {
                    Text(drug).foregroundColor(.primary)
                }
            }
            .navigationTitle("Log Other Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - ETCO2 Input Modal
struct Etco2ModalView: View {
    @Binding var isPresented: Bool
    let onConfirm: (String) -> Void
    
    @State private var value: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Log ETCO2 Value").font(.title2.bold())
            Text("Enter the current end-tidal CO2 reading in mmHg.").foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("e.g., 35", text: $value)
                .keyboardType(.numberPad)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
                .multilineTextAlignment(.center)
                .focused($isFocused)

            ActionButton(title: "Log Value", icon: "checkmark", color: .teal) {
                onConfirm(value)
                isPresented = false
            }
            
            Button("Cancel") { isPresented = false }.padding(.top)
        }
        .padding()
        .onAppear {
            isFocused = true
        }
    }
}
