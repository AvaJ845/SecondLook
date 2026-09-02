import AppIntents
import SwiftUI

/// "Is this a scam?" — runs SecondLook's on-device check on a piece of text and
/// shows the result inline, without opening the app. Everything happens locally;
/// the message never leaves the device.
struct ScamCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Check a message for scam patterns"
    static var description = IntentDescription(
        "Runs SecondLook's on-device check on text you pass in and shows what stands out — without opening the app.",
        categoryName: "Checking"
    )
    static var openAppWhenRun = false

    @Parameter(title: "Message", inputOptions: String.IntentInputOptions(multiline: true))
    var message: String

    @Parameter(title: "Hiring stage", default: .unsure)
    var stage: HiringStageAppValue

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let report = RuleEngine.analyze(text: message, stage: stage.stage)
        let dialog = IntentDialog(stringLiteral: Self.spoken(report))
        return .result(dialog: dialog, view: ScamCheckSnippet(report: report))
    }

    private static func spoken(_ report: AnalysisReport) -> String {
        switch report.overall {
        case .clear:  return "Nothing SecondLook checks for matched. Stay alert as the conversation continues."
        case .review: return "A few things here don't match how legitimate hiring usually works. \(report.activeFindings.count) to look at."
        case .strong: return "Several things don't line up — this matches patterns seen in fake job offers. Don't send money, documents, or personal numbers."
        }
    }
}

/// A Shortcuts-friendly wrapper for `HiringStage`.
enum HiringStageAppValue: String, AppEnum {
    case firstContact, interviewing, offer, onboarding, unsure

    var stage: HiringStage { HiringStage(rawValue: rawValue) ?? .unsure }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Hiring stage" }
    static var caseDisplayRepresentations: [HiringStageAppValue: DisplayRepresentation] {
        [
            .firstContact: "First contact",
            .interviewing: "Interviewing",
            .offer: "Offer on the table",
            .onboarding: "Accepted — onboarding",
            .unsure: "Not sure",
        ]
    }
}

/// The inline card shown after the intent runs.
struct ScamCheckSnippet: View {
    let report: AnalysisReport

    private var tint: Color { Palette.color(for: report.overall) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(report.overall.headline).font(.headline)
            } icon: {
                Image(systemName: report.overall.symbolName).foregroundStyle(tint)
            }

            if report.activeFindings.isEmpty {
                Text("Nothing SecondLook checks for matched. A clean result isn't a guarantee — keep watching for requests for money, documents, or personal numbers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.activeFindings.prefix(4)) { finding in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: finding.severity.symbolName)
                            .font(.caption2)
                            .foregroundStyle(Palette.color(for: finding.severity))
                        Text(finding.title).font(.footnote)
                    }
                }
                if report.activeFindings.count > 4 {
                    Text("+\(report.activeFindings.count - 4) more — open SecondLook for the full breakdown")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let employer = report.employer, employer.isConcern {
                Text(employer.headline)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.color(for: .critical))
            }

            Label("Checked on your device", systemImage: "lock.iphone")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(4)
    }
}
