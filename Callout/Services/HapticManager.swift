import UIKit

/// Centralized haptic feedback manager for Callout
/// Provides consistent tactile feedback across the app
final class HapticManager {
    static let shared = HapticManager()
    
    // MARK: - Configuration
    
    /// User preference for haptic feedback
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "hapticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsEnabled") }
    }
    
    // MARK: - Generators (lazy-loaded for performance)
    
    private lazy var impactLight = UIImpactFeedbackGenerator(style: .light)
    private lazy var impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private lazy var impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private lazy var notification = UINotificationFeedbackGenerator()
    private lazy var selection = UISelectionFeedbackGenerator()
    
    // MARK: - Initialization
    
    private init() {
        // Default to enabled
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            isEnabled = true
        }
    }
    
    // MARK: - Prepare (call before time-sensitive feedback)
    
    /// Prepare generators for immediate feedback
    func prepare() {
        guard isEnabled else { return }
        impactRigid.prepare()
        impactMedium.prepare()
        notification.prepare()
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
    
    // MARK: - Feedback Methods
    
    /// Set logged successfully - satisfying double-tap
    func setLogged() {
        guard isEnabled else { return }
        
        // Double rigid impact for that satisfying "logged!" feel
        impactRigid.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.impactRigid.impactOccurred()
        }
    }
    
    /// Exercise changed - medium impact
    func exerciseChanged() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }
    
    /// Error occurred - error notification
    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }
    
    /// Alert/warning - warning notification
    func alert() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }
    
    /// Light selection feedback (scrolling, minor interactions)
    func selection() {
        guard isEnabled else { return }
        self.selection.selectionChanged()
    }
    
    /// Personal record achieved - celebratory sequence!
    func personalRecord() {
        guard isEnabled else { return }
        
        // Build-up
        impactLight.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.impactMedium.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.impactHeavy.impactOccurred()
        }
        
        // Success notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.notification.notificationOccurred(.success)
        }
    }
    
    /// Workout completed - success notification
    func workoutCompleted() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }
    
    /// Voice recording started
    func recordingStarted() {
        guard isEnabled else { return }
        impactSoft.impactOccurred()
    }
    
    /// Voice recording stopped
    func recordingStopped() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
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
