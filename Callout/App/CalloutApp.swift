import SwiftUI

@main
struct CalloutApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        // Pre-warm all services on launch for zero-lag experience
        warmUpServices()
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RestLoopView()
            } else {
                OnboardingView()
            }
        }
    }
    
    /// Pre-initialize all services to eliminate first-use lag
    private func warmUpServices() {
        // Touch singletons to trigger lazy initialization
        _ = DeepgramService.shared
        _ = WorkoutSession.shared
        _ = PersistenceManager.shared
        
        // Prepare haptic generators for immediate feedback
        HapticManager.shared.prepareAll()
    }
}
