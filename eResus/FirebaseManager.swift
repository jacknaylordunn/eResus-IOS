//
//  FirebaseManager.swift
//  eResus
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Combine

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    // Lazy var ensures Firestore isn't called before FirebaseApp.configure()
    private lazy var db = Firestore.firestore()
    
    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    @Published var currentUserEmail: String?
    
    // Dynamic Organizations List
    @Published var availableOrganizations: [String] = ["Independent / None"]
    
    private init() {} // Private to enforce singleton
    
    // Call this manually AFTER FirebaseApp.configure()
    func configure() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            // Treat anonymous users as "authenticated" for backend writes, but not for the UI profile
            self?.isAuthenticated = user != nil && !(user?.isAnonymous ?? true)
            self?.currentUserId = user?.uid
            self?.currentUserEmail = user?.email
            
            // If they have no account and research is on, ensure they have an anonymous ID
            if user == nil && AppSettings.researchModeEnabled {
                self?.signInAnonymously()
            }
        }
        fetchOrganizations()
    }
    
    // MARK: - Dynamic Data Fetching
    func fetchOrganizations() {
        db.collection("organizations").order(by: "name").getDocuments { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let fetchedOrgs = documents.compactMap { $0.data()["name"] as? String }
            DispatchQueue.main.async {
                self?.availableOrganizations = ["Independent / None"] + fetchedOrgs
            }
        }
    }
    
    // MARK: - Authentication
    
    func signInAnonymously() {
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                print("Anon Auth error: \(error.localizedDescription)")
            }
        }
    }
    
    func signUpWithEmail(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            completion(error)
        }
    }
    
    func signInWithEmail(email: String, password: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            completion(error)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            if AppSettings.researchModeEnabled {
                signInAnonymously()
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Research Analytics & Database
    
    func uploadLog(_ log: SavedArrestLog, events: [Event]) {
        guard AppSettings.researchModeEnabled else { return }
        
        if Auth.auth().currentUser == nil {
            signInAnonymously()
        }
        
        let logId = UUID().uuidString
        var data: [String: Any] = [
            "startTime": log.startTime,
            "totalDuration": log.totalDuration,
            "finalOutcome": log.finalOutcome,
            "shockCount": log.shockCount,
            "adrenalineCount": log.adrenalineCount,
            "amiodaroneCount": log.amiodaroneCount,
            "patientAge": log.patientAge ?? "Unknown",
            "patientGender": log.patientGender ?? "Unknown",
            "initialRhythm": log.initialRhythm ?? "Unknown",
            "organization": log.organization ?? "Unknown",
            "uid": Auth.auth().currentUser?.uid ?? "anonymous",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        if let rosc = log.roscTime { data["roscTime"] = rosc }
        
        db.collection("arrestLogs").document(logId).setData(data) { error in
            if let error = error {
                print("Failed to upload log: \(error.localizedDescription)")
            } else {
                print("Successfully uploaded log to Firestore.")
            }
        }
        
        for event in events {
            let eventData: [String: Any] = [
                "timestamp": event.timestamp,
                "message": event.message,
                "type": event.typeString
            ]
            db.collection("arrestLogs").document(logId).collection("events").addDocument(data: eventData)
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
            ]) { error in
                completion(error == nil ? transferId : nil)
            }
        } catch {
            completion(nil)
        }
    }
    
    func fetchSessionTransfer(transferId: String, completion: @escaping (UndoState?) -> Void) {
        db.collection("transfers").document(transferId).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let stateData = data["stateData"] as? Data else {
                completion(nil)
                return
            }
            
            do {
                let state = try JSONDecoder().decode(UndoState.self, from: stateData)
                self.db.collection("transfers").document(transferId).delete()
                completion(state)
            } catch {
                completion(nil)
            }
        }
    }
}
