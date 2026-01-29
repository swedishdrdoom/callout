import Foundation

// MARK: - Backend Response Models

/// Response from /api/understand endpoint
struct BackendResult: Decodable {
    let transcript: String
    let interpreted: InterpretedData
    let latency: LatencyInfo?
    
    struct InterpretedData: Decodable {
        let type: String
        let weight: Double?
        let unit: String?
        let reps: Int?
        let name: String?
        let text: String?
    }
    
    struct LatencyInfo: Decodable {
        let transcribe: Int?
        let interpret: Int?
        let total: Int?
    }
}
