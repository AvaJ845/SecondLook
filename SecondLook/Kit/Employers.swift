import Foundation

/// Bundled, offline reference: the employers most often *named* in job-scam
/// messages (for credibility) and where their real jobs actually live. Nothing
/// here is looked up — the check compares a name found in the text against the
/// links in the same message.
///
/// Not a "verified employer database" (the COO ruled that out as a liability
/// sink). It's a short, stable list of the household names scammers borrow —
/// big banks, retail/ops, shipping, health insurers, tech, staffing firms,
/// airlines, and the government agencies used in the payroll variants. Edit in
/// app releases; the check says plainly when a company isn't on the list.
struct Employer: Equatable {
    /// Display name, e.g. "Wells Fargo".
    let name: String
    /// Lowercased phrases that count as naming this employer in prose. Keep
    /// them distinctive — a bare common word ("target", "chase") only counts
    /// next to a hiring cue (see `EmployerCheck`).
    let aliases: [String]
    /// Registrable domains that belong to this employer (eTLD+1).
    let officialDomains: Set<String>
    /// Human-readable address for "apply directly here".
    let careersURL: String
    /// True when `aliases` contains an everyday English word and needs a hiring
    /// cue nearby to count as a mention.
    let commonWord: Bool
    /// True when nobody legitimately hires "on behalf of" this employer through
    /// a third-party link — a bank, an insurer, a government agency. Only these
    /// get the "no link — apply directly at …" nudge, so a real Amazon delivery
    /// partner or a staffing agency isn't wrongly second-guessed.
    let directHire: Bool

    init(_ name: String, aliases: [String], domains: Set<String>, careers: String,
         commonWord: Bool = false, directHire: Bool = false) {
        self.name = name
        self.aliases = aliases
        self.officialDomains = domains
        self.careersURL = careers
        self.commonWord = commonWord
        self.directHire = directHire
    }

    /// Every registrable domain that legitimately belongs to this employer,
    /// including the one its `careersURL` sits on (so a link to the real
    /// careers host is never flagged as a mismatch).
    var trustedDomains: Set<String> {
        var set = officialDomains
        let host = careersURL.split(separator: "/").first.map(String.init) ?? careersURL
        set.insert(KnownDomains.registrableDomain(host))
        return set
    }
}

enum Employers {

    static let all: [Employer] = [
        // ── Banks & finance ───────────────────────────────────────────────
        Employer("Wells Fargo", aliases: ["wells fargo"], domains: ["wellsfargo.com"], careers: "wellsfargo.com/careers", directHire: true),
        Employer("Bank of America", aliases: ["bank of america", "bofa"], domains: ["bankofamerica.com", "bofa.com"], careers: "careers.bankofamerica.com", directHire: true),
        Employer("Chase", aliases: ["chase", "jpmorgan chase", "jp morgan", "jpmorgan", "chase bank"], domains: ["chase.com", "jpmorganchase.com", "jpmorgan.com"], careers: "jpmorganchase.com/careers", commonWord: true, directHire: true),
        Employer("Citi", aliases: ["citibank", "citigroup"], domains: ["citi.com", "citigroup.com"], careers: "jobs.citi.com", directHire: true),
        Employer("Capital One", aliases: ["capital one"], domains: ["capitalone.com"], careers: "capitalonecareers.com", directHire: true),
        Employer("U.S. Bank", aliases: ["u.s. bank", "us bank", "usbank"], domains: ["usbank.com"], careers: "careers.usbank.com", directHire: true),
        Employer("PNC", aliases: ["pnc bank", "pnc financial"], domains: ["pnc.com"], careers: "careers.pnc.com", directHire: true),
        Employer("American Express", aliases: ["american express", "amex"], domains: ["americanexpress.com", "aexp.com"], careers: "aexp.com/careers", directHire: true),
        Employer("Fidelity", aliases: ["fidelity investments"], domains: ["fidelity.com"], careers: "jobs.fidelity.com", directHire: true),
        Employer("Charles Schwab", aliases: ["charles schwab", "schwab"], domains: ["schwab.com"], careers: "schwabjobs.com", directHire: true),

        // ── Retail, grocery, logistics ────────────────────────────────────
        Employer("Amazon", aliases: ["amazon"], domains: ["amazon.com", "amazon.jobs", "aboutamazon.com"], careers: "amazon.jobs"),
        Employer("Walmart", aliases: ["walmart"], domains: ["walmart.com", "walmartcareers.com"], careers: "careers.walmart.com"),
        Employer("Target", aliases: ["target corporation"], domains: ["target.com"], careers: "corporate.target.com/careers", commonWord: true),
        Employer("Costco", aliases: ["costco"], domains: ["costco.com"], careers: "costco.com/careers.html"),
        Employer("The Home Depot", aliases: ["home depot"], domains: ["homedepot.com"], careers: "careers.homedepot.com"),
        Employer("Lowe's", aliases: ["lowe's", "lowes"], domains: ["lowes.com"], careers: "talent.lowes.com"),
        Employer("Kroger", aliases: ["kroger"], domains: ["kroger.com"], careers: "jobs.kroger.com"),
        Employer("Best Buy", aliases: ["best buy"], domains: ["bestbuy.com"], careers: "jobs.bestbuy.com"),
        Employer("UPS", aliases: ["ups ", "united parcel"], domains: ["ups.com"], careers: "upsjobs.com"),
        Employer("FedEx", aliases: ["fedex"], domains: ["fedex.com"], careers: "careers.fedex.com"),
        Employer("USPS", aliases: ["usps", "united states postal", "u.s. postal service", "post office"], domains: ["usps.com", "usps.gov"], careers: "usps.com/careers"),
        Employer("DHL", aliases: ["dhl"], domains: ["dhl.com"], careers: "careers.dhl.com"),

        // ── Health insurers & pharmacies ─────────────────────────────────
        Employer("UnitedHealth Group", aliases: ["unitedhealth", "united health", "unitedhealthcare", "optum"], domains: ["unitedhealthgroup.com", "uhg.com", "optum.com"], careers: "careers.unitedhealthgroup.com", directHire: true),
        Employer("CVS Health", aliases: ["cvs health", "cvs pharmacy", "cvs caremark"], domains: ["cvshealth.com", "cvs.com"], careers: "jobs.cvshealth.com", directHire: true),
        Employer("Cigna", aliases: ["cigna"], domains: ["cigna.com"], careers: "jobs.cigna.com", directHire: true),
        Employer("Humana", aliases: ["humana"], domains: ["humana.com"], careers: "careers.humana.com", directHire: true),
        Employer("Elevance Health", aliases: ["elevance", "anthem blue cross"], domains: ["elevancehealth.com"], careers: "careers.elevancehealth.com", directHire: true),
        Employer("Kaiser Permanente", aliases: ["kaiser permanente"], domains: ["kaiserpermanente.org", "kp.org"], careers: "jobs.kaiserpermanente.org", directHire: true),

        // ── Tech ─────────────────────────────────────────────────────────
        Employer("Google", aliases: ["google llc", "google careers", "alphabet inc"], domains: ["google.com", "abc.xyz", "withgoogle.com"], careers: "google.com/about/careers", commonWord: true),
        Employer("Microsoft", aliases: ["microsoft"], domains: ["microsoft.com"], careers: "careers.microsoft.com"),
        Employer("Apple", aliases: ["apple inc"], domains: ["apple.com"], careers: "jobs.apple.com", commonWord: true),
        Employer("Meta", aliases: ["meta platforms", "facebook inc"], domains: ["meta.com", "fb.com"], careers: "metacareers.com", commonWord: true),
        Employer("IBM", aliases: ["ibm "], domains: ["ibm.com"], careers: "ibm.com/careers"),
        Employer("Oracle", aliases: ["oracle corporation"], domains: ["oracle.com"], careers: "oracle.com/careers", commonWord: true),
        Employer("Salesforce", aliases: ["salesforce"], domains: ["salesforce.com"], careers: "salesforce.com/company/careers"),
        Employer("Dell", aliases: ["dell technologies"], domains: ["dell.com"], careers: "jobs.dell.com", commonWord: true),
        Employer("Nvidia", aliases: ["nvidia"], domains: ["nvidia.com"], careers: "nvidia.com/en-us/about-nvidia/careers"),

        // ── Staffing & recruiting firms ──────────────────────────────────
        Employer("Randstad", aliases: ["randstad"], domains: ["randstad.com", "randstadusa.com"], careers: "randstadusa.com/jobs"),
        Employer("Adecco", aliases: ["adecco"], domains: ["adecco.com", "adeccousa.com"], careers: "adeccousa.com/jobs"),
        Employer("ManpowerGroup", aliases: ["manpower", "experis"], domains: ["manpower.com", "manpowergroup.com"], careers: "manpower.com/jobs"),
        Employer("Robert Half", aliases: ["robert half"], domains: ["roberthalf.com"], careers: "roberthalf.com/jobs"),
        Employer("Kelly Services", aliases: ["kelly services", "kelly ocg"], domains: ["kellyservices.com", "kellyservices.us"], careers: "kellyservices.us/us/careers"),
        Employer("Aerotek", aliases: ["aerotek"], domains: ["aerotek.com"], careers: "aerotek.com/en/find-a-job"),
        Employer("Insight Global", aliases: ["insight global"], domains: ["insightglobal.com"], careers: "insightglobal.com/find-a-job"),
        Employer("TEKsystems", aliases: ["teksystems"], domains: ["teksystems.com"], careers: "teksystems.com/en/careers"),
        Employer("Aston Carter", aliases: ["aston carter"], domains: ["astoncarter.com"], careers: "astoncarter.com/en/careers"),

        // ── Airlines, telecom, misc. large employers ────────────────────
        Employer("Delta Air Lines", aliases: ["delta air lines", "delta airlines"], domains: ["delta.com"], careers: "delta.com/us/en/careers"),
        Employer("American Airlines", aliases: ["american airlines"], domains: ["aa.com"], careers: "jobs.aa.com"),
        Employer("United Airlines", aliases: ["united airlines"], domains: ["united.com"], careers: "careers.united.com"),
        Employer("Southwest Airlines", aliases: ["southwest airlines"], domains: ["southwest.com"], careers: "careers.southwestair.com"),
        Employer("AT&T", aliases: ["at&t", "at & t"], domains: ["att.com"], careers: "att.jobs"),
        Employer("Verizon", aliases: ["verizon"], domains: ["verizon.com"], careers: "mycareer.verizon.com"),
        Employer("T-Mobile", aliases: ["t-mobile", "tmobile"], domains: ["t-mobile.com"], careers: "careers.t-mobile.com"),
        Employer("Comcast", aliases: ["comcast", "xfinity"], domains: ["comcast.com"], careers: "jobs.comcast.com"),
        Employer("Marriott", aliases: ["marriott"], domains: ["marriott.com"], careers: "careers.marriott.com"),
        Employer("Hilton", aliases: ["hilton hotels", "hilton worldwide"], domains: ["hilton.com"], careers: "jobs.hilton.com"),
        Employer("Deloitte", aliases: ["deloitte"], domains: ["deloitte.com"], careers: "apply.deloitte.com"),
        Employer("Accenture", aliases: ["accenture"], domains: ["accenture.com"], careers: "accenture.com/us-en/careers"),
        Employer("PwC", aliases: ["pwc", "pricewaterhousecoopers"], domains: ["pwc.com"], careers: "pwc.com/us/en/careers"),
        Employer("EY", aliases: ["ernst & young", "ernst and young"], domains: ["ey.com"], careers: "ey.com/en_us/careers"),
        Employer("KPMG", aliases: ["kpmg"], domains: ["kpmg.com", "kpmg.us"], careers: "kpmguscareers.com"),

        // ── Government (payroll / benefits scam variants) ────────────────
        Employer("USAJOBS", aliases: ["usajobs", "usa jobs", "federal government job"], domains: ["usajobs.gov"], careers: "usajobs.gov", directHire: true),
        Employer("the Social Security Administration", aliases: ["social security administration", "the ssa"], domains: ["ssa.gov"], careers: "ssa.gov/careers", directHire: true),
        Employer("the IRS", aliases: ["internal revenue service", "the irs"], domains: ["irs.gov", "jobs.irs.gov"], careers: "jobs.irs.gov", directHire: true),
        Employer("the U.S. Census Bureau", aliases: ["census bureau", "u.s. census"], domains: ["census.gov"], careers: "census.gov/about/careers.html", directHire: true),
    ]

    // MARK: Detection

    /// Hiring cues that make a bare common-word company name ("Apple", "Target")
    /// count as a real mention.
    static let hiringCues = [
        "hiring", "position", "role", "opening", "job", "career", "recruit",
        "opportunity", "vacancy", "candidate", "applicant", "onboarding",
        "on behalf of", "represents", "staffing for", "payroll", "hr department",
        "human resources", "talent",
    ]

    /// The employers this message names, most-specific alias first.
    static func mentioned(in message: MessageText) -> [Employer] {
        let text = message.lower
        return all.filter { employer in
            employer.aliases.contains { alias in
                guard containsWord(alias, in: text) else { return false }
                guard employer.commonWord else { return true }
                // A common word only counts with a hiring cue somewhere in the text.
                return hiringCues.contains { text.contains($0) }
            }
        }
    }

    /// Whole-token match so "targeted" doesn't match "target" and "grape" won't
    /// hit "ape". Alias phrases match on their own boundaries.
    private static func containsWord(_ needle: String, in haystack: String) -> Bool {
        guard let range = haystack.range(of: needle) else { return false }
        let before = range.lowerBound == haystack.startIndex ? nil : haystack[haystack.index(before: range.lowerBound)]
        let after = range.upperBound == haystack.endIndex ? nil : haystack[range.upperBound]
        let boundary: (Character?) -> Bool = { c in
            guard let c else { return true }
            return !(c.isLetter || c.isNumber)
        }
        return boundary(before) && boundary(after)
    }
}
