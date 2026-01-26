//
//  HapticManager.swift
//  Callout
//
//  Haptic feedback manager for workout logging interactions
//

import UIKit

// MARK: - HapticType

enum HapticType {
    /// Success double-tap for logging a set
    case setLogged
    
    /// Medium impact for exercise changes
    case exerciseChanged
    
    /// Error notification
    case error
    
    /// Warning/alert notification
    case alert
    
    /// Light tap for selection
    case selection
    
    /// Heavy impact for PR/personal record
    case personalRecord
}

// MARK: - HapticManager

/// Manages haptic feedback throughout the app
final class HapticManager {
    
    // MARK: - Singleton
    
    static let shared = HapticManager()
    
    // MARK: - Properties
    
    /// Whether haptics are enabled (user preference)
    var isEnabled: Bool = true
    
    /// Whether the device supports haptics
    private(set) var supportsHaptics: Bool
    
    // Generators (lazy-loaded and reused for performance)
    private lazy var lightImpact = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var softImpact = UIImpactFeedbackGenerator(style: .soft)
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Initialization
    
    private init() {
        // Check for haptic support
        supportsHaptics = UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // MARK: - Public Methods
    
    /// Play a predefined haptic pattern
    /// - Parameter type: The type of haptic feedback to play
    func play(_ type: HapticType) {
        guard isEnabled && supportsHaptics else { return }
        
        switch type {
        case .setLogged:
            playSetLoggedHaptic()
            
        case .exerciseChanged:
            playExerciseChangedHaptic()
            
        case .error:
            playErrorHaptic()
            
        case .alert:
            playAlertHaptic()
            
        case .selection:
            playSelectionHaptic()
            
        case .personalRecord:
            playPersonalRecordHaptic()
        }
    }
    
    /// Prepare generators for immediate playback (call before expected interaction)
    func prepare(for type: HapticType) {
        guard isEnabled && supportsHaptics else { return }
        
        switch type {
        case .setLogged:
            rigidImpact.prepare()
            
        case .exerciseChanged:
            mediumImpact.prepare()
            
        case .error:
            notificationGenerator.prepare()
            
        case .alert:
            notificationGenerator.prepare()
            
        case .selection:
            selectionGenerator.prepare()
            
        case .personalRecord:
            heavyImpact.prepare()
            notificationGenerator.prepare()
        }
    }
    
    /// Play a custom impact haptic
    /// - Parameters:
    ///   - style: The impact style
    ///   - intensity: Intensity from 0.0 to 1.0
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        guard isEnabled && supportsHaptics else { return }
        
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = lightImpact
        case .medium:
            generator = mediumImpact
        case .heavy:
            generator = heavyImpact
        case .rigid:
            generator = rigidImpact
        case .soft:
            generator = softImpact
        @unknown default:
            generator = mediumImpact
        }
        
        generator.impactOccurred(intensity: intensity)
    }
    
    /// Play a notification haptic
    /// - Parameter type: The notification type
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled && supportsHaptics else { return }
        notificationGenerator.notificationOccurred(type)
    }
    
    // MARK: - Private Haptic Patterns
    
    /// Success double-tap for logging a set
    private func playSetLoggedHaptic() {
        // First tap
        rigidImpact.impactOccurred(intensity: 0.8)
        
        // Second tap after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.rigidImpact.impactOccurred(intensity: 1.0)
        }
    }
    
    /// Medium impact for exercise changes
    private func playExerciseChangedHaptic() {
        mediumImpact.impactOccurred(intensity: 0.7)
    }
    
    /// Error notification
    private func playErrorHaptic() {
        notificationGenerator.notificationOccurred(.error)
    }
    
    /// Warning/alert notification
    private func playAlertHaptic() {
        notificationGenerator.notificationOccurred(.warning)
    }
    
    /// Light selection haptic
    private func playSelectionHaptic() {
        selectionGenerator.selectionChanged()
    }
    
    /// Celebratory haptic for personal records
    private func playPersonalRecordHaptic() {
        // Strong initial impact
        heavyImpact.impactOccurred(intensity: 1.0)
        
        // Success notification after brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.notificationGenerator.notificationOccurred(.success)
        }
        
        // Final celebratory tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.rigidImpact.impactOccurred(intensity: 0.6)
        }
    }
}

// MARK: - Convenience Extensions

extension HapticManager {
    /// Quick success feedback
    func success() {
        play(.setLogged)
    }
    
    /// Quick error feedback  
    func error() {
        play(.error)
    }
    
    /// Quick selection feedback
    func select() {
        play(.selection)
    }
}
