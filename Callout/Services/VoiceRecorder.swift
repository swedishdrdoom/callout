import AVFoundation
import Foundation

/// AVFoundation-based audio recorder optimized for Whisper transcription
/// Supports AirPods and handles audio route changes gracefully
@Observable
final class VoiceRecorder: NSObject {
    
    // MARK: - State
    
    enum State: Equatable {
        case idle
        case preparing
        case recording
        case paused
        case stopped
    }
    
    private(set) var state: State = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var averagePower: Float = 0
    private(set) var peakPower: Float = 0
    private(set) var recordingURL: URL?
    
    // MARK: - Delegate
    
    weak var delegate: VoiceRecorderDelegate?
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private let audioSession = AVAudioSession.sharedInstance()
    
    /// Recording settings optimized for Whisper API
    /// 16kHz mono AAC - good quality, small file size
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotifications()
        // Pre-configure audio session on init for faster first-record
        preWarmAudioSession()
    }
    
    /// Pre-configure audio session to eliminate first-record delay
    private func preWarmAudioSession() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                try self.audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.allowBluetooth, .defaultToSpeaker]
                )
                #if DEBUG
                print("[VoiceRecorder] Audio session pre-warmed")
                #endif
            } catch {
                #if DEBUG
                print("[VoiceRecorder] Pre-warm failed: \(error)")
                #endif
            }
        }
    }
    
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public API
    
    /// Start recording audio
    func start() async throws {
        guard state == .idle || state == .stopped else { return }
        
        state = .preparing
        
        do {
            try await configureAudioSession()
            try setupRecorder()
            
            audioRecorder?.record()
            state = .recording
            startMetering()
            delegate?.voiceRecorderDidStartRecording(self)
            
        } catch {
            state = .idle
            throw error
        }
    }
    
    /// Stop recording and return the file URL
    @discardableResult
    func stop() -> URL? {
        guard state == .recording || state == .paused else { return nil }
        
        stopMetering()
        audioRecorder?.stop()
        state = .stopped
        
        delegate?.voiceRecorderDidStopRecording(self, fileURL: recordingURL)
        return recordingURL
    }
    
    /// Pause recording
    func pause() {
        guard state == .recording else { return }
        audioRecorder?.pause()
        state = .paused
        delegate?.voiceRecorderDidPause(self)
    }
    
    /// Resume recording after pause
    func resume() {
        guard state == .paused else { return }
        audioRecorder?.record()
        state = .recording
        delegate?.voiceRecorderDidResume(self)
    }
    
    /// Cancel recording and delete the file
    func cancel() {
        stopMetering()
        audioRecorder?.stop()
        
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingURL = nil
        state = .idle
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() async throws {
        // Request microphone permission
        if #available(iOS 17.0, *) {
            let permissionGranted = await AVAudioApplication.requestRecordPermission()
            guard permissionGranted else {
                throw VoiceRecorderError.microphonePermissionDenied
            }
        } else {
            let permissionGranted = await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard permissionGranted else {
                throw VoiceRecorderError.microphonePermissionDenied
            }
        }
        
        // Configure for recording with Bluetooth support
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetooth, .defaultToSpeaker]
        )
        
        try audioSession.setActive(true)
        
        // Prefer Bluetooth input if available (AirPods)
        if let bluetoothInput = audioSession.availableInputs?.first(where: {
            $0.portType == .bluetoothHFP
        }) {
            try audioSession.setPreferredInput(bluetoothInput)
        }
    }
    
    private func setupRecorder() throws {
        let url = generateRecordingURL()
        recordingURL = url
        
        audioRecorder = try AVAudioRecorder(url: url, settings: recordingSettings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord()
    }
    
    private func generateRecordingURL() -> URL {
        let filename = "callout_\(Date().timeIntervalSince1970).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
    
    // MARK: - Metering
    
    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMeters()
        }
    }
    
    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }
    
    private func updateMeters() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        currentTime = recorder.currentTime
        averagePower = recorder.averagePower(forChannel: 0)
        peakPower = recorder.peakPower(forChannel: 0)
        
        delegate?.voiceRecorder(self, didUpdateMeters: averagePower, peak: peakPower)
    }
    
    // MARK: - Interruption Handling
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
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
                pause()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) && state == .paused {
                    resume()
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
        
        switch reason {
        case .oldDeviceUnavailable:
            // AirPods disconnected mid-recording
            if state == .recording {
                pause()
                delegate?.voiceRecorderDidLoseAudioRoute(self)
            }
        default:
            break
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        stopMetering()
        audioRecorder?.stop()
        audioRecorder = nil
        try? audioSession.setActive(false)
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            delegate?.voiceRecorder(self, didFailWithError: VoiceRecorderError.recordingFailed)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            delegate?.voiceRecorder(self, didFailWithError: error)
        }
    }
}

// MARK: - Delegate Protocol

protocol VoiceRecorderDelegate: AnyObject {
    func voiceRecorderDidStartRecording(_ recorder: VoiceRecorder)
    func voiceRecorderDidStopRecording(_ recorder: VoiceRecorder, fileURL: URL?)
    func voiceRecorderDidPause(_ recorder: VoiceRecorder)
    func voiceRecorderDidResume(_ recorder: VoiceRecorder)
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateMeters average: Float, peak: Float)
    func voiceRecorder(_ recorder: VoiceRecorder, didFailWithError error: Error)
    func voiceRecorderDidLoseAudioRoute(_ recorder: VoiceRecorder)
}

// Default implementations
extension VoiceRecorderDelegate {
    func voiceRecorderDidStartRecording(_ recorder: VoiceRecorder) {}
    func voiceRecorderDidStopRecording(_ recorder: VoiceRecorder, fileURL: URL?) {}
    func voiceRecorderDidPause(_ recorder: VoiceRecorder) {}
    func voiceRecorderDidResume(_ recorder: VoiceRecorder) {}
    func voiceRecorder(_ recorder: VoiceRecorder, didUpdateMeters average: Float, peak: Float) {}
    func voiceRecorder(_ recorder: VoiceRecorder, didFailWithError error: Error) {}
    func voiceRecorderDidLoseAudioRoute(_ recorder: VoiceRecorder) {}
}

// MARK: - Errors

enum VoiceRecorderError: LocalizedError {
    case microphonePermissionDenied
    case recordingFailed
    case audioSessionError(Error)
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required for voice input"
        case .recordingFailed:
            return "Recording failed unexpectedly"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        }
    }
}
