import Foundation

/// How serious a single matched signal is. Deliberately a small, ordered set —
/// SecondLook reports *signals*, not a 0–100 "scam score" (CFO/CCO direction:
/// explainable findings, never a black-box number, never "Company X is a scam").
enum Severity: Int, Codable, CaseIterable, Comparable {
    case info      // normal for this stage, shown for context / good hygiene
    case caution   // worth noticing
    case serious   // does not match how legitimate hiring usually works
    case critical  // a pattern strongly associated with job scams

    static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .info: return "Context"
        case .caution: return "Worth noticing"
        case .serious: return "Unusual"
        case .critical: return "Major red flag"
        }
    }

    var symbolName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .caution: return "eye.circle.fill"
        case .serious: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

/// Where the conversation is in a normal hiring process. The same ask can be
/// perfectly normal at one stage and a red flag at another (an SSN request is
/// routine onboarding paperwork, alarming during first contact).
enum HiringStage: String, Codable, CaseIterable, Identifiable {
    case firstContact
    case interviewing
    case offer
    case onboarding
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstContact: return "First contact"
        case .interviewing: return "Interviewing"
        case .offer: return "Offer on the table"
        case .onboarding: return "Accepted — onboarding"
        case .unsure: return "Not sure"
        }
    }

    var blurb: String {
        switch self {
        case .firstContact:
            return "A recruiter reached out, or you just applied. No interview yet."
        case .interviewing:
            return "You're scheduling interviews or in the middle of them."
        case .offer:
            return "You have a written or verbal offer but haven't accepted."
        case .onboarding:
            return "You accepted and you're doing new-hire paperwork."
        case .unsure:
            return "We'll check against every stage and be a little more cautious."
        }
    }

    /// One-line description of what a legitimate employer would normally ask for
    /// at this point. Shown at the top of the report to frame the findings.
    var whatIsNormal: String {
        switch self {
        case .firstContact:
            return "At this stage a real employer asks about your experience and availability — nothing more. No documents, no numbers, no money."
        case .interviewing:
            return "During interviews a real employer evaluates your skills over phone, video, or in person. They still don't need your ID, SSN, or bank details."
        case .offer:
            return "With an offer out, a real employer sends written terms on company letterhead or email. Background checks run through a named vendor with your consent — never by asking you to wire a fee."
        case .onboarding:
            return "Onboarding is the one stage where SSN, ID, and direct-deposit details are normal — but only through an official payroll or HR portal, never by email, chat, or text."
        case .unsure:
            return "Because the stage is unknown, treat any request for documents, personal numbers, or money as something to verify first."
        }
    }
}

/// A concrete match of one rule against the submitted text.
struct RuleHit: Equatable {
    /// Redacted sentence(s) from the message that triggered the rule.
    var quotes: [String]
}

/// A rule that fired, resolved against the chosen hiring stage.
struct Finding: Identifiable, Equatable, Hashable {
    var ruleID: String
    var title: String
    var severity: Severity
    var explanation: String
    var whatToDo: String
    var quotes: [String]
    /// Set when the underlying ask is actually normal at the chosen stage;
    /// carries the "…but only via an official portal" caveat.
    var normalStageNote: String?

    var id: String { ruleID }
    var isNormalForStage: Bool { normalStageNote != nil }
}

/// Overall read of the message. Wording is intentionally hedged — SecondLook
/// describes the message, it does not deliver verdicts about companies or people.
enum OverallLevel: Int, Codable {
    case clear
    case review
    case strong

    var headline: String {
        switch self {
        case .clear: return "Nothing here stood out"
        case .review: return "A few things worth a closer look"
        case .strong: return "Several things don't line up"
        }
    }

    var detail: String {
        switch self {
        case .clear:
            return "None of our checks matched this message. That's a good sign, but it isn't a guarantee — stay alert as the conversation continues."
        case .review:
            return "Some of what's here doesn't match how legitimate hiring usually works. Read the notes below and verify anything that's asked of you before you respond."
        case .strong:
            return "Multiple parts of this message match patterns commonly seen in fake job offers. Slow down. Don't send money, documents, or personal numbers, and confirm the employer independently."
        }
    }

    var symbolName: String {
        switch self {
        case .clear: return "checkmark.shield.fill"
        case .review: return "questionmark.circle.fill"
        case .strong: return "exclamationmark.shield.fill"
        }
    }
}

/// How a domain found in the message compares to known, real hiring
/// infrastructure. All of this is evaluated on-device against a bundled list —
/// SecondLook never contacts the domain.
struct DomainAssessment: Identifiable, Equatable, Hashable {
    enum Kind: Equatable, Hashable {
        case knownCareerSite(String)   // matched an applicant-tracking / careers host
        case freeMailProvider          // gmail.com, outlook.com, …
        case lookalike(brand: String)  // contains a known brand token, not the official domain
        case unrecognized
    }

    var domain: String
    var kind: Kind

    var id: String { domain }

    var note: String {
        switch kind {
        case .knownCareerSite(let name):
            return "\(domain) is a recognized \(name) address. That's consistent with a real hiring process."
        case .freeMailProvider:
            return "\(domain) is a free personal email service. A recruiter for an established company using a personal address — rather than a company one — is unusual."
        case .lookalike(let brand):
            return "\(domain) resembles \(brand) but is not \(brand)'s official domain. Lookalike domains are a common tactic in impersonation scams."
        case .unrecognized:
            return "We couldn't match \(domain) to a known careers or applicant-tracking site. That isn't automatically bad — look it up independently rather than trusting the link."
        }
    }

    var isReassuring: Bool {
        if case .knownCareerSite = kind { return true }
        return false
    }
}

/// The full result rendered by `ReportView`.
struct AnalysisReport: Equatable, Hashable {
    var stage: HiringStage
    var overall: OverallLevel
    var findings: [Finding]
    var domains: [DomainAssessment]
    var hadText: Bool

    var activeFindings: [Finding] { findings.filter { !$0.isNormalForStage } }
    var contextFindings: [Finding] { findings.filter { $0.isNormalForStage } }

    func count(of severity: Severity) -> Int {
        activeFindings.filter { $0.severity == severity }.count
    }
}
