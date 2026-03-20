//
//  ResearchViews.swift
//  eResus
//

import SwiftUI

struct PatientInfoPromptView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Demographics")) {
                    TextField("Approx Age (e.g. 45)", text: $viewModel.patientAgeStr)
                        .keyboardType(.numberPad)
                    
                    Picker("Gender", selection: $viewModel.patientGenderStr) {
                        Text("Unknown").tag("")
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                }
                
                if AppSettings.researchModeEnabled {
                    Section(footer: Text("These details help ambulance trusts understand demographic differences in cardiac arrest outcomes.")) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Patient Info")
            .navigationBarItems(trailing: Button("Save") {
                // Auto-evaluate the age string into the correct enum for Drug Dosages!
                if let ageInt = Int(viewModel.patientAgeStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    if ageInt < 1 {
                        if let infantCase = PatientAgeCategory.allCases.first(where: { $0.rawValue.lowercased().contains("infant") }) {
                            viewModel.patientAgeCategory = infantCase
                        }
                    } else if ageInt <= 18 {
                        if let childCase = PatientAgeCategory.allCases.first(where: { $0.rawValue.lowercased().contains("child") }) {
                            viewModel.patientAgeCategory = childCase
                        }
                    } else {
                        if let adultCase = PatientAgeCategory.allCases.first(where: { $0.rawValue.lowercased().contains("adult") }) {
                            viewModel.patientAgeCategory = adultCase
                        }
                    }
                }
                dismiss()
            })
        }
        .presentationDetents([.medium]) // Makes it a half-screen modal
    }
}

struct ResearchConsentView: View {
    @Binding var isPresented: Bool
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    // Default to "Independent / None" if empty
    @State private var orgName: String = AppSettings.userOrganization.isEmpty ? "Independent / None" : AppSettings.userOrganization
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.top, 40)
            
            Text("Help Advance Science")
                .font(.largeTitle).bold()
            
            Text("eResus is partnering with researchers to track the effectiveness of interventions. By enrolling, your app will automatically upload anonymised records when an arrest concludes.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Embedded Data Policy Hyperlink
            Link("Read the Data Collection Policy & Agreement", destination: URL(string: "https://tech.aegismedicalsolutions.co.uk/eresus/data-policy")!)
                .font(.footnote)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Select your Ambulance Trust / Organisation:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                Picker("Ambulance Trust / Organisation", selection: $orgName) {
                    ForEach(firebaseManager.availableOrganizations, id: \.self) { org in
                        Text(org).tag(org)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer()
            
            Button("Enroll & Accept Terms") {
                AppSettings.researchModeEnabled = true
                AppSettings.userOrganization = orgName
                AppSettings.hasRespondedToResearchTerms = true
                FirebaseManager.shared.signInAnonymously()
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button("No, Opt Out") {
                AppSettings.researchModeEnabled = false
                AppSettings.hasRespondedToResearchTerms = true
                isPresented = false
            }
            .padding(.bottom)
        }
        .onAppear {
            firebaseManager.fetchOrganizations()
        }
    }
}
