#if DEBUG
import SwiftUI

/// DEBUG-only viewer for the in-memory AI call log. Never compiled into a
/// release build.
struct DebugLLMLogView: View {
    @Environment(LLMLog.self) private var log

    var body: some View {
        List {
            Section {
                Toggle("Capture AI calls", isOn: Binding(
                    get: { log.isCapturing },
                    set: { log.isCapturing = $0 }
                ))
                Button("Clear", role: .destructive) { log.clear() }
                    .disabled(log.entries.isEmpty)
            }

            if log.entries.isEmpty {
                ContentUnavailableView("No calls yet", systemImage: "terminal")
            } else {
                ForEach(log.entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.task).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(entry.outcome.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(entry.isFailure ? .red : .green)
                        }
                        Text("\(entry.provider) · \(entry.tier) · \(entry.latencyMS)ms\(entry.cached ? " · cached" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let detail = entry.detail {
                            Text(detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(3)
                        }
                    }
                }
            }
        }
        .navigationTitle("AI call log")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
