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
    @Published var hideAmiodaronePrompt: Bool = false
    @Published var lastRhythmNonShockable: Bool = false
    @Published var airwayAdjunct: AirwayAdjunctType? = nil
    @Published var roscTime: TimeInterval? = nil
    
    @Published var airwayPlaced = false
    @Published var antiarrhythmicGiven: AntiarrhythmicDrug = .none
    
    @Published var reversibleCauses: [ChecklistItem] = AppConstants.reversibleCausesTemplate
    @Published var postROSCTasks: [ChecklistItem] = AppConstants.postROSCTasksTemplate
    @Published var postMortemTasks: [ChecklistItem] = AppConstants.postMortemTasksTemplate
    @Published var nlsPretermTasks: [ChecklistItem] = AppConstants.nlsPretermTasksTemplate
    @Published var patientAgeCategory: PatientAgeCategory?
    
    @Published var isTimerPaused: Bool = false
    
    // MARK: - Private State Properties
    private var timer: Timer?
    private var startTime: Date?
    private var cprCycleStartTime: TimeInterval = 0
    private var lastAdrenalineTime: TimeInterval?
    private var shockCountForAmiodarone1: Int?
    private var undoHistory: [UndoState] = []
    
    // Used to calculate paused duration correctly
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
        return amiodaroneCount == 1 && shockCount >= shockCountDose1 + 2 && !hideAmiodaronePrompt
    }
    
    var shouldShowAmiodaroneFirstDosePrompt: Bool {
        return isAmiodaroneAvailable && amiodaroneCount == 0 && !hideAmiodaronePrompt
    }
    
    var shouldShowAdrenalinePrompt: Bool {
        guard isAdrenalineAvailable && !hideAdrenalinePrompt else { return false }
        
        // 1. Don't show the "Consider" prompt if the timer is already showing the critical "Due" warning
        if let timeUntil = timeUntilAdrenaline, timeUntil <= 0 {
            return false
        }
        
        // 2. Initial dose logic
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
            // Offset the startTime by the amount of time we were paused
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
            
            // Only update CPR time if arrest is active and we are not analyzing/shocking
            if self.arrestState == .active && self.uiState == .default {
                let oldCprTime = self.cprTime
                let cycleDuration = self.arrestType == .general ? AppSettings.cprCycleDuration : self.nlsCycleDuration
                
                self.cprTime = cycleDuration - (self.totalArrestTime - self.cprCycleStartTime)

                // Haptic for last 10 seconds
                if self.cprTime <= 10 && self.cprTime > 0 {
                    HapticManager.shared.impact(style: .light)
                }
                
                // Haptic for cycle end
                if oldCprTime > 0 && self.cprTime <= 0 {
                    HapticManager.shared.notification(type: .warning)
                }
                
                if self.cprTime <= 0 && !self.isRhythmCheckDue {
                    self.isRhythmCheckDue = true
                }
                
                if self.cprTime < -0.9 { // Add tolerance for timer drift
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
        logEvent("Arrest Started at \(Date().formatted(date: .omitted, time: .standard))", type: .status)
        startTimer()
    }
    
    func startNewbornArrest(isPreterm: Bool) {
        saveUndoState()
        startTime = Date()
        isTimerPaused = false
        pauseStartTime = nil
        arrestType = .newborn
        self.isPreterm = isPreterm
        self.patientAgeCategory = .atBirth // Set default age category for dosage logic
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
        logEvent(arrestType == .newborn ? "Resuscitation Ended" : "Arrest Ended (Patient Deceased)", type: .status)
    }
    
    func reArrest() {
        saveUndoState()
        arrestState = .active
        cprCycleStartTime = totalArrestTime
        
        if arrestType == .newborn {
            // Once a newborn achieves ROSC and re-arrests, transition to Paediatric ALS automatically
            arrestType = .general
            cprTime = AppSettings.cprCycleDuration
            logEvent("Baby Stopped Breathing. Transitioning to Paediatric ALS.", type: .status)
        } else {
            cprTime = AppSettings.cprCycleDuration
            logEvent("Patient Re-Arrested. CPR Resumed.", type: .status)
        }
        
        if !isTimerPaused {
            startTimer()
        }
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
            cprTime = 30
            nlsCycleDuration = 30
            logEvent("Moved to Airway & Inflation Breaths", type: .airway)
        case .optimiseAirway:
            cprTime = 30
            nlsCycleDuration = 30
            logEvent("Moved to Optimise Airway Troubleshooting", type: .airway)
        case .advancedAirway:
            cprTime = 30
            nlsCycleDuration = 30
            logEvent("Moved to Advanced Airway interventions", type: .airway)
        case .ventilation:
            cprTime = 30
            nlsCycleDuration = 30
            logEvent("Started Ventilation Breaths (30/min)", type: .airway)
        case .continueVentilation:
            cprTime = 30
            nlsCycleDuration = 30
            logEvent("Continuing Ventilation (HR ≥ 60)", type: .airway)
        case .compressions:
            cprTime = 30
            nlsCycleDuration = 30
            logEvent("Started Chest Compressions (3:1 Ratio, 100% O2)", type: .cpr)
        }
        
        cprCycleStartTime = totalArrestTime
    }
    
    func reassessPatient() {
        saveUndoState()
        resetNLSTimer()
        logEvent("Reassessed Patient HR and Chest Rise", type: .status)
    }
    
    // MARK: - Undo & Reset Logic
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
                isTimerPaused: isTimerPaused, pauseStartTime: pauseStartTime
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
            arrestType = lastState.arrestType
            isPreterm = lastState.isPreterm
            nlsState = lastState.nlsState
            masterTime = lastState.masterTime
            cprTime = lastState.cprTime
            timeOffset = lastState.timeOffset
            nlsCycleDuration = lastState.nlsCycleDuration
            isRhythmCheckDue = lastState.isRhythmCheckDue
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
            nlsPretermTasks = lastState.nlsPretermTasks
            startTime = lastState.startTime
            uiState = lastState.uiState
            patientAgeCategory = lastState.patientAgeCategory
            
            hideAdrenalinePrompt = lastState.hideAdrenalinePrompt ?? false
            hideAmiodaronePrompt = lastState.hideAmiodaronePrompt ?? false
            lastRhythmNonShockable = lastState.lastRhythmNonShockable ?? false
            airwayAdjunct = lastState.airwayAdjunct
            roscTime = lastState.roscTime
            
            isTimerPaused = lastState.isTimerPaused ?? false
            pauseStartTime = lastState.pauseStartTime
            
            if (arrestState == .active || arrestState == .rosc) && !isTimerPaused && timer == nil {
                startTimer()
            } else if arrestState == .pending || arrestState == .ended || isTimerPaused {
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
        lastRhythmNonShockable = false
        airwayAdjunct = nil
        roscTime = nil
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
            roscTime: roscTime
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
        let shocks = shockCount
        let adCount = adrenalineCount
        let amioCount = amiodaroneCount
        let lidocaineCount = lidocaineCount
        let roscText: String
        if let roscTime = roscTime {
            roscText = "ROSC at: \(TimeFormatter.format(roscTime)) (from start)"
        } else {
            roscText = "ROSC: Not achieved"
        }
        let startText = startTime != nil ? DateFormatter.localizedString(from: startTime!, dateStyle: .none, timeStyle: .short) : "Unknown"
        let header = """
        eResus Event Summary
        Start Time (clock): \(startText)
        Total Arrest Time: \(TimeFormatter.format(totalArrestTime))
        Shocks: \(shocks)  |  Adrenaline: \(adCount)  |  Amiodarone: \(amioCount)  |  Lidocaine: \(lidocaineCount)
        \(roscText)
        """
        let log = events.sorted(by: { $0.timestamp < $1.timestamp }).map { "[\(TimeFormatter.format($0.timestamp))] \($0.message)" }.joined(separator: "\n")
        let summaryText = header + "\n\n--- Event Log ---\n" + log
        UIPasteboard.general.string = summaryText
        HapticManager.shared.notification(type: .success)
    }
    
    private func logEvent(_ message: String, type: EventType) {
        let newEvent = Event(timestamp: totalArrestTime, message: message, type: type)
        events.insert(newEvent, at: 0)
        HapticManager.shared.impact()
    }
}

