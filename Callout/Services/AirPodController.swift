import AVFoundation
import MediaPlayer
import UIKit

/// Handles AirPod tap/press detection and voice trigger configuration
/// Uses MPRemoteCommandCenter to intercept media controls
@Observable
final class AirPodController {
    static let shared = AirPodController()
    
    // MARK: - Configuration
    
    enum TriggerMode: String, CaseIterable, Codable {
        case tapLeft = "tap_left"
        case tapRight = "tap_right"
        case holdLeft = "hold_left"
        case holdRight = "hold_right"
        case doubleTapLeft = "double_tap_left"
        case doubleTapRight = "double_tap_right"
        
        var displayName: String {
            switch self {
            case .tapLeft: return "Tap Left AirPod"
            case .tapRight: return "Tap Right AirPod"
            case .holdLeft: return "Hold Left AirPod"
            case .holdRight: return "Hold Right AirPod"
            case .doubleTapLeft: return "Double-Tap Left"
            case .doubleTapRight: return "Double-Tap Right"
            }
        }
    }
    
    var triggerMode: TriggerMode {
        get {
            let raw = UserDefaults.standard.string(forKey: "airpodTriggerMode") ?? TriggerMode.tapLeft.rawValue
            return TriggerMode(rawValue: raw) ?? .tapLeft
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "airpodTriggerMode")
            setupRemoteCommands()
        }
    }
    
    // MARK: - State
    
    private(set) var isListening = false
    private(set) var isAirPodsConnected = false
    
    // MARK: - Callbacks
    
    var onTriggerActivated: (() -> Void)?
    var onTriggerReleased: (() -> Void)?
    
    // MARK: - Private
    
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var audioSession = AVAudioSession.sharedInstance()
    
    // MARK: - Initialization
    
    private init() {
        setupAudioSessionNotifications()
        checkAirPodsStatus()
    }
    
    // MARK: - Setup
    
    func activate() {
        setupRemoteCommands()
        becomeNowPlayingApp()
    }
    
    func deactivate() {
        clearRemoteCommands()
    }
    
    private func setupRemoteCommands() {
        clearRemoteCommands()
        
        // Configure based on trigger mode
        switch triggerMode {
        case .tapLeft, .tapRight:
            // Use play/pause command for single tap
            commandCenter.playCommand.isEnabled = true
            commandCenter.playCommand.addTarget { [weak self] _ in
                self?.handleTriggerActivated()
                return .success
            }
            
            commandCenter.pauseCommand.isEnabled = true
            commandCenter.pauseCommand.addTarget { [weak self] _ in
                self?.handleTriggerReleased()
                return .success
            }
            
        case .holdLeft, .holdRight:
            // Use toggle command for hold detection (via pause/play state)
            commandCenter.togglePlayPauseCommand.isEnabled = true
            commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                if self?.isListening == true {
                    self?.handleTriggerReleased()
                } else {
                    self?.handleTriggerActivated()
                }
                return .success
            }
            
        case .doubleTapLeft, .doubleTapRight:
            // Use skip commands for double-tap
            commandCenter.nextTrackCommand.isEnabled = true
            commandCenter.nextTrackCommand.addTarget { [weak self] _ in
                self?.handleTriggerActivated()
                // Auto-release after a moment for double-tap mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.handleTriggerReleased()
                }
                return .success
            }
        }
    }
    
    private func clearRemoteCommands() {
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
    }
    
    /// Make this app the "Now Playing" app to receive remote commands
    private func becomeNowPlayingApp() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try audioSession.setActive(true)
            
            // Set minimal now playing info
            var nowPlayingInfo = [String: Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = "Callout"
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Ready to log"
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
        } catch {
            #if DEBUG
            print("Failed to setup audio session: \(error)")
            #endif
        }
    }
    
    // MARK: - Trigger Handling
    
    private func handleTriggerActivated() {
        guard !isListening else { return }
        isListening = true
        onTriggerActivated?()
    }
    
    private func handleTriggerReleased() {
        guard isListening else { return }
        isListening = false
        onTriggerReleased?()
    }
    
    // MARK: - AirPods Detection
    
    private func setupAudioSessionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        checkAirPodsStatus()
    }
    
    func checkAirPodsStatus() {
        let outputs = audioSession.currentRoute.outputs
        
        isAirPodsConnected = outputs.contains { output in
            // Check for AirPods by port type
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothHFP ||
            output.portName.lowercased().contains("airpod")
        }
    }
    
    // MARK: - Manual Trigger (Fallback)
    
    /// Manually trigger start (for on-screen button fallback)
    func manualTriggerStart() {
        handleTriggerActivated()
    }
    
    /// Manually trigger stop
    func manualTriggerStop() {
        handleTriggerReleased()
    }
}

// MARK: - AirPod Trigger Settings View Helper

extension AirPodController {
    var allTriggerModes: [TriggerMode] {
        TriggerMode.allCases
    }
}
