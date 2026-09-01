#if DEBUG
import Foundation

/// Canned, instant AI responses for tests and previews. Swapped in by the
/// `-uitest-mock-ai` launch argument so the progressive-enhancement paths get
/// exercised without depending on a live backend.
///
/// DEBUG-only — compiled out of release builds.
struct MockAIGateway: AIGateway {
    func run(_ request: AIRequest) async throws -> AIResponse {
        let text: String
        switch request.task {
        case .plainSummary:
            text = "Several requests in this message arrive earlier than a real hiring process would "
                + "ever ask for them, and one of them — a payment to get started — has no legitimate "
                + "version. Treat the whole message as unverified until you've confirmed the employer yourself."
        case .replyCoach:
            text = "Thanks for reaching out. Before I share any documents or personal details, I'd like "
                + "to confirm the role on a short video call with the hiring manager, from a company email "
                + "address. Could we set that up?"
        case .verifyEmployer:
            text = """
            CHECKS:
            - Search the company's real website for this exact job title
            - Confirm the recruiter's name on the company's staff or LinkedIn page
            - Check that the email domain matches the company's official domain
            SEARCHES:
            - "company name" careers
            - "recruiter name" "company name"
            """
        case .deepCheck:
            text = """
            READ: several things do not line up
            CONCERNS:
            - Asks for a Social Security number and a photo of your ID before any interview — a real employer collects these only during onboarding
            - Mentions sending a check to buy equipment and wiring back the balance, which is a classic fake-check scheme
            - Pushes to continue on a personal messaging app instead of a company email address
            REPLY: Thanks for the details. Before I share any documents or personal information, I'd like to confirm the role on a short video call with the hiring manager from a company email address. Could we set that up?
            VERIFY:
            - Look up the company's real careers page and confirm this job is posted there
            - Check the recruiter's name against the company's staff directory or LinkedIn
            """
        }
        return AIResponse(text: text, model: "mock", cached: false,
                          usage: AIUsage(inputTokens: 0, outputTokens: 0))
    }
}
#endif
