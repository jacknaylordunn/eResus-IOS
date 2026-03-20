//
//  FirebaseManager.swift
//  eResus
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftData

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private lazy var db = Firestore.firestore()
    
    // Constant matching the PWA structure
    private let appId = "eresus-6e65e"
    
    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    @Published var currentUserEmail: String?
    
    @Published var availableOrganizations: [String] = ["Independent / None"]
    
    private init() {}
    
    func configure() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let isRealUser = user != nil && !(user?.isAnonymous ?? true)
            self?.isAuthenticated = isRealUser
            self?.currentUserId = user?.uid
            self?.currentUserEmail = user?.email
            
            if user == nil && AppSettings.researchModeEnabled {
                self?.signInAnonymously()
            } else if isRealUser {
                self?.fetchSettingsFromCloud()
            }
        }
        fetchOrganizations()
    }
    
    func fetchOrganizations() {
        db.collection("organizations").order(by: "name").getDocuments { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let fetchedOrgs = documents.compactMap { $0.data()["name"] as? String }
            DispatchQueue.main.async {
                self?.availableOrganizations = ["Independent / None"] + fetchedOrgs
            }
        }
    }
    
    // MARK: - Settings Cloud Sync (Aligned with PWA)
    func syncSettingsToCloud() {
        guard isAuthenticated, let uid = currentUserId else { return }
        
        let settingsData: [String: Any] = [
            "researchModeEnabled": UserDefaults.standard.bool(forKey: "researchModeEnabled"),
            "userOrganization": UserDefaults.standard.string(forKey: "userOrganization") ?? "Independent / None",
            "askForPatientInfo": UserDefaults.standard.bool(forKey: "askForPatientInfo"),
            "hasRespondedToResearchTerms": UserDefaults.standard.bool(forKey: "hasRespondedToResearchTerms"),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        let settingsRef = db.collection("artifacts").document(appId).collection("users").document(uid).collection("settings").document("research")
        settingsRef.setData(settingsData, merge: true)
    }
    
    func fetchSettingsFromCloud() {
        guard isAuthenticated, let uid = currentUserId else { return }
        
        let settingsRef = db.collection("artifacts").document(appId).collection("users").document(uid).collection("settings").document("research")
        
        settingsRef.getDocument { [weak self] snapshot, error in
            if let data = snapshot?.data(), !data.isEmpty {
                DispatchQueue.main.async {
                    if let research = data["researchModeEnabled"] as? Bool { UserDefaults.standard.set(research, forKey: "researchModeEnabled") }
                    if let org = data["userOrganization"] as? String { UserDefaults.standard.set(org, forKey: "userOrganization") }
                    if let ask = data["askForPatientInfo"] as? Bool { UserDefaults.standard.set(ask, forKey: "askForPatientInfo") }
                    if let responded = data["hasRespondedToResearchTerms"] as? Bool { UserDefaults.standard.set(responded, forKey: "hasRespondedToResearchTerms") }
                }
            } else {
                // If cloud is empty, push local settings up
                self?.syncSettingsToCloud()
            }
        }
    }
    
    // MARK: - Smart Authentication
    func signInAnonymously() {
        Auth.auth().signInAnonymously { _, _ in }
    }
    
    func authenticate(with credential: AuthCredential, completion: @escaping (Error?) -> Void) {
        let oldUid = Auth.auth().currentUser?.uid
        
        if let user = Auth.auth().currentUser, user.isAnonymous {
            user.link(with: credential) { result, error in
                if let error = error as NSError?, error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    // Sign in to existing account and migrate anonymous logs
                    Auth.auth().signIn(with: credential) { signInResult, signInError in
                        if let newUid = signInResult?.user.uid, let old = oldUid, old != newUid {
                            self.migrateAnonymousLogs(oldUserId: old, newUserId: newUid)
                        }
                        completion(signInError)
                    }
                } else {
                    completion(error)
                }
            }
        } else {
            Auth.auth().signIn(with: credential) { _, error in
                completion(error)
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            if AppSettings.researchModeEnabled { signInAnonymously() }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - PWA Migration Logic
    private func migrateAnonymousLogs(oldUserId: String, newUserId: String) {
        if oldUserId == newUserId { return }
        
        let oldLogsRef = db.collection("artifacts").document(appId).collection("users").document(oldUserId).collection("logs")
        let newLogsRef = db.collection("artifacts").document(appId).collection("users").document(newUserId).collection("logs")
        
        oldLogsRef.getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            for doc in docs {
                newLogsRef.document(doc.documentID).setData(doc.data(), merge: true)
                
                oldLogsRef.document(doc.documentID).collection("events").getDocuments { evSnap, _ in
                    guard let evDocs = evSnap?.documents else { return }
                    for evDoc in evDocs {
                        newLogsRef.document(doc.documentID).collection("events").document(evDoc.documentID).setData(evDoc.data(), merge: true)
                    }
                }
            }
        }
    }
    
    // MARK: - Two-Way Database Sync (PWA Structure)
    func uploadLog(_ log: SavedArrestLog, events: [Event]) {
        guard AppSettings.researchModeEnabled else { return }
        if Auth.auth().currentUser == nil { signInAnonymously() }
        
        let uid = Auth.auth().currentUser?.uid ?? "anonymous"
        let logId = "\(Int(log.startTime.timeIntervalSince1970))"
        
        // Match the PWA structure exactly, using NSNull() for missing values
        let data: [String: Any] = [
            "startTime": log.startTime,
            "totalDuration": log.totalDuration,
            "finalOutcome": log.finalOutcome,
            "shockCount": log.shockCount,
            "adrenalineCount": log.adrenalineCount,
            "amiodaroneCount": log.amiodaroneCount,
            "userId": uid, // Fixed key to match PWA
            "isSynced": true, // Required by PWA
            "patientAge": log.patientAge ?? NSNull(),
            "patientGender": log.patientGender ?? NSNull(),
            "initialRhythm": log.initialRhythm ?? NSNull(),
            "organization": log.organization ?? "Independent / None",
            "roscTime": log.roscTime ?? NSNull()
        ]
        
        // Use PWA specific path
        let logRef = db.collection("artifacts").document(appId).collection("users").document(uid).collection("logs").document(logId)
        logRef.setData(data, merge: true)
        
        for event in events {
            let eventData: [String: Any] = [
                "timestamp": event.timestamp,
                "message": event.message,
                "type": event.typeString
            ]
            logRef.collection("events").document(event.id.uuidString).setData(eventData, merge: true)
        }
    }
    
    @MainActor
    func downloadLogs(to context: ModelContext) {
        guard let uid = currentUserId else { return }
        
        // Read from PWA specific path
        let logsRef = db.collection("artifacts").document(appId).collection("users").document(uid).collection("logs")
        
        logsRef.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let localLogs = (try? context.fetch(FetchDescriptor<SavedArrestLog>())) ?? []
            
            for doc in documents {
                let data = doc.data()
                guard let cloudStartTime = (data["startTime"] as? Timestamp)?.dateValue() else { continue }
                
                if let existingLog = localLogs.first(where: { abs($0.startTime.timeIntervalSince(cloudStartTime)) < 1.0 }) {
                    var needsSave = false
                    
                    // Safely ignore NSNull objects coming from the PWA
                    if let cloudAge = data["patientAge"] as? String, existingLog.patientAge != cloudAge {
                        existingLog.patientAge = cloudAge; needsSave = true
                    }
                    if let cloudGender = data["patientGender"] as? String, existingLog.patientGender != cloudGender {
                        existingLog.patientGender = cloudGender; needsSave = true
                    }
                    if let cloudRhythm = data["initialRhythm"] as? String, existingLog.initialRhythm != cloudRhythm {
                        existingLog.initialRhythm = cloudRhythm; needsSave = true
                    }
                    if let cloudOrg = data["organization"] as? String, existingLog.organization != cloudOrg {
                        existingLog.organization = cloudOrg; needsSave = true
                    }
                    if needsSave { try? context.save() }
                    
                } else {
                    let newLog = SavedArrestLog(
                        startTime: cloudStartTime,
                        totalDuration: data["totalDuration"] as? TimeInterval ?? 0,
                        finalOutcome: data["finalOutcome"] as? String ?? "Unknown",
                        events: [],
                        shockCount: data["shockCount"] as? Int ?? 0,
                        adrenalineCount: data["adrenalineCount"] as? Int ?? 0,
                        amiodaroneCount: data["amiodaroneCount"] as? Int ?? 0,
                        roscTime: data["roscTime"] as? TimeInterval,
                        patientAge: data["patientAge"] as? String,
                        patientGender: data["patientGender"] as? String,
                        initialRhythm: data["initialRhythm"] as? String,
                        organization: data["organization"] as? String,
                        isSynced: true
                    )
                    context.insert(newLog)
                    
                    logsRef.document(doc.documentID).collection("events").getDocuments { evSnap, _ in
                        guard let evDocs = evSnap?.documents else { return }
                        for evDoc in evDocs {
                            let evData = evDoc.data()
                            let event = Event(
                                timestamp: evData["timestamp"] as? TimeInterval ?? 0,
                                message: evData["message"] as? String ?? "",
                                type: EventType(rawValue: evData["type"] as? String ?? "") ?? .status
                            )
                            event.log = newLog
                            context.insert(event)
                        }
                        try? context.save()
                    }
                }
            }
        }
    }
    
    // NEW: Cloud Deletion
    func deleteLog(_ log: SavedArrestLog) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let logId = "\(Int(log.startTime.timeIntervalSince1970))"
        let logRef = db.collection("artifacts").document(appId).collection("users").document(uid).collection("logs").document(logId)
        
        logRef.collection("events").getDocuments { snapshot, _ in
            snapshot?.documents.forEach { $0.reference.delete() }
            logRef.delete()
        }
    }
    
    // MARK: - Session Transfer
    func hostSessionTransfer(state: UndoState, completion: @escaping (String?) -> Void) {
        do {
            let data = try JSONEncoder().encode(state)
            let transferId = String(format: "%06d", Int.random(in: 100000...999999))
            db.collection("transfers").document(transferId).setData([
                "stateData": data,
                "createdAt": FieldValue.serverTimestamp()
            ]) { error in completion(error == nil ? transferId : nil) }
        } catch { completion(nil) }
    }
    
    func fetchSessionTransfer(transferId: String, completion: @escaping (UndoState?) -> Void) {
        db.collection("transfers").document(transferId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), let stateData = data["stateData"] as? Data else { completion(nil); return }
            do {
                let state = try JSONDecoder().decode(UndoState.self, from: stateData)
                self.db.collection("transfers").document(transferId).delete()
                completion(state)
            } catch { completion(nil) }
        }
    }
}
