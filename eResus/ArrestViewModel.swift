//
//  ArrestViewModel.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
class ArrestViewModel: ObservableObject {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Published State Properties
    @Published var arrestState: ArrestState = .pending
    @Published var uiState: UIState = .default
    @Published var masterTime: TimeInterval = 0
    @Published var timeOffset: TimeInterval = 0
    @Published var cprTimeRemaining: TimeInterval = AppSettings.cprCycleDuration
    @Published var events: [Event] = []

    @Published var shockCount: Int = 0
    @Published var adrenalineCount: Int = 0
    @Published var amiodaroneCount: Int = 0
    @Published var lidocaineCount: Int = 0
    @Published var airwayPlaced: Bool = false
    
    @Published var shockCountOnAmiodarone1: Int? = nil

    @Published var reversibleCauses: [ChecklistItem] = AppConstants.reversibleCauses
    @Published var postROSCTasks: [ChecklistItem] = AppConstants.postROSCTasks
    @Published var postMortemTasks: [ChecklistItem] = AppConstants.postMortemTasks

    @Published var isShowingSummary = false
    @Published var isShowingResetModal = false
    @Published var isShowingEtco2Input = false
    @Published var isShowingHypothermiaInput = false
    @Published var isShowingOtherDrugs = false
    @Published var isMetronomeOn = false
    
    // For local PDF viewing
    @Published var selectedPDF: (name: String, title: String)? = nil
    var isShowingPDF: Binding<Bool> {
        Binding(
            get: { self.selectedPDF != nil },
            set: { if !$0 { self.selectedPDF = nil } }
        )
    }

    // MARK: - Private Properties
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var cprCycleStartTime: TimeInterval = 0
    var lastAdrenalineTime: TimeInterval?
    private var undoHistory: [UndoState] = []
    private let metronome = Metronome()
    
    // MARK: - Computed Properties
    var totalElapsedTime: TimeInterval { masterTime + timeOffset }

    var isAdrenalineDue: Bool {
        guard let lastAdrenalineTime = lastAdrenalineTime else { return false }
        return (totalElapsedTime - lastAdrenalineTime) >= currentAdrenalineInterval
    }
    
    var timeToNextAdrenaline: TimeInterval {
        guard let lastAdrenalineTime = lastAdrenalineTime else { return 0 }
        let timeRemaining = currentAdrenalineInterval - (totalElapsedTime - lastAdrenalineTime)
        return max(0, timeRemaining)
    }
    
    var hypothermiaStatus: HypothermiaStatus {
        reversibleCauses.first(where: { $0.name == "Hypothermia" })?.hypothermiaStatus ?? .none
    }
    
    var isAmiodaroneEnabled: Bool { shockCount >= 3 && amiodaroneCount < 2 && lidocaineCount == 0 && hypothermiaStatus != .severe }
    var isLidocaineEnabled: Bool { shockCount >= 3 && lidocaineCount < 2 && amiodaroneCount == 0 }
    var isAdrenalineEnabled: Bool { hypothermiaStatus != .severe }
    
    var showAmiodaroneDose2Reminder: Bool {
        guard let shockCountOnAmiodarone1 = shockCountOnAmiodarone1 else { return false }
        return amiodaroneCount == 1 && shockCount >= shockCountOnAmiodarone1 + 2
    }
    
    private var currentAdrenalineInterval: TimeInterval {
        hypothermiaStatus == .moderate ? AppSettings.hypothermicAdrenalineInterval : AppSettings.adrenalineInterval
    }
    
    var canUndo: Bool { !undoHistory.isEmpty }

    // MARK: - Core Logic
    func addTimeOffset(_ offset: TimeInterval) {
        saveStateForUndo()
        timeOffset += offset
        logEvent("Time offset added: +\(Int(offset / 60)) min", type: .status)
    }

    func startArrest() {
        saveStateForUndo()
        startTime = Date()
        masterTime = 0 // Fix: Start master time at exactly 0
        arrestState = .active
        cprCycleStartTime = timeOffset
        cprTimeRemaining = AppSettings.cprCycleDuration
        logEvent("Arrest Started at \(Date().formatted(date: .omitted, time: .standard))", type: .status)
        
        startTimerIfNeeded()
        HapticManager.shared.trigger(.success)
    }

    private func tick() {
        guard let startTime = startTime, arrestState == .active || arrestState == .rosc else { return }
        
        masterTime = Date().timeIntervalSince(startTime)
        
        if arrestState == .active {
            let timeSinceCycleStart = totalElapsedTime - cprCycleStartTime
            cprTimeRemaining = AppSettings.cprCycleDuration - timeSinceCycleStart
            
            if cprTimeRemaining > 0 && cprTimeRemaining <= 10 { HapticManager.shared.impact(.light) }
            if cprTimeRemaining < 0 { startNewCPRCycle() }
            if isAdrenalineDue { HapticManager.shared.trigger(.warning) }
        }
    }
    
    func startRhythmAnalysis() {
        saveStateForUndo()
        uiState = .analyzing
        logEvent("Rhythm Analysis Paused", type: .analysis)
    }
    
    func logRhythm(type: String, isShockable: Bool) {
        saveStateForUndo()
        logEvent("Rhythm is \(type)", type: .rhythm)
        uiState = isShockable ? .shockAdvised : .default
        if !isShockable { startNewCPRCycle() }
    }
    
    func deliverShock() {
        saveStateForUndo()
        shockCount += 1
        logEvent("Shock \(shockCount) Delivered. Resuming CPR.", type: .shock)
        uiState = .default
        startNewCPRCycle()
        HapticManager.shared.trigger(.success)
    }

    func logAdrenaline() {
        saveStateForUndo()
        adrenalineCount += 1
        lastAdrenalineTime = totalElapsedTime
        logEvent("Adrenaline (1mg) Given - Dose \(adrenalineCount)", type: .drug)
    }

    func logAmiodarone() {
        saveStateForUndo()
        amiodaroneCount += 1
        if amiodaroneCount == 1 {
            shockCountOnAmiodarone1 = shockCount
            logEvent("Amiodarone (300mg) Given - Dose 1", type: .drug)
        } else {
            logEvent("Amiodarone (150mg) Given - Dose 2", type: .drug)
        }
    }
    
    func logLidocaine() {
        saveStateForUndo()
        lidocaineCount += 1
        logEvent("Lidocaine Given - Dose \(lidocaineCount)", type: .drug)
    }
    
    func logOtherDrug(_ drug: String) {
        saveStateForUndo()
        logEvent("\(drug) Given", type: .drug)
    }
    
    func logAirway() {
        saveStateForUndo()
        airwayPlaced = true
        logEvent("Advanced Airway Placed", type: .airway)
    }
    
    func logEtco2(value: String) {
        guard !value.isEmpty, let numValue = Int(value) else { return }
        saveStateForUndo()
        logEvent("ETCO2: \(numValue) mmHg", type: .etco2)
    }

    func achieveROSC() {
        saveStateForUndo()
        arrestState = .rosc
        logEvent("Return of Spontaneous Circulation (ROSC)", type: .status)
        HapticManager.shared.trigger(.success)
    }
    
    func reArrest() {
        saveStateForUndo()
        arrestState = .active
        startNewCPRCycle()
        logEvent("Patient Re-Arrested. CPR Resumed.", type: .status)
    }

    func endArrest() {
        saveStateForUndo()
        arrestState = .ended
        timer?.cancel()
        logEvent("Arrest Ended (Patient Deceased)", type: .status)
    }

    func performReset(shouldSaveLog: Bool, shouldCopy: Bool) {
        if shouldCopy {
            copySummaryToClipboard()
        }
        
        if shouldSaveLog {
            let outcome: String
            switch arrestState {
            case .rosc: outcome = "ROSC"
            case .ended: outcome = "Deceased"
            default: outcome = "Incomplete"
            }
            saveLog(outcome: outcome)
        }
        
        arrestState = .pending
        uiState = .default
        masterTime = 0
        timeOffset = 0
        cprTimeRemaining = AppSettings.cprCycleDuration
        events = []
        shockCount = 0
        adrenalineCount = 0
        amiodaroneCount = 0
        lidocaineCount = 0
        airwayPlaced = false
        shockCountOnAmiodarone1 = nil
        reversibleCauses = AppConstants.reversibleCauses
        postROSCTasks = AppConstants.postROSCTasks
        postMortemTasks = AppConstants.postMortemTasks
        timer?.cancel()
        startTime = nil
        lastAdrenalineTime = nil
        undoHistory.removeAll()
        if isMetronomeOn { toggleMetronome() }
        HapticManager.shared.trigger(.warning)
    }

    func setHypothermiaStatus(_ status: HypothermiaStatus) {
        saveStateForUndo()
        if let index = reversibleCauses.firstIndex(where: { $0.name == "Hypothermia" }) {
            reversibleCauses[index].hypothermiaStatus = status
            reversibleCauses[index].isCompleted = (status != .none)
            let message: String
            switch status {
            case .severe: message = "Hypothermia status set to: Severe (< 30°C)"
            case .moderate: message = "Hypothermia status set to: Moderate (30-35°C)"
            case .normothermic: message = "Hypothermia status cleared (Normothermic)"
            case .none: message = "Hypothermia status cleared"
            }
            logEvent(message, type: .cause)
        }
    }
    
    func toggleMetronome() {
        isMetronomeOn.toggle()
        isMetronomeOn ? metronome.start() : metronome.stop()
    }
    
    func toggleChecklistItem(id: UUID, list: Binding<[ChecklistItem]>) {
        saveStateForUndo()
        if let index = list.wrappedValue.firstIndex(where: { $0.id == id }) {
            list.wrappedValue[index].isCompleted.toggle()
        }
    }

    func undo() {
        guard let previousState = undoHistory.popLast() else { return }
        
        let oldState = self.arrestState
        
        self.arrestState = previousState.arrestState
        self.uiState = previousState.uiState
        self.events = previousState.events
        self.shockCount = previousState.shockCount
        self.adrenalineCount = previousState.adrenalineCount
        self.amiodaroneCount = previousState.amiodaroneCount
        self.lidocaineCount = previousState.lidocaineCount
        self.airwayPlaced = previousState.airwayPlaced
        self.reversibleCauses = previousState.reversibleCauses
        self.postROSCTasks = previousState.postROSCTasks
        self.postMortemTasks = previousState.postMortemTasks
        self.timeOffset = previousState.timeOffset
        self.shockCountOnAmiodarone1 = previousState.shockCountOnAmiodarone1
        self.lastAdrenalineTime = previousState.lastAdrenalineTime
        self.masterTime = previousState.masterTime
        self.startTime = previousState.startTime
        self.cprCycleStartTime = previousState.cprCycleStartTime
        
        if (oldState == .ended || oldState == .rosc) && (self.arrestState == .active || self.arrestState == .rosc) {
            startTimerIfNeeded()
        }
    }
    
    func copySummaryToClipboard() {
        var text = "eResus Event Summary\n"
        if !events.isEmpty {
            text += "Total Arrest Time: \(formatTime(totalElapsedTime))\n\n"
        }
        text += "--- Event Log ---\n"
        text += events.reversed().map { event in
            "[\(formatTime(event.timestamp))] \(event.message)"
        }.joined(separator: "\n")
        
        UIPasteboard.general.string = text
    }
    
    private func saveStateForUndo() {
        let currentState = UndoState(
            arrestState: self.arrestState, uiState: self.uiState, events: self.events,
            shockCount: self.shockCount, adrenalineCount: self.adrenalineCount,
            amiodaroneCount: self.amiodaroneCount, lidocaineCount: self.lidocaineCount,
            airwayPlaced: self.airwayPlaced, reversibleCauses: self.reversibleCauses,
            postROSCTasks: self.postROSCTasks, postMortemTasks: self.postMortemTasks,
            timeOffset: self.timeOffset, shockCountOnAmiodarone1: self.shockCountOnAmiodarone1,
            lastAdrenalineTime: self.lastAdrenalineTime, masterTime: self.masterTime,
            startTime: self.startTime, cprCycleStartTime: self.cprCycleStartTime
        )
        undoHistory.append(currentState)
    }
    
    private func startTimerIfNeeded() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }
    }
    
    private func startNewCPRCycle() {
        cprCycleStartTime = totalElapsedTime
        cprTimeRemaining = AppSettings.cprCycleDuration
        logEvent("New CPR Cycle Started", type: .cpr)
        HapticManager.shared.trigger(.success)
    }

    private func logEvent(_ message: String, type: EventType) {
        let newEvent = Event(timestamp: totalElapsedTime, message: message, type: type)
        events.insert(newEvent, at: 0)
    }
    
    private func saveLog(outcome: String) {
        guard let startTime = startTime, !events.isEmpty else { return }
        let log = SavedArrestLog(
            startTime: startTime,
            endTime: Date(),
            totalDuration: totalElapsedTime,
            outcome: outcome,
            events: events
        )
        modelContext.insert(log)
        try? modelContext.save()
    }
}
