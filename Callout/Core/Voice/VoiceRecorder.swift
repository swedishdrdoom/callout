//
//  VoiceRecorder.swift
//  Callout
//
//  Audio recording service using AVFoundation
//

import AVFoundation
import Foundation

// MARK: - RecordingError

enum RecordingError: LocalizedError {
    case permissionDenied
    case audioSessionSetupFailed(Error)
    case recorderInitFailed(Error)
    case notRecording
    case alreadyRecording
    case noRecordingAvailable
    case exportFailed(Error)
    case interrupted
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .audioSessionSetupFailed(let error):
            return "Audio session setup failed: \(error.localizedDescription)"
        case .recorderInitFailed(let error):
            return "Failed to initialize recorder: \(error.localizedDescription)"
        case .notRecording:
            return "No recording in progress"
        case .alreadyRecording:
            return "Recording already in progress"
        case .noRecordingAvailable:
            return "No recording available"
        case .exportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .interrupted:
            return "Recording was interrupted"
        }
    }
}

// MARK: - RecordingState

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopped
    case error(String)
    
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.recording, .recording),
             (.paused, .paused),
             (.stopped, .stopped):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - VoiceRecorderDelegate

protocol VoiceRecorderDelegate: AnyObject {
    func voiceRecorder(_ recorder: VoiceRecorder, didChangeState state: RecordingState)
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateMetering averagePower: Float, peakPower: Float)
    func voiceRecorderDidFinishRecording(_ recorder: VoiceRecorder, successfully: Bool)
}

// Default implementations
extension VoiceRecorderDelegate {
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateMetering averagePower: Float, peakPower: Float) {}
}

// MARK: - VoiceRecorder

/// Manages audio recording optimized for voice input with AirPods support
final class VoiceRecorder: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: VoiceRecorderDelegate?
    
    private(set) var state: RecordingState = .idle {
        didSet {
            guard state != oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.voiceRecorder(self, didChangeState: self.state)
            }
        }
    }
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var meteringTimer: Timer?
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let fileManager = FileManager.default
    
    /// Recording settings optimized for Whisper API
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000,  // Whisper works well with 16kHz
        AVNumberOfChannelsKey: 1,  // Mono for voice
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        AVEncoderBitRateKey: 64000
    ]
    
    /// Duration of current recording in seconds
    var currentDuration: TimeInterval {
        audioRecorder?.currentTime ?? 0
    }
    
    /// Whether metering is enabled
    var isMeteringEnabled: Bool = false {
        didSet {
            audioRecorder?.isMeteringEnabled = isMeteringEnabled
            updateMeteringTimer()
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Request microphone permission
    /// - Returns: Whether permission was granted
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Check current microphone permission status
    var permissionStatus: AVAudioSession.RecordPermission {
        audioSession.recordPermission
    }
    
    /// Start recording audio
    func startRecording() async throws {
        guard state != .recording else {
            throw RecordingError.alreadyRecording
        }
        
        // Check permission
        guard await requestPermission() else {
            state = .error("Permission denied")
            throw RecordingError.permissionDenied
        }
        
        state = .preparing
        
        do {
            try configureAudioSession()
            try setupRecorder()
            
            guard let recorder = audioRecorder else {
                throw RecordingError.recorderInitFailed(NSError(domain: "VoiceRecorder", code: -1))
            }
            
            recorder.isMeteringEnabled = isMeteringEnabled
            
            if recorder.record() {
                state = .recording
                updateMeteringTimer()
            } else {
                state = .error("Failed to start recording")
                throw RecordingError.recorderInitFailed(NSError(domain: "VoiceRecorder", code: -2))
            }
        } catch let error as RecordingError {
            state = .error(error.localizedDescription)
            throw error
        } catch {
            state = .error(error.localizedDescription)
            throw RecordingError.audioSessionSetupFailed(error)
        }
    }
    
    /// Stop recording and return the audio file URL
    /// - Returns: URL to the recorded audio file (m4a format)
    func stopRecording() throws -> URL {
        guard state == .recording || state == .paused else {
            throw RecordingError.notRecording
        }
        
        meteringTimer?.invalidate()
        meteringTimer = nil
        
        audioRecorder?.stop()
        state = .stopped
        
        guard let url = recordingURL, fileManager.fileExists(atPath: url.path) else {
            throw RecordingError.noRecordingAvailable
        }
        
        return url
    }
    
    /// Pause the current recording
    func pauseRecording() throws {
        guard state == .recording else {
            throw RecordingError.notRecording
        }
        
        audioRecorder?.pause()
        state = .paused
        meteringTimer?.invalidate()
    }
    
    /// Resume a paused recording
    func resumeRecording() throws {
        guard state == .paused else {
            throw RecordingError.notRecording
        }
        
        if audioRecorder?.record() == true {
            state = .recording
            updateMeteringTimer()
        }
    }
    
    /// Cancel and delete the current recording
    func cancelRecording() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        audioRecorder = nil
        
        if let url = recordingURL {
            try? fileManager.removeItem(at: url)
        }
        recordingURL = nil
        
        state = .idle
        deactivateAudioSession()
    }
    
    /// Get the audio data from the last recording
    /// - Returns: Audio data suitable for Whisper API
    func getRecordingData() throws -> Data {
        guard let url = recordingURL else {
            throw RecordingError.noRecordingAvailable
        }
        
        return try Data(contentsOf: url)
    }
    
    /// Reset to idle state, cleaning up any resources
    func reset() {
        cancelRecording()
    }
    
    // MARK: - Private Methods
    
    private func configureAudioSession() throws {
        do {
            // Configure for recording with Bluetooth (AirPods) support
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth,
                    .allowBluetoothA2DP
                ]
            )
            
            // Set preferred input to Bluetooth if available
            if let bluetoothInput = audioSession.availableInputs?.first(where: { 
                $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP
            }) {
                try audioSession.setPreferredInput(bluetoothInput)
            }
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw RecordingError.audioSessionSetupFailed(error)
        }
    }
    
    private func deactivateAudioSession() {
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func setupRecorder() throws {
        // Create unique filename
        let filename = "callout_recording_\(Date().timeIntervalSince1970).m4a"
        let tempDir = fileManager.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        // Clean up any existing file
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            recordingURL = fileURL
        } catch {
            throw RecordingError.recorderInitFailed(error)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            if state == .recording {
                try? pauseRecording()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && state == .paused {
                    try? resumeRecording()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Handle device disconnection during recording
        if reason == .oldDeviceUnavailable && state == .recording {
            // Continue recording with default input
            try? configureAudioSession()
        }
    }
    
    private func updateMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        
        guard isMeteringEnabled && state == .recording else { return }
        
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            
            let averagePower = recorder.averagePower(forChannel: 0)
            let peakPower = recorder.peakPower(forChannel: 0)
            
            DispatchQueue.main.async {
                self.delegate?.voiceRecorder(self, didUpdateMetering: averagePower, peakPower: peakPower)
            }
        }
    }
    
    private func cleanup() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        
        if let url = recordingURL {
            try? fileManager.removeItem(at: url)
        }
        recordingURL = nil
        
        deactivateAudioSession()
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !flag && self.state == .recording {
                self.state = .error("Recording failed")
            }
            
            self.delegate?.voiceRecorderDidFinishRecording(self, successfully: flag)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.state = .error(error?.localizedDescription ?? "Encoding error")
        }
    }
}
