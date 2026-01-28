import Foundation

// MARK: - DeepgramService

/// Service for transcribing audio using Callout's backend proxy
/// Optimized for speed and gym vocabulary
@Observable
final class DeepgramService {
    
    // MARK: - Singleton
    
    static let shared = DeepgramService()
    
    // MARK: - Configuration
    
    /// Backend API endpoint - proxies to Deepgram with gym keywords
    private let transcribeURL = URL(string: "http://139.59.185.244:3100/api/transcribe")!
    
    private let session: URLSession
    
    // MARK: - State
    
    private(set) var isTranscribing = false
    private(set) var lastError: DeepgramError?
    private(set) var lastLatencyMs: Int?
    
    /// Always available - backend handles API key
    var hasAPIKey: Bool { true }
    
    // MARK: - Initialization
    
    init() {
        // Configure session - aggressive timeout, we'll retry on failure
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8  // Fast fail, then retry
        config.timeoutIntervalForResource = 16
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }
    
    /// Legacy - no longer needed with backend proxy
    func setAPIKey(_ key: String) {
        // No-op: backend handles API key
        #if DEBUG
        print("[DeepgramService] API key management handled by backend")
        #endif
    }
    
    // MARK: - Public API
    
    /// Transcribe audio data to text via backend proxy
    /// Includes automatic retry on timeout
    func transcribe(
        audioData: Data,
        language: String? = "en",
        model: String = "nova-2"
    ) async throws -> String {
        
        isTranscribing = true
        lastError = nil
        defer { isTranscribing = false }
        
        // Try up to 2 times (initial + 1 retry)
        var lastError: Error?
        for attempt in 1...2 {
            do {
                #if DEBUG
                print("[DeepgramService] Attempt \(attempt): Transcribing \(audioData.count) bytes...")
                let startTime = CFAbsoluteTimeGetCurrent()
                #endif
                
                var request = URLRequest(url: transcribeURL)
                request.httpMethod = "POST"
                request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
                request.httpBody = audioData
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DeepgramError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200:
                    let result = try parseResponse(data)
                    lastLatencyMs = result.latencyMs
                    
                    #if DEBUG
                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                    print("[DeepgramService] Success in \(String(format: "%.2f", elapsed))s, API latency: \(result.latencyMs)ms")
                    print("[DeepgramService] Transcript: \(result.transcript)")
                    #endif
                    
                    return result.transcript
                    
                case 429:
                    throw DeepgramError.rateLimited
                case 500...599:
                    throw DeepgramError.serverError(httpResponse.statusCode)
                default:
                    let errorBody = String(data: data, encoding: .utf8)
                    throw DeepgramError.httpError(httpResponse.statusCode, errorBody)
                }
                
            } catch {
                lastError = error
                #if DEBUG
                print("[DeepgramService] Attempt \(attempt) failed: \(error.localizedDescription)")
                #endif
                
                // Don't retry on non-recoverable errors
                if case DeepgramError.rateLimited = error { throw error }
                if case DeepgramError.invalidAPIKey = error { throw error }
                
                // Brief pause before retry
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                }
            }
        }
        
        throw lastError ?? DeepgramError.networkError(NSError(domain: "DeepgramService", code: -1))
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
    
    private func parseResponse(_ data: Data) throws -> TranscribeResponse {
        struct APIResponse: Decodable {
            let transcript: String
            let latencyMs: Int
        }
        
        let response = try JSONDecoder().decode(APIResponse.self, from: data)
        return TranscribeResponse(transcript: response.transcript, latencyMs: response.latencyMs)
    }
}

// MARK: - Response

private struct TranscribeResponse {
    let transcript: String
    let latencyMs: Int
}

// MARK: - Errors

enum DeepgramError: LocalizedError {
    case missingAPIKey  // Legacy, kept for compatibility
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
            return "Backend unavailable"
        case .invalidAPIKey:
            return "Invalid API configuration"
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
