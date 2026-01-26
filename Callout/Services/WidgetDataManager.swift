import Foundation
import WidgetKit

// MARK: - WidgetDataManager

/// Shares workout state with the Widget extension
/// Uses App Groups for cross-process data sharing
final class WidgetDataManager {
    
    // MARK: - Singleton
    
    static let shared = WidgetDataManager()
    
    // MARK: - Configuration
    
    private let suiteName = "group.callout.shared"
    
    // MARK: - Private Properties
    
    /// Shared UserDefaults for App Group
    /// Returns nil if the app group is not configured
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Update the current exercise shown in widget
    /// - Parameter name: Exercise name, or nil to clear
    func setCurrentExercise(_ name: String?) {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("[WidgetDataManager] Warning: App Group not configured")
            #endif
            return
        }
        defaults.set(name, forKey: "currentExercise")
        reloadWidget()
    }
    
    /// Update the last logged set display
    /// - Parameters:
    ///   - weight: Weight lifted
    ///   - reps: Number of repetitions
    ///   - unit: Weight unit string (kg/lbs)
    func setLastSet(weight: Double, reps: Int, unit: String) {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("[WidgetDataManager] Warning: App Group not configured")
            #endif
            return
        }
        let formatted = "\(formatWeight(weight))\(unit) × \(reps)"
        defaults.set(formatted, forKey: "lastSet")
        defaults.set(Date(), forKey: "lastSetTime")
        reloadWidget()
    }
    
    /// Clear workout state (session ended)
    func clearSession() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: "currentExercise")
        defaults.removeObject(forKey: "lastSet")
        defaults.removeObject(forKey: "lastSetTime")
        reloadWidget()
    }
    
    // MARK: - Private Helpers
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }
    
    private func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
