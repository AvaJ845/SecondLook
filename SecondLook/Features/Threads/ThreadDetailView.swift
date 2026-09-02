import SwiftUI

struct ThreadDetailView: View {
    let threadID: UUID

    @Environment(ThreadStore.self) private var threads
    @Environment(AIClient.self) private var ai
    @Environment(Entitlements.self) private var entitlements
    @Environment(DeepCheckQuota.self) private var quota

    @State private var newReply = ""
    @State private var escalation: ThreadEscalation?
    @State private var showFullReport = false
    @FocusState private var composerFocused: Bool

    private var thread: ConversationThread? { threads.thread(threadID) }

    var body: some View {
        Group {
            if let thread {
                content(thread)
            } else {
                ContentUnavailableView("Conversation not found", systemImage: "bubble.left.and.exclamationmark.bubble.right")
            }
        }
        .navigationTitle(thread?.label ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(_ thread: ConversationThread) -> some View {
        let report = thread.combinedReport()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OverallBanner(report: report)

                if let escalation {
                    escalationCard(escalation)
                }

                Text("The conversation so far")
                    .font(.headline)

                ForEach(Array(thread.messages.enumerated()), id: \.element.id) { index, message in
                    messageRow(number: index + 1, message: message, isLatest: index == thread.messages.count - 1)
                }

                composer(thread)

                DisclosureGroup("What SecondLook found across the whole conversation") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(report.activeFindings) { finding in
                            FindingCard(finding: finding, deepDiveUnlocked: entitlements.isPlus)
                        }
                        if report.activeFindings.isEmpty {
                            Text("Nothing has matched so far. Keep adding replies as they come in.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.subheadline.weight(.medium))
                .tint(.primary)

                DisclaimerFooter()
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func messageRow(number: Int, message: ConversationThread.Message, isLatest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Message \(number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(message.overall.headline)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Palette.color(for: message.overall).opacity(0.15), in: Capsule())
                    .foregroundStyle(Palette.color(for: message.overall))
            }
            Text(message.text)
                .font(.footnote)
                .foregroundStyle(isLatest ? .primary : .secondary)
                .lineLimit(isLatest ? nil : 4)
            Text(message.addedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    private func composer(_ thread: ConversationThread) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add their next reply")
                .font(.subheadline.weight(.medium))
            TextEditor(text: $newReply)
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .focused($composerFocused)
                .cardStyle()
            Button {
                composerFocused = false
                withAnimation {
                    escalation = threads.addMessage(newReply, to: thread.id)
                }
                newReply = ""
            } label: {
                Text("Re-check the conversation")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brandTeal)
            .disabled(newReply.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
        }
    }

    private func escalationCard(_ e: ThreadEscalation) -> some View {
        let tint = Palette.color(for: e.to)
        return VStack(alignment: .leading, spacing: 8) {
            Label(e.headline, systemImage: "arrow.up.forward.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            if e.to.rawValue > e.from.rawValue {
                Text("Went from \u{201C}\(e.from.headline)\u{201D} to \u{201C}\(e.to.headline)\u{201D}.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !e.newFlags.isEmpty {
                ForEach(e.newFlags, id: \.self) { flag in
                    Label(flag, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(tint)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.35), lineWidth: 1))
    }
}
