import Foundation

/// One round card for "Spot the scam". Every message here is **synthetic** —
/// invented recruiters, companies, and domains, written to demonstrate a
/// pattern, never a copy of a real message (same rule as `SampleMessages`).
///
/// `isScam` is the answer shown to the player. The test suite cross-checks it
/// against `RuleEngine.analyze` so the practice mode can never teach something
/// the real engine contradicts.
struct PracticeCard: Identifiable, Equatable {
    let id: String
    let text: String
    let stage: HiringStage
    /// The answer: does this message show job-scam patterns?
    let isScam: Bool
    /// Rule ids this card is built to demonstrate (links into "Your radar").
    /// Empty for the legit cards.
    let teaches: [String]
    /// One sentence shown on the reveal, in plain language.
    let takeaway: String
}

enum PracticeDeck {

    /// How many cards make one round.
    static let roundLength = 6

    static let all: [PracticeCard] = [

        // ── Scam cards ───────────────────────────────────────────────────────

        PracticeCard(
            id: "kit-fee",
            text: """
            Congratulations! You've been approved for the Remote Customer Support role \
            at BrightPath Solutions ($29/hr). Before your start date we'll ship your \
            equipment package. There is a one-time refundable equipment fee of $185 — \
            send it via Cash App to our procurement team and your laptop goes out same day.
            """,
            stage: .offer,
            isScam: true,
            teaches: ["upfront_payment", "gift_card_or_wire"],
            takeaway: "Money in a real hiring process only ever flows toward you. A fee to start is the scam itself."
        ),

        PracticeCard(
            id: "overpayment",
            text: """
            Welcome to the team! Your first task is to set up your home office. \
            We've mailed you a check for $2,400. Deposit it, keep $400 as your \
            signing bonus, and wire the remaining $2,000 to our approved furniture \
            vendor today so everything arrives before Monday.
            """,
            stage: .onboarding,
            isScam: true,
            teaches: ["check_overpayment"],
            takeaway: "The check looks fine for a few days, then bounces — and the bank takes back every dollar, including what you wired on."
        ),

        PracticeCard(
            id: "giftcards",
            text: """
            Hi, welcome aboard. To get your software licenses activated, please \
            purchase four $200 Apple gift cards from any store and send me photos of \
            the codes on the back. You'll be reimbursed in your first paycheck.
            """,
            stage: .onboarding,
            isScam: true,
            teaches: ["gift_card_or_wire", "upfront_payment"],
            takeaway: "No real employer or payroll runs on gift cards. Once a code is read, the money is gone."
        ),

        PracticeCard(
            id: "ssn-first-contact",
            text: """
            Hello, we reviewed your application for the Data Analyst opening and would \
            like to move forward. To run a preliminary check, reply with your full name, \
            home address, and Social Security number so HR can open your file.
            """,
            stage: .firstContact,
            isScam: true,
            teaches: ["ssn_request", "unsolicited_offer"],
            takeaway: "Before any interview, a real employer asks about your experience — never your SSN."
        ),

        PracticeCard(
            id: "telegram-interview",
            text: """
            Thanks for your interest in the Marketing Assistant position. Our hiring \
            manager conducts all interviews over Telegram. Please download the app and \
            message @BrightPath_HR to begin your screening today.
            """,
            stage: .interviewing,
            isScam: true,
            teaches: ["chat_app_interview", "move_off_platform"],
            takeaway: "Real interviews happen on the phone, on video, or in person — not entirely through a chat app."
        ),

        PracticeCard(
            id: "hired-on-the-spot",
            text: """
            Dear Applicant, we are pleased to offer you the position of Administrative \
            Coordinator. No interview is necessary — your resume speaks for itself. \
            Reply "I accept" within 24 hours to secure your spot and we'll send \
            onboarding documents.
            """,
            stage: .firstContact,
            isScam: true,
            teaches: ["offer_without_interview", "generic_greeting", "urgency_pressure"],
            takeaway: "An offer with no interview, a generic greeting, and a countdown are three classic tells at once."
        ),

        PracticeCard(
            id: "license-photo",
            text: """
            Hi! Great news — you're a strong fit for the Remote Scheduler role. To \
            verify your identity before we proceed, text a clear photo of the front and \
            back of your driver's license to this number.
            """,
            stage: .firstContact,
            isScam: true,
            teaches: ["id_document_request"],
            takeaway: "ID verification belongs at onboarding, through an official portal — not by text before you've even interviewed."
        ),

        PracticeCard(
            id: "reshipping",
            text: """
            The Logistics Quality Associate role is fully remote. You'll receive \
            packages at your home, inspect the contents, repackage them, and forward \
            them to addresses we provide using prepaid labels. Pay is $35 per package.
            """,
            stage: .offer,
            isScam: true,
            teaches: ["reshipping_or_payment_processing"],
            takeaway: "\"Receive and reship packages\" jobs move stolen goods. You're the one whose name is on the shipments."
        ),

        PracticeCard(
            id: "too-good",
            text: """
            Dear Candidate, we came across your profile and think you'd be perfect. \
            Simple data entry, no experience needed, work just 2-3 hours daily from \
            home for $95/hour. Positions are filling fast — reply now to claim yours.
            """,
            stage: .firstContact,
            isScam: true,
            teaches: ["too_good_pay", "generic_greeting", "unsolicited_offer", "urgency_pressure"],
            takeaway: "Pay far above the going rate for easy work, aimed at \"Dear Candidate,\" is bait."
        ),

        PracticeCard(
            id: "gmail-recruiter-link",
            text: """
            Hello, I'm a recruiter working on behalf of a Fortune 500 client. Please \
            complete your onboarding and background check at hr-verify-portal.co \
            (link: bit.ly/3xampleHR). Any questions, reply to this address: \
            brightpath.talent2026@gmail.com
            """,
            stage: .offer,
            isScam: true,
            teaches: ["unverified_onboarding_link", "personal_email_for_company_recruiter"],
            takeaway: "A recruiter on a free email address, sending a shortened link to an unfamiliar \"portal,\" is impersonation."
        ),

        // ── Legitimate cards ─────────────────────────────────────────────────

        PracticeCard(
            id: "clean-recruiter",
            text: """
            Hi Sam — I'm a recruiter at Northwind Software. We saw your application for \
            the Backend Engineer role and I'd love to set up a 30-minute phone screen. \
            You can pick a time here: https://jobs.lever.co/northwind/backend-engineer
            """,
            stage: .firstContact,
            isScam: false,
            teaches: [],
            takeaway: "A named company, a real applicant-tracking link, and a simple ask to talk — nothing unusual here."
        ),

        PracticeCard(
            id: "real-onboarding",
            text: """
            Hi Jordan, welcome aboard! Now that your offer is signed, log in to our \
            Workday portal (link in your company email) to complete your I-9 and W-4. \
            You'll enter your Social Security number and set up direct deposit there. \
            First day is Monday.
            """,
            stage: .onboarding,
            isScam: false,
            teaches: [],
            takeaway: "SSN and direct deposit are normal at onboarding — but only inside an official payroll portal, which this is."
        ),

        PracticeCard(
            id: "offer-letter",
            text: """
            Hi Alex, it was great meeting the team. Attached is your formal offer \
            letter for the Product Designer role — salary, start date, and benefits are \
            all spelled out. Take your time reviewing it and let me know if you have \
            questions. — Dana, People team, Northwind
            """,
            stage: .offer,
            isScam: false,
            teaches: [],
            takeaway: "A written offer with clear terms, after interviews, from a named person — this is how it's supposed to look."
        ),

        PracticeCard(
            id: "interview-schedule",
            text: """
            Hi Priya, thanks for the great conversation yesterday. We'd like to invite \
            you to a final round: a 45-minute technical interview and a 30-minute chat \
            with the hiring manager. Are you free Thursday or Friday afternoon?
            """,
            stage: .interviewing,
            isScam: false,
            teaches: [],
            takeaway: "Scheduling more conversations, referencing a real prior one — normal interview logistics."
        ),

        PracticeCard(
            id: "vendor-bgcheck",
            text: """
            Hi Chris, as a final step before your start date we run a standard \
            background check through our vendor, HireRight. You'll get an email from \
            them directly asking for your consent and details — nothing is handled \
            through me. Let me know once you've completed it.
            """,
            stage: .offer,
            isScam: false,
            teaches: [],
            takeaway: "A real background check runs through a named vendor with your consent — the employer never collects the data by DM."
        ),

        PracticeCard(
            id: "portfolio-request",
            text: """
            Hi Morgan — following up on your application for the UX Researcher role. \
            Could you share a link to your portfolio or a few case studies, and let me \
            know your general availability for a first call next week?
            """,
            stage: .firstContact,
            isScam: false,
            teaches: [],
            takeaway: "Asking for work samples and availability is exactly what a first recruiter message should contain."
        ),
    ]

    /// A shuffled round: `roundLength` cards with a realistic mix (never all
    /// scam or all legit).
    static func round(using generator: inout some RandomNumberGenerator) -> [PracticeCard] {
        let scams = all.filter(\.isScam).shuffled(using: &generator)
        let legit = all.filter { !$0.isScam }.shuffled(using: &generator)
        let legitCount = max(2, min(legit.count, roundLength / 2 - 1 + Int.random(in: 0...1, using: &generator)))
        let picked = (Array(legit.prefix(legitCount)) + Array(scams.prefix(roundLength - legitCount)))
        return picked.shuffled(using: &generator)
    }

    static func round() -> [PracticeCard] {
        var g = SystemRandomNumberGenerator()
        return round(using: &g)
    }
}
