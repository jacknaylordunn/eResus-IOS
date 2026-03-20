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
    @State private var showAirwayAdjunctModal = false
    @State private var showVascularModal = false
    @State private var showTORModal = false
    @Binding var pdfToShow: PDFIdentifiable?
    @State private var drugToLog: DrugToLog?
    @State private var drugConfirmationToShow: DrugConfirmation?
    
    // Transfer Modals
    @State private var showTransferModal = false
    @State private var showQRScanner = false
    @State private var scannedCode: String? = nil
    
    // Success Animation States
    @State private var airwaySuccess = false
    @State private var vascularSuccess = false
    
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
                        if viewModel.arrestType == .general {
                            ActiveArrestContentView(
                                viewModel: viewModel,
                                metronome: metronome,
                                showOtherDrugsModal: $showOtherDrugsModal,
                                showEtco2Modal: $showEtco2Modal,
                                showHypothermiaModal: $showHypothermiaModal,
                                pdfToShow: $pdfToShow,
                                showAirwayAdjunctModal: $showAirwayAdjunctModal,
                                showVascularModal: $showVascularModal,
                                showTORModal: $showTORModal,
                                airwaySuccess: $airwaySuccess,
                                vascularSuccess: $vascularSuccess,
                                onLogAdrenaline: handleAdrenaline,
                                onLogAmiodarone: handleAmiodarone,
                                onLogLidocaine: handleLidocaine
                            )
                        } else {
                            NewbornActiveArrestContentView(
                                viewModel: viewModel,
                                metronome: metronome,
                                showOtherDrugsModal: $showOtherDrugsModal,
                                pdfToShow: $pdfToShow,
                                showAirwayAdjunctModal: $showAirwayAdjunctModal,
                                showVascularModal: $showVascularModal,
                                showTORModal: $showTORModal,
                                airwaySuccess: $airwaySuccess,
                                vascularSuccess: $vascularSuccess,
                                onLogAdrenaline: handleAdrenaline
                            )
                        }
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
        // MARK: - Native AirDrop Receiver
        .dropDestination(for: UndoState.self) { items, location in
            if let transferState = items.first {
                viewModel.restoreFromTransfer(state: transferState)
                return true
            }
            return false
        }
        // MARK: - Modal Sheets
        .sheet(isPresented: $viewModel.showPatientInfoPrompt) {
            PatientInfoPromptView(viewModel: viewModel)
        }
        .sheet(isPresented: $showTransferModal) {
            SessionTransferModal(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            QRScannerView(scannedCode: $scannedCode)
                .ignoresSafeArea()
        }
        .onChange(of: scannedCode) { newValue in
            if let code = newValue {
                FirebaseManager.shared.fetchSessionTransfer(transferId: code) { state in
                    if let state = state {
                        viewModel.restoreFromTransfer(state: state)
                    }
                }
                scannedCode = nil
            }
        }
        .sheet(isPresented: $showOtherDrugsModal) {
            OtherDrugsModal(isPresented: $showOtherDrugsModal, onSelectDrug: handleOtherDrug)
        }
        .sheet(isPresented: $showEtco2Modal) {
            Etco2ModalView(isPresented: $showEtco2Modal, onConfirm: viewModel.logEtco2)
        }
        .sheet(isPresented: $showHypothermiaModal) {
            HypothermiaModal(isPresented: $showHypothermiaModal, onConfirm: viewModel.setHypothermiaStatus)
        }
        .sheet(isPresented: $showAirwayAdjunctModal) {
            AirwayAdjunctModal(isPresented: $showAirwayAdjunctModal) { type in
                viewModel.logAirwayPlaced(type: type)
                triggerAirwaySuccess()
            }
        }
        .sheet(isPresented: $showVascularModal) {
            VascularAccessModal(isPresented: $showVascularModal) { type, location, gauge, success in
                viewModel.logVascularAccess(type: type, location: location, gauge: gauge, successful: success)
                triggerVascularSuccess()
            }
        }
        .sheet(isPresented: $showTORModal) {
            TORGuidanceModal(viewModel: viewModel, isPresented: $showTORModal)
        }
        .sheet(isPresented: $showSummaryModal) {
            SummaryView(
                events: viewModel.events,
                totalTime: viewModel.totalArrestTime,
                startTime: viewModel.arrestStartTime,
                shockCount: viewModel.shockCount,
                adrenalineCount: viewModel.adrenalineCount,
                amiodaroneCount: viewModel.amiodaroneCount,
                lidocaineCount: viewModel.lidocaineCount,
                roscTime: viewModel.roscTime,
                patientAge: viewModel.patientAgeStr.isEmpty ? nil : viewModel.patientAgeStr,
                patientGender: viewModel.patientGenderStr.isEmpty ? nil : viewModel.patientGenderStr
            )
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
            DosageEntryModal(
                drug: drug,
                amiodaroneDoseCount: viewModel.amiodaroneCount,
                patientAgeStr: $viewModel.patientAgeStr,
                initialAgeCategory: viewModel.patientAgeCategory
            ) { dosage, ageCategory in
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
    
    // MARK: - Success Animation Triggers
    private func triggerAirwaySuccess() {
        withAnimation { airwaySuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { airwaySuccess = false }
        }
    }
    
    private func triggerVascularSuccess() {
        withAnimation { vascularSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { vascularSuccess = false }
        }
    }
    
    // MARK: - Action Handlers
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

