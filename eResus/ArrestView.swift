//
//  ArrestView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI

struct ArrestView: View {
    @ObservedObject var viewModel: ArrestViewModel

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {
                HeaderView(viewModel: viewModel)
                
                if viewModel.arrestState == .pending {
                    PendingView(viewModel: viewModel)
                } else {
                    ScrollView {
                        switch viewModel.arrestState {
                        case .active:
                            ActiveArrestView(viewModel: viewModel)
                        case .rosc:
                            RoscView(viewModel: viewModel)
                        case .ended:
                            EndedView(viewModel: viewModel)
                        default:
                            EmptyView()
                        }
                    }
                }
                
                if viewModel.arrestState != .pending {
                    FooterView(viewModel: viewModel)
                }
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        // MARK: - Modal Presentations
        .sheet(isPresented: $viewModel.isShowingSummary) {
            SummaryView(events: viewModel.events)
        }
        .sheet(isPresented: $viewModel.isShowingEtco2Input) {
            Etco2ModalView(isPresented: $viewModel.isShowingEtco2Input, onConfirm: viewModel.logEtco2)
                .presentationDetents([.height(350)])
        }
        .sheet(isPresented: $viewModel.isShowingHypothermiaInput) {
            HypothermiaModalView(isPresented: $viewModel.isShowingHypothermiaInput, onConfirm: viewModel.setHypothermiaStatus)
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $viewModel.isShowingOtherDrugs) {
            OtherDrugsModalView(isPresented: $viewModel.isShowingOtherDrugs, onSelect: viewModel.logOtherDrug)
        }
        .sheet(isPresented: $viewModel.isShowingResetModal) {
            ResetModalView(
                isPresented: $viewModel.isShowingResetModal,
                onCopyAndReset: {
                    viewModel.copySummaryToClipboard()
                    viewModel.performReset(shouldSaveLog: true)
                },
                onResetAnyway: {
                    viewModel.performReset(shouldSaveLog: true)
                }
            )
            .presentationDetents([.height(400)])
        }
    }
}
