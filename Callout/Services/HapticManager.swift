import UIKit

// MARK: - HapticManager

/// Centralized haptic feedback manager for Callout
/// Provides consistent tactile feedback across the app
final class HapticManager {
    
    // MARK: - Singleton
    
    static let shared = HapticManager()
    
    // MARK: - Configuration
    
    /// User preference for haptic feedback
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "hapticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsEnabled") }
    }
    
    // MARK: - Feedback Generators (lazy-loaded for performance)
    
    private lazy var impactLight = UIImpactFeedbackGenerator(style: .light)
    private lazy var impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private lazy var impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private lazy var notificationGenerator = UINotificationFeedbackGenerator()
    private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Initialization
    
    private init() {
        // Default to enabled on first launch
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            isEnabled = true
        }
    }
    
    // MARK: - Prepare (call before time-sensitive feedback)
    
    /// Prepare ALL generators for immediate feedback - call on app launch
    func prepareAll() {
        guard isEnabled else { return }
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactRigid.prepare()
        impactSoft.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    /// Prepare generators for immediate feedback
    func prepare() {
        guard isEnabled else { return }
        impactRigid.prepare()
        impactMedium.prepare()
        notificationGenerator.prepare()
    }
    
    /// Prepare specific generator
    func prepareForSetLog() {
        guard isEnabled else { return }
        impactRigid.prepare()
    }
    
    func prepareForExerciseChange() {
        guard isEnabled else { return }
        impactMedium.prepare()
    }
    
    // MARK: - Workout Feedback
    
    /// Set logged successfully - satisfying double-tap feel
    func setLogged() {
        guard isEnabled else { return }
        
        // Double rigid impact for that satisfying "logged!" feel
        impactRigid.impactOccurred()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            self.impactRigid.impactOccurred()
        }
    }
    
    /// Exercise changed - medium confirmation tap
    func exerciseChanged() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }
    
    /// Workout completed - success notification
    func workoutCompleted() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }
    
    /// Personal record achieved - celebratory haptic sequence
    func personalRecord() {
        guard isEnabled else { return }
        
        Task { @MainActor in
            // Build-up sequence
            self.impactLight.impactOccurred()
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            self.impactMedium.impactOccurred()
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            self.impactHeavy.impactOccurred()
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.notificationGenerator.notificationOccurred(.success)
        }
    }
    
    // MARK: - Voice Feedback
    
    /// Voice recording started - soft tap
    func recordingStarted() {
        guard isEnabled else { return }
        impactSoft.impactOccurred()
    }
    
    /// Voice recording stopped - medium tap
    func recordingStopped() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }
    
    // MARK: - General Feedback
    
    /// Error occurred - error notification
    func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }
    
    /// Alert/warning - warning notification
    func alert() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }
    
    /// Light selection feedback for minor interactions
    func selectionTap() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }
    
    /// Button tap - light impact
    func tap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }
    
    /// Heavy impact for significant actions
    func heavy() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }
}
