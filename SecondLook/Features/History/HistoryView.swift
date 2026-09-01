import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history

    var body: some View {
        NavigationStack {
            Group {
                if history.checks.isEmpty {
                    ContentUnavailableView {
                        Label("No saved checks", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("When you save a check, it's kept here — just the matched signals, the stage, and the date. The message text is never stored.")
                    }
                } else {
                    List {
                        ForEach(history.checks) { check in
                            NavigationLink(value: check) {
                                row(check)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.map { history.checks[$0] }.forEach(history.delete)
                        }
                    }
                }
            }
            .navigationTitle("Saved checks")
            .navigationDestination(for: StoredCheck.self) { check in
                ReportView(report: check.reconstructedReport())
            }
            .toolbar {
                if !history.checks.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Clear all", role: .destructive) { history.clearAll() }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    private func row(_ check: StoredCheck) -> some View {
        HStack(spacing: 12) {
            Image(systemName: check.overall.symbolName)
                .foregroundStyle(Palette.color(for: check.overall))
            VStack(alignment: .leading, spacing: 2) {
                Text(check.label).font(.subheadline.weight(.medium))
                Text("\(check.stage.title) · \(check.matchedRuleIDs.count) signal\(check.matchedRuleIDs.count == 1 ? "" : "s") · \(check.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
