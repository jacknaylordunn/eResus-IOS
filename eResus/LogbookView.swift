//
//  LogbookView.swift
//  eResus
//
//  Created by Jack Naylor Dunn on 10/09/2025.
//

import SwiftUI
import SwiftData

struct LogbookView: View {
    @Query(sort: \SavedArrestLog.startTime, order: .reverse) private var logs: [SavedArrestLog]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedLog: SavedArrestLog?

    var body: some View {
        NavigationView {
            List {
                if logs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 60))
                        Text("No Saved Logs")
                            .font(.title2.bold())
                        Text("Completed arrest logs will appear here for review.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(logs) { log in
                        Button(action: { selectedLog = log }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(log.startTime, style: .date)
                                        .fontWeight(.bold)
                                    Text(log.startTime, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(log.outcome)
                                        .font(.headline)
                                        .foregroundColor(log.outcome == "ROSC" ? .green : .gray)
                                    Text("Duration: \(formatTime(log.totalDuration))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteLog)
                }
            }
            .navigationTitle("Logbook")
            .sheet(item: $selectedLog) { log in
                SummaryView(events: log.events)
            }
        }
    }
    
    private func deleteLog(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(logs[index])
            }
        }
    }
}
