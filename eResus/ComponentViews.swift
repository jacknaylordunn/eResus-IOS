//
//  ComponentViews.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

// MARK: - Action Button (Shared Component)
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !disabled {
                HapticManager.shared.impact(.medium)
                action()
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(4)
            .background(disabled ? Color.gray.opacity(0.5) : color)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(disabled)
        .animation(.default, value: disabled)
    }
}

// MARK: - Screen State Views
struct PendingView: View {
    @ObservedObject var viewModel: ArrestViewModel
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 80))
                .foregroundColor(.red)
            Text("eResus")
                .font(.system(size: 40, weight: .bold))
            Text("by Aegis Medical Solutions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ActionButton(title: "Start Arrest", icon: "bolt.heart.fill", color: .red, action: viewModel.startArrest)
                .padding(.vertical)

            Spacer()
            GroupBox("Pre-Arrival Downtime") {
                HStack(spacing: 20) {
                    TimeOffsetButton(title: "+1m", offset: 60, action: viewModel.addTimeOffset)
                    TimeOffsetButton(title: "+5m", offset: 300, action: viewModel.addTimeOffset)
                    TimeOffsetButton(title: "+10m", offset: 600, action: viewModel.addTimeOffset)
                }
            }
        }
    }
}

struct ActiveArrestView: View {
    @ObservedObject var viewModel: ArrestViewModel
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                CprTimerView(timeRemaining: viewModel.cprTimeRemaining)
                MetronomeToggle(isOn: $viewModel.isMetronomeOn)
            }
            AdrenalineTimerView(viewModel: viewModel)
            AmiodaroneReminderView(viewModel: viewModel)
            ActionGridView(viewModel: viewModel)
            
            // New Time Offset section for active arrests
            GroupBox("Adjust Downtime") {
                HStack(spacing: 20) {
                    TimeOffsetButton(title: "+1m", offset: 60, action: viewModel.addTimeOffset)
                    TimeOffsetButton(title: "+5m", offset: 300, action: viewModel.addTimeOffset)
                    TimeOffsetButton(title: "+10m", offset: 600, action: viewModel.addTimeOffset)
                }
            }
            
            ChecklistView(
                title: "4 H's & 4 T's",
                items: $viewModel.reversibleCauses,
                onToggle: { id in
                    if viewModel.reversibleCauses.first(where: { $0.id == id })?.name == "Hypothermia" {
                        viewModel.isShowingHypothermiaInput = true
                    } else {
                        viewModel.toggleChecklistItem(id: id, list: $viewModel.reversibleCauses)
                    }
                }
            )
            AlgorithmLinkView(viewModel: viewModel)
            EventLogView(events: viewModel.events)
        }
    }
}

struct RoscView: View {
    @ObservedObject var viewModel: ArrestViewModel
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("ROSC Achieved")
                .font(.largeTitle.bold()).foregroundColor(.green).padding()
            ActionButton(title: "Patient Re-Arrested", icon: "exclamationmark.triangle.fill", color: .orange, action: viewModel.reArrest)
            ChecklistView(title: "Post-ROSC Care", items: $viewModel.postROSCTasks, onToggle: { id in
                viewModel.toggleChecklistItem(id: id, list: $viewModel.postROSCTasks)
            })
            AlgorithmLinkView(viewModel: viewModel)
            EventLogView(events: viewModel.events)
            Spacer()
        }
    }
}

struct EndedView: View {
    @ObservedObject var viewModel: ArrestViewModel
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Arrest Ended (Deceased)")
                .font(.largeTitle.bold()).foregroundColor(.gray).padding()
            ChecklistView(title: "Actions Following Death", items: $viewModel.postMortemTasks, onToggle: { id in
                viewModel.toggleChecklistItem(id: id, list: $viewModel.postMortemTasks)
            })
            EventLogView(events: viewModel.events)
            Spacer()
        }
    }
}

// MARK: - Header & Footer
struct HeaderView: View {
    @ObservedObject var viewModel: ArrestViewModel
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("eResus").font(.largeTitle).bold()
                Text(viewModel.arrestState.rawValue)
                    .font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(viewModel.arrestState.color).foregroundColor(.white).cornerRadius(8)
            }
            Spacer()
            HStack(spacing: 0) {
                if viewModel.timeOffset > 0 {
                    Text("\(Int(viewModel.timeOffset / 60))+")
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow.opacity(0.8))
                        .padding(.trailing, 2)
                }
                Text(formatTime(viewModel.masterTime))
                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.arrestState == .rosc ? .green : .yellow)
            }
        }
    }
}

struct FooterView: View {
    @ObservedObject var viewModel: ArrestViewModel
    var body: some View {
        HStack(spacing: 12) {
            Button("Undo", action: viewModel.undo)
                .buttonStyle(FooterButtonStyle(backgroundColor: .blue))
                .disabled(!viewModel.canUndo)
            
            Button("Summary") { viewModel.isShowingSummary = true }
                .buttonStyle(FooterButtonStyle(backgroundColor: .secondary))

            Button("Reset") { viewModel.isShowingResetModal = true }
                .buttonStyle(FooterButtonStyle(backgroundColor: .red))
        }
        .frame(height: 50)
    }
}

// MARK: - Component Views
struct CprTimerView: View {
    let timeRemaining: TimeInterval
    private var totalTime: TimeInterval { AppSettings.cprCycleDuration }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 15)
            
            Circle()
                .trim(from: 0, to: CGFloat(timeRemaining / totalTime))
                .stroke(timeRemaining <= 10 ? Color.red : Color.cyan, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: timeRemaining)

            VStack {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(timeRemaining <= 10 ? .red : .cyan)
                Text("CPR CYCLE")
                    .font(.caption)
                    .kerning(1.5)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 200, height: 200)
    }
}

struct AdrenalineTimerView: View {
    @ObservedObject var viewModel: ArrestViewModel
    
    var body: some View {
        if viewModel.lastAdrenalineTime != nil {
            if viewModel.isAdrenalineDue {
                Label("Adrenaline Due", systemImage: "syringe.fill")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .transition(.scale.animation(.bouncy))
            } else {
                HStack {
                    Image(systemName: "syringe")
                    Text("Adrenaline due in: ")
                    Text(formatTime(viewModel.timeToNextAdrenaline))
                        .font(.system(.body, design: .monospaced).bold())
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
}

struct AmiodaroneReminderView: View {
    @ObservedObject var viewModel: ArrestViewModel
    @State private var isPulsing = false
    
    var body: some View {
        if viewModel.showAmiodaroneDose2Reminder {
            Label("Consider 2nd Amiodarone Dose", systemImage: "syringe.fill")
                .font(.headline.bold())
                .frame(maxWidth: .infinity).padding()
                .background(Color.purple.opacity(0.8))
                .foregroundColor(.white).cornerRadius(12)
                .scaleEffect(isPulsing ? 1.05 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
        }
    }
}

struct ActionGridView: View {
    @ObservedObject var viewModel: ArrestViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            GroupBox("Rhythm & Shock") {
                if viewModel.uiState == .default {
                    ActionButton(title: "Analyse Rhythm", icon: "bolt.heart.fill", color: .blue, action: viewModel.startRhythmAnalysis)
                } else if viewModel.uiState == .analyzing {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ActionButton(title: "VF", icon: "chart.pulse", color: .orange) {
                                viewModel.logRhythm(type: "VF", isShockable: true)
                            }
                            ActionButton(title: "VT", icon: "chart.pulse", color: .orange) {
                                 viewModel.logRhythm(type: "VT", isShockable: true)
                            }
                        }
                        HStack(spacing: 12) {
                            ActionButton(title: "PEA", icon: "chart.pulse", color: .gray) {
                                viewModel.logRhythm(type: "PEA", isShockable: false)
                            }
                            ActionButton(title: "Asystole", icon: "chart.pulse", color: .gray) {
                                viewModel.logRhythm(type: "Asystole", isShockable: false)
                            }
                        }
                    }
                } else if viewModel.uiState == .shockAdvised {
                     ActionButton(title: "Deliver Shock", icon: "bolt.fill", color: .orange, action: viewModel.deliverShock)
                }
            }
            
            GroupBox("Medications") {
                HStack(spacing: 12) {
                    ActionButton(title: "Adrenaline", icon: "syringe.fill", color: .red, disabled: !viewModel.isAdrenalineEnabled, action: viewModel.logAdrenaline)
                    ActionButton(title: "Amiodarone", icon: "syringe.fill", color: .purple, disabled: !viewModel.isAmiodaroneEnabled, action: viewModel.logAmiodarone)
                }
                 HStack(spacing: 12) {
                    ActionButton(title: "Lidocaine", icon: "syringe.fill", color: .pink, disabled: !viewModel.isLidocaineEnabled, action: viewModel.logLidocaine)
                    ActionButton(title: "Other...", icon: "pills.fill", color: .secondary, action: { viewModel.isShowingOtherDrugs = true })
                }
            }
            
            GroupBox("Procedures") {
                HStack(spacing: 12) {
                    ActionButton(title: "Airway", icon: "lungs.fill", color: .indigo, disabled: viewModel.airwayPlaced, action: viewModel.logAirway)
                    ActionButton(title: "ETCO2", icon: "waveform.path.ecg", color: .teal) {
                        viewModel.isShowingEtco2Input = true
                    }
                }
            }
            
            GroupBox("Patient Status") {
                 HStack(spacing: 12) {
                    ActionButton(title: "ROSC", icon: "heart.fill", color: .green, action: viewModel.achieveROSC)
                    ActionButton(title: "End Arrest", icon: "xmark.square.fill", color: .red.opacity(0.8), action: viewModel.endArrest)
                }
            }
        }
    }
}

struct ChecklistView: View {
    let title: String
    @Binding var items: [ChecklistItem]
    let onToggle: (UUID) -> Void

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach($items) { $item in
                    Button(action: { onToggle(item.id) }) {
                        HStack {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isCompleted ? .green : .secondary)
                            Text(item.name)
                                .foregroundColor(.primary)
                                .strikethrough(item.isCompleted, color: .secondary)
                            if item.hypothermiaStatus != .none && item.hypothermiaStatus != .normothermic {
                                Text("(\(item.hypothermiaStatus.rawValue.capitalized))")
                                    .font(.caption.bold())
                                    .foregroundColor(item.hypothermiaStatus == .severe ? .blue : .yellow)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct EventLogView: View {
    let events: [Event]

    var body: some View {
        GroupBox("Event Log") {
            if events.isEmpty {
                Text("No events yet.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(events) { event in
                                HStack(alignment: .top) {
                                    Text("[\(formatTime(event.timestamp))]")
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .foregroundColor(event.type.color)
                                    Text(event.message)
                                        .font(.caption)
                                }.id(event.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: events) {
                        if let firstEvent = events.first {
                            proxy.scrollTo(firstEvent.id, anchor: .top)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

struct AlgorithmLinkView: View {
    @ObservedObject var viewModel: ArrestViewModel

    private var title: String {
        viewModel.arrestState == .rosc ? "Post-Resuscitation Care Guideline" : "Resuscitation Council UK Algorithms"
    }

    var body: some View {
        GroupBox(title) {
            if viewModel.arrestState == .rosc {
                AlgorithmCard(
                    title: "Post Cardiac Arrest Rehabilitation",
                    pdfName: "post_arrest"
                ) {
                    viewModel.selectedPDF = ("post_arrest", "Post Arrest Care")
                }
            } else {
                VStack(spacing: 12) {
                    AlgorithmCard(title: "Adult ALS Algorithm", pdfName: "adult_als") {
                        viewModel.selectedPDF = ("adult_als", "Adult ALS")
                    }
                    AlgorithmCard(title: "Paediatric ALS Algorithm", pdfName: "paediatric_als") {
                        viewModel.selectedPDF = ("paediatric_als", "Paediatric ALS")
                    }
                    AlgorithmCard(title: "Newborn Life Support", pdfName: "newborn_ls") {
                        viewModel.selectedPDF = ("newborn_ls", "Newborn Life Support")
                    }
                }
            }
        }
    }
}

struct AlgorithmCard: View {
    let title: String
    let pdfName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "doc.text.fill")
            }
            .foregroundColor(.accentColor)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

// MARK: - Button Styles and Small Components
struct FooterButtonStyle: ButtonStyle {
    var backgroundColor: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.label.anyView is EmptyView ? 0.5 : 1.0)
    }
}


struct TimeOffsetButton: View {
    let title: String
    let offset: TimeInterval
    let action: (TimeInterval) -> Void
    var body: some View {
        Button(title) {
            HapticManager.shared.impact(.light)
            action(offset)
        }
        .font(.headline.bold())
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(12)
    }
}

struct MetronomeToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            isOn.toggle()
        }) {
            Image(systemName: "music.quarternote.3")
                .font(.largeTitle)
                .foregroundColor(isOn ? .white : .primary)
                .frame(width: 80, height: 80)
                .background(isOn ? Color.green : Color.secondary.opacity(0.2))
                .clipShape(Circle())
        }
    }
}

// Helper to disable footer buttons correctly
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    var anyView: AnyView { AnyView(self) }
}
