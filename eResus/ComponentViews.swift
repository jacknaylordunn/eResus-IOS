//
//  ComponentViews.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

// MARK: - View Modifiers
struct PulsatingModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && isPulsing ? 1.02 : 1.0)
            .opacity(isActive && isPulsing ? 0.9 : 1.0)
            .animation(isActive ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isPulsing)
            .onChange(of: isActive) { newValue in
                isPulsing = newValue
            }
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Button Styles & Animations
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String?
    let backgroundColor: Color
    let foregroundColor: Color
    let height: CGFloat
    let fontSize: Font
    let action: () -> Void
    
    @Environment(\.isEnabled) private var isEnabled

    init(title: String, icon: String?, backgroundColor: Color, foregroundColor: Color, height: CGFloat = 50, fontSize: Font = .headline, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.height = height
        self.fontSize = fontSize
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .multilineTextAlignment(.center)
            }
            .font(fontSize)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(12)
        }
        .opacity(isEnabled ? 1.0 : 0.4)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Header & Timers
struct HeaderView: View {
    @ObservedObject var viewModel: ArrestViewModel
    
    var body: some View {
        let isDue = viewModel.isRhythmCheckDue && viewModel.arrestState == .active && viewModel.uiState == .default
        
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isDue ? (viewModel.arrestType == .newborn ? "REASSESS PATIENT" : "RHYTHM CHECK DUE") : "eResus")
                        .font(isDue ? .title : .largeTitle).bold()
                        .foregroundColor(isDue ? .white : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text(viewModel.isTimerPaused ? "PAUSED" : viewModel.arrestState.rawValue)
                        .font(.caption)
                        .fontWeight(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewModel.isTimerPaused ? Color.orange : (isDue ? Color.white : viewModel.arrestState.color))
                        .foregroundColor(viewModel.isTimerPaused ? .white : (isDue ? Color.red : .white))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        if viewModel.timeOffset > 0 {
                            Text("\(Int(viewModel.timeOffset / 60))+")
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(isDue && !viewModel.isTimerPaused ? .white : Color.accentColor)
                                .padding(.trailing, 2)
                        }
                        Text(TimeFormatter.format(viewModel.masterTime))
                            .font(.system(size: 50, weight: .bold, design: .monospaced))
                            .foregroundColor(isDue && !viewModel.isTimerPaused ? .white : Color.accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    if (viewModel.arrestState == .active || viewModel.arrestState == .pending) && !viewModel.isTimerPaused {
                        TimeOffsetButtons(viewModel: viewModel, isDue: isDue)
                    }
                }
            }
            
            if viewModel.arrestState != .pending && viewModel.arrestType == .general {
                 CountersView(viewModel: viewModel, isDue: isDue && !viewModel.isTimerPaused)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 12)
        .background {
            if viewModel.isTimerPaused {
                Color.orange.opacity(0.15)
            } else if isDue {
                Color.red.shadow(radius: 2, y: 2)
            } else {
                Color(UIColor.systemGroupedBackground).shadow(radius: 2, y: 2)
            }
        }
        .onTapGesture {
            if isDue && !viewModel.isTimerPaused {
                if viewModel.arrestType == .general {
                    viewModel.analyseRhythm()
                } else {
                    viewModel.reassessPatient()
                }
            }
        }
    }
}


struct CountersView: View {
    @ObservedObject var viewModel: ArrestViewModel
    let isDue: Bool
    
    var body: some View {
        HStack {
            Spacer()
            CounterItem(label: "Shocks", value: viewModel.shockCount, color: .orange, isDue: isDue)
            Spacer()
            CounterItem(label: "Adrenaline", value: viewModel.adrenalineCount, color: .pink, isDue: isDue)
            Spacer()
            CounterItem(label: "Amiodarone", value: viewModel.amiodaroneCount, color: .purple, isDue: isDue)
            Spacer()
            CounterItem(label: "Lidocaine", value: viewModel.lidocaineCount, color: .indigo, isDue: isDue)
            Spacer()
        }
    }
}

struct CounterItem: View {
    let label: String
    let value: Int
    let color: Color
    let isDue: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(isDue ? .white : color)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(isDue ? .white.opacity(0.8) : .secondary)
        }
        .frame(minWidth: 65)
    }
}

struct TimeOffsetButtons: View {
    @ObservedObject var viewModel: ArrestViewModel
    let isDue: Bool
    
    var body: some View {
        HStack {
            Button("+1m") { viewModel.addTimeOffset(60) }
            Button("+5m") { viewModel.addTimeOffset(300) }
            Button("+10m") { viewModel.addTimeOffset(600) }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .tint(isDue ? .white : .accentColor)
        .controlSize(.small)
    }
}

struct CPRTimerView: View {
    let cprTime: TimeInterval
    var totalDuration: TimeInterval = AppSettings.cprCycleDuration
    var title: String = "CPR CYCLE"
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 20)
            
            Circle()
                .trim(from: 0, to: cprTime / totalDuration)
                .stroke(cprTime <= 10 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: cprTime)

            VStack {
                Text(TimeFormatter.format(cprTime))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(cprTime <= 10 ? .red : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(45)
        }
        .frame(width: 250, height: 270)
    }
}

struct NLSSquareTimerView: View {
    let time: TimeInterval
    var totalDuration: TimeInterval
    var title: String = "REASSESS IN"
    
    var body: some View {
        VStack(spacing: 4) {
            Text(TimeFormatter.format(time))
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundColor(time <= 10 ? .red : .primary)
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
        }
        .frame(width: 140, height: 90)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(time <= 10 ? Color.red : Color.blue.opacity(0.6), lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Screen State Views
struct PendingView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @Binding var pdfToShow: PDFIdentifiable?
    
    @State private var showNewbornOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                if showNewbornOptions {
                    VStack(spacing: 16) {
                        Text("Select Newborn Type")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ActionButton(title: "Term (≥32 Weeks)", icon: nil, backgroundColor: .purple, foregroundColor: .white, height: 60, fontSize: .title2) {
                            viewModel.startNewbornArrest(isPreterm: false)
                        }
                        
                        ActionButton(title: "Preterm (<32 Weeks)", icon: nil, backgroundColor: .indigo, foregroundColor: .white, height: 60, fontSize: .title2) {
                            viewModel.startNewbornArrest(isPreterm: true)
                        }
                        
                        Button("Cancel") {
                            withAnimation { showNewbornOptions = false }
                        }
                        .font(.headline)
                        .padding(.top, 8)
                    }
                    .padding(.top)
                    .transition(.opacity)
                } else {
                    ActionButton(title: "Start Arrest", icon: nil, backgroundColor: .red, foregroundColor: .white, height: 60, fontSize: .title2, action: viewModel.startArrest)
                        .padding(.top)
                    
                    ActionButton(title: "Newborn Life Support", icon: nil, backgroundColor: .purple, foregroundColor: .white, height: 60, fontSize: .title2) {
                        withAnimation { showNewbornOptions = true }
                    }
                    .transition(.opacity)
                }
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
                    .padding(.horizontal)
            }
            .padding(.horizontal)
            .animation(.easeInOut, value: showNewbornOptions)
        }
    }
}

struct ActiveArrestContentView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @ObservedObject var metronome: Metronome
    
    @Binding var showOtherDrugsModal: Bool
    @Binding var showEtco2Modal: Bool
    @Binding var showHypothermiaModal: Bool
    @Binding var pdfToShow: PDFIdentifiable?
    @Binding var showAirwayAdjunctModal: Bool
    @Binding var showVascularModal: Bool
    @Binding var showTORModal: Bool
    @Binding var airwaySuccess: Bool
    @Binding var vascularSuccess: Bool
    
    let onLogAdrenaline: () -> Void
    let onLogAmiodarone: () -> Void
    let onLogLidocaine: () -> Void
    
    @State private var showTransferModal = false
    @State private var showQRScanner = false
    @State private var scannedCode: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack(alignment: .bottomTrailing) {
                    CPRTimerView(cprTime: viewModel.cprTime)
                    MetronomeButton(metronome: metronome)
                        .offset(x: 10, y: 10)
                }
                .padding(.top)
                
                if let timeUntilAdrenaline = viewModel.timeUntilAdrenaline {
                    if timeUntilAdrenaline > 0 {
                        AdrenalineTimerView(timeRemaining: timeUntilAdrenaline)
                    } else if !viewModel.hideAdrenalineDueWarning {
                        AdrenalineDueWarning(
                            action: onLogAdrenaline,
                            onDismiss: { viewModel.hideAdrenalineDueWarning = true }
                        )
                    }
                }
                
                if viewModel.shouldShowAdrenalinePrompt {
                    AdrenalinePromptView(action: onLogAdrenaline, onDismiss: { viewModel.hideAdrenalinePrompt = true })
                }
                
                if viewModel.shouldShowAmiodaroneFirstDosePrompt {
                    AmiodaronePromptView(action: onLogAmiodarone, onDismiss: { viewModel.hideAmiodaronePrompt = true })
                }
                
                if viewModel.shouldShowAmiodaroneReminder {
                    AmiodaroneReminderView(action: onLogAmiodarone, onDismiss: { viewModel.hideAmiodaronePrompt = true })
                }
                
                ActionGridView(
                    viewModel: viewModel,
                    showOtherDrugsModal: $showOtherDrugsModal,
                    showEtco2Modal: $showEtco2Modal,
                    showAirwayAdjunctModal: $showAirwayAdjunctModal,
                    showVascularModal: $showVascularModal,
                    showTORModal: $showTORModal,
                    airwaySuccess: $airwaySuccess,
                    vascularSuccess: $vascularSuccess,
                    onLogAdrenaline: onLogAdrenaline,
                    onLogAmiodarone: onLogAmiodarone,
                    onLogLidocaine: onLogLidocaine
                )
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
                
                ChecklistView(title: "Reversible Causes (4 H's & 4 T's)", items: $viewModel.reversibleCauses, viewModel: viewModel, showHypothermiaModal: $showHypothermiaModal)
                
                EventLogView(events: viewModel.events)
                
                // MARK: - Transfer Arrest Button
                VStack(spacing: 12) {
                    Divider().padding(.horizontal)
                    
                    Menu {
                        Button { showTransferModal = true } label: {
                            Label("Share/Transfer Session", systemImage: "square.and.arrow.up")
                        }
                        Button { showQRScanner = true } label: {
                            Label("Receive via QR", systemImage: "qrcode.viewfinder")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.arrow.left")
                            Text("Transfer Arrest")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal)
            .padding(.bottom, 200)
            .opacity(viewModel.isTimerPaused ? 0.5 : 1.0)
            .disabled(viewModel.isTimerPaused)
        }
        .onAppear {
            metronome.mode = .general
        }
        .sheet(isPresented: $showTransferModal) { SessionTransferModal(viewModel: viewModel) }
        .fullScreenCover(isPresented: $showQRScanner) { QRScannerView(scannedCode: $scannedCode).ignoresSafeArea() }
        .onChange(of: scannedCode) { newValue in
            if let code = newValue {
                FirebaseManager.shared.fetchSessionTransfer(transferId: code) { state in
                    if let state = state { viewModel.restoreFromTransfer(state: state) }
                }
                scannedCode = nil
            }
        }
    }
}

// MARK: - Newborn Wizard Blocks
struct WizardInstructionBlock: View {
    let title: String
    let primaryInstruction: String
    let secondaryInstructions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.black)
                .foregroundColor(.secondary)
                .tracking(1.0)
            
            if !primaryInstruction.isEmpty {
                Text(primaryInstruction)
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if !secondaryInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(secondaryInstructions, id: \.self) { inst in
                        HStack(alignment: .top) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.purple)
                                .padding(.top, 4)
                            Text(.init(inst))
                                .font(.body)
                                .foregroundColor(.primary.opacity(0.85))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

struct WizardQuestionBlock: View {
    let question: String
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            Text(question)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }
}

struct NewbornActiveArrestContentView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @ObservedObject var metronome: Metronome
    
    @Binding var showOtherDrugsModal: Bool
    @Binding var pdfToShow: PDFIdentifiable?
    @Binding var showAirwayAdjunctModal: Bool
    @Binding var showVascularModal: Bool
    @Binding var showTORModal: Bool
    @Binding var airwaySuccess: Bool
    @Binding var vascularSuccess: Bool
    
    let onLogAdrenaline: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    NLSSquareTimerView(time: viewModel.cprTime, totalDuration: viewModel.nlsCycleDuration)
                    Spacer()
                }
                .padding(.top)
                
                // GUIDED WIZARD CARD
                VStack(alignment: .leading, spacing: 16) {
                    switch viewModel.nlsState {
                    case .initialAssessment:
                        WizardInstructionBlock(title: "Initial Assessment", primaryInstruction: "Assess tone, breathing and heart rate.", secondaryInstructions: viewModel.isPreterm ? ["Place undried body in a plastic bag + radiant heat.", "If breathing consider: CPAP 5–8 cm H₂O and ≥ 30% FiO₂.", "Ensure an open airway."] : ["Delay cord clamping. Stimulate. Thermal care.", "Ensure an open airway."])
                        WizardQuestionBlock(question: "Is the baby breathing adequately?")
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow { ActionButton(title: "No (Inadequate)", icon: "lungs.fill", backgroundColor: .blue, foregroundColor: .white) { viewModel.advanceNLS(to: .inflationBreaths) }; ActionButton(title: "Yes (Adequate)", icon: "heart.fill", backgroundColor: .green, foregroundColor: .white) { viewModel.achieveROSC() } }
                        }

                    case .inflationBreaths:
                        WizardInstructionBlock(title: "Airway & Inflation Breaths", primaryInstruction: "Give 5 inflation breaths.", secondaryInstructions: viewModel.isPreterm ? ["Initial PIP 25 cm H₂O, PEEP 6 cm H₂O.", "≥ 30% FiO₂.", "SpO₂ +/- ECG monitoring."] : ["30 cm H₂O, air (21%).", "PEEP 6 cm H₂O, if possible.", "SpO₂ +/- ECG monitoring."])
                        WizardQuestionBlock(question: "Reassess heart rate and chest rise. Is the chest moving?")
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow { ActionButton(title: "Chest NOT Moving", icon: "exclamationmark.triangle", backgroundColor: .orange, foregroundColor: .white) { viewModel.advanceNLS(to: .optimiseAirway) }; ActionButton(title: "Chest Moving", icon: "lungs.fill", backgroundColor: .blue, foregroundColor: .white) { viewModel.advanceNLS(to: .ventilation) } }
                        }
                        
                    case .optimiseAirway:
                        WizardInstructionBlock(title: "Troubleshoot Airway", primaryInstruction: "Troubleshoot airway and repeat 5 inflation breaths.", secondaryInstructions: ["Check mask, head and jaw position.", "2 person support."])
                        WizardQuestionBlock(question: "Reassess heart rate and chest rise. Is the chest moving now?")
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow { ActionButton(title: "Chest NOT Moving", icon: "arrow.triangle.2.circlepath", backgroundColor: .orange, foregroundColor: .white) { viewModel.advanceNLS(to: .advancedAirway) }; ActionButton(title: "Chest Moving", icon: "lungs.fill", backgroundColor: .blue, foregroundColor: .white) { viewModel.advanceNLS(to: .ventilation) } }
                        }
                        
                    case .advancedAirway:
                        WizardInstructionBlock(title: "Advanced Airway", primaryInstruction: "Consider advanced airway interventions and repeat 5 inflation breaths.", secondaryInstructions: ["Consider: SGA, Suction, Tracheal tube.", "Consider increasing Inflation pressures."])
                        WizardQuestionBlock(question: "Reassess heart rate and chest rise. Is the chest moving now?")
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow { ActionButton(title: "Chest NOT Moving", icon: "arrow.triangle.2.circlepath", backgroundColor: .orange, foregroundColor: .white) { viewModel.logNLSAction("Chest still not moving. Advanced airway interventions continued."); viewModel.resetNLSTimer() }; ActionButton(title: "Chest Moving", icon: "lungs.fill", backgroundColor: .blue, foregroundColor: .white) { viewModel.advanceNLS(to: .ventilation) } }
                        }

                    case .ventilation:
                        WizardInstructionBlock(title: "Ventilation", primaryInstruction: "Start ventilation breaths (30 min⁻¹).", secondaryInstructions: [])
                        WizardQuestionBlock(question: "Reassess after 30 seconds. What is the Heart Rate?")
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow { ActionButton(title: "HR < 60 min⁻¹\n(Start CPR)", icon: "arrow.down.heart", backgroundColor: .red, foregroundColor: .white, height: 65) { viewModel.advanceNLS(to: .compressions) }; ActionButton(title: "HR ≥ 60 min⁻¹\n(Continue Vent.)", icon: "lungs.fill", backgroundColor: .blue, foregroundColor: .white, height: 65) { viewModel.advanceNLS(to: .continueVentilation) } }
                            GridRow { ActionButton(title: "Breathing normally", icon: "heart.fill", backgroundColor: .green, foregroundColor: .white) { viewModel.achieveROSC() }.gridCellColumns(2) }
                        }
                        
                    case .continueVentilation:
                        WizardInstructionBlock(title: "Continue Ventilation", primaryInstruction: "Continue ventilations until confident baby is breathing adequately and HR is stable.", secondaryInstructions: ["Maintain ventilation rate at 30 min⁻¹.", "Assess breathing and heart rate regularly."])
                        WizardQuestionBlock(question: "Reassess every 30 seconds.")
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow { ActionButton(title: "HR < 60 min⁻¹\n(Start CPR)", icon: "arrow.down.heart", backgroundColor: .red, foregroundColor: .white, height: 65) { viewModel.advanceNLS(to: .compressions) }; ActionButton(title: "Not Breathing Adequately\n(Cont. Vent)", icon: "lungs.fill", backgroundColor: .blue, foregroundColor: .white, height: 65) { viewModel.logNLSAction("Ventilation continued (Not breathing adequately)"); viewModel.resetNLSTimer() } }
                            GridRow { ActionButton(title: "Breathing normally", icon: "heart.fill", backgroundColor: .green, foregroundColor: .white) { viewModel.achieveROSC() }.gridCellColumns(2) }
                        }

                    case .compressions:
                        WizardInstructionBlock(title: "Chest Compressions", primaryInstruction: "Start chest compressions (3:1 ratio).", secondaryInstructions: ["Synchronise compressions and ventilation.", "100% Oxygen.", "Consider SGA or intubation.", "If HR remains < 60: Vascular access, drugs, check blood glucose, consider other factors."])
                        Button(action: { metronome.mode = .nls; metronome.toggle() }) {
                            HStack(spacing: 12) { Image(systemName: "metronome.fill").font(.title2); Text(metronome.isMetronomeOn ? "STOP 3:1 METRONOME" : "START 3:1 METRONOME").fontWeight(.bold) }
                            .frame(maxWidth: .infinity).padding().background(metronome.isMetronomeOn ? Color.blue : Color.blue.opacity(0.15)).foregroundColor(metronome.isMetronomeOn ? .white : .blue).cornerRadius(12)
                        }
                        .padding(.bottom, 8)
                        WizardQuestionBlock(question: "Reassess every 30 seconds. Does HR remain < 60 min⁻¹?")
                        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow { ActionButton(title: "Yes (HR < 60)\n(Continue CPR)", icon: "heart.text.square.fill", backgroundColor: .red, foregroundColor: .white, height: 65) { viewModel.logNLSAction("Compressions continued (HR < 60)"); viewModel.resetNLSTimer() }; ActionButton(title: "No (HR ≥ 60)\n(Stop CPR)", icon: "lungs.fill", backgroundColor: .blue, foregroundColor: .white, height: 65) { viewModel.advanceNLS(to: .ventilation) } }
                            GridRow { ActionButton(title: "Breathing normally", icon: "heart.fill", backgroundColor: .green, foregroundColor: .white) { viewModel.achieveROSC() }.gridCellColumns(2) }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                
                SpO2TargetTable()
                
                // Meds and Procedures
                VStack(spacing: 12) {
                    Text("Advanced Procedures").font(.headline).foregroundColor(.secondary)
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            ActionButton(title: vascularSuccess ? "Access Logged" : "Log IV / IO", icon: vascularSuccess ? "checkmark.circle.fill" : "drop.fill", backgroundColor: vascularSuccess ? .green : .purple, foregroundColor: .white, action: { showVascularModal = true })
                            ActionButton(title: "Adrenaline", icon: "syringe", backgroundColor: .pink, foregroundColor: .white, action: onLogAdrenaline)
                        }
                        GridRow {
                            ActionButton(title: airwaySuccess ? "Airway Logged" : "Intubation / SGA", icon: airwaySuccess ? "checkmark.circle.fill" : "waveform.path", backgroundColor: airwaySuccess ? .green : .indigo, foregroundColor: .white, action: { showAirwayAdjunctModal = true })
                            ActionButton(title: "Other Meds / Vol...", icon: "pills", backgroundColor: .gray, foregroundColor: .white, action: { showOtherDrugsModal = true })
                        }
                        GridRow {
                            ActionButton(title: "TOR", icon: "xmark.square.fill", backgroundColor: Color(UIColor.systemRed), foregroundColor: .white, action: { showTORModal = true })
                                .gridCellColumns(2)
                        }
                    }
                }
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
                if viewModel.isPreterm { ChecklistView(title: "Preterm < 32 Weeks Tasks", items: $viewModel.nlsPretermTasks, viewModel: viewModel, showHypothermiaModal: .constant(false)) }
                EventLogView(events: viewModel.events)
            }
            .padding(.horizontal)
            .padding(.bottom, 200)
            .opacity(viewModel.isTimerPaused ? 0.5 : 1.0)
            .disabled(viewModel.isTimerPaused)
        }
        .onChange(of: viewModel.nlsState) { newState in
            if newState != .compressions { metronome.turnOff() }
        }
    }
}


struct RoscView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @Binding var showOtherDrugsModal: Bool
    @Binding var pdfToShow: PDFIdentifiable?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ActionButton(title: viewModel.arrestType == .newborn ? "Baby Stopped Breathing" : "Patient Re-Arrested", icon: "arrow.clockwise.heart", backgroundColor: .orange, foregroundColor: .white, height: 60, action: viewModel.reArrest)
                
                ActionButton(title: "Administer Medication", icon: "syringe", backgroundColor: .gray, foregroundColor: .white, height: 60, action: { showOtherDrugsModal = true })
                
                if viewModel.arrestType == .general {
                    ChecklistView(title: "Post-ROSC Care", items: $viewModel.postROSCTasks, viewModel: viewModel, showHypothermiaModal: .constant(false))
                } else {
                    ActionButton(title: "Check Blood Glucose", icon: "drop", backgroundColor: .blue, foregroundColor: .white, action: { viewModel.logNLSAction("Blood Glucose Checked") })
                }
                
                EventLogView(events: viewModel.events)
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
            }
            .padding()
            .padding(.bottom, 120)
        }
    }
}

struct EndedView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @Binding var pdfToShow: PDFIdentifiable?
    @State private var showPLIIEModal = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.arrestType == .general {
                    
                    // NEW: VOD vs Care After Death Flow
                    if !viewModel.vodConfirmed {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Verification of Death (VOD)")
                                .font(.title2).bold()
                                .foregroundColor(.primary)
                            
                            Text("Assess for a minimum of 5 minutes after asystole onset.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            
                            ChecklistView(title: "VOD Criteria", items: $viewModel.vodTasks, viewModel: viewModel, showHypothermiaModal: .constant(false))
                            
                            let allChecked = viewModel.vodTasks.allSatisfy { $0.isCompleted }
                            
                            ActionButton(title: "Confirm VOD", icon: "checkmark.seal.fill", backgroundColor: allChecked ? .green : .gray, foregroundColor: .white) {
                                viewModel.logVOD()
                            }
                            .disabled(!allChecked)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Care After Death")
                                .font(.title2).bold()
                                .foregroundColor(.primary)
                            
                            Text("If suspicious or unnatural circumstances are suspected, leave equipment in situ, minimize contamination, and contact the Police.")
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            
                            ActionButton(title: "Breaking Bad News (PLIIE)", icon: "person.2.wave.2.fill", backgroundColor: .blue, foregroundColor: .white) {
                                showPLIIEModal = true
                            }
                            
                            ChecklistView(title: "Actions Following Death", items: $viewModel.postMortemTasks, viewModel: viewModel, showHypothermiaModal: .constant(false))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                    
                } else {
                    ActionButton(title: "Update Parents & Complete Records", icon: "person.2.fill", backgroundColor: .gray, foregroundColor: .white, action: { viewModel.logNLSAction("Updated Parents & Records") })
                }
                
                EventLogView(events: viewModel.events)
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
            }
            .padding()
            .padding(.bottom, 120)
        }
        .sheet(isPresented: $showPLIIEModal) {
            PLIIEGuidanceModal(isPresented: $showPLIIEModal)
        }
    }
}


// MARK: - Reusable Components
struct SpO2TargetTable: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Acceptable Pre-ductal SpO₂")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.purple)
            
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Text("3 min").padding(6).frame(maxWidth: .infinity).border(Color.secondary.opacity(0.3))
                    Text("5 min").padding(6).frame(maxWidth: .infinity).border(Color.secondary.opacity(0.3))
                    Text("10 min").padding(6).frame(maxWidth: .infinity).border(Color.secondary.opacity(0.3))
                }
                VStack(spacing: 0) {
                    Text("70-75%").padding(6).frame(maxWidth: .infinity).border(Color.secondary.opacity(0.3))
                    Text("80-85%").padding(6).frame(maxWidth: .infinity).border(Color.secondary.opacity(0.3))
                    Text("85-95%").padding(6).frame(maxWidth: .infinity).border(Color.secondary.opacity(0.3))
                }
            }
            .font(.caption)
            
            Text("Titrate O₂ to achieve target SpO₂")
                .font(.caption2)
                .italic()
                .padding(.vertical, 4)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple, lineWidth: 2)
        )
    }
}

struct ActionGridView: View {
    @ObservedObject var viewModel: ArrestViewModel // Still needed for state checks
    @Binding var showOtherDrugsModal: Bool
    @Binding var showEtco2Modal: Bool
    @Binding var showAirwayAdjunctModal: Bool
    @Binding var showVascularModal: Bool
    @Binding var showTORModal: Bool
    @Binding var airwaySuccess: Bool
    @Binding var vascularSuccess: Bool
    
    let onLogAdrenaline: () -> Void
    let onLogAmiodarone: () -> Void
    let onLogLidocaine: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            if viewModel.uiState == .default {
                ActionButton(title: "Analyse Rhythm", icon: "waveform.path.ecg", backgroundColor: .blue, foregroundColor: .white, height: 65, fontSize: .title2, action: viewModel.analyseRhythm)
            } else if viewModel.uiState == .analyzing {
                VStack(spacing: 12) {
                    Text("Select Rhythm").font(.headline).foregroundColor(.secondary)
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            ActionButton(title: "VF", icon: nil, backgroundColor: .orange, foregroundColor: .white, action: { viewModel.logRhythm("VF", isShockable: true) })
                            ActionButton(title: "VT", icon: nil, backgroundColor: .orange, foregroundColor: .white, action: { viewModel.logRhythm("VT", isShockable: true) })
                        }
                        GridRow {
                            ActionButton(title: "PEA", icon: nil, backgroundColor: .gray, foregroundColor: .white, action: { viewModel.logRhythm("PEA", isShockable: false) })
                            ActionButton(title: "Asystole", icon: nil, backgroundColor: .gray, foregroundColor: .white, action: { viewModel.logRhythm("Asystole", isShockable: false) })
                        }
                        GridRow {
                            ActionButton(title: "ROSC", icon: "heart.fill", backgroundColor: .green, foregroundColor: .white, action: viewModel.achieveROSC)
                                .gridCellColumns(2)
                        }
                    }
                }
            } else if viewModel.uiState == .shockAdvised {
                ActionButton(title: "Deliver Shock", icon: "bolt.heart", backgroundColor: .orange, foregroundColor: .white, height: 65, fontSize: .title2, action: viewModel.deliverShock)
            }
            
            VStack(spacing: 12) {
                Text("Medications").font(.headline).foregroundColor(.secondary)
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        ActionButton(title: "Adrenaline", icon: "syringe", backgroundColor: .pink, foregroundColor: .white, action: onLogAdrenaline)
                            .disabled(!viewModel.isAdrenalineAvailable)
                        ActionButton(title: "Amiodarone", icon: "syringe", backgroundColor: .purple, foregroundColor: .white, action: onLogAmiodarone)
                            .disabled(!viewModel.isAmiodaroneAvailable)
                    }
                    GridRow {
                        ActionButton(title: "Lidocaine", icon: "syringe", backgroundColor: .indigo, foregroundColor: .white, action: onLogLidocaine)
                            .disabled(!viewModel.isLidocaineAvailable)
                        ActionButton(title: "Other Meds...", icon: "pills", backgroundColor: .gray, foregroundColor: .white, action: { showOtherDrugsModal = true })
                    }
                }
            }
            
            VStack(spacing: 12) {
                Text("Procedures").font(.headline).foregroundColor(.secondary)
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        ActionButton(
                            title: airwaySuccess ? "Airway Logged" : "Adv. Airway",
                            icon: airwaySuccess ? "checkmark.circle.fill" : "lungs",
                            backgroundColor: airwaySuccess ? .green : .blue,
                            foregroundColor: .white,
                            action: { showAirwayAdjunctModal = true }
                        )
                        ActionButton(title: "Log ETCO2", icon: "waveform.path", backgroundColor: .teal, foregroundColor: .white, action: { showEtco2Modal = true })
                    }
                    GridRow {
                        ActionButton(
                            title: vascularSuccess ? "Access Logged" : "Log IV / IO",
                            icon: vascularSuccess ? "checkmark.circle.fill" : "drop.fill",
                            backgroundColor: vascularSuccess ? .green : .purple,
                            foregroundColor: .white,
                            action: { showVascularModal = true }
                        )
                        .gridCellColumns(2) // Stretches across the full screen beautifully
                    }
                }
            }
            
            VStack(spacing: 12) {
                Text("Patient Status").font(.headline).foregroundColor(.secondary)
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        ActionButton(title: "ROSC", icon: "heart.fill", backgroundColor: .green, foregroundColor: .white, action: viewModel.achieveROSC)
                        ActionButton(title: "TOR", icon: "xmark.square.fill", backgroundColor: Color(UIColor.systemRed), foregroundColor: .white, action: { showTORModal = true })
                    }
                }
            }
        }
    }
}

// ... Additional helper views (AdrenalineTimerView, ChecklistView, AlgorithmGridView, etc) remain identical.
struct AdrenalineTimerView: View {
    let timeRemaining: TimeInterval
    
    var body: some View {
        HStack {
            Image(systemName: "syringe.fill")
            Text("Adrenaline due in: \(TimeFormatter.format(timeRemaining))")
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.3))
        .foregroundColor(.primary)
        .cornerRadius(12)
    }
}

struct AdrenalineDueWarning: View {
    let action: () -> Void
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Adrenaline Due")
                    .fontWeight(.bold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(PulsatingModifier(isActive: true))
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -40 { onDismiss?() }
                }
        )
    }
}

struct AmiodaroneReminderView: View {
    let action: () -> Void
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "syringe.fill")
                Text("Consider 2nd Amiodarone Dose")
                    .fontWeight(.bold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.purple.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(PulsatingModifier(isActive: true))
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -40 { onDismiss?() }
                }
        )
    }
}

struct AdrenalinePromptView: View {
    let action: () -> Void
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "syringe.fill")
                Text("Consider giving Adrenaline")
                    .fontWeight(.bold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.pink.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(PulsatingModifier(isActive: true))
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -40 { onDismiss?() }
                }
        )
    }
}

struct AmiodaronePromptView: View {
    let action: () -> Void
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "syringe.fill")
                Text("Consider giving Amiodarone")
                    .fontWeight(.bold)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.purple.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(PulsatingModifier(isActive: true))
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < -40 { onDismiss?() }
                }
        )
    }
}


struct MetronomeButton: View {
    @ObservedObject var metronome: Metronome
    
    var body: some View {
        Button(action: metronome.toggle) {
            Image(systemName: "metronome.fill")
                .font(.title2)
                .foregroundColor(metronome.isMetronomeOn ? .white : .blue)
                .frame(width: 44, height: 44)
                .background(metronome.isMetronomeOn ? Color.blue : Color(UIColor.secondarySystemBackground))
                .cornerRadius(22)
                .shadow(radius: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ChecklistView: View {
    let title: String
    @Binding var items: [ChecklistItem]
    @ObservedObject var viewModel: ArrestViewModel
    @Binding var showHypothermiaModal: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            ForEach($items) { $item in
                if item.name == "Hypothermia" {
                    Button(action: { showHypothermiaModal = true }) {
                        ChecklistItemView(item: $item)
                    }
                } else {
                    Button(action: { viewModel.toggleChecklistItemCompletion(for: $item) }) {
                        ChecklistItemView(item: $item)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ChecklistItemView: View {
    @Binding var item: ChecklistItem
    
    var body: some View {
        HStack(alignment: .top) { // Align top for multiline
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(item.isCompleted ? .green : .secondary)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                // Using LocalizedStringKey renders the **Markdown** natively!
                Text(LocalizedStringKey(item.name))
                    .strikethrough(item.isCompleted, color: .primary)
                    .multilineTextAlignment(.leading) // Force left alignment
                
                if item.hypothermiaStatus != .none && item.hypothermiaStatus != .normothermic {
                    Text("(\(item.hypothermiaStatus.rawValue.capitalized))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(item.hypothermiaStatus == .severe ? .blue : .orange)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(.primary)
        .contentShape(Rectangle())
    }
}

struct EventLogView: View {
    let events: [Event]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Log")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if events.isEmpty {
                Text("No events logged yet.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(events) { event in
                    HStack(alignment: .firstTextBaseline) {
                        Text("[\(TimeFormatter.format(event.timestamp))]")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(event.type.color)
                        
                        Text(event.message)
                            .font(.system(size: 14, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct AlgorithmGridView: View {
    @Binding var pdfToShow: PDFIdentifiable?
    
    let algorithms = [
        PDFIdentifiable(pdfName: "adult_als", title: "Adult ALS"),
        PDFIdentifiable(pdfName: "paediatric_als", title: "Paediatric ALS"),
        PDFIdentifiable(pdfName: "newborn_ls", title: "Newborn LS"),
        PDFIdentifiable(pdfName: "post_arrest", title: "Post Arrest Care")
    ]
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Resuscitation Council UK")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Grid(alignment: .center, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    AlgorithmCard(pdf: algorithms[0], pdfToShow: $pdfToShow)
                    AlgorithmCard(pdf: algorithms[1], pdfToShow: $pdfToShow)
                }
                GridRow {
                    AlgorithmCard(pdf: algorithms[2], pdfToShow: $pdfToShow)
                    AlgorithmCard(pdf: algorithms[3], pdfToShow: $pdfToShow)
                }
            }
        }
    }
}

struct AlgorithmCard: View {
    let pdf: PDFIdentifiable
    @Binding var pdfToShow: PDFIdentifiable?
    
    var body: some View {
        Button(action: { pdfToShow = pdf }) {
            Text(pdf.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct BottomControlsView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @Binding var showSummaryModal: Bool
    @Binding var showResetModal: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if viewModel.isTimerPaused {
                Button { viewModel.resumeArrest() } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .tint(.green)
            } else {
                Button { viewModel.undo() } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .disabled(!viewModel.canUndo)
            }
            
            Button { showSummaryModal = true } label: {
                Text("Summary")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            
            if viewModel.isTimerPaused {
                Button { showResetModal = true } label: {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .tint(.red)
            } else {
                Button { viewModel.pauseArrest() } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .tint(.red)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.thinMaterial)
    }
}

