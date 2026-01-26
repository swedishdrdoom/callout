import Foundation

/// Service for transcribing audio using OpenAI's Whisper API
/// Falls back to mock transcription if no API key is configured
@Observable
final class WhisperService {
    static let shared = WhisperService()
    
    // MARK: - Configuration
    
    private var apiKey: String {
        // Check UserDefaults first, then environment
        UserDefaults.standard.string(forKey: "openai_api_key") 
            ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"] 
            ?? ""
    }
    
    private let baseURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let session: URLSession
    
    /// Gym vocabulary prompt to improve transcription accuracy
    private let gymVocabularyPrompt = """
    Gym workout logging: bench press, squat, deadlift, overhead press, barbell row, \
    pull up, chin up, dumbbell, barbell, cable, machine, RPE, RIR, reps, sets, \
    plates, pounds, kilograms, kg, lbs, warmup, working set, PR, personal record, \
    failure, drop set, rest pause, superset, one rep max, 1RM
    """
    
    // MARK: - State
    
    private(set) var isTranscribing = false
    private(set) var lastError: WhisperError?
    
    /// Whether to use mock transcription (for testing without API key)
    var useMockTranscription: Bool {
        get { UserDefaults.standard.bool(forKey: "useMockTranscription") }
        set { UserDefaults.standard.set(newValue, forKey: "useMockTranscription") }
    }
    
    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared) {
        self.session = session
        
        // Default to mock if no API key
        if !hasAPIKey && UserDefaults.standard.object(forKey: "useMockTranscription") == nil {
            useMockTranscription = true
        }
    }
    
    /// Set the API key
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
        if !key.isEmpty {
            useMockTranscription = false
        }
    }
    
    // MARK: - Public API
    
    /// Transcribe audio data to text
    func transcribe(
        audioData: Data,
        language: String? = "en",
        prompt: String? = nil
    ) async throws -> String {
        
        // Use mock if enabled or no API key
        if useMockTranscription || apiKey.isEmpty {
            print("[WhisperService] Using mock transcription")
            return try await mockTranscribe()
        }
        
        print("[WhisperService] Transcribing with Whisper API...")
        
        isTranscribing = true
        lastError = nil
        defer { isTranscribing = false }
        
        let request = try buildRequest(
            audioData: audioData,
            language: language,
            prompt: prompt ?? gymVocabularyPrompt
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let text = try parseResponse(data)
            print("[WhisperService] Transcription: \(text)")
            return text
        case 401:
            throw WhisperError.invalidAPIKey
        case 429:
            throw WhisperError.rateLimited
        case 500...599:
            throw WhisperError.serverError(httpResponse.statusCode)
        default:
            throw WhisperError.httpError(httpResponse.statusCode, String(data: data, encoding: .utf8))
        }
    }
    
    /// Transcribe audio from a file URL
    func transcribe(
        fileURL: URL,
        language: String? = "en",
        prompt: String? = nil
    ) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        return try await transcribe(audioData: data, language: language, prompt: prompt)
    }
    
    // MARK: - Mock Transcription
    
    /// Mock transcription for testing without API key
    /// Returns random gym commands
    private func mockTranscribe() async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let mockResponses = [
            "bench press",
            "100 for 5",
            "squat",
            "80 for 8",
            "same",
            "deadlift",
            "120 for 3",
            "overhead press",
            "60 for 6",
            "same again",
        ]
        
        let response = mockResponses.randomElement() ?? "100 for 5"
        print("[WhisperService] Mock transcription: \(response)")
        return response
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(
        audioData: Data,
        language: String?,
        prompt: String
    ) throws -> URLRequest {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Model field
        body.appendMultipart(name: "model", value: "whisper-1", boundary: boundary)
        
        // Language field (optional)
        if let language {
            body.appendMultipart(name: "language", value: language, boundary: boundary)
        }
        
        // Prompt field
        body.appendMultipart(name: "prompt", value: prompt, boundary: boundary)
        
        // Audio file
        body.appendMultipart(
            name: "file",
            filename: "audio.m4a",
            mimeType: "audio/m4a",
            data: audioData,
            boundary: boundary
        )
        
        // Final boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        return request
    }
    
    private func parseResponse(_ data: Data) throws -> String {
        struct TranscriptionResponse: Decodable {
            let text: String
        }
        
        let response = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return response.text
    }
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case serverError(Int)
    case httpError(Int, String?)
    case invalidResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not configured"
        case .invalidAPIKey:
            return "Invalid OpenAI API key"
        case .rateLimited:
            return "Rate limited - please wait and try again"
        case .serverError(let code):
            return "Server error (\(code)) - please try again"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "Unknown")"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Data Extensions

private extension Data {
    mutating func appendMultipart(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func appendMultipart(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
