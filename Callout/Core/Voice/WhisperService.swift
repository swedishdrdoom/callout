//
//  WhisperService.swift
//  Callout
//
//  Voice transcription service using OpenAI Whisper API
//

import Foundation

// MARK: - WhisperError

enum WhisperError: LocalizedError {
    case noAPIKey
    case invalidAudioData
    case networkError(Error)
    case invalidResponse
    case transcriptionFailed(String)
    case rateLimited
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .invalidAudioData:
            return "Invalid or empty audio data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Whisper API"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .rateLimited:
            return "Rate limited - please try again later"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        }
    }
}

// MARK: - WhisperResponse

private struct WhisperResponse: Decodable {
    let text: String
}

private struct WhisperErrorResponse: Decodable {
    let error: WhisperErrorDetail
    
    struct WhisperErrorDetail: Decodable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - WhisperService

/// Service for transcribing audio using OpenAI's Whisper API
final class WhisperService: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = WhisperService()
    
    // MARK: - Configuration
    
    private let apiEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let model = "whisper-1"
    
    /// OpenAI API key - configure before use
    /// In production, load from Keychain or secure storage
    var apiKey: String? {
        get { _apiKey }
        set { _apiKey = newValue }
    }
    private var _apiKey: String?
    
    /// Default prompt hint for gym/workout vocabulary
    private let defaultPromptHint = """
    Workout logging. Common terms: sets, reps, bench press, squat, deadlift, \
    overhead press, barbell, dumbbell, kettlebell, pounds, lbs, kilograms, kg, \
    RPE, RIR, PR, personal record, warm-up, working set, drop set, superset, \
    incline, decline, lat pulldown, row, curl, tricep, extension, press, fly, \
    raise, shrug, calf, leg press, hack squat, Romanian deadlift, RDL, \
    hip thrust, pull-up, chin-up, dip, cable, machine, free weight.
    """
    
    private let urlSession: URLSession
    
    // MARK: - Initialization
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio data to text using Whisper API
    /// - Parameters:
    ///   - audioData: Audio data in a supported format (m4a, mp3, wav, etc.)
    ///   - filename: Original filename with extension (used for format detection)
    ///   - language: Optional language hint (ISO-639-1 code, e.g., "en")
    ///   - prompt: Optional custom prompt hint for vocabulary context
    /// - Returns: Transcribed text
    func transcribe(
        audioData: Data,
        filename: String = "recording.m4a",
        language: String? = "en",
        prompt: String? = nil
    ) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw WhisperError.noAPIKey
        }
        
        guard !audioData.isEmpty else {
            throw WhisperError.invalidAudioData
        }
        
        let request = try buildRequest(
            audioData: audioData,
            filename: filename,
            language: language,
            prompt: prompt ?? defaultPromptHint,
            apiKey: apiKey
        )
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            return try processResponse(data: data, response: response)
        } catch let error as WhisperError {
            throw error
        } catch {
            throw WhisperError.networkError(error)
        }
    }
    
    /// Transcribe audio file from URL
    /// - Parameters:
    ///   - fileURL: URL to audio file
    ///   - language: Optional language hint
    ///   - prompt: Optional custom prompt hint
    /// - Returns: Transcribed text
    func transcribe(
        fileURL: URL,
        language: String? = "en",
        prompt: String? = nil
    ) async throws -> String {
        let audioData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        
        return try await transcribe(
            audioData: audioData,
            filename: filename,
            language: language,
            prompt: prompt
        )
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(
        audioData: Data,
        filename: String,
        language: String?,
        prompt: String,
        apiKey: String
    ) throws -> URLRequest {
        guard let url = URL(string: apiEndpoint) else {
            throw WhisperError.invalidResponse
        }
        
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        var body = Data()
        
        // Add model field
        body.appendMultipartField(name: "model", value: model, boundary: boundary)
        
        // Add language field if specified
        if let language = language {
            body.appendMultipartField(name: "language", value: language, boundary: boundary)
        }
        
        // Add prompt hint
        body.appendMultipartField(name: "prompt", value: prompt, boundary: boundary)
        
        // Add response format
        body.appendMultipartField(name: "response_format", value: "json", boundary: boundary)
        
        // Add audio file
        let mimeType = mimeType(for: filename)
        body.appendMultipartFile(
            name: "file",
            filename: filename,
            mimeType: mimeType,
            data: audioData,
            boundary: boundary
        )
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return request
    }
    
    private func processResponse(data: Data, response: URLResponse) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return whisperResponse.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
        case 429:
            throw WhisperError.rateLimited
            
        case 400..<500:
            if let errorResponse = try? JSONDecoder().decode(WhisperErrorResponse.self, from: data) {
                throw WhisperError.transcriptionFailed(errorResponse.error.message)
            }
            throw WhisperError.transcriptionFailed("Client error (HTTP \(httpResponse.statusCode))")
            
        case 500..<600:
            throw WhisperError.serverError(httpResponse.statusCode)
            
        default:
            throw WhisperError.invalidResponse
        }
    }
    
    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "mp4": return "audio/mp4"
        case "mpeg": return "audio/mpeg"
        case "mpga": return "audio/mpeg"
        case "oga", "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "audio/m4a"
        }
    }
}

// MARK: - Data Extensions

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func appendMultipartFile(name: String, filename: String, mimeType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
