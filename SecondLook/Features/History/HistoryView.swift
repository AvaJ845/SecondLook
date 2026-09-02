import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @Environment(ThreadStore.self) private var threads
    @Environment(Entitlements.self) private var entitlements
    @State private var showPaywall = false

    private var visibleChecks: [StoredCheck] {
        guard let limit = entitlements.plan.savedHistoryLimit else { return history.checks }
        return Array(history.checks.prefix(limit))
    }
    private var hiddenCount: Int { max(0, history.checks.count - visibleChecks.count) }
    private var isEmpty: Bool { history.checks.isEmpty && threads.threads.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    ContentUnavailableView {
                        Label("Nothing saved yet", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Save a check to keep the matched signals, or track a whole recruiter conversation with SecondLook Plus.")
                    }
                } else {
                    List {
                        if !threads.threads.isEmpty {
                            Section("Conversations") {
                                ForEach(threads.threads) { thread in
                                    NavigationLink(value: Route.thread(thread.id)) { threadRow(thread) }
                                }
                                .onDelete { $0.map { threads.threads[$0] }.forEach { threads.delete($0.id) } }
                            }
                        }

                        if !history.checks.isEmpty {
                            Section("Saved checks") {
                                ForEach(visibleChecks) { check in
                                    NavigationLink(value: Route.check(check)) { checkRow(check) }
                                }
                                .onDelete { $0.map { visibleChecks[$0] }.forEach(history.delete) }

                                if hiddenCount > 0 {
                                    Button { showPaywall = true } label: {
                                        Label("\(hiddenCount) older — SecondLook Plus keeps them all", systemImage: "lock")
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .thread(let id): ThreadDetailView(threadID: id)
                case .check(let check): ReportView(report: check.reconstructedReport())
                }
            }
            .toolbar {
                if !isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if !history.checks.isEmpty {
                                Button("Clear saved checks", role: .destructive) { history.clearAll() }
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .general) }
        }
    }

    private enum Route: Hashable {
        case thread(UUID)
        case check(StoredCheck)
    }

    private func threadRow(_ thread: ConversationThread) -> some View {
        HStack(spacing: 12) {
            Image(systemName: thread.currentOverall.symbolName)
                .foregroundStyle(Palette.color(for: thread.currentOverall))
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.label).font(.subheadline.weight(.medium))
                Text("\(thread.messages.count) message\(thread.messages.count == 1 ? "" : "s") · \(thread.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func checkRow(_ check: StoredCheck) -> some View {
        HStack(spacing: 12) {
            Image(systemName: check.overall.symbolName)
                .foregroundStyle(Palette.color(for: check.overall))
            VStack(alignment: .leading, spacing: 2) {
                Text(check.label).font(.subheadline.weight(.medium))
                Text("\(check.stage.title) · \(check.matchedRuleIDs.count) signal\(check.matchedRuleIDs.count == 1 ? "" : "s") · \(check.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
