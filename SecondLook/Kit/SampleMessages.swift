import Foundation

/// Canned examples for the empty state, previews, and the test suite. These are
/// synthetic — invented recruiters and domains, not copies of real messages.
enum SampleMessages {

    struct Sample: Identifiable {
        let id: String
        let label: String
        let stage: HiringStage
        let text: String
    }

    static let all: [Sample] = [
        Sample(
            id: "reshipping",
            label: "\"Remote work coordinator\" offer",
            stage: .firstContact,
            text: """
            Dear Applicant,

            We found your resume online and are pleased to offer you the position of \
            Remote Work Coordinator with a pay of $38/hour for 2-3 hours daily. No experience needed.

            To begin, please confirm your full name, home address, and date of birth, and send a \
            photo of your driver's license so we can verify your identity. You will receive a check \
            to purchase a company laptop and office supplies; deposit it and wire the remaining \
            balance to our equipment vendor.

            This offer expires in 24 hours. Contact our hiring manager directly on Telegram to continue.

            HR Department
            careers@amaz0n-remote-hiring.com
            """
        ),
        Sample(
            id: "normal-onboarding",
            label: "Onboarding paperwork email",
            stage: .onboarding,
            text: """
            Hi Jordan,

            Welcome aboard! Now that you've signed your offer letter, please log in to our Workday \
            portal (link in your company email) to complete your I-9 and W-4. You'll enter your \
            Social Security number and set up direct deposit there.

            Your first day is Monday. Reach out if the portal gives you any trouble.

            People Operations
            onboarding@company.myworkdayjobs.com
            """
        ),
        Sample(
            id: "impersonation",
            label: "\"Wells Fargo\" hiring email",
            stage: .firstContact,
            text: """
            Dear Candidate,

            Wells Fargo is pleased to move forward with your application for a \
            Remote Client Services role ($32/hour). No interview is required at \
            this stage.

            To begin onboarding, verify your identity and complete your new-hire \
            paperwork at our secure portal: hr-verify-wf.co (bit.ly/wf-onboard). \
            You'll enter your Social Security number and direct-deposit details there.

            Please complete this within 24 hours to hold your position.

            Talent Acquisition Team
            recruiting.wellsfargo2026@gmail.com
            """
        ),
        Sample(
            id: "clean-recruiter",
            label: "Recruiter first message",
            stage: .firstContact,
            text: """
            Hi Sam, I'm a recruiter at Northwind Software. We saw your application for the \
            Backend Engineer role. Are you available for a 30-minute phone screen this week? \
            You can grab a time here: https://jobs.lever.co/northwind/backend-engineer

            Best,
            Alex
            """
        ),
    ]
}
