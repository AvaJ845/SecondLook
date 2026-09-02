import Foundation

/// The "company reality check": when a message names a household-name employer,
/// compare its links to that employer's real domains. Pure and offline — it
/// only reads the text and the links already in it.
enum EmployerCheck {

    static func run(_ message: MessageText) -> EmployerRealityCheck? {
        let mentioned = Employers.mentioned(in: message)
        guard !mentioned.isEmpty else { return nil }

        let linkDomains = message.domains.map { KnownDomains.registrableDomain($0) }.deduplicated()

        let results = mentioned.compactMap { assess($0, linkDomains: linkDomains) }

        // Surface the most useful one: a mismatch beats a match beats "no link".
        return results.first(where: \.isConcern)
            ?? results.first { if case .linkMatches = $0.verdict { return true }; return false }
            ?? results.first
    }

    private static func assess(_ employer: Employer, linkDomains: [String]) -> EmployerRealityCheck? {
        let trusted = employer.trustedDomains
        func make(_ v: EmployerRealityCheck.Verdict) -> EmployerRealityCheck {
            .init(employer: employer.name, careersURL: employer.careersURL, verdict: v)
        }

        if linkDomains.contains(where: trusted.contains) {
            return make(.linkMatches)
        }

        // Links present, none belongs to the employer, and at least one isn't a
        // recognized applicant-tracking host → real mismatch.
        let elsewhere = linkDomains.filter { KnownDomains.careerSites[$0] == nil }
        if !elsewhere.isEmpty {
            return make(.linkMismatch(seen: elsewhere))
        }

        // No link to weigh (or only ATS links). Only nudge for employers that
        // never hire through a third party — otherwise stay quiet.
        return employer.directHire ? make(.noLink) : nil
    }
}
