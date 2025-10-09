//
//  ArrestView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import SwiftData

struct DrugConfirmation: Identifiable {
    let id = UUID()
    let drug: DrugToLog
    let calculatedDose: String
}

struct ArrestView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @StateObject private var metronome = Metronome()
    
    // State for presenting modals
    @State private var showOtherDrugsModal = false
    @State private var showEtco2Modal = false
    @State private var showHypothermiaModal = false
    @State private var showSummaryModal = false
    @State private var showResetModal = false
    @Binding var pdfToShow: PDFIdentifiable?
    @State private var drugToLog: DrugToLog?
    @State private var drugConfirmationToShow: DrugConfirmation?
    
    @AppStorage("showDosagePrompts") private var showDosagePrompts: Bool = false
    
    var body: some View {
        // Use a ZStack to layer the main content and the sticky footer
        ZStack(alignment: .bottom) {
            // Main content area
            VStack(spacing: 0) {
                HeaderView(viewModel: viewModel)
                
                // The content for each arrest state
                Group {
                    switch viewModel.arrestState {
                    case .pending:
                        PendingView(viewModel: viewModel, pdfToShow: $pdfToShow)
                    case .active:
                        ActiveArrestContentView(
                            viewModel: viewModel,
                            metronome: metronome,
                            showOtherDrugsModal: $showOtherDrugsModal,
                            showEtco2Modal: $showEtco2Modal,
                            showHypothermiaModal: $showHypothermiaModal,
                            pdfToShow: $pdfToShow,
                            onLogAdrenaline: handleAdrenaline,
                            onLogAmiodarone: handleAmiodarone,
                            onLogLidocaine: handleLidocaine
                        )
                    case .rosc:
                        RoscView(
                            viewModel: viewModel,
                            showOtherDrugsModal: $showOtherDrugsModal,
                            pdfToShow: $pdfToShow
                        )
                    case .ended:
                        EndedView(viewModel: viewModel, pdfToShow: $pdfToShow)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // Sticky Footer - always visible on top of the content
            if viewModel.arrestState != .pending {
                BottomControlsView(
                    viewModel: viewModel,
                    showSummaryModal: $showSummaryModal,
                    showResetModal: $showResetModal
                )
                // This padding ensures the footer sits above the main Tab Bar
                .padding(.bottom, 82)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        // MARK: - Modal Sheets
        .sheet(isPresented: $showOtherDrugsModal) {
            OtherDrugsModal(isPresented: $showOtherDrugsModal, onSelectDrug: handleOtherDrug)
        }
        .sheet(isPresented: $showEtco2Modal) {
            Etco2ModalView(isPresented: $showEtco2Modal, onConfirm: viewModel.logEtco2)
        }
        .sheet(isPresented: $showHypothermiaModal) {
            HypothermiaModal(isPresented: $showHypothermiaModal, onConfirm: viewModel.setHypothermiaStatus)
        }
        .sheet(isPresented: $showSummaryModal) {
            SummaryView(events: viewModel.events, totalTime: viewModel.totalArrestTime)
        }
        .sheet(isPresented: $showResetModal) {
            ResetModalView(
                isPresented: $showResetModal,
                onCopyAndReset: {
                    viewModel.performReset(shouldSaveLog: true, shouldCopy: true)
                },
                onResetAnyway: {
                    viewModel.performReset(shouldSaveLog: true, shouldCopy: false)
                }
            )
        }
        .sheet(item: $drugToLog) { drug in
            DosageEntryModal(drug: drug, amiodaroneDoseCount: viewModel.amiodaroneCount) { dosage, ageCategory in
                if let age = ageCategory {
                    viewModel.setPatientAgeCategory(age)
                }
                
                switch drug {
                case .adrenaline:
                    viewModel.logAdrenaline(with: dosage)
                case .amiodarone:
                    viewModel.logAmiodarone(with: dosage)
                case .lidocaine:
                    viewModel.logLidocaine(with: dosage)
                case .other(let name):
                    viewModel.logOtherDrug(name, with: dosage)
                }
            }
        }
        .alert(
            "Confirm Dosage",
            isPresented: Binding(
                get: { drugConfirmationToShow != nil },
                set: { if !$0 { drugConfirmationToShow = nil } }
            ),
            presenting: drugConfirmationToShow
        ) { confirmation in
            Button("Confirm") {
                switch confirmation.drug {
                case .adrenaline:
                    viewModel.logAdrenaline(with: confirmation.calculatedDose)
                case .amiodarone:
                    viewModel.logAmiodarone(with: confirmation.calculatedDose)
                default: break // Should not happen for this alert
                }
            }
            Button("Change") {
                drugToLog = confirmation.drug
            }
            Button("Cancel", role: .cancel) { }
        } message: { confirmation in
            Text("Confirm ")
            + Text(confirmation.calculatedDose).bold()
            + Text(" \(confirmation.drug.title) given?")
        }
    }
    
    private func handleAdrenaline() {
        if showDosagePrompts {
            if let age = viewModel.patientAgeCategory {
                let dose = DosageCalculator.calculateAdrenalineDose(for: age)
                drugConfirmationToShow = DrugConfirmation(drug: .adrenaline, calculatedDose: dose)
            } else {
                drugToLog = .adrenaline
            }
        } else {
            viewModel.logAdrenaline()
        }
    }
    
    private func handleAmiodarone() {
        if showDosagePrompts {
            if let age = viewModel.patientAgeCategory,
               let dose = DosageCalculator.calculateAmiodaroneDose(for: age, doseNumber: viewModel.amiodaroneCount + 1) {
                drugConfirmationToShow = DrugConfirmation(drug: .amiodarone, calculatedDose: dose)
            } else {
                drugToLog = .amiodarone
            }
        } else {
            viewModel.logAmiodarone()
        }
    }

    private func handleLidocaine() {
        if showDosagePrompts {
            drugToLog = .lidocaine
        } else {
            viewModel.logLidocaine()
        }
    }
    
    private func handleOtherDrug(_ name: String) {
        if showDosagePrompts {
            drugToLog = .other(name)
        } else {
            viewModel.logOtherDrug(name)
        }
    }
}
