import Foundation

/// Service for transcribing audio using OpenAI's Whisper API
/// Best accuracy for gym terminology
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
    Gym workout logging. Common phrases: bench press, squat, deadlift, overhead press, \
    barbell row, pull up, chin up, dumbbell, barbell, cable, machine, RPE, RIR, reps, sets, \
    plates, pounds, kilograms, kg, lbs, warmup, working set, PR, personal record, \
    failure, drop set, rest pause, superset, one rep max, 1RM, same, same again, \
    100 for 5, 80 for 8, 60 for 10. Numbers followed by "for" then more numbers means weight for reps.
    """
    
    // MARK: - State
    
    private(set) var isTranscribing = false
    private(set) var lastError: WhisperError?
    
    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Set the API key
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
        #if DEBUG
        print("[WhisperService] API key set")
        #endif
    }
    
    // MARK: - Public API
    
    /// Transcribe audio data to text
    func transcribe(
        audioData: Data,
        language: String? = "en",
        prompt: String? = nil
    ) async throws -> String {
        
        guard !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }
        
        #if DEBUG
        print("[WhisperService] Transcribing \(audioData.count) bytes...")
        #endif
        
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
            #if DEBUG
            print("[WhisperService] Transcription: \(text)")
            #endif
            return text
        case 401:
            throw WhisperError.invalidAPIKey
        case 429:
            throw WhisperError.rateLimited
        case 500...599:
            throw WhisperError.serverError(httpResponse.statusCode)
        default:
            let errorBody = String(data: data, encoding: .utf8)
            throw WhisperError.httpError(httpResponse.statusCode, errorBody)
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
