//
//  Models.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Database Models
@Model
final class SavedArrestLog {
    var startTime: Date
    var totalDuration: TimeInterval
    var finalOutcome: String
    
    @Relationship(deleteRule: .cascade, inverse: \Event.log)
    var events: [Event]
    
    init(startTime: Date, totalDuration: TimeInterval, finalOutcome: String, events: [Event]) {
        self.startTime = startTime
        self.totalDuration = totalDuration
        self.finalOutcome = finalOutcome
        self.events = events
    }
}

@Model
final class Event {
    var id: UUID = UUID()
    var timestamp: TimeInterval
    var message: String
    var typeString: String
    
    var log: SavedArrestLog?
    
    init(id: UUID = UUID(), timestamp: TimeInterval, message: String, type: EventType) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.typeString = type.rawValue
    }
    
    var type: EventType {
        EventType(rawValue: typeString) ?? .status
    }
}


// MARK: - App State Enums
enum ArrestState: String, Codable {
    case pending = "PENDING"
    case active = "ACTIVE"
    case rosc = "ROSC"
    case ended = "DECEASED"
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .active: return .red
        case .rosc: return .green
        case .ended: return .black
        }
    }
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
        case .drug: return .pink
        case .airway: return .teal
        case .etco2: return .indigo
        case .cause: return .secondary
        }
    }
}

enum UIState: Codable {
    case `default`, analyzing, shockAdvised
}

enum AntiarrhythmicDrug: String, Codable {
    case none, amiodarone, lidocaine
}

enum HypothermiaStatus: String, Codable {
    case none, severe, moderate, normothermic
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: Self { self }
}

enum DrugToLog: Identifiable {
    case adrenaline
    case amiodarone
    case lidocaine
    case other(String)
    
    var id: String {
        switch self {
        case .adrenaline: return "adrenaline"
        case .amiodarone: return "amiodarone"
        case .lidocaine: return "lidocaine"
        case .other(let name): return "other-\(name)"
        }
    }
    
    var title: String {
        switch self {
        case .adrenaline: return "Adrenaline"
        case .amiodarone: return "Amiodarone"
        case .lidocaine: return "Lidocaine"
        case .other(let name): return name
        }
    }
}


// MARK: - UI & Data Structs

// A simple Codable version of Event for undo history
struct EventCodable: Codable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval
    let message: String
    let type: EventType
    
    init(from event: Event) {
        self.id = event.id
        self.timestamp = event.timestamp
        self.message = event.message
        self.type = event.type
    }
    
    func toEvent() -> Event {
        return Event(id: self.id, timestamp: self.timestamp, message: self.message, type: self.type)
    }
}


struct ChecklistItem: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    var isCompleted: Bool
    var hypothermiaStatus: HypothermiaStatus

    init(name: String, isCompleted: Bool = false, hypothermiaStatus: HypothermiaStatus = .none) {
        self.id = UUID()
        self.name = name
        self.isCompleted = isCompleted
        self.hypothermiaStatus = hypothermiaStatus
    }
}


struct UndoState: Codable {
    let arrestState: ArrestState
    let masterTime: TimeInterval
    let cprTime: TimeInterval
    let timeOffset: TimeInterval
    let eventsData: Data
    let shockCount: Int
    let adrenalineCount: Int
    let amiodaroneCount: Int
    let lidocaineCount: Int
    let lastAdrenalineTime: TimeInterval?
    let antiarrhythmicGiven: AntiarrhythmicDrug
    let shockCountForAmiodarone1: Int?
    let airwayPlaced: Bool
    let reversibleCauses: [ChecklistItem]
    let postROSCTasks: [ChecklistItem]
    let postMortemTasks: [ChecklistItem]
    let startTime: Date?
    let uiState: UIState
    let patientAgeCategory: PatientAgeCategory?
}

struct PDFIdentifiable: Identifiable, Hashable {
    let id = UUID()
    let pdfName: String
    let title: String
}

// MARK: - App Constants & Settings
struct AppSettings {
    @AppStorage("cprCycleDuration") static var cprCycleDuration: TimeInterval = 120
    @AppStorage("adrenalineInterval") static var adrenalineInterval: TimeInterval = 240
    @AppStorage("metronomeBPM") static var metronomeBPM: Int = 110
    @AppStorage("appearanceMode") static var appearanceMode: AppearanceMode = .system
    @AppStorage("showDosagePrompts") static var showDosagePrompts: Bool = false
}

struct AppConstants {
    static let reversibleCausesTemplate: [ChecklistItem] = [
        ChecklistItem(name: "Hypoxia"), ChecklistItem(name: "Hypovolemia"),
        ChecklistItem(name: "Hypo/Hyperkalaemia"), ChecklistItem(name: "Hypothermia"),
        ChecklistItem(name: "Toxins"), ChecklistItem(name: "Tamponade"),
        ChecklistItem(name: "Tension Pneumothorax"), ChecklistItem(name: "Thrombosis")
    ]
    
    static let postROSCTasksTemplate: [ChecklistItem] = [
        ChecklistItem(name: "Optimise Ventilation & Oxygenation"), ChecklistItem(name: "12-Lead ECG"),
        ChecklistItem(name: "Treat Hypotension (SBP < 90)"), ChecklistItem(name: "Check Blood Glucose"),
        ChecklistItem(name: "Consider Temperature Control"), ChecklistItem(name: "Identify & Treat Causes")
    ]
    
    static let postMortemTasksTemplate: [ChecklistItem] = [
        ChecklistItem(name: "Reposition body & remove lines/tubes"), ChecklistItem(name: "Complete documentation"),
        ChecklistItem(name: "Determine expected/unexpected death"), ChecklistItem(name: "Contact Coroner (if unexpected)"),
        ChecklistItem(name: "Follow local body handling procedure"), ChecklistItem(name: "Provide leaflet to bereaved relatives"),
        ChecklistItem(name: "Consider organ/tissue donation")
    ]
    
    static let otherDrugs: [String] = [
        "Adenosine", "Adrenaline 1:1000", "Adrenaline 1:10,000", "Amiodarone (Further Dose)",
        "Atropine", "Calcium chloride", "Glucose", "Hartmann’s solution", "Magnesium sulphate",
        "Midazolam", "Naloxone", "Potassium chloride", "Sodium bicarbonate", "Sodium chloride", "Tranexamic acid"
    ].sorted()
}
