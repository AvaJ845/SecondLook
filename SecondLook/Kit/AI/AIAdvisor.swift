import Foundation

/// A piece of advice text plus where it came from, so the UI can label it
/// honestly ("Written from the signals above" vs. a generated paragraph).
struct AIText: Equatable {
    enum Source: Equatable { case generated, deterministic }
    var text: String
    var source: Source
}

protocol AIAdvisor {
    /// A short plain-language read of the report.
    func plainSummary(for report: AnalysisReport) async -> AIText
    /// A safe reply the user could send, or a note on why not to reply.
    func replyCoaching(for report: AnalysisReport) async -> AIText
}

/// Turns SecondLook's deterministic findings into readable guidance. When a
/// backend is configured it asks the AI gateway to phrase it; otherwise it
/// builds the same guidance from templates. Either way the input is the app's
/// own rule metadata — **the user's message text is never sent anywhere.**
struct DefaultAIAdvisor: AIAdvisor {
    var ai: AIClient

    // MARK: Plain summary

    func plainSummary(for report: AnalysisReport) async -> AIText {
        let signals = report.activeFindings
            .map { "\($0.severity.label): \($0.title)" }
            .joined(separator: "; ")
        let context = report.contextFindings.map(\.title).joined(separator: "; ")
        let hasLookalike = report.domains.contains {
            if case .lookalike = $0.kind { return true }; return false
        }

        let request = AIRequest(
            task: .plainSummary,
            input: [
                "hiring_stage": report.stage.title,
                "overall_read": report.overall.headline,
                "signals_that_fired": signals.isEmpty ? "none" : signals,
                "normal_for_this_stage": context.isEmpty ? "none" : context,
                "lookalike_domain_present": hasLookalike ? "yes" : "no",
            ],
            prompt: "In 2–3 calm sentences, plain language, explain what stands out about this job "
                + "message for someone at this hiring stage, using ONLY the signals listed. Never "
                + "state that a named company or person is a scammer. Do not introduce signals that "
                + "aren't listed. No greeting, no markdown."
        )

        if let text = await ai.text(for: request), !text.isEmpty {
            return AIText(text: Self.tidy(text), source: .generated)
        }
        return AIText(text: Self.deterministicSummary(report), source: .deterministic)
    }

    static func deterministicSummary(_ report: AnalysisReport) -> String {
        let critical = report.count(of: .critical)
        let serious = report.count(of: .serious)
        let caution = report.count(of: .caution)

        if critical == 0 && serious == 0 && caution == 0 {
            return "None of SecondLook's checks matched this message for the \(report.stage.title.lowercased()) "
                + "stage. That's reassuring, but it isn't proof the offer is real — keep watching for any "
                + "request for money, documents, or personal numbers as the conversation continues."
        }

        var parts: [String] = []
        let topTitles = report.activeFindings.prefix(2).map { "“\($0.title.lowercased())”" }
        if !topTitles.isEmpty {
            parts.append("The clearest issues are " + topTitles.joined(separator: " and ") + ".")
        }
        if critical > 0 {
            parts.append("At least one of these — a major red flag — has no legitimate version at any hiring stage.")
        } else if serious > 0 {
            parts.append("These don't match how a real employer operates at the \(report.stage.title.lowercased()) stage.")
        } else {
            parts.append("None are proof of a scam on their own, but together they're worth pausing on.")
        }
        parts.append("Don't send money, documents, or personal numbers until you've confirmed the employer independently.")
        return parts.joined(separator: " ")
    }

    // MARK: Reply coaching

    func replyCoaching(for report: AnalysisReport) async -> AIText {
        guard !report.activeFindings.isEmpty else {
            return AIText(
                text: "Nothing here calls for a cautious reply. Respond as you normally would, and stay "
                    + "alert if the conversation later turns to money, documents, or personal details.",
                source: .deterministic
            )
        }

        let asks = report.activeFindings.map(\.title).joined(separator: "; ")
        let request = AIRequest(
            task: .replyCoach,
            input: [
                "hiring_stage": report.stage.title,
                "concerning_asks": asks,
                "severity": report.overall.headline,
            ],
            prompt: "Write a short, polite reply (3–4 sentences, plain text, no greeting line needed) the "
                + "job seeker could send that (a) declines to share money, documents, or personal numbers "
                + "for now and (b) asks to verify the role on a video call from a company email address. "
                + "Do not accuse anyone. Do not use markdown."
        )

        if let text = await ai.text(for: request), !text.isEmpty {
            return AIText(text: Self.tidy(text), source: .generated)
        }
        return AIText(text: Self.deterministicReply(report), source: .deterministic)
    }

    static func deterministicReply(_ report: AnalysisReport) -> String {
        let mentionsMoney = report.activeFindings.contains { ["upfront_payment", "gift_card_or_wire", "check_overpayment"].contains($0.ruleID) }
        let mentionsDocs = report.activeFindings.contains { ["ssn_request", "bank_details_request", "id_document_request", "dob_request"].contains($0.ruleID) }

        var body = "Thanks for the details. "
        if mentionsDocs {
            body += "Before I share any personal information or documents, "
        } else if mentionsMoney {
            body += "I'm not able to send any payment or deposit checks as part of a hiring process, and before going further "
        } else {
            body += "Before we go further, "
        }
        body += "I'd like to confirm the role on a short video call with the hiring manager, from a company "
            + "email address. Could you share a company email and a couple of times that work? Once I've "
            + "verified that, I'm happy to continue."
        return body
    }

    // MARK: -

    private static func tidy(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
}
