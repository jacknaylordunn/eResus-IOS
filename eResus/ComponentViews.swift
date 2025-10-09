//
//  ComponentViews.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

// MARK: - Button Styles & Animations
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// ActionButton has been refactored to take an 'action' closure directly.
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
        // The action is now passed directly to the Button, which is more reliable.
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
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
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("eResus")
                        .font(.largeTitle).bold()
                    Text(viewModel.arrestState.rawValue)
                        .font(.caption)
                        .fontWeight(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(viewModel.arrestState.color)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        if viewModel.timeOffset > 0 {
                            Text("\(Int(viewModel.timeOffset / 60))+")
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.accentColor)
                                .padding(.trailing, 2)
                        }
                        Text(TimeFormatter.format(viewModel.masterTime))
                            .font(.system(size: 50, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    if viewModel.arrestState == .active || viewModel.arrestState == .pending {
                        TimeOffsetButtons(viewModel: viewModel)
                    }
                }
            }
            
            if viewModel.arrestState != .pending {
                 CountersView(viewModel: viewModel)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 5)
        .background(Color(UIColor.systemGroupedBackground).shadow(radius: 2, y: 2))
    }
}


struct CountersView: View {
    @ObservedObject var viewModel: ArrestViewModel
    
    var body: some View {
        HStack {
            Spacer()
            CounterItem(label: "Shocks", value: viewModel.shockCount, color: .orange)
            Spacer()
            CounterItem(label: "Adrenaline", value: viewModel.adrenalineCount, color: .pink)
            Spacer()
            CounterItem(label: "Amiodarone", value: viewModel.amiodaroneCount, color: .purple)
            Spacer()
            CounterItem(label: "Lidocaine", value: viewModel.lidocaineCount, color: .indigo)
            Spacer()
        }
    }
}

struct CounterItem: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(.secondary)
        }
        .foregroundColor(color)
        .frame(minWidth: 65)
    }
}

struct TimeOffsetButtons: View {
    @ObservedObject var viewModel: ArrestViewModel
    
    var body: some View {
        HStack {
            Button("+1m") { viewModel.addTimeOffset(60) }
            Button("+5m") { viewModel.addTimeOffset(300) }
            Button("+10m") { viewModel.addTimeOffset(600) }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct CPRTimerView: View {
    let cprTime: TimeInterval
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 20)
            
            Circle()
                .trim(from: 0, to: cprTime / AppSettings.cprCycleDuration)
                .stroke(cprTime <= 10 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: cprTime)

            VStack {
                Text(TimeFormatter.format(cprTime))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(cprTime <= 10 ? .red : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("CPR CYCLE")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(45)
        }
        .frame(width: 250, height: 270)
    }
}

// MARK: - Screen State Views
struct PendingView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @Binding var pdfToShow: PDFIdentifiable?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Now uses the corrected ActionButton initializer
                ActionButton(title: "Start Arrest", icon: nil, backgroundColor: .red, foregroundColor: .white, height: 60, fontSize: .title2, action: viewModel.startArrest)
                    .padding()
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
                    .padding(.horizontal)
            }
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
    
    let onLogAdrenaline: () -> Void
    let onLogAmiodarone: () -> Void
    let onLogLidocaine: () -> Void
    
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
                    } else {
                        AdrenalineDueWarning()
                    }
                }
                
                if viewModel.shouldShowAdrenalinePrompt {
                    AdrenalinePromptView()
                }
                
                if viewModel.shouldShowAmiodaroneFirstDosePrompt {
                    AmiodaronePromptView()
                }
                
                if viewModel.shouldShowAmiodaroneReminder {
                    AmiodaroneReminderView()
                }
                
                ActionGridView(
                    viewModel: viewModel,
                    showOtherDrugsModal: $showOtherDrugsModal,
                    showEtco2Modal: $showEtco2Modal,
                    onLogAdrenaline: onLogAdrenaline,
                    onLogAmiodarone: onLogAmiodarone,
                    onLogLidocaine: onLogLidocaine
                )
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
                
                ChecklistView(title: "Reversible Causes (4 H's & 4 T's)", items: $viewModel.reversibleCauses, viewModel: viewModel, showHypothermiaModal: $showHypothermiaModal)
                
                EventLogView(events: viewModel.events)
            }
            .padding(.horizontal)
            .padding(.bottom, 200)
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
                ActionButton(title: "Patient Re-Arrested", icon: "arrow.clockwise.heart", backgroundColor: .orange, foregroundColor: .white, height: 60, action: viewModel.reArrest)
                
                ActionButton(title: "Administer Medication", icon: "syringe", backgroundColor: .gray, foregroundColor: .white, height: 60, action: { showOtherDrugsModal = true })
                
                ChecklistView(title: "Post-ROSC Care", items: $viewModel.postROSCTasks, viewModel: viewModel, showHypothermiaModal: .constant(false))
                
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ChecklistView(title: "Actions Following Death", items: $viewModel.postMortemTasks, viewModel: viewModel, showHypothermiaModal: .constant(false))
                
                EventLogView(events: viewModel.events)
                
                AlgorithmGridView(pdfToShow: $pdfToShow)
            }
            .padding()
            .padding(.bottom, 120)
        }
    }
}


// MARK: - Reusable Components
struct ActionGridView: View {
    @ObservedObject var viewModel: ArrestViewModel // Still needed for state checks
    @Binding var showOtherDrugsModal: Bool
    @Binding var showEtco2Modal: Bool
    
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
                        ActionButton(title: "Adv. Airway", icon: "lungs", backgroundColor: .blue, foregroundColor: .white, action: viewModel.logAirwayPlaced)
                            .disabled(viewModel.airwayPlaced)
                        ActionButton(title: "Log ETCO2", icon: "waveform.path", backgroundColor: .teal, foregroundColor: .white, action: { showEtco2Modal = true })
                    }
                }
            }
            
            VStack(spacing: 12) {
                Text("Patient Status").font(.headline).foregroundColor(.secondary)
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        ActionButton(title: "ROSC", icon: "heart.fill", backgroundColor: .green, foregroundColor: .white, action: viewModel.achieveROSC)
                        ActionButton(title: "End Arrest", icon: "xmark.square.fill", backgroundColor: Color(UIColor.systemRed), foregroundColor: .white, action: viewModel.endArrest)
                    }
                }
            }
        }
    }
}

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
    @State private var isPulsing = false
    
    var body: some View {
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
        .scaleEffect(isPulsing ? 1.03 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever()) {
                isPulsing.toggle()
            }
        }
    }
}

struct AmiodaroneReminderView: View {
    @State private var isPulsing = false
    
    var body: some View {
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
        .scaleEffect(isPulsing ? 1.03 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                isPulsing.toggle()
            }
        }
    }
}

struct AdrenalinePromptView: View {
    @State private var isPulsing = false
    
    var body: some View {
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
        .scaleEffect(isPulsing ? 1.03 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                isPulsing.toggle()
            }
        }
    }
}

struct AmiodaronePromptView: View {
    @State private var isPulsing = false
    
    var body: some View {
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
        .scaleEffect(isPulsing ? 1.03 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                isPulsing.toggle()
            }
        }
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
        HStack {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(item.isCompleted ? .green : .secondary)
                .font(.title2)
            
            Text(item.name)
                .strikethrough(item.isCompleted, color: .primary)
            
            if item.hypothermiaStatus != .none && item.hypothermiaStatus != .normothermic {
                Text("(\(item.hypothermiaStatus.rawValue.capitalized))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(item.hypothermiaStatus == .severe ? .blue : .orange)
            }
            
            Spacer()
        }
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
            Button { viewModel.undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .disabled(!viewModel.canUndo)
            
            Button { showSummaryModal = true } label: {
                Text("Summary")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            
            Button { showResetModal = true } label: {
                Label("Reset", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .tint(.red)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.thinMaterial)
    }
}
