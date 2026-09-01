import Foundation

/// Input for the opt-in deep check. `text` is the pasted / OCR'd message;
/// `imageData` is a downscaled JPEG of the screenshot (either may be empty, not
/// both).
struct DeepCheckInput: Equatable {
    var text: String
    var imageData: Data?
    var stage: HiringStage

    var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil
    }
}

/// The vision model's read, parsed from the backend's labelled-block reply.
struct DeepCheckResult: Equatable {
    enum Read: Equatable {
        case consistent, worthChecking, doesNotLineUp, unclear

        var headline: String {
            switch self {
            case .consistent: return "Looks consistent with a real process"
            case .worthChecking: return "A few things worth checking"
            case .doesNotLineUp: return "Several things don't line up"
            case .unclear: return "Deep check result"
            }
        }
    }

    var read: Read
    var readLine: String
    var concerns: [String]
    var reply: String
    var verifySteps: [String]
    var model: String
    var rawText: String
}

enum DeepCheckError: Error, LocalizedError {
    case notConfigured
    case noInput
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "The AI backend isn't set up for this build, so the deep check isn't available."
        case .noInput: return "Add a screenshot or paste some message text first."
        case .failed(let why): return why
        }
    }
}

/// Runs the deep check. Only reachable when a backend is configured **and** the
/// user has accepted the one-time consent (`DeepCheckConsent`).
struct DeepChecker {
    var ai: AIClient

    /// Images are capped so the base64 payload stays reasonable.
    static let maxImageBytes = 900_000

    func run(_ input: DeepCheckInput) async throws -> DeepCheckResult {
        guard ai.isConfigured else { throw DeepCheckError.notConfigured }
        guard input.hasContent else { throw DeepCheckError.noInput }

        // Sanitize BEFORE anything leaves the device. SSNs, card/bank numbers
        // and dates of birth are stripped from the text payload here — the
        // screenshot cannot be scrubbed (it's pixels), which the consent copy
        // spells out.
        let text = Sanitizer.sanitized(input.text.trimmingCharacters(in: .whitespacesAndNewlines)).value
        var payload: [String: String] = ["hiring_stage": input.stage.title]
        if !text.isEmpty { payload["text"] = String(text.prefix(6000)) }
        if let data = input.imageData, data.count <= Self.maxImageBytes {
            payload["image"] = "data:image/jpeg;base64,\(data.base64EncodedString())"
        }

        let request = AIRequest(
            task: .deepCheck,
            input: payload,
            prompt: "Assess this job message for someone at the given hiring stage."
        )

        do {
            let response = try await ai.run(request)
            return Self.parse(response.text, model: response.model)
        } catch {
            if error.isCancellation { throw error }
            let why = (error as? AIGatewayError).map(Self.describe) ?? "The AI backend couldn't be reached. Try again in a moment."
            throw DeepCheckError.failed(why)
        }
    }

    private static func describe(_ error: AIGatewayError) -> String {
        switch error {
        case .server(let status) where status == 429: return "The AI backend is busy right now. Try again in a minute."
        case .server(let status): return "The AI backend returned an error (\(status))."
        case .transport, .decoding, .notConfigured: return "The AI backend couldn't be reached. Try again in a moment."
        }
    }

    // MARK: Parsing

    static func parse(_ raw: String, model: String) -> DeepCheckResult {
        let lines = raw.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        var readLine = ""
        var concerns: [String] = []
        var reply = ""
        var verify: [String] = []

        enum Block { case none, concerns, verify }
        var block: Block = .none

        for line in lines where !line.isEmpty {
            let lower = line.lowercased()
            if lower.hasPrefix("read:") {
                readLine = trimValue(line); block = .none
            } else if lower.hasPrefix("concerns:") {
                block = .concerns
                let inline = trimValue(line); if !inline.isEmpty { concerns.append(inline) }
            } else if lower.hasPrefix("reply:") {
                reply = trimValue(line); block = .none
            } else if lower.hasPrefix("verify:") {
                block = .verify
                let inline = trimValue(line); if !inline.isEmpty { verify.append(inline) }
            } else if line.hasPrefix("-") || line.hasPrefix("•") || line.hasPrefix("*") {
                let item = line.drop { "-•* \t".contains($0) }.trimmingCharacters(in: .whitespaces)
                guard !item.isEmpty else { continue }
                switch block {
                case .concerns: concerns.append(item)
                case .verify: verify.append(item)
                case .none: break
                }
            } else if block == .none, reply.isEmpty == false {
                reply += " " + line   // wrapped reply paragraph
            }
        }

        let filteredConcerns = concerns.filter { !$0.lowercased().contains("none found") && $0.lowercased() != "none" }

        return DeepCheckResult(
            read: classify(readLine, concerns: filteredConcerns),
            readLine: readLine.isEmpty ? "Here's the deep check." : readLine,
            concerns: filteredConcerns,
            reply: reply.trimmingCharacters(in: .whitespaces),
            verifySteps: verify,
            model: model,
            rawText: raw
        )
    }

    private static func trimValue(_ line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func classify(_ readLine: String, concerns: [String]) -> DeepCheckResult.Read {
        let l = readLine.lowercased()
        if l.contains("do not line up") || l.contains("don't line up") || l.contains("does not line up") { return .doesNotLineUp }
        if l.contains("worth checking") || l.contains("few things") { return .worthChecking }
        if l.contains("consistent") { return concerns.isEmpty ? .consistent : .worthChecking }
        if concerns.count >= 3 { return .doesNotLineUp }
        if !concerns.isEmpty { return .worthChecking }
        return readLine.isEmpty ? .unclear : .consistent
    }
}
