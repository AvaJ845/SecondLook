import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @Environment(Entitlements.self) private var entitlements
    @State private var showPaywall = false

    /// Free keeps a recent window; Plus keeps everything. Saving is never blocked
    /// — the whole ledger stays on device — this only limits what the list shows.
    private var visibleChecks: [StoredCheck] {
        guard let limit = entitlements.plan.savedHistoryLimit else { return history.checks }
        return Array(history.checks.prefix(limit))
    }

    private var hiddenCount: Int {
        max(0, history.checks.count - visibleChecks.count)
    }

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
                        Section {
                            ForEach(visibleChecks) { check in
                                NavigationLink(value: check) { row(check) }
                            }
                            .onDelete { indexSet in
                                indexSet.map { visibleChecks[$0] }.forEach(history.delete)
                            }
                        }

                        if hiddenCount > 0 {
                            Section {
                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack {
                                        Label("\(hiddenCount) more in your history", systemImage: "lock")
                                        Spacer()
                                        Text("Plus").font(.caption.weight(.bold)).foregroundStyle(Palette.brandTeal)
                                    }
                                }
                            } footer: {
                                Text("SecondLook Plus keeps your full saved history. Your recent checks are always here.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: .general)
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
