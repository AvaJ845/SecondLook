import Foundation

/// The optional "check the links against real career sites" pass. Entirely
/// on-device and offline: every domain in the message is compared to the
/// bundled `KnownDomains` reference data. SecondLook never resolves or contacts
/// the domain.
enum DomainChecker {

    static func assess(_ message: MessageText) -> [DomainAssessment] {
        var seen = Set<String>()
        var results: [DomainAssessment] = []

        for domain in message.domains {
            let registrable = KnownDomains.registrableDomain(domain)
            guard seen.insert(registrable).inserted else { continue }

            results.append(DomainAssessment(domain: registrable, kind: classify(domain: domain, registrable: registrable)))
        }

        // Reassuring matches first, then most concerning.
        return results.sorted { lhs, rhs in
            rank(lhs.kind) < rank(rhs.kind)
        }
    }

    private static func classify(domain: String, registrable: String) -> DomainAssessment.Kind {
        // 1. Exact host or registrable match against known hiring infrastructure.
        if let name = KnownDomains.careerSites[domain] ?? KnownDomains.careerSites[registrable] {
            return .knownCareerSite(name)
        }

        // 2. Lookalike: the leading label looks like a brand name (allowing for
        //    character swaps like amaz0n / we11sfarg0) but the domain isn't that
        //    brand's real one. Prefix match on tokens of 5+ chars keeps generic
        //    words ("groups", "purchase") from tripping it.
        let leadingLabel = deLeet(String(registrable.split(separator: ".").first ?? "")
            .replacingOccurrences(of: "-", with: ""))
        for brand in KnownDomains.brands where brand.token.count >= 5 {
            let token = deLeet(brand.token.replacingOccurrences(of: "-", with: ""))
            if leadingLabel.hasPrefix(token), !brand.official.contains(registrable) {
                return .lookalike(brand: brand.name)
            }
        }

        // 3. Free personal mail provider.
        if KnownDomains.freeMailProviders.contains(registrable) {
            return .freeMailProvider
        }

        return .unrecognized
    }

    private static func deLeet(_ s: String) -> String {
        let map: [Character: Character] = ["0": "o", "1": "l", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b"]
        return String(s.map { map[$0] ?? $0 })
    }

    private static func rank(_ kind: DomainAssessment.Kind) -> Int {
        switch kind {
        case .knownCareerSite: return 0
        case .unrecognized: return 1
        case .freeMailProvider: return 2
        case .lookalike: return 3
        }
    }
}
