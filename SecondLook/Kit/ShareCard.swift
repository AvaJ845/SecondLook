import Foundation

/// The forwardable artifact — "here's what SecondLook flagged," built to be
/// shared with a friend who's job hunting.
///
/// It is constructed **only** from safe fields: the overall read, the finding
/// *titles* (SecondLook's own strings), and their severities. There is no field
/// for a message quote, a domain, an email, a name, or anything identifying —
/// so a share can never leak the message, by construction.
struct ShareCard: Equatable {
    struct Line: Equatable {
        var title: String
        var severity: Severity
    }

    var headline: String
    var subhead: String
    var lines: [Line]
    var stageLabel: String?
    var contextNote: String?

    /// How many findings to show before "+N more".
    static let maxLines = 6

    init(from report: AnalysisReport) {
        headline = report.overall.headline
        subhead = Self.subhead(for: report)

        let active = report.activeFindings
        lines = active.prefix(Self.maxLines).map { Line(title: $0.title, severity: $0.severity) }
        if active.count > Self.maxLines {
            contextNote = "+\(active.count - Self.maxLines) more in the app"
        }

        stageLabel = report.stage == .unsure ? nil : "Checked for: \(report.stage.title.lowercased())"
    }

    private static func subhead(for report: AnalysisReport) -> String {
        switch report.overall {
        case .clear:
            return "Nothing SecondLook checks for matched — but stay alert as the conversation continues."
        case .review:
            return "Some things here don't match how legitimate hiring usually works. Verify before you respond."
        case .strong:
            return "Multiple parts of this message match patterns seen in fake job offers. Don't send money, documents, or personal numbers."
        }
    }

    /// Plain-text version for share targets that can't take an image, and for
    /// copy. Same content, no message text.
    func plainText() -> String {
        var out = "SecondLook — \(headline)\n\n\(subhead)\n"
        if !lines.isEmpty {
            out += "\nWhat it flagged:\n"
            out += lines.map { "• \($0.title) (\($0.severity.label.lowercased()))" }.joined(separator: "\n")
            if let contextNote { out += "\n• \(contextNote)" }
        }
        if let stageLabel { out += "\n\n\(stageLabel)." }
        out += "\n\nSecondLook checks job messages for scam patterns — on your device. \(SecondLookLinks.shareTagline)"
        return out
    }
}

enum SecondLookLinks {
    /// Set to the real App Store URL once the app is live.
    static let appStore = "https://apps.apple.com/app/secondlook"
    static let shareTagline = "Get it: \(appStore)"
}
