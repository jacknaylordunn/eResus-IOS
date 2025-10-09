//
//  LogbookView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import SwiftData

struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedArrestLog.startTime, order: .reverse) private var logs: [SavedArrestLog]
    
    @State private var selectedLog: SavedArrestLog?

    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
                    Button(action: { selectedLog = log }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.startTime, style: .date)
                                .font(.headline)
                            Text(log.startTime, style: .time)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Duration: \(TimeFormatter.format(log.totalDuration)) | Outcome: \(log.finalOutcome)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundColor(.primary)
                }
                .onDelete(perform: deleteLogs)
            }
            .navigationTitle("Logbook")
            .sheet(item: $selectedLog) { log in
                // The events need to be converted from a persistent array to a regular array for the view
                SummaryView(events: Array(log.events), totalTime: log.totalDuration)
            }
        }
    }

    private func deleteLogs(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(logs[index])
            }
        }
    }
}
