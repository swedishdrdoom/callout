import SwiftUI

@main
struct CalloutApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingSplash = true
    
    init() {
        // Pre-warm all services on launch for zero-lag experience
        warmUpServices()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content (loads behind splash)
                Group {
                    if hasCompletedOnboarding {
                        RestLoopView()
                    } else {
                        OnboardingView()
                    }
                }
                .opacity(showingSplash ? 0 : 1)
                
                // Splash overlay
                if showingSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Dismiss splash after brief branding moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingSplash = false
                    }
                }
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
