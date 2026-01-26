import Foundation
import WidgetKit

/// Shares workout state with the Widget extension
/// Uses App Groups for cross-process data sharing
final class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let suiteName = "group.callout.shared"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    private init() {}
    
    // MARK: - Update Widget Data
    
    /// Update the current exercise shown in widget
    func setCurrentExercise(_ name: String?) {
        sharedDefaults?.set(name, forKey: "currentExercise")
        reloadWidget()
    }
    
    /// Update the last logged set display
    func setLastSet(weight: Double, reps: Int, unit: String) {
        let formatted = "\(formatWeight(weight))\(unit) × \(reps)"
        sharedDefaults?.set(formatted, forKey: "lastSet")
        sharedDefaults?.set(Date(), forKey: "lastSetTime")
        reloadWidget()
    }
    
    /// Clear workout state (session ended)
    func clearSession() {
        sharedDefaults?.removeObject(forKey: "currentExercise")
        sharedDefaults?.removeObject(forKey: "lastSet")
        sharedDefaults?.removeObject(forKey: "lastSetTime")
        reloadWidget()
    }
    
    // MARK: - Helpers
    
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
