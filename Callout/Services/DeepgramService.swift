import Foundation

// MARK: - DeepgramService

/// Service for transcribing audio using Deepgram's Nova API
/// Optimized for speed and gym vocabulary
@Observable
final class DeepgramService {
    
    // MARK: - Singleton
    
    static let shared = DeepgramService()
    
    // MARK: - Configuration
    
    private var apiKey: String {
        // Check UserDefaults first, then environment
        UserDefaults.standard.string(forKey: "deepgram_api_key") 
            ?? ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] 
            ?? ""
    }
    
    private let baseURL = URL(string: "https://api.deepgram.com/v1/listen")!
    private let session: URLSession
    
    /// Gym vocabulary keywords to boost transcription accuracy
    private let gymKeywords = [
        "bench press", "squat", "deadlift", "overhead press", "barbell row",
        "pull up", "chin up", "dumbbell", "barbell", "cable", "machine",
        "RPE", "RIR", "reps", "sets", "plates", "pounds", "kilograms",
        "warmup", "working set", "PR", "personal record", "failure",
        "drop set", "rest pause", "superset", "one rep max"
    ]
    
    // MARK: - State
    
    private(set) var isTranscribing = false
    private(set) var lastError: DeepgramError?
    
    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Set the API key
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "deepgram_api_key")
        #if DEBUG
        print("[DeepgramService] API key set")
        #endif
    }
    
    // MARK: - Public API
    
    /// Transcribe audio data to text
    func transcribe(
        audioData: Data,
        language: String? = "en",
        model: String = "nova-2"
    ) async throws -> String {
        
        guard !apiKey.isEmpty else {
            throw DeepgramError.missingAPIKey
        }
        
        #if DEBUG
        print("[DeepgramService] Transcribing \(audioData.count) bytes...")
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif
        
        isTranscribing = true
        lastError = nil
        defer { isTranscribing = false }
        
        let request = try buildRequest(
            audioData: audioData,
            language: language,
            model: model
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepgramError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let text = try parseResponse(data)
            #if DEBUG
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("[DeepgramService] Transcription in \(String(format: "%.2f", elapsed))s: \(text)")
            #endif
            return text
        case 401, 403:
            throw DeepgramError.invalidAPIKey
        case 429:
            throw DeepgramError.rateLimited
        case 500...599:
            throw DeepgramError.serverError(httpResponse.statusCode)
        default:
            let errorBody = String(data: data, encoding: .utf8)
            throw DeepgramError.httpError(httpResponse.statusCode, errorBody)
        }
    }
    
    /// Transcribe audio from a file URL
    func transcribe(
        fileURL: URL,
        language: String? = "en",
        model: String = "nova-2"
    ) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        return try await transcribe(audioData: data, language: language, model: model)
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(
        audioData: Data,
        language: String?,
        model: String
    ) throws -> URLRequest {
        // Build URL with query parameters
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "numerals", value: "true")  // Better number handling
        ]
        
        if let language {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        
        // Add keywords for gym vocabulary boosting
        for keyword in gymKeywords {
            queryItems.append(URLQueryItem(name: "keywords", value: keyword))
        }
        
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        
        return request
    }
    
    private func parseResponse(_ data: Data) throws -> String {
        struct DeepgramResponse: Decodable {
            struct Results: Decodable {
                struct Channel: Decodable {
                    struct Alternative: Decodable {
                        let transcript: String
                    }
                    let alternatives: [Alternative]
                }
                let channels: [Channel]
            }
            let results: Results
        }
        
        let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
        
        // Get the best transcript from first channel, first alternative
        guard let transcript = response.results.channels.first?.alternatives.first?.transcript else {
            throw DeepgramError.emptyTranscription
        }
        
        return transcript
    }
}

// MARK: - Errors

enum DeepgramError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case serverError(Int)
    case httpError(Int, String?)
    case invalidResponse
    case emptyTranscription
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Deepgram API key not configured"
        case .invalidAPIKey:
            return "Invalid Deepgram API key"
        case .rateLimited:
            return "Rate limited - please wait and try again"
        case .serverError(let code):
            return "Server error (\(code)) - please try again"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "Unknown")"
        case .invalidResponse:
            return "Invalid response from server"
        case .emptyTranscription:
            return "No transcription returned"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
