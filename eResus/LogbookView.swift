//
//  LogbookView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import SwiftData

struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedArrestLog.startTime, order: .reverse) private var logs: [SavedArrestLog]
    
    // Read Settings State
    @AppStorage("researchModeEnabled") private var researchModeEnabled: Bool = true
    @AppStorage("askForPatientInfo") private var askForPatientInfo: Bool = false
    
    // State to control which sheets are showing
    @State private var selectedLog: SavedArrestLog?
    @State private var logToEdit: SavedArrestLog?

    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
                    // Clean and check existing info
                    let ageText = log.patientAge?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let genderText = log.patientGender?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let hasAge = !ageText.isEmpty
                    let hasGender = !genderText.isEmpty
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.startTime, style: .date)
                            .font(.headline)
                        
                        if hasAge || hasGender {
                            // SHOW: Actual Patient Demographics at the top
                            let a = hasAge ? "\(ageText) y/o" : ""
                            let g = hasGender ? genderText : ""
                            let combined = [a, g].filter { !$0.isEmpty }.joined(separator: " ")
                            
                            HStack(spacing: 4) {
                                Image(systemName: "person.text.rectangle.fill")
                                Text(combined)
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                        }
                        
                        Text(log.startTime, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, hasAge || hasGender ? 2 : 0) // dynamic spacing
                            
                        Text("Duration: \(TimeFormatter.format(log.totalDuration)) | Outcome: \(log.finalOutcome)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        
                        if !(hasAge || hasGender) && (researchModeEnabled || askForPatientInfo) {
                            // SHOW: Add Info Button (ONLY if settings allow and info is missing)
                            Button(action: {
                                logToEdit = log
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                    Text("Add Patient Info")
                                }
                                .font(.caption2.bold())
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.borderless) // Critical for buttons inside lists!
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle()) // Makes the whole blank area tappable
                    .onTapGesture {
                        // Tapping the cell anywhere else still opens the Summary
                        selectedLog = log
                    }
                    // MARK: - Swipe Action (Swipe Left to Right)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        // Only show edit swipe if the feature is on, or if info already exists and they want to change it
                        if hasAge || hasGender || researchModeEnabled || askForPatientInfo {
                            Button {
                                logToEdit = log
                            } label: {
                                Label("Edit Info", systemImage: "person.text.rectangle")
                            }
                            .tint(.blue)
                        }
                    }
                    // MARK: - Long Press Menu
                    .contextMenu {
                        if hasAge || hasGender || researchModeEnabled || askForPatientInfo {
                            Button {
                                logToEdit = log
                            } label: {
                                Label("Add / Edit Patient Info", systemImage: "person.text.rectangle")
                            }
                        }
                        
                        Button(role: .destructive) {
                            deleteSingleLog(log)
                        } label: {
                            Label("Delete Log", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteLogs)
            }
            .navigationTitle("Logbook")
            .sheet(item: $selectedLog) { log in
                            // Standard Summary View
                            SummaryView(
                                events: Array(log.events),
                                totalTime: log.totalDuration,
                                startTime: log.startTime,
                                shockCount: log.shockCount,
                                adrenalineCount: log.adrenalineCount,
                                amiodaroneCount: log.amiodaroneCount,
                                lidocaineCount: 0,
                                roscTime: log.roscTime,
                                patientAge: log.patientAge,
                                patientGender: log.patientGender
                            )
                        }
            .sheet(item: $logToEdit) { log in
                // NEW: Research Demographic Edit View
                EditLogPatientInfoView(log: log)
            }
        }
    }
    
    private func deleteSingleLog(_ log: SavedArrestLog) {
        withAnimation {
            FirebaseManager.shared.deleteLog(log)
            modelContext.delete(log)
        }
    }
    
    private func deleteLogs(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let log = logs[index]
                FirebaseManager.shared.deleteLog(log)
                modelContext.delete(log)
            }
        }
    }
}

