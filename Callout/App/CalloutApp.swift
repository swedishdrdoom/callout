import SwiftUI

@main
struct CalloutApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RestLoopView()
            } else {
                OnboardingView()
            }
        }
    }
}
