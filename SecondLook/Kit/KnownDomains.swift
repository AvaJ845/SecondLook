import Foundation

/// Bundled reference data for the on-device domain check. Nothing here touches
/// the network — the COO explicitly ruled out a "verified employer database" as
/// a maintenance and liability sink. This is a small, stable set of *hiring
/// infrastructure* hosts plus brand tokens for lookalike detection.
enum KnownDomains {

    /// Applicant-tracking systems and careers hosts. A message that links here
    /// is consistent with a real hiring process.
    static let careerSites: [String: String] = [
        "greenhouse.io": "Greenhouse ATS",
        "boards.greenhouse.io": "Greenhouse ATS",
        "job-boards.greenhouse.io": "Greenhouse ATS",
        "lever.co": "Lever ATS",
        "jobs.lever.co": "Lever ATS",
        "myworkdayjobs.com": "Workday",
        "myworkdaysite.com": "Workday",
        "wd1.myworkdayjobs.com": "Workday",
        "wd5.myworkdayjobs.com": "Workday",
        "icims.com": "iCIMS ATS",
        "smartrecruiters.com": "SmartRecruiters ATS",
        "jobs.smartrecruiters.com": "SmartRecruiters ATS",
        "ashbyhq.com": "Ashby ATS",
        "jobs.ashbyhq.com": "Ashby ATS",
        "bamboohr.com": "BambooHR",
        "jobvite.com": "Jobvite ATS",
        "recruiting.paylocity.com": "Paylocity",
        "taleo.net": "Oracle Taleo",
        "successfactors.com": "SAP SuccessFactors",
        "successfactors.eu": "SAP SuccessFactors",
        "workable.com": "Workable ATS",
        "apply.workable.com": "Workable ATS",
        "breezy.hr": "Breezy HR",
        "rippling.com": "Rippling",
        "ats.rippling.com": "Rippling",
        "gusto.com": "Gusto",
        "linkedin.com": "LinkedIn",
        "indeed.com": "Indeed",
        "ziprecruiter.com": "ZipRecruiter",
        "glassdoor.com": "Glassdoor",
        "dice.com": "Dice",
        "wellfound.com": "Wellfound",
        "usajobs.gov": "USAJOBS (federal)",
    ]

    /// Free personal email services. Fine for a friend; a yellow flag for a
    /// "recruiter" claiming to represent an established company.
    static let freeMailProviders: Set<String> = [
        "gmail.com", "googlemail.com", "outlook.com", "hotmail.com", "live.com",
        "yahoo.com", "ymail.com", "aol.com", "icloud.com", "me.com", "mac.com",
        "proton.me", "protonmail.com", "gmx.com", "gmx.us", "mail.com",
        "zoho.com", "yandex.com", "tutanota.com", "hey.com", "pm.me",
    ]

    /// Brand tokens for lookalike detection, mapped to that brand's real
    /// primary domains. If a message domain *contains* the token but its
    /// registrable domain isn't in the allowed set, it's flagged as a lookalike.
    static let brands: [(token: String, name: String, official: Set<String>)] = [
        ("amazon", "Amazon", ["amazon.com", "amazon.jobs", "amazon.co.uk", "aboutamazon.com"]),
        ("wellsfargo", "Wells Fargo", ["wellsfargo.com"]),
        ("wells-fargo", "Wells Fargo", ["wellsfargo.com"]),
        ("chase", "Chase", ["chase.com", "jpmorganchase.com"]),
        ("jpmorgan", "JPMorgan", ["jpmorganchase.com", "jpmorgan.com"]),
        ("bankofamerica", "Bank of America", ["bankofamerica.com", "bofa.com"]),
        ("usps", "USPS", ["usps.com", "usps.gov"]),
        ("fedex", "FedEx", ["fedex.com"]),
        ("ups", "UPS", ["ups.com"]),
        ("walmart", "Walmart", ["walmart.com", "walmartcareers.com"]),
        ("target", "Target", ["target.com"]),
        ("google", "Google", ["google.com", "abc.xyz", "withgoogle.com"]),
        ("microsoft", "Microsoft", ["microsoft.com"]),
        ("apple", "Apple", ["apple.com"]),
        ("meta", "Meta", ["meta.com", "fb.com"]),
        ("delta", "Delta Air Lines", ["delta.com"]),
        ("cigna", "Cigna", ["cigna.com"]),
        ("unitedhealth", "UnitedHealth", ["unitedhealthgroup.com", "uhg.com"]),
        ("cvs", "CVS", ["cvshealth.com", "cvs.com"]),
        ("humana", "Humana", ["humana.com"]),
        ("costco", "Costco", ["costco.com"]),
    ]

    /// Multi-part public suffixes we recognize so "careers.company.co.uk"
    /// reduces to "company.co.uk" rather than "co.uk".
    private static let multiPartSuffixes: Set<String> = [
        "co.uk", "org.uk", "gov.uk", "ac.uk", "com.au", "net.au", "org.au",
        "co.nz", "co.in", "co.jp", "com.br", "com.mx", "com.sg", "com.hk",
    ]

    /// Best-effort registrable domain (eTLD+1) without shipping a full public
    /// suffix list.
    static func registrableDomain(_ host: String) -> String {
        let parts = host.lowercased().split(separator: ".").map(String.init)
        guard parts.count > 2 else { return host.lowercased() }
        let lastTwo = parts.suffix(2).joined(separator: ".")
        if multiPartSuffixes.contains(lastTwo), parts.count >= 3 {
            return parts.suffix(3).joined(separator: ".")
        }
        return lastTwo
    }
}
