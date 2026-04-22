import Foundation

final class MiniMaxAnalyzer: @unchecked Sendable {
    private var apiKey: String
    private let baseURL = "https://api.minimax.chat/v1"

    init(apiKey: String = "") {
        self.apiKey = apiKey
    }

    func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    static let promptTemplates: [MeetingType: String] = [
        .marketingMeeting: """
        Analyze this marketing meeting transcript. Extract:
        1) Key decisions made
        2) Action items with owners
        3) Campaign ideas discussed
        4) Budget implications
        5) Next steps
        """,
        .lessonPlanMeeting: """
        Analyze this lesson planning meeting. Extract:
        1) Topics/units discussed
        2) Learning objectives defined
        3) Materials needed
        4) Assessment strategies
        5) Timeline
        """,
        .studentInterview: """
        Analyze this student interview. Extract:
        1) Student's strengths
        2) Areas for improvement
        3) Goals discussed
        4) Support needed
        5) Follow-up actions
        """,
        .parentTeacherMeeting: """
        Analyze this parent-teacher meeting. Extract:
        1) Student progress summary
        2) Concerns raised (by parent and teacher)
        3) Agreements made
        4) Action items for home and school
        5) Next meeting date
        """,
        .parentIntroductoryCall: """
        Analyze this introductory call with parents. Extract:
        1) Family background shared
        2) Student's learning needs
        3) Parent expectations
        4) Program details discussed
        5) Next steps
        """,
        .classSession: """
        Analyze this class session recording. Extract:
        1) Topics covered
        2) Key concepts taught
        3) Student questions asked
        4) Areas where students struggled
        5) Homework/assignments given
        """,
        .spar: """
        Analyze this sparring/debate session. Extract:
        1) Main arguments presented by each side
        2) Strongest points
        3) Weakest points
        4) Logical fallacies detected
        5) Overall assessment
        """,
        .other: """
        Analyze this meeting transcript. Extract:
        1) Main topics discussed
        2) Key decisions made
        3) Action items
        4) Open questions
        5) Next steps
        """
    ]

    func analyzeTranscript(transcript: String, meetingType: MeetingType) async throws -> String {
        guard !apiKey.isEmpty else {
            throw MiniMaxAnalyzerError.noApiKey
        }

        let prompt = Self.promptTemplates[meetingType] ?? Self.promptTemplates[.other]!

        let fullPrompt = """
        \(prompt)

        TRANSCRIPT:
        \(transcript)

        Please provide a detailed analysis based on the transcript above.
        """

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "MiniMax-Text-01",
            "messages": [
                ["role": "user", "content": fullPrompt]
            ],
            "max_tokens": 2048,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MiniMaxAnalyzerError.apiCallFailed
        }

        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = responseJSON?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? "No analysis generated"

        return content
    }
}

enum MiniMaxAnalyzerError: Error, LocalizedError {
    case noApiKey
    case apiCallFailed

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "MiniMax API key is not configured. Please add it in Settings."
        case .apiCallFailed:
            return "Failed to call MiniMax API. Please check your API key and try again."
        }
    }
}
