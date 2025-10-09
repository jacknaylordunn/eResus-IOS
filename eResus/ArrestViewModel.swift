//
//  ArrestViewModel.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class ArrestViewModel: ObservableObject {
    private var modelContext: ModelContext
    
    // MARK: - Published State Properties
    @Published var arrestState: ArrestState = .pending
    @Published var masterTime: TimeInterval = 0
    @Published var cprTime: TimeInterval = AppSettings.cprCycleDuration
    @Published var timeOffset: TimeInterval = 0
    @Published var uiState: UIState = .default
    @Published var events: [Event] = []

    @Published var shockCount = 0
    @Published var adrenalineCount = 0
    @Published var amiodaroneCount = 0
    @Published var lidocaineCount = 0
    
    @Published var airwayPlaced = false
    @Published var antiarrhythmicGiven: AntiarrhythmicDrug = .none
    
    @Published var reversibleCauses: [ChecklistItem] = AppConstants.reversibleCausesTemplate
    @Published var postROSCTasks: [ChecklistItem] = AppConstants.postROSCTasksTemplate
    @Published var postMortemTasks: [ChecklistItem] = AppConstants.postMortemTasksTemplate
    @Published var patientAgeCategory: PatientAgeCategory?
    
    // MARK: - Private State Properties
    private var timer: Timer?
    private var startTime: Date?
    private var cprCycleStartTime: TimeInterval = 0
    private var lastAdrenalineTime: TimeInterval?
    private var shockCountForAmiodarone1: Int?
    private var undoHistory: [UndoState] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Computed Properties for UI Logic
    var totalArrestTime: TimeInterval { masterTime + timeOffset }
    var canUndo: Bool { !undoHistory.isEmpty }

    var isAdrenalineAvailable: Bool {
        reversibleCauses.first(where: { $0.name == "Hypothermia" })?.hypothermiaStatus != .severe
    }

    var isAmiodaroneAvailable: Bool {
        let isEligibleShockCount = (shockCount >= 3 && amiodaroneCount == 0) || (shockCount >= 5 && amiodaroneCount == 1)
        return isEligibleShockCount && antiarrhythmicGiven != .lidocaine && isAdrenalineAvailable
    }

    var isLidocaineAvailable: Bool {
        let isEligibleShockCount = (shockCount >= 3 && lidocaineCount == 0) || (shockCount >= 5 && lidocaineCount == 1)
        return isEligibleShockCount && antiarrhythmicGiven != .amiodarone
    }
    
    var timeUntilAdrenaline: TimeInterval? {
        guard let lastAdrenalineTime = lastAdrenalineTime else { return nil }
        let hypothermiaStatus = reversibleCauses.first { $0.name == "Hypothermia" }?.hypothermiaStatus
        let interval = hypothermiaStatus == .moderate ? AppSettings.adrenalineInterval * 2 : AppSettings.adrenalineInterval
        let timeSince = totalArrestTime - lastAdrenalineTime
        return interval - timeSince
    }

    var shouldShowAmiodaroneReminder: Bool {
        guard let shockCountDose1 = shockCountForAmiodarone1 else { return false }
        return amiodaroneCount == 1 && shockCount >= shockCountDose1 + 2
    }
    
    var shouldShowAmiodaroneFirstDosePrompt: Bool {
        return isAmiodaroneAvailable && amiodaroneCount == 0
    }
    
    var shouldShowAdrenalinePrompt: Bool {
        // Prompt after 3rd shock if no adrenaline given yet.
        return shockCount >= 3 && adrenalineCount == 0 && isAdrenalineAvailable
    }
    
    // MARK: - Core Timer Logic
    private func startTimer() {
        stopTimer()
        cprCycleStartTime = totalArrestTime
        
        // Schedule timer on common run loop to prevent pausing during UI interaction
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let startTime = startTime else { return }
        
        Task { @MainActor in
            self.masterTime = Date().timeIntervalSince(startTime)
            
            // Only update CPR time if arrest is active and we are not analyzing/shocking
            if self.arrestState == .active && self.uiState == .default {
                let oldCprTime = self.cprTime
                self.cprTime = AppSettings.cprCycleDuration - (self.totalArrestTime - self.cprCycleStartTime)

                // Haptic for last 10 seconds
                if self.cprTime <= 10 && self.cprTime > 0 {
                    HapticManager.shared.impact(style: .light)
                }
                
                // Haptic for cycle end
                if oldCprTime > 0 && self.cprTime <= 0 {
                    HapticManager.shared.notification(type: .warning)
                }
                
                if self.cprTime < -0.9 { // Add tolerance for timer drift
                    self.cprCycleStartTime = self.totalArrestTime
                    self.cprTime = AppSettings.cprCycleDuration
                    // "CPR Cycle Complete" log removed as requested
                }
            }
        }
    }

    // MARK: - User Actions
    func startArrest() {
        saveUndoState()
        startTime = Date()
        arrestState = .active
        logEvent("Arrest Started at \(Date().formatted(date: .omitted, time: .standard))", type: .status)
        startTimer()
    }
    
    func analyseRhythm() {
        saveUndoState()
        uiState = .analyzing
        logEvent("Rhythm analysis. Pausing CPR.", type: .analysis)
    }
    
    func logRhythm(_ rhythm: String, isShockable: Bool) {
        saveUndoState()
        logEvent("Rhythm is \(rhythm)", type: .rhythm)
        if isShockable {
            uiState = .shockAdvised
        } else {
            resumeCPR()
        }
    }
    
    func deliverShock() {
        saveUndoState()
        shockCount += 1
        logEvent("Shock \(shockCount) Delivered", type: .shock)
        resumeCPR()
    }
    
    private func resumeCPR() {
        uiState = .default
        cprCycleStartTime = totalArrestTime
        cprTime = AppSettings.cprCycleDuration
        logEvent("Resuming CPR.", type: .cpr)
    }

    func logAdrenaline(with dosage: String? = nil) {
        saveUndoState()
        adrenalineCount += 1
        lastAdrenalineTime = totalArrestTime
        let dosageText = (AppSettings.showDosagePrompts && dosage != nil) ? " (\(dosage!))" : ""
        logEvent("Adrenaline\(dosageText) Given - Dose \(adrenalineCount)", type: .drug)
    }
    
    func logAmiodarone(with dosage: String? = nil) {
        saveUndoState()
        amiodaroneCount += 1
        antiarrhythmicGiven = .amiodarone
        if amiodaroneCount == 1 {
            shockCountForAmiodarone1 = shockCount
        }
        let dosageText = (AppSettings.showDosagePrompts && dosage != nil) ? " (\(dosage!))" : ""
        logEvent("Amiodarone\(dosageText) Given - Dose \(amiodaroneCount)", type: .drug)
    }
    
    func logLidocaine(with dosage: String? = nil) {
        saveUndoState()
        lidocaineCount += 1
        antiarrhythmicGiven = .lidocaine
        let dosageText = (AppSettings.showDosagePrompts && dosage != nil) ? " (\(dosage!))" : ""
        logEvent("Lidocaine\(dosageText) Given - Dose \(lidocaineCount)", type: .drug)
    }
    
    func logOtherDrug(_ drug: String, with dosage: String? = nil) {
        saveUndoState()
        let dosageText = (AppSettings.showDosagePrompts && dosage != nil) ? " (\(dosage!))" : ""
        logEvent("\(drug)\(dosageText) Given", type: .drug)
    }
    
    func setPatientAgeCategory(_ ageCategory: PatientAgeCategory?) {
        self.patientAgeCategory = ageCategory
    }
    
    func logAirwayPlaced() {
        saveUndoState()
        airwayPlaced = true
        logEvent("Advanced Airway Placed", type: .airway)
    }
    
    func logEtco2(_ value: String) {
        saveUndoState()
        if let number = Int(value), number > 0 {
            logEvent("ETCO2: \(number) mmHg", type: .etco2)
        }
    }
    
    func achieveROSC() {
        saveUndoState()
        arrestState = .rosc
        uiState = .default
        logEvent("Return of Spontaneous Circulation (ROSC)", type: .status)
    }
    
    func endArrest() {
        saveUndoState()
        arrestState = .ended
        stopTimer()
        logEvent("Arrest Ended (Patient Deceased)", type: .status)
    }
    
    func reArrest() {
        saveUndoState()
        arrestState = .active
        cprCycleStartTime = totalArrestTime
        cprTime = AppSettings.cprCycleDuration
        logEvent("Patient Re-Arrested. CPR Resumed.", type: .status)
    }

    func addTimeOffset(_ seconds: TimeInterval) {
        saveUndoState()
        timeOffset += seconds
        logEvent("Time offset added: +\(Int(seconds / 60)) min", type: .status)
    }
    
    func toggleChecklistItemCompletion(for item: Binding<ChecklistItem>) {
        saveUndoState()
        item.wrappedValue.isCompleted.toggle()
        let status = item.wrappedValue.isCompleted ? "checked" : "unchecked"
        logEvent("\(item.wrappedValue.name) \(status)", type: .cause)
    }

    func setHypothermiaStatus(_ status: HypothermiaStatus) {
        saveUndoState()
        if let index = reversibleCauses.firstIndex(where: { $0.name == "Hypothermia" }) {
            reversibleCauses[index].hypothermiaStatus = status
            reversibleCauses[index].isCompleted = (status != .none)
            logEvent("Hypothermia status set to: \(status.rawValue)", type: .cause)
        }
    }
    
    // MARK: - Undo & Reset Logic
    private func saveUndoState() {
        do {
            let eventsData = try JSONEncoder().encode(events.map { EventCodable(from: $0) })
            
            let currentState = UndoState(
                arrestState: arrestState, masterTime: masterTime, cprTime: cprTime, timeOffset: timeOffset,
                eventsData: eventsData, shockCount: shockCount, adrenalineCount: adrenalineCount,
                amiodaroneCount: amiodaroneCount, lidocaineCount: lidocaineCount,
                lastAdrenalineTime: lastAdrenalineTime, antiarrhythmicGiven: antiarrhythmicGiven,
                shockCountForAmiodarone1: shockCountForAmiodarone1, airwayPlaced: airwayPlaced,
                reversibleCauses: reversibleCauses, postROSCTasks: postROSCTasks,
                postMortemTasks: postMortemTasks, startTime: startTime, uiState: uiState,
                patientAgeCategory: patientAgeCategory
            )
            undoHistory.append(currentState)
        } catch {
            print("Failed to save undo state: \(error)")
        }
    }
    
    func undo() {
        guard let lastState = undoHistory.popLast() else { return }
        
        do {
            let decodedEvents = try JSONDecoder().decode([EventCodable].self, from: lastState.eventsData)
            events = decodedEvents.map { $0.toEvent() }
            
            arrestState = lastState.arrestState
            masterTime = lastState.masterTime
            cprTime = lastState.cprTime
            timeOffset = lastState.timeOffset
            shockCount = lastState.shockCount
            adrenalineCount = lastState.adrenalineCount
            amiodaroneCount = lastState.amiodaroneCount
            lidocaineCount = lastState.lidocaineCount
            lastAdrenalineTime = lastState.lastAdrenalineTime
            antiarrhythmicGiven = lastState.antiarrhythmicGiven
            shockCountForAmiodarone1 = lastState.shockCountForAmiodarone1
            airwayPlaced = lastState.airwayPlaced
            reversibleCauses = lastState.reversibleCauses
            postROSCTasks = lastState.postROSCTasks
            postMortemTasks = lastState.postMortemTasks
            startTime = lastState.startTime
            uiState = lastState.uiState
            patientAgeCategory = lastState.patientAgeCategory
            
            if (arrestState == .active || arrestState == .rosc) && timer == nil {
                startTimer()
            } else if arrestState == .pending || arrestState == .ended {
                stopTimer()
            }
        } catch {
            print("Failed to restore undo state: \(error)")
        }
    }

    func performReset(shouldSaveLog: Bool, shouldCopy: Bool) {
        if shouldSaveLog && startTime != nil {
            saveLogToDatabase()
        }
        if shouldCopy {
            copySummaryToClipboard()
        }
        
        stopTimer()
        arrestState = .pending
        masterTime = 0
        cprTime = AppSettings.cprCycleDuration
        timeOffset = 0
        uiState = .default
        events = []
        shockCount = 0
        adrenalineCount = 0
        amiodaroneCount = 0
        lidocaineCount = 0
        airwayPlaced = false
        antiarrhythmicGiven = .none
        lastAdrenalineTime = nil
        shockCountForAmiodarone1 = nil
        startTime = nil
        undoHistory = []
        patientAgeCategory = nil
        reversibleCauses = AppConstants.reversibleCausesTemplate
        postROSCTasks = AppConstants.postROSCTasksTemplate
        postMortemTasks = AppConstants.postMortemTasksTemplate
    }
    
    private func saveLogToDatabase() {
        guard let startTime = startTime else { return }
        
        let finalOutcome: String
        switch arrestState {
        case .rosc: finalOutcome = "ROSC"
        case .ended: finalOutcome = "Deceased"
        default: finalOutcome = "Incomplete"
        }
        
        let newLog = SavedArrestLog(
            startTime: startTime,
            totalDuration: totalArrestTime,
            finalOutcome: finalOutcome,
            events: []
        )
        modelContext.insert(newLog)
        
        for event in events {
            let newEvent = Event(timestamp: event.timestamp, message: event.message, type: event.type)
            newEvent.log = newLog
            modelContext.insert(newEvent)
        }
        
        try? modelContext.save()
    }
    
    private func copySummaryToClipboard() {
        let summaryText = """
        eResus Event Summary
        Total Arrest Time: \(TimeFormatter.format(totalArrestTime))
        
        --- Event Log ---
        \(events.sorted(by: { $0.timestamp < $1.timestamp }).map { "[\(TimeFormatter.format($0.timestamp))] \($0.message)" }.joined(separator: "\n"))
        """
        UIPasteboard.general.string = summaryText
        HapticManager.shared.notification(type: .success)
    }
    
    private func logEvent(_ message: String, type: EventType) {
        let newEvent = Event(timestamp: totalArrestTime, message: message, type: type)
        events.insert(newEvent, at: 0)
        HapticManager.shared.impact()
    }
}
