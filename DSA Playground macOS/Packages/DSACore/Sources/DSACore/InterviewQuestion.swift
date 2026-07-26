import Foundation

/// Classic interview prompt linked to a DSA module (loaded from static JSON).
public struct InterviewQuestion: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let difficulty: String
    /// Short one-line blurb for compact lists.
    public let summary: String
    /// Full problem description shown in the Question Bank UI.
    public let description: String
    public let approach: String
    /// Swift playground source embedded in the JSON file.
    public let swiftCode: String
    public let tags: [String]
    public let moduleID: String?

    public init(
        id: String,
        title: String,
        difficulty: String,
        summary: String,
        description: String? = nil,
        approach: String,
        swiftCode: String,
        tags: [String] = [],
        moduleID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.difficulty = difficulty
        self.summary = summary
        self.description = (description?.isEmpty == false) ? description! : summary
        self.approach = approach
        self.swiftCode = swiftCode
        self.tags = tags
        self.moduleID = moduleID
    }

    /// Backward-compatible alias used by editor open/run helpers.
    public var starterCode: String { swiftCode }

    public var searchText: String {
        ([title, difficulty, summary, description, approach] + tags).joined(separator: " ").lowercased()
    }

    enum CodingKeys: String, CodingKey {
        case id, title, difficulty, summary, description, approach, swiftCode, tags, moduleID
        case starterCode
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        difficulty = try c.decode(String.self, forKey: .difficulty)
        summary = try c.decode(String.self, forKey: .summary)
        let decodedDescription = try c.decodeIfPresent(String.self, forKey: .description)
        description = (decodedDescription?.isEmpty == false) ? decodedDescription! : summary
        approach = try c.decode(String.self, forKey: .approach)
        if let code = try c.decodeIfPresent(String.self, forKey: .swiftCode) {
            swiftCode = code
        } else {
            swiftCode = try c.decode(String.self, forKey: .starterCode)
        }
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        moduleID = try c.decodeIfPresent(String.self, forKey: .moduleID)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(summary, forKey: .summary)
        try c.encode(description, forKey: .description)
        try c.encode(approach, forKey: .approach)
        try c.encode(swiftCode, forKey: .swiftCode)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(moduleID, forKey: .moduleID)
    }
}

/// Loads per-question static JSON from `Resources/QuestionBank/{moduleID}/{id}.json`.
public enum InterviewQuestionBank {
    private static var cache: [String: [InterviewQuestion]] = [:]
    private static let lock = NSLock()

    public static func questions(forModuleID moduleID: String) -> [InterviewQuestion] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[moduleID] { return cached }
        let loaded = loadFromBundle(moduleID: moduleID)
        cache[moduleID] = loaded
        return loaded
    }

    public static func resetCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    private static func loadFromBundle(moduleID: String) -> [InterviewQuestion] {
        guard let root = Bundle.main.resourceURL?
            .appendingPathComponent("QuestionBank", isDirectory: true)
            .appendingPathComponent(moduleID, isDirectory: true)
        else {
            return []
        }

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let decoder = JSONDecoder()
        var questions: [InterviewQuestion] = []
        for url in files where url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: url),
                  var question = try? decoder.decode(InterviewQuestion.self, from: data)
            else { continue }
            if question.moduleID == nil {
                question = InterviewQuestion(
                    id: question.id,
                    title: question.title,
                    difficulty: question.difficulty,
                    summary: question.summary,
                    description: question.description,
                    approach: question.approach,
                    swiftCode: question.swiftCode,
                    tags: question.tags,
                    moduleID: moduleID
                )
            }
            questions.append(question)
        }
        return questions.sorted { lhs, rhs in
            if lhs.difficultyRank != rhs.difficultyRank {
                return lhs.difficultyRank < rhs.difficultyRank
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension InterviewQuestion {
    var difficultyRank: Int {
        switch difficulty.lowercased() {
        case "easy": return 0
        case "medium": return 1
        case "hard": return 2
        default: return 3
        }
    }
}
