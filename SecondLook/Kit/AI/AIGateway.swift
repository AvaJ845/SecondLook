import Foundation

/// Which class of model a task needs. Cheap/fast for short structured text,
/// stronger for the paragraph a person actually reads. The app picks the tier
/// per task; the backend owns the task -> model map and the failover chain.
enum ModelTier: String, Codable {
    case fast
    case quality
}

/// Every AI call is one of a fixed set of tasks — never a free-form prompt from
/// a random call site. The backend can route, cache, price, and observe per task,
/// and every task has a deterministic on-device fallback.
///
/// Note on privacy: the `input` for these tasks is built from SecondLook's own
/// rule metadata (which signals fired, the hiring stage) — **not** the user's
/// message text or screenshot. See `AIAdvisor`.
enum AITask: String, Codable, CaseIterable {
    /// One short paragraph explaining what stands out, grounded only in the
    /// listed signals. Never a verdict about a company or person.
    case plainSummary
    /// A safe reply the user could send, or a note explaining why not to reply.
    case replyCoach
    /// A "how to verify this employer yourself" checklist. Guidance, never a
    /// conclusion.
    case verifyEmployer

    /// Opt-in only. A vision model reads the screenshot and/or full message text
    /// and reasons about whether the requests fit a legitimate hiring process.
    /// This is the one task that sends the user's message content off-device —
    /// gated behind an explicit one-time consent in the app.
    case deepCheck

    var defaultTier: ModelTier {
        switch self {
        case .plainSummary, .verifyEmployer: return .fast
        case .replyCoach, .deepCheck: return .quality
        }
    }

    /// True for the task that transmits the user's message content.
    var sendsMessageContent: Bool { self == .deepCheck }
}

/// Who is waiting on a call. A person tapping a button must not queue behind a
/// background pass — `AIClient` grants the pipeline to `.userInitiated` first.
enum RequestOrigin {
    case userInitiated
    case background
}

/// A typed request into the gateway. `input` is structured facts; `prompt` is
/// the instruction. The backend may ignore `prompt` and build its own from
/// `task` + `input`.
struct AIRequest {
    var task: AITask
    var tier: ModelTier
    var input: [String: String]
    var prompt: String
    var origin: RequestOrigin

    init(task: AITask, tier: ModelTier? = nil, input: [String: String] = [:],
         prompt: String, origin: RequestOrigin = .userInitiated) {
        self.task = task
        self.tier = tier ?? task.defaultTier
        self.input = input
        self.prompt = prompt
        self.origin = origin
    }
}

struct AIUsage: Codable, Hashable {
    var inputTokens: Int
    var outputTokens: Int
}

struct AIResponse {
    var text: String
    var model: String
    var cached: Bool
    var usage: AIUsage?
}

enum AIGatewayError: Error {
    /// No backend configured — the app is running fully offline.
    case notConfigured
    case transport(Error)
    case server(status: Int)
    case decoding
}

extension Error {
    /// True when this is just a cancelled async task or URL request — benign
    /// teardown (the caller's view went away or a newer request superseded it),
    /// never a real failure. Cancellations must not be logged, counted, or
    /// failed-over — they unwind quietly.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        if let gatewayError = self as? AIGatewayError, case .transport(let inner) = gatewayError {
            return inner.isCancellation
        }
        return false
    }
}

/// The boundary between the app and every AI provider. Only implementations in
/// this folder ever exist; a caller receives an `AIClient`, never a gateway.
protocol AIGateway {
    func run(_ request: AIRequest) async throws -> AIResponse
}
