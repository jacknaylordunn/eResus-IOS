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
    @Published var arrestType: ArrestType = .general
    @Published var isPreterm: Bool = false
    @Published var nlsState: NLSState = .initialAssessment
    @Published var masterTime: TimeInterval = 0
    @Published var cprTime: TimeInterval = AppSettings.cprCycleDuration
    @Published var timeOffset: TimeInterval = 0
    @Published var uiState: UIState = .default
    @Published var events: [Event] = []
    
    @Published var nlsCycleDuration: TimeInterval = 60 // 60s for Golden Minute, 30s for loops
    @Published var isRhythmCheckDue: Bool = false

    @Published var shockCount = 0
    @Published var adrenalineCount = 0
    @Published var amiodaroneCount = 0
    @Published var lidocaineCount = 0
    
    @Published var hideAdrenalinePrompt: Bool = false
    @Published var hideAdrenalineDueWarning: Bool = false // NEW: Swipe dismiss for Adrenaline Due
    @Published var hideAmiodaronePrompt: Bool = false
    @Published var lastRhythmNonShockable: Bool = false
    @Published var airwayAdjunct: AirwayAdjunctType? = nil
    @Published var roscTime: TimeInterval? = nil
    
    @Published var airwayPlaced = false
    @Published var vascularAccessPlaced = false
    @Published var antiarrhythmicGiven: AntiarrhythmicDrug = .none
    
    @Published var reversibleCauses: [ChecklistItem] = AppConstants.reversibleCausesTemplate
    @Published var postROSCTasks: [ChecklistItem] = AppConstants.postROSCTasksTemplate
    @Published var postMortemTasks: [ChecklistItem] = AppConstants.postMortemTasksTemplate
    @Published var nlsPretermTasks: [ChecklistItem] = AppConstants.nlsPretermTasksTemplate
    @Published var patientAgeCategory: PatientAgeCategory?
    
    // VOD State
    @Published var vodConfirmed = false
    @Published var vodTasks: [ChecklistItem] = [
        ChecklistItem(name: "**A/B:** Apnoea / Absent Breathing"),
        ChecklistItem(name: "**C:** Absent Circulation (Pulse/Heart sounds)"),
        ChecklistItem(name: "**D:** Disability (Unresponsive / GCS 3)"),
        ChecklistItem(name: "**E:** 5 mins continuous asystole on ECG")
    ]
    
    @Published var isTimerPaused: Bool = false
    
    // Research Variables
    @Published var patientAgeStr: String = ""
    @Published var patientGenderStr: String = ""
    @Published var initialRhythm: String? = nil
    @Published var showPatientInfoPrompt: Bool = false
    
    // MARK: - Private State Properties
    private var timer: Timer?
    private var startTime: Date?
    private var cprCycleStartTime: TimeInterval = 0
    private var lastAdrenalineTime: TimeInterval?
    private var shockCountForAmiodarone1: Int?
    private var undoHistory: [UndoState] = []
    private var pauseStartTime: Date?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Computed Properties for UI Logic
    var totalArrestTime: TimeInterval { masterTime + timeOffset }
    var canUndo: Bool { !undoHistory.isEmpty }
    var arrestStartTime: Date? { startTime }

    var isAdrenalineAvailable: Bool {
        reversibleCauses.first(where: { $0.name == "Hypothermia" })?.hypothermiaStatus != .severe
    }

    // Buttons are unblocked, but mutual exclusion is maintained
    var isAmiodaroneAvailable: Bool {
        return antiarrhythmicGiven != .lidocaine && isAdrenalineAvailable
    }

    var isLidocaineAvailable: Bool {
        return antiarrhythmicGiven != .amiodarone
    }
    
    var timeUntilAdrenaline: TimeInterval? {
        guard let lastAdrenalineTime = lastAdrenalineTime else { return nil }
        let hypothermiaStatus = reversibleCauses.first { $0.name == "Hypothermia" }?.hypothermiaStatus
        let interval = hypothermiaStatus == .moderate ? AppSettings.adrenalineInterval * 2 : AppSettings.adrenalineInterval
        let timeSince = totalArrestTime - lastAdrenalineTime
        return interval - timeSince
    }

    var shouldShowAmiodaroneFirstDosePrompt: Bool {
        // STRICT LOGIC: Banner only shows after 3rd shock
        return shockCount >= 3 && amiodaroneCount == 0 && !hideAmiodaronePrompt && antiarrhythmicGiven != .lidocaine && isAdrenalineAvailable
    }

    var shouldShowAmiodaroneReminder: Bool {
        // STRICT LOGIC: Banner only shows 2 shocks AFTER the 1st dose was logged
        guard let shockCountDose1 = shockCountForAmiodarone1 else { return false }
        return amiodaroneCount == 1 && shockCount >= (shockCountDose1 + 2) && !hideAmiodaronePrompt
    }
    
    var shouldShowAdrenalinePrompt: Bool {
        guard isAdrenalineAvailable && !hideAdrenalinePrompt else { return false }
        if let timeUntil = timeUntilAdrenaline, timeUntil <= 0 { return false }
        if adrenalineCount == 0 {
            if shockCount >= 3 { return true }
            if lastRhythmNonShockable { return true }
        }
        return false
    }
    
    // MARK: - Core Timer Logic
    private func startTimer() {
        stopTimer()
        cprCycleStartTime = totalArrestTime
        
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
    
    func pauseArrest() {
        saveUndoState()
        isTimerPaused = true
        pauseStartTime = Date()
        stopTimer()
        logEvent("Arrest Timer Paused", type: .status)
    }
    
    func resumeArrest() {
        saveUndoState()
        isTimerPaused = false
        if let pauseStart = pauseStartTime, let start = startTime {
            let pausedDuration = Date().timeIntervalSince(pauseStart)
            startTime = start.addingTimeInterval(pausedDuration)
        }
        pauseStartTime = nil
        startTimer()
        logEvent("Arrest Timer Resumed", type: .status)
    }

    private func tick() {
        guard let startTime = startTime, !isTimerPaused else { return }
        
        Task { @MainActor in
            self.masterTime = Date().timeIntervalSince(startTime)
            
            if self.arrestState == .active && self.uiState == .default {
                let oldCprTime = self.cprTime
                let cycleDuration = self.arrestType == .general ? AppSettings.cprCycleDuration : self.nlsCycleDuration
                
                self.cprTime = cycleDuration - (self.totalArrestTime - self.cprCycleStartTime)

                if self.cprTime <= 10 && self.cprTime > 0 { HapticManager.shared.impact(style: .light) }
                if oldCprTime > 0 && self.cprTime <= 0 { HapticManager.shared.notification(type: .warning) }
                if self.cprTime <= 0 && !self.isRhythmCheckDue { self.isRhythmCheckDue = true }
                
                if self.cprTime < -0.9 {
                    self.cprCycleStartTime = self.totalArrestTime
                    self.cprTime = cycleDuration
                }
            }
        }
    }

    // MARK: - User Actions
    func startArrest() {
        saveUndoState()
        startTime = Date()
        isTimerPaused = false
        pauseStartTime = nil
        arrestType = .general
        arrestState = .active
        initialRhythm = nil
        logEvent("Arrest Started at \(Date().formatted(date: .omitted, time: .standard))", type: .status)
        startTimer()
        
        if AppSettings.researchModeEnabled || AppSettings.askForPatientInfo {
            showPatientInfoPrompt = true
        }
    }
    
    func startNewbornArrest(isPreterm: Bool) {
        saveUndoState()
        startTime = Date()
        isTimerPaused = false
        pauseStartTime = nil
        arrestType = .newborn
        self.isPreterm = isPreterm
        self.patientAgeCategory = .atBirth
        self.patientAgeStr = "Newborn"
        arrestState = .active
        nlsState = .initialAssessment
        nlsCycleDuration = 60
        cprTime = 60
        
        let typeStr = isPreterm ? "Preterm (<32w) Life Support" : "Newborn (Term) Life Support"
        logEvent("\(typeStr) Started (Birth) at \(Date().formatted(date: .omitted, time: .standard))", type: .status)
        
        if isPreterm {
            logEvent("Placed in plastic bag + radiant heat.", type: .status)
        } else {
            logEvent("Dried and wrapped. Stimulated.", type: .status)
        }
        
        startTimer()
    }
    
    func analyseRhythm() {
        saveUndoState()
        hideAdrenalinePrompt = false
        uiState = .analyzing
        lastRhythmNonShockable = false
        isRhythmCheckDue = false
        logEvent("Rhythm analysis. Pausing CPR.", type: .analysis)
    }
    
    func logRhythm(_ rhythm: String, isShockable: Bool) {
        saveUndoState()
        if initialRhythm == nil { initialRhythm = rhythm }
        logEvent("Rhythm is \(rhythm)", type: .rhythm)
        lastRhythmNonShockable = !isShockable
        if !isShockable { hideAdrenalinePrompt = false }
        if isShockable {
            uiState = .shockAdvised
        } else {
            resumeCPR()
        }
    }
    
    func deliverShock() {
        saveUndoState()
        shockCount += 1
        hideAdrenalinePrompt = false
        hideAmiodaronePrompt = false
        logEvent("Shock \(shockCount) Delivered", type: .shock)
        resumeCPR()
    }
    
    private func resumeCPR() {
        uiState = .default
        cprCycleStartTime = totalArrestTime
        cprTime = AppSettings.cprCycleDuration
        isRhythmCheckDue = false
        logEvent("Resuming CPR.", type: .cpr)
    }

    func logAdrenaline(with dosage: String? = nil) {
        saveUndoState()
        adrenalineCount += 1
        lastAdrenalineTime = totalArrestTime
        lastRhythmNonShockable = false
        let dosageText = (AppSettings.showDosagePrompts && dosage != nil) ? " (\(dosage!))" : ""
        logEvent("Adrenaline\(dosageText) Given - Dose \(adrenalineCount)", type: .drug)
        hideAdrenalinePrompt = false
        hideAdrenalineDueWarning = false // Reset swipe dismiss!
    }
    
    func logAmiodarone(with dosage: String? = nil) {
        saveUndoState()
        amiodaroneCount += 1
        antiarrhythmicGiven = .amiodarone
        if amiodaroneCount == 1 { shockCountForAmiodarone1 = shockCount }
        let dosageText = (AppSettings.showDosagePrompts && dosage != nil) ? " (\(dosage!))" : ""
        logEvent("Amiodarone\(dosageText) Given - Dose \(amiodaroneCount)", type: .drug)
        hideAmiodaronePrompt = false
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
        airwayAdjunct = nil
        logEvent("Advanced Airway Placed", type: .airway)
    }
    
    func logAirwayPlaced(type: AirwayAdjunctType) {
        saveUndoState()
        airwayPlaced = true
        airwayAdjunct = type
        logEvent("Advanced Airway Placed - \(type.displayName)", type: .airway)
    }
    
    func logVascularAccess(type: String, location: String, gauge: String, successful: Bool) {
        saveUndoState()
        if successful { vascularAccessPlaced = true }
        let status = successful ? "Successful" : "Unsuccessful"
        
        var details = [String]()
        if !location.isEmpty { details.append(location) }
        if !gauge.isEmpty { details.append(gauge) }
        let detailsStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
        
        logEvent("\(type) Access\(detailsStr) - \(status)", type: .status)
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
        isRhythmCheckDue = false
        roscTime = totalArrestTime
        logEvent(arrestType == .newborn ? "HR > 100 / Spontaneous Breathing Established" : "Return of Spontaneous Circulation (ROSC)", type: .status)
    }
    
    func endArrest() {
        saveUndoState()
        arrestState = .ended
        isTimerPaused = false
        stopTimer()
        logEvent(arrestType == .newborn ? "Resuscitation Ended" : "Termination of Resuscitation (TOR)", type: .status)
    }
    
    // Verification of Death
    func logVOD() {
        saveUndoState()
        vodConfirmed = true
        logEvent("Verification of Death (VOD) Confirmed", type: .status)
    }
    
    func reArrest() {
        saveUndoState()
        arrestState = .active
        cprCycleStartTime = totalArrestTime
        
        if arrestType == .newborn {
            arrestType = .general
            cprTime = AppSettings.cprCycleDuration
            logEvent("Baby Stopped Breathing. Transitioning to Paediatric ALS.", type: .status)
        } else {
            cprTime = AppSettings.cprCycleDuration
            logEvent("Patient Re-Arrested. CPR Resumed.", type: .status)
        }
        if !isTimerPaused { startTimer() }
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
    
    // MARK: - Newborn Specific Actions
    func logNLSAction(_ title: String) {
        saveUndoState()
        logEvent(title, type: .status)
    }
    
    func resetNLSTimer() {
        cprCycleStartTime = totalArrestTime
        cprTime = nlsCycleDuration
        isRhythmCheckDue = false
    }
    
    func advanceNLS(to state: NLSState) {
        saveUndoState()
        nlsState = state
        isRhythmCheckDue = false
        
        switch state {
        case .initialAssessment:
            cprTime = 60
            nlsCycleDuration = 60
            logEvent("Returned to Initial Assessment", type: .status)
        case .inflationBreaths:
            cprTime = 30; nlsCycleDuration = 30; logEvent("Moved to Airway & Inflation Breaths", type: .airway)
        case .optimiseAirway:
            cprTime = 30; nlsCycleDuration = 30; logEvent("Moved to Optimise Airway Troubleshooting", type: .airway)
        case .advancedAirway:
            cprTime = 30; nlsCycleDuration = 30; logEvent("Moved to Advanced Airway interventions", type: .airway)
        case .ventilation:
            cprTime = 30; nlsCycleDuration = 30; logEvent("Started Ventilation Breaths (30/min)", type: .airway)
        case .continueVentilation:
            cprTime = 30; nlsCycleDuration = 30; logEvent("Continuing Ventilation (HR ≥ 60)", type: .airway)
        case .compressions:
            cprTime = 30; nlsCycleDuration = 30; logEvent("Started Chest Compressions (3:1 Ratio, 100% O2)", type: .cpr)
        }
        cprCycleStartTime = totalArrestTime
    }
    
    func reassessPatient() {
        saveUndoState()
        resetNLSTimer()
        logEvent("Reassessed Patient HR and Chest Rise", type: .status)
    }
    
    // MARK: - Undo & Session Transfer Logic
    func generateTransferState() -> UndoState? {
        saveUndoState()
        return undoHistory.last
    }
    
    private func saveUndoState() {
        do {
            let eventsData = try JSONEncoder().encode(events.map { EventCodable(from: $0) })
            
            let currentState = UndoState(
                arrestState: arrestState, arrestType: arrestType, isPreterm: isPreterm, nlsState: nlsState, masterTime: masterTime, cprTime: cprTime, timeOffset: timeOffset,
                nlsCycleDuration: nlsCycleDuration, isRhythmCheckDue: isRhythmCheckDue, eventsData: eventsData, shockCount: shockCount, adrenalineCount: adrenalineCount,
                amiodaroneCount: amiodaroneCount, lidocaineCount: lidocaineCount,
                lastAdrenalineTime: lastAdrenalineTime, antiarrhythmicGiven: antiarrhythmicGiven,
                shockCountForAmiodarone1: shockCountForAmiodarone1, airwayPlaced: airwayPlaced,
                reversibleCauses: reversibleCauses, postROSCTasks: postROSCTasks,
                postMortemTasks: postMortemTasks, nlsPretermTasks: nlsPretermTasks, startTime: startTime, uiState: uiState,
                patientAgeCategory: patientAgeCategory,
                hideAdrenalinePrompt: hideAdrenalinePrompt, hideAmiodaronePrompt: hideAmiodaronePrompt,
                lastRhythmNonShockable: lastRhythmNonShockable, airwayAdjunct: airwayAdjunct, roscTime: roscTime,
                isTimerPaused: isTimerPaused, pauseStartTime: pauseStartTime,
                initialRhythm: initialRhythm, patientAgeStr: patientAgeStr, patientGenderStr: patientGenderStr
            )
            undoHistory.append(currentState)
        } catch {
            print("Failed to save undo state: \(error)")
        }
    }
    
    func undo() {
        guard let lastState = undoHistory.popLast() else { return }
        applyState(lastState)
    }
    
    func restoreFromTransfer(state: UndoState) {
        stopTimer()
        applyState(state)
        logEvent("Session Transferred from another device", type: .status)
        undoHistory.removeAll()
    }
    
    private func applyState(_ state: UndoState) {
        do {
            let decodedEvents = try JSONDecoder().decode([EventCodable].self, from: state.eventsData)
            events = decodedEvents.map { $0.toEvent() }
            
            arrestState = state.arrestState
            arrestType = state.arrestType
            isPreterm = state.isPreterm
            nlsState = state.nlsState
            masterTime = state.masterTime
            cprTime = state.cprTime
            timeOffset = state.timeOffset
            nlsCycleDuration = state.nlsCycleDuration
            isRhythmCheckDue = state.isRhythmCheckDue
            shockCount = state.shockCount
            adrenalineCount = state.adrenalineCount
            amiodaroneCount = state.amiodaroneCount
            lidocaineCount = state.lidocaineCount
            lastAdrenalineTime = state.lastAdrenalineTime
            antiarrhythmicGiven = state.antiarrhythmicGiven
            shockCountForAmiodarone1 = state.shockCountForAmiodarone1
            airwayPlaced = state.airwayPlaced
            reversibleCauses = state.reversibleCauses
            postROSCTasks = state.postROSCTasks
            postMortemTasks = state.postMortemTasks
            nlsPretermTasks = state.nlsPretermTasks
            startTime = state.startTime
            uiState = state.uiState
            patientAgeCategory = state.patientAgeCategory
            hideAdrenalinePrompt = state.hideAdrenalinePrompt ?? false
            hideAmiodaronePrompt = state.hideAmiodaronePrompt ?? false
            lastRhythmNonShockable = state.lastRhythmNonShockable ?? false
            airwayAdjunct = state.airwayAdjunct
            roscTime = state.roscTime
            isTimerPaused = state.isTimerPaused ?? false
            pauseStartTime = state.pauseStartTime
            initialRhythm = state.initialRhythm
            patientAgeStr = state.patientAgeStr ?? ""
            patientGenderStr = state.patientGenderStr ?? ""
            
            vascularAccessPlaced = events.contains { $0.message.contains("Access") && $0.message.contains("Successful") }
            vodConfirmed = events.contains { $0.message.contains("Verification of Death") }
            
            if vodConfirmed {
                vodTasks.indices.forEach { vodTasks[$0].isCompleted = true }
            } else {
                vodTasks.indices.forEach { vodTasks[$0].isCompleted = false }
            }
            
            if (arrestState == .active || arrestState == .rosc) && !isTimerPaused && timer == nil {
                startTimer()
            } else if arrestState == .pending || arrestState == .ended || isTimerPaused {
                stopTimer()
            }
        } catch {
            print("Failed to restore state: \(error)")
        }
    }

    func performReset(shouldSaveLog: Bool, shouldCopy: Bool) {
        if shouldSaveLog && startTime != nil {
            saveLogToDatabase()
        }
        
        stopTimer()
        arrestState = .pending
        arrestType = .general
        isPreterm = false
        nlsState = .initialAssessment
        masterTime = 0
        cprTime = AppSettings.cprCycleDuration
        timeOffset = 0
        nlsCycleDuration = 60
        isRhythmCheckDue = false
        uiState = .default
        events = []
        shockCount = 0
        adrenalineCount = 0
        amiodaroneCount = 0
        lidocaineCount = 0
        airwayPlaced = false
        vascularAccessPlaced = false
        antiarrhythmicGiven = .none
        lastAdrenalineTime = nil
        shockCountForAmiodarone1 = nil
        startTime = nil
        isTimerPaused = false
        pauseStartTime = nil
        undoHistory = []
        patientAgeCategory = nil
        reversibleCauses = AppConstants.reversibleCausesTemplate
        postROSCTasks = AppConstants.postROSCTasksTemplate
        postMortemTasks = AppConstants.postMortemTasksTemplate
        nlsPretermTasks = AppConstants.nlsPretermTasksTemplate
        hideAdrenalinePrompt = false
        hideAmiodaronePrompt = false
        hideAdrenalineDueWarning = false
        lastRhythmNonShockable = false
        airwayAdjunct = nil
        roscTime = nil
        patientAgeStr = ""
        patientGenderStr = ""
        initialRhythm = nil
        showPatientInfoPrompt = false
        
        vodConfirmed = false
        vodTasks.indices.forEach { vodTasks[$0].isCompleted = false }
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
            events: [],
            shockCount: shockCount,
            adrenalineCount: adrenalineCount,
            amiodaroneCount: amiodaroneCount,
            roscTime: roscTime,
            patientAge: patientAgeStr.isEmpty ? nil : patientAgeStr,
            patientGender: patientGenderStr.isEmpty ? nil : patientGenderStr,
            initialRhythm: initialRhythm,
            organization: AppSettings.userOrganization.isEmpty ? nil : AppSettings.userOrganization,
            isSynced: false
        )
        modelContext.insert(newLog)
        
        for event in events {
            let newEvent = Event(timestamp: event.timestamp, message: event.message, type: event.type)
            newEvent.log = newLog
            modelContext.insert(newEvent)
        }
        try? modelContext.save()
        
        if AppSettings.researchModeEnabled {
            FirebaseManager.shared.uploadLog(newLog, events: events)
            newLog.isSynced = true
        }
    }
    
    func syncOfflineLogs() {
        guard AppSettings.researchModeEnabled else { return }
        let descriptor = FetchDescriptor<SavedArrestLog>(predicate: #Predicate { $0.isSynced == false })
        do {
            let unsyncedLogs = try modelContext.fetch(descriptor)
            for log in unsyncedLogs {
                FirebaseManager.shared.uploadLog(log, events: log.events)
                log.isSynced = true
            }
            try modelContext.save()
        } catch {
            print("Failed to sweep offline logs: \(error.localizedDescription)")
        }
    }
    
    private func logEvent(_ message: String, type: EventType) {
        let timestamp: TimeInterval
        if let start = startTime, arrestState == .ended {
            timestamp = Date().timeIntervalSince(start) + timeOffset
        } else {
            timestamp = totalArrestTime
        }
        let newEvent = Event(timestamp: timestamp, message: message, type: type)
        events.insert(newEvent, at: 0)
        HapticManager.shared.impact()
    }
}

