import Foundation

/// The full rule catalog. Ordered roughly worst-to-least; the engine re-sorts
/// findings by resolved severity anyway. Every string here is user-facing.
enum Rules {

    static let all: [Rule] = [

        // MARK: Money moving toward the "employer"

        Rule(
            id: "upfront_payment",
            title: "Asks you to pay to get the job",
            severity: .critical,
            explanation: "Legitimate employers never charge you for training, equipment, a starter kit, software, a background check, or \"processing.\" Money in a real hiring process only ever flows to you.",
            whatToDo: "Do not pay anything. A request for payment to start work is one of the clearest signs of a fake job.",
            deepDive: DeepDive(
                mechanic: "The \"fee\" is the whole scam. There is no job — the goal is to get one payment from you, or many small ones (\"the training fee, then the equipment fee, then the certification fee\"). The role, the pay, and the company are set dressing to make the ask feel normal.",
                ifYouEngage: "You pay by a method that can't be reversed (gift card, wire, cash app, crypto), the \"recruiter\" goes quiet or invents a new fee, and the money is gone. Some victims are also strung along for weeks doing unpaid \"onboarding tasks.\"",
                protectYourself: "Treat any pre-employment payment as a hard stop — don't negotiate it down or ask for a refund policy, just leave. Real employers pay for their own tools; if equipment is genuinely needed, it's shipped to you or expensed after you start on payroll. Report it at reportfraud.ftc.gov.",
                alsoCalled: "advance-fee job scam · fake job / employment scam"
            ),
            detect: Rule.phrases([
                "registration fee", "training fee", "starter kit", "activation fee",
                "onboarding fee", "equipment fee", "processing fee", "application fee",
                "pay for the equipment", "purchase your own equipment", "buy the software",
                "cover the cost of", "one-time fee", "refundable deposit", "security deposit",
                "pay for your background check",
            ])
        ),

        Rule(
            id: "gift_card_or_wire",
            title: "Wants payment by gift card, wire, crypto, or a cash app",
            severity: .critical,
            explanation: "Gift cards, wire transfers, cryptocurrency, Zelle, Cash App, Venmo and Western Union are favored by scammers because the money can't be recovered. No real employer or payroll runs on them.",
            whatToDo: "Never buy gift cards or send crypto or a wire for anything job-related. Once it's sent, it's gone.",
            deepDive: DeepDive(
                mechanic: "These payment rails are chosen precisely because banks and card networks can't claw the money back. A gift-card code read over the phone, a wire, or a crypto transfer is as final as handing over cash to a stranger.",
                ifYouEngage: "The moment the code or transfer confirmation reaches them, the money is unrecoverable. Requests usually escalate — \"the first card didn't work, buy two more\" — until you stop.",
                protectYourself: "No legitimate employer, payroll provider, or government agency is ever paid in gift cards or crypto. If you've already sent a gift card, call the card's issuer immediately with the receipt and card number — occasionally funds can be frozen if it's fast enough. Then report it to the FTC.",
                alsoCalled: "gift-card scam · wire-transfer fraud"
            ),
            detect: Rule.phrases([
                "gift card", "google play card", "steam card", "apple gift", "itunes card",
                "bitcoin", "btc", "usdt", "crypto wallet", "cryptocurrency",
                "wire transfer", "western union", "moneygram", "zelle", "cash app",
                "cashapp", "venmo", "paypal friends and family", "money order",
            ])
        ),

        Rule(
            id: "check_overpayment",
            title: "Sends you a check and asks you to send money back or buy supplies",
            severity: .critical,
            explanation: "The check is fake. It looks fine for a few days, so you buy equipment or wire back the \"extra\" — then the check bounces and the bank claws back the full amount from your account.",
            whatToDo: "Do not deposit any check from someone you were hired by online, and never forward money from it. This is the overpayment scam.",
            deepDive: DeepDive(
                mechanic: "Your bank makes the check's funds available in a day or two before it actually clears. The scammer uses that window: you're told to keep part as \"pay\" and send the rest to a \"vendor\" (them) for equipment. Days later the check is confirmed fake and your bank reverses the entire amount.",
                ifYouEngage: "You're left owing the bank the full face value of the check plus any overdraft fees — often thousands of dollars — and the money you \"sent to the vendor\" is gone. Depositing a knowingly fake check can also be treated as fraud by the bank.",
                protectYourself: "Never deposit a check from an online \"employer,\" and never send money onward from a deposit. Real payroll is direct deposit set up in an official system after you start. If you already deposited one, tell your bank now, before the funds are spent or forwarded.",
                alsoCalled: "fake-check scam · overpayment scam"
            ),
            detect: Rule.phrases([
                "deposit the check", "cash the check", "mobile deposit", "we will mail you a check",
                "send you a check", "send a check", "receive a check", "you will receive a check",
                "a check will be", "send the remaining", "send back the difference",
                "wire the difference", "wire the remaining", "wire the balance", "wire back",
                "send the balance", "forward the balance", "keep $",
                "purchase the equipment with these funds", "use the funds to buy",
                "use these funds to", "e-check", "cashier's check",
            ])
        ),

        // MARK: Sensitive personal data

        Rule(
            id: "ssn_request",
            title: "Asks for your Social Security number",
            severity: .critical,
            explanation: "Your SSN is only needed for tax and payroll setup, which happens after you've accepted a written offer — and always through an official HR or payroll system, never over email, chat, or text.",
            whatToDo: "Don't send your SSN in a message. If you've genuinely been hired, provide it only inside the company's official onboarding portal.",
            deepDive: DeepDive(
                mechanic: "Your SSN plus your name and date of birth is enough to open credit cards, take out loans, file a fraudulent tax return in your name, or sell the identity package on. Scammers collect it early, before you'd expect a real employer to ask, precisely because most people are used to \"HR paperwork.\"",
                ifYouEngage: "You may not see anything for months, then find accounts you didn't open, a tax refund already claimed, or collections calls. Cleaning up SSN-based identity theft commonly takes 100+ hours over a year.",
                protectYourself: "If you've already sent it: place a free credit freeze at all three bureaus (Equifax, Experian, TransUnion), request an IRS Identity Protection PIN, and file a report at identitytheft.gov for a recovery plan. Going forward, provide an SSN only inside a named company's official payroll/HR portal, never in a message.",
                alsoCalled: "identity theft · SSN scam"
            ),
            normalAtStage: .onboarding,
            normalStageNote: "An SSN request is normal during onboarding — but only inside an official payroll or HR portal (for your W-4 and I-9). Never send it by email, chat, or text, even now.",
            detect: Rule.phrases([
                "social security number", "social security #", "ssn", "your ssn", "s.s.n",
            ])
        ),

        Rule(
            id: "bank_details_request",
            title: "Asks for your bank account or direct-deposit details early",
            severity: .critical,
            explanation: "Direct-deposit setup is part of payroll onboarding after you're hired, done in an official system. Being asked for your account and routing numbers before that has no legitimate purpose.",
            whatToDo: "Don't share banking details over a message. Set up direct deposit only inside the employer's payroll system once you've verified the job is real.",
            deepDive: DeepDive(
                mechanic: "Account and routing numbers let someone create fraudulent ACH debits from your account, or route your real paycheck from a legitimate job to themselves (\"payroll diversion\"). A voided check or online-banking login hands over even more.",
                ifYouEngage: "Unauthorized withdrawals, or a paycheck that never arrives because the deposit was redirected. Recovering diverted wages can take weeks and depends on your bank's and employer's fraud processes.",
                protectYourself: "Never send banking details, a voided check, or a login in a message. If you already did: contact your bank to watch for or block unauthorized ACH activity, consider a new account number, and change any shared password. Real direct-deposit setup happens in the employer's payroll system (ADP, Workday, Gusto, etc.).",
                alsoCalled: "payroll diversion · direct-deposit scam"
            ),
            normalAtStage: .onboarding,
            normalStageNote: "Direct-deposit setup is a normal onboarding step — but do it in the official payroll system, not by sending your account and routing numbers in a message.",
            detect: Rule.phrases([
                "bank account number", "routing number", "account and routing", "voided check",
                "direct deposit information", "your banking details", "debit card number",
                "online banking login", "bank login",
            ])
        ),

        Rule(
            id: "id_document_request",
            title: "Asks you to send a photo of your ID, license, or passport",
            severity: .serious,
            explanation: "Identity documents are verified during formal onboarding (the I-9), through a secure system — not by texting a photo to a recruiter. A driver's license or passport image is enough for identity theft on its own.",
            whatToDo: "Don't send images of your ID over chat or email. Upload them only to the employer's official onboarding portal after verifying the job.",
            deepDive: DeepDive(
                mechanic: "A clear photo of a driver's license or passport is a complete identity kit — it's used to pass \"know your customer\" checks and open bank accounts, crypto exchanges, and loans in your name, or resold. A \"selfie holding your ID\" is even more valuable because it defeats liveness checks.",
                ifYouEngage: "Accounts and credit opened in your name, and your ID circulating on fraud marketplaces indefinitely — you can't \"un-send\" it. Some victims only find out when a bank's fraud team contacts them.",
                protectYourself: "If you've already sent it: freeze your credit, watch for new-account alerts, and report at identitytheft.gov. Real I-9 identity checks happen in person or through the employer's official onboarding portal after you're hired — never as a texted photo to a recruiter.",
                alsoCalled: "identity theft · document fraud"
            ),
            normalAtStage: .onboarding,
            normalStageNote: "Verifying ID is a real onboarding step (Form I-9) — but do it through the official portal or in person, not by sending a photo in a chat.",
            detect: Rule.phrases([
                "photo of your id", "picture of your id", "copy of your id", "photo of your license",
                "driver's license", "drivers license", "your passport", "government id",
                "state id", "photo id", "selfie holding", "id verification photo",
            ])
        ),

        Rule(
            id: "dob_request",
            title: "Asks for your date of birth or security-question answers",
            severity: .serious,
            explanation: "Date of birth, mother's maiden name, and similar details are the exact answers used to unlock bank and credit accounts. There's no reason to collect them before you're hired.",
            whatToDo: "Don't provide these before an offer, and never provide \"security questions\" answers to an employer at all.",
            normalAtStage: .onboarding,
            normalStageNote: "Date of birth can be a legitimate onboarding field for benefits enrollment — inside the HR system. \"Mother's maiden name\" and security-question answers are never a legitimate employer ask.",
            detect: Rule.phrases([
                "date of birth", "your dob", "mother's maiden name", "mothers maiden name",
                "security question", "first pet", "city where you were born",
            ])
        ),

        // MARK: Process shape

        Rule(
            id: "offer_without_interview",
            title: "Offers the job with no real interview",
            severity: .serious,
            explanation: "Real employers evaluate candidates over at least one live conversation — phone, video, or in person. An offer after only messages, a form, or a quick chat skips the part that protects both sides.",
            whatToDo: "Ask to speak with the hiring manager by video or phone. Reluctance to ever get on a call is a strong warning sign.",
            deepDive: DeepDive(
                mechanic: "Skipping the interview isn't sloppiness — it's the point. A live call would expose that there's no real hiring manager, no real team, and no real role. The \"offer\" exists only to move fast to the part where you hand over money or documents.",
                ifYouEngage: "You're rushed into \"onboarding\" — an equipment fee, a deposited check, an ID photo, or payroll details — while it still feels like a normal new job. The person avoids or endlessly reschedules any video call.",
                protectYourself: "Insist on a video call with a named person before accepting anything, and look them up on the company's real site or LinkedIn. A genuine employer will never be offended by that. If every call is dodged, walk away.",
                alsoCalled: "instant-hire scam"
            ),
            flaggedStages: [.firstContact, .interviewing, .offer, .unsure],
            detect: { message in
                let offerLanguage = ["you are hired", "you're hired", "you have been hired",
                                     "pleased to offer you", "we would like to offer you",
                                     "congratulations, you have been selected",
                                     "you have been selected for the position",
                                     "offer you the position", "your application was successful and"]
                guard offerLanguage.contains(where: { message.lower.contains($0) }) else { return nil }
                guard !message.mentionsLiveInterview else { return nil }
                let quote = message.sentences.first { sentence in
                    offerLanguage.contains { sentence.lowercased().contains($0) }
                }
                return RuleHit(quotes: [quote ?? "An offer was extended with no mention of a phone, video, or in-person interview."])
            }
        ),

        Rule(
            id: "chat_app_interview",
            title: "Interview happens only over text or a chat app",
            severity: .serious,
            explanation: "\"Interviews\" conducted entirely over Telegram, WhatsApp, Signal, Google Hangouts/Chat, Skype chat, or Teams text are a hallmark of fake recruiting. Real interviews use voice or video so both people can see who they're talking to.",
            whatToDo: "Decline a text-only interview. Ask for a video call on a normal platform, scheduled from a company email address.",
            deepDive: DeepDive(
                mechanic: "A text-only \"interview\" on Telegram or WhatsApp lets one operator run many victims at once from a script, with no face, no voice, and no verifiable identity. The chat app is also outside any company's oversight, so there's no one to report the account to.",
                ifYouEngage: "The \"interview\" is a few generic questions, then a fast \"you're hired\" and a move straight to onboarding costs or personal details. Ask for a video call and the person will claim a broken camera, a company policy, or simply keep rescheduling.",
                protectYourself: "Treat \"the interview is on Telegram\" as a stop sign. Real interviews are a phone or video call, usually scheduled from a company email address through a normal calendar tool. If you want to keep the door open, reply only asking for a video call — and expect it not to happen.",
                alsoCalled: "Telegram job scam · chat-app recruiting scam"
            ),
            detect: Rule.phrasesTogether(
                ["interview", "screening", "hiring process", "onboarding", "chat with", "meeting"],
                ["telegram", "whatsapp", "signal app", "google hangouts", "hangouts",
                 "skype chat", "wire app", "wickr", "text me on", "message me on",
                 "via text message", "text interview", "chat interview"]
            )
        ),

        Rule(
            id: "move_off_platform",
            title: "Pushes the conversation to a personal channel right away",
            severity: .caution,
            explanation: "Moving off a job board or company email early — to a personal Gmail, a phone number, or a messaging app — takes the conversation somewhere with no oversight and no paper trail.",
            whatToDo: "Keep hiring conversations on the original platform or a verified company email address until you've confirmed the employer.",
            detect: Rule.phrases([
                "contact me directly at", "email me at my personal", "reach me on telegram",
                "add me on whatsapp", "text me at", "message me at", "let's continue on",
                "reply to my personal email", "here is my personal",
            ])
        ),

        Rule(
            id: "urgency_pressure",
            title: "Pressures you to act immediately",
            severity: .caution,
            explanation: "Artificial urgency — \"respond in the next hour,\" \"only two slots left\" — is designed to stop you from checking things. A real employer expects you to take time with an offer.",
            whatToDo: "Slow down. Anything genuine will still be there tomorrow after you've verified it.",
            detect: Rule.phrases([
                "respond within 24 hours", "reply within the hour", "act now", "act fast",
                "limited slots", "positions are filling", "immediate start", "start immediately",
                "offer expires", "must confirm today", "as soon as possible or we will",
                "don't miss this opportunity", "urgent response required",
            ])
        ),

        Rule(
            id: "unsolicited_offer",
            title: "Unsolicited offer for a job you didn't apply to",
            severity: .caution,
            explanation: "Being \"selected\" for a role you never applied for — often after they say they \"found your resume\" — is how many scams open. It's not always fake, but it deserves extra scrutiny.",
            whatToDo: "Look up the company yourself, find its real careers page, and confirm the recruiter works there before engaging.",
            flaggedStages: [.firstContact, .unsure],
            detect: Rule.phrases([
                "found your resume", "came across your profile", "your profile matched",
                "we got your contact", "sourced your details", "your resume was forwarded to us",
                "you have been shortlisted", "we found your cv",
            ])
        ),

        Rule(
            id: "reshipping_or_payment_processing",
            title: "Job is receiving packages or moving money",
            severity: .serious,
            explanation: "\"Package inspection,\" \"quality-control reshipping,\" \"payment processing agent,\" and \"money transfer specialist\" roles are almost always fronts that use you to launder stolen goods or funds.",
            whatToDo: "Don't take a role that involves receiving and reshipping packages or receiving and forwarding payments from your own accounts.",
            deepDive: DeepDive(
                mechanic: "You are the middle layer. \"Reshipping\" moves goods bought with stolen cards through your address so the trail ends at you, not the criminal. \"Payment processing\" runs stolen funds through your bank account, which is money laundering with your name on it.",
                ifYouEngage: "You're rarely paid the promised salary. Your bank account gets frozen or closed for fraud, packages traced to your home can bring a law-enforcement visit, and you can face criminal liability for handling stolen goods or money even if you didn't know.",
                protectYourself: "Never accept a job that has you receive and forward packages, or receive and forward money through your own accounts. If you've already done it: stop, keep every message, and talk to your bank — and consider reporting to the FBI's IC3 (ic3.gov).",
                alsoCalled: "reshipping scam · money mule scheme"
            ),
            detect: Rule.phrases([
                "reship", "re-ship", "package forwarding", "receive packages", "inspect packages",
                "quality control of packages", "payment processing agent", "money transfer agent",
                "process payments through your", "receive funds and forward",
            ])
        ),

        Rule(
            id: "too_good_pay",
            title: "Pay is high for very little, vague work",
            severity: .caution,
            explanation: "A large hourly rate for \"simple data entry,\" \"a few hours a day,\" or work with \"no experience needed\" and no clear responsibilities is a lure, not a job description.",
            whatToDo: "Compare the pay to real listings for that title. If the numbers don't match reality, treat everything else in the message with suspicion.",
            detect: Rule.phrasesTogether(
                ["no experience needed", "no experience required", "simple data entry",
                 "few hours a day", "1-2 hours", "2-3 hours daily", "easy work", "flexible hours from home"],
                ["$", "per hour", "per week", "weekly pay", "/hr", "/hour", "salary"]
            )
        ),

        Rule(
            id: "generic_greeting",
            title: "Generic greeting or noticeably off writing",
            severity: .info,
            explanation: "\"Dear Applicant,\" \"Hello Dear,\" or \"Dear Sir/Madam\" from a recruiter who should know your name — often alongside awkward phrasing — suggests a mass message rather than a real approach.",
            whatToDo: "On its own this isn't proof of anything, but combined with other flags on this list it adds up.",
            detect: Rule.phrases([
                "dear applicant", "dear candidate", "dear sir/madam", "dear sir or madam",
                "hello dear", "good day dear", "dear beneficiary", "attention: job seeker",
            ])
        ),

        Rule(
            id: "unverified_onboarding_link",
            title: "Sends a \"portal\" or \"background check\" link on an unfamiliar site",
            severity: .caution,
            explanation: "A new-hire portal or background-check page hosted on a random domain (not the company's site or a known vendor) is a way to collect your personal data on a page that looks official.",
            whatToDo: "Don't enter anything. Navigate to the company's real website yourself and ask HR to confirm the link.",
            detect: Rule.phrasesTogether(
                ["background check", "onboarding portal", "new hire portal", "employee portal",
                 "complete your profile", "verify your identity at", "hr portal", "candidate portal"],
                ["http://", "https://", ".com", ".net", ".org", ".info", ".xyz", "click here", "link below"]
            )
        ),

        Rule(
            id: "personal_email_for_company_recruiter",
            title: "\"Recruiter\" writes from a personal email address",
            severity: .caution,
            explanation: "Someone hiring on behalf of an established company almost always emails from that company's domain. A Gmail or Outlook address for official recruiting is a mismatch worth questioning.",
            whatToDo: "Ask for a company email address and verify the person on the company's website or LinkedIn before continuing.",
            detect: { message in
                let freeHits = message.emails.filter { email in
                    guard let at = email.firstIndex(of: "@") else { return false }
                    let domain = String(email[email.index(after: at)...])
                    return KnownDomains.freeMailProviders.contains(KnownDomains.registrableDomain(domain))
                }
                let recruiterLanguage = ["recruiter", "hiring manager", "hr department", "talent acquisition",
                                         "on behalf of", "human resources", "recruitment team"]
                guard !freeHits.isEmpty, recruiterLanguage.contains(where: { message.lower.contains($0) }) else { return nil }
                return RuleHit(quotes: freeHits.map { "Sender address: \($0)" })
            }
        ),
    ]

    static func rule(id: String) -> Rule? { all.first { $0.id == id } }
}
