import SwiftUI

// MARK: - App Flow State

enum AppFlowState {
    case splash
    case onboarding
    case start       // New: Start screen with big button
    case workout     // Active workout
    case processing  // LLM crunching
    case results     // Workout card
}

@main
struct CalloutApp: App {
    @AppStorage(UserDefaultsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var flowState: AppFlowState = .splash
    @State private var completedWorkout: CompletedWorkout?
    
    init() {
        // Pre-warm all services on launch for zero-lag experience
        warmUpServices()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                CalloutTheme.background.ignoresSafeArea()
                
                switch flowState {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                    
                case .onboarding:
                    OnboardingView()
                        .transition(.move(edge: .trailing))
                    
                case .start:
                    StartScreen {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            flowState = .workout
                        }
                    }
                    .transition(.move(edge: .trailing))
                    
                case .workout:
                    MainView(
                        onFinish: { workout in
                            completedWorkout = workout
                            withAnimation(.easeInOut(duration: 0.3)) {
                                flowState = .processing
                            }
                            // Simulate processing delay (replace with actual LLM check)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    flowState = .results
                                }
                            }
                        },
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                flowState = .start
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                    
                case .processing:
                    ProcessingView()
                        .transition(.opacity)
                    
                case .results:
                    if let workout = completedWorkout {
                        WorkoutCardView(workout: workout) {
                            // Reset for next workout
                            completedWorkout = nil
                            withAnimation(.easeInOut(duration: 0.3)) {
                                flowState = .start
                            }
                        }
                        .transition(.move(edge: .trailing))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: flowState)
            .onAppear {
                // Dismiss splash after brief branding moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        flowState = hasCompletedOnboarding ? .start : .onboarding
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
