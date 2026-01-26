import Foundation
import Speech
import AVFoundation

// MARK: - SpeechRecognitionService

/// On-device speech recognition using Apple's SFSpeechRecognizer
/// Free, private, works offline - no API key needed
@Observable
@MainActor
final class SpeechRecognitionService: NSObject {
    
    // MARK: - Singleton
    
    static let shared = SpeechRecognitionService()
    
    // MARK: - Published State
    
    private(set) var isListening = false
    private(set) var isAvailable = false
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    /// The latest transcription result (updates in real-time while listening)
    private(set) var currentTranscription: String = ""
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    private override init() {
        // Initialize with English locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        super.init()
        
        speechRecognizer?.delegate = self
        isAvailable = speechRecognizer?.isAvailable ?? false
        
        #if DEBUG
        print("[SpeechRecognition] Initialized, available: \(isAvailable)")
        #endif
    }
    
    // MARK: - Authorization
    
    /// Request speech recognition permission
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    #if DEBUG
                    print("[SpeechRecognition] Authorization status: \(status.rawValue)")
                    #endif
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }
    
    // MARK: - Recognition
    
    /// Start listening and transcribing speech
    /// Returns the final transcription when stopped
    func startListening() async throws {
        // Check authorization
        if authorizationStatus == .notDetermined {
            let granted = await requestAuthorization()
            guard granted else {
                throw SpeechRecognitionError.notAuthorized
            }
        } else if authorizationStatus != .authorized {
            throw SpeechRecognitionError.notAuthorized
        }
        
        // Check availability
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }
        
        // Stop any existing task
        stopListening()
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.requestCreationFailed
        }
        
        // Configure for real-time results
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // Enable on-device recognition if available (iOS 13+)
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
            #if DEBUG
            print("[SpeechRecognition] On-device recognition: \(speechRecognizer.supportsOnDeviceRecognition)")
            #endif
        }
        
        // Set up audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
        currentTranscription = ""
        
        #if DEBUG
        print("[SpeechRecognition] Started listening")
        #endif
        
        // Start recognition task - use Task to ensure main thread updates
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    self.currentTranscription = result.bestTranscription.formattedString
                    #if DEBUG
                    print("[SpeechRecognition] Partial: \(self.currentTranscription)")
                    #endif
                }
                
                if let error = error {
                    #if DEBUG
                    print("[SpeechRecognition] Error: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
    
    /// Stop listening and return the final transcription
    @discardableResult
    func stopListening() -> String {
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        
        let finalTranscription = currentTranscription
        #if DEBUG
        print("[SpeechRecognition] Stopped, final: \(finalTranscription)")
        #endif
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        return finalTranscription
    }
    
    /// Convenience method: listen for a duration and return result
    func listenFor(seconds: TimeInterval) async throws -> String {
        try await startListening()
        
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        
        return stopListening()
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        isAvailable = available
        #if DEBUG
        print("[SpeechRecognition] Availability changed: \(available)")
        #endif
    }
}

// MARK: - Errors

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case notAvailable
    case requestCreationFailed
    case audioEngineError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .requestCreationFailed:
            return "Failed to create speech recognition request."
        case .audioEngineError(let error):
            return "Audio error: \(error.localizedDescription)"
        }
    }
}
