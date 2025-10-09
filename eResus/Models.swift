//
//  Models.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - App Constants & Settings
struct AppSettings {
    @AppStorage("cprCycleDuration") static var cprCycleDuration: TimeInterval = 120
    @AppStorage("adrenalineInterval") static var adrenalineInterval: TimeInterval = 240
    @AppStorage("metronomeBPM") static var metronomeBPM: Double = 110
    
    static let hypothermicAdrenalineInterval: TimeInterval = 480
}

struct AppConstants {
    static let reversibleCauses: [ChecklistItem] = [
        ChecklistItem(name: "Hypoxia"), ChecklistItem(name: "Hypovolemia"),
        ChecklistItem(name: "Hypo/Hyperkalaemia"), ChecklistItem(name: "Hypothermia"),
        ChecklistItem(name: "Toxins"), ChecklistItem(name: "Tamponade"),
        ChecklistItem(name: "Tension Pneumothorax"), ChecklistItem(name: "Thrombosis")
    ]
    
    static let postROSCTasks: [ChecklistItem] = [
        ChecklistItem(name: "Optimise Ventilation & Oxygenation"), ChecklistItem(name: "12-Lead ECG"),
        ChecklistItem(name: "Treat Hypotension (SBP < 90)"), ChecklistItem(name: "Check Blood Glucose"),
        ChecklistItem(name: "Consider Temperature Control"), ChecklistItem(name: "Identify & Treat Causes")
    ]
    
    static let postMortemTasks: [ChecklistItem] = [
        ChecklistItem(name: "Reposition body & remove lines/tubes"), ChecklistItem(name: "Complete documentation"),
        ChecklistItem(name: "Determine expected/unexpected death"), ChecklistItem(name: "Contact Coroner (if unexpected)"),
        ChecklistItem(name: "Follow local body handling procedure"), ChecklistItem(name: "Provide leaflet to bereaved relatives"),
        ChecklistItem(name: "Consider organ/tissue donation")
    ]
    
    static let otherMedications: [String] = [
        "Adenosine", "Adrenaline 1:1000", "Adrenaline 1:10,000", "Amiodarone (Further Dose)",
        "Atropine", "Calcium chloride", "Glucose", "Hartmann’s solution", "Magnesium sulphate",
        "Midazolam", "Naloxone", "Potassium chloride", "Sodium bicarbonate",
        "Sodium chloride", "Tranexamic acid"
    ].sorted()
}


// MARK: - Core Data Models
@Model
final class SavedArrestLog {
    var startTime: Date
    var endTime: Date
    var totalDuration: TimeInterval
    var outcome: String
    @Relationship(deleteRule: .cascade, inverse: \Event.log)
    var events: [Event] = []

    init(startTime: Date, endTime: Date, totalDuration: TimeInterval, outcome: String, events: [Event]) {
        self.startTime = startTime
        self.endTime = endTime
        self.totalDuration = totalDuration
        self.outcome = outcome
        self.events = events
    }
}

@Model
final class Event: Identifiable, Hashable {
    @Attribute(.unique) let id: UUID
    var timestamp: TimeInterval
    var message: String
    private var typeName: String
    var log: SavedArrestLog?

    init(id: UUID = UUID(), timestamp: TimeInterval, message: String, type: EventType) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.typeName = type.rawValue
    }
    
    var type: EventType {
        get { EventType(rawValue: self.typeName) ?? .status }
        set { self.typeName = newValue.rawValue }
    }
    
    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Enums and Structs
enum ArrestState: String, Codable {
    case pending = "PENDING"
    case active = "ACTIVE"
    case rosc = "ROSC"
    case ended = "ENDED"

    var color: Color {
        switch self {
        case .pending: return .gray
        case .active: return .red
        case .rosc: return .green
        case .ended: return .gray
        }
    }
}

enum UIState: Codable {
    case `default`, analyzing, shockAdvised
}

enum EventType: String, Codable {
    case status, cpr, shock, analysis, rhythm, drug, airway, etco2, cause

    var color: Color {
        switch self {
        case .status: return .green
        case .cpr: return .cyan
        case .shock: return .orange
        case .analysis: return .blue
        case .rhythm: return .purple
        case .drug: return .red
        case .airway: return .indigo
        case .etco2: return .teal
        case .cause: return .secondary
        }
    }
}

enum HypothermiaStatus: String, Codable {
    case none, severe, moderate, normothermic
}

struct ChecklistItem: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var isCompleted: Bool = false
    var hypothermiaStatus: HypothermiaStatus = .none
}

struct UndoState {
    var arrestState: ArrestState
    var uiState: UIState
    var events: [Event]
    var shockCount: Int
    var adrenalineCount: Int
    var amiodaroneCount: Int
    var lidocaineCount: Int
    var airwayPlaced: Bool
    var reversibleCauses: [ChecklistItem]
    var postROSCTasks: [ChecklistItem]
    var postMortemTasks: [ChecklistItem]
    var timeOffset: TimeInterval
    var shockCountOnAmiodarone1: Int?
    var lastAdrenalineTime: TimeInterval?
    var masterTime: TimeInterval
    var startTime: Date?
    var cprCycleStartTime: TimeInterval
}
