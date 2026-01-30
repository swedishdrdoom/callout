import SwiftUI

/// The "Start Workout" screen - shown after splash
/// Single purpose: big button to begin a workout session
struct StartScreen: View {
    let onStart: () -> Void
    
    @State private var buttonScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            CalloutTheme.background.ignoresSafeArea()
            
            VStack(spacing: 60) {
                Spacer()
                
                // App title
                VStack(spacing: 8) {
                    Text("CALLOUT")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(CalloutTheme.white)
                    
                    Text("Voice-first workout logging")
                        .font(.subheadline)
                        .foregroundStyle(CalloutTheme.dimWhite)
                }
                
                Spacer()
                
                // Big start button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 0.95
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            buttonScale = 1.0
                        }
                        onStart()
                    }
                } label: {
                    ZStack {
                        // Pulse ring
                        Circle()
                            .stroke(CalloutTheme.lime.opacity(pulseOpacity), lineWidth: 2)
                            .frame(width: 200, height: 200)
                        
                        // Main button
                        Circle()
                            .fill(CalloutTheme.lime)
                            .frame(width: 180, height: 180)
                            .shadow(color: CalloutTheme.lime.opacity(0.4), radius: 20, y: 5)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 48))
                                .foregroundStyle(.black)
                            
                            Text("START")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                        }
                    }
                    .scaleEffect(buttonScale)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Subtle hint
                Text("Tap to begin your workout")
                    .font(.caption)
                    .foregroundStyle(CalloutTheme.subtleWhite)
                    .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Subtle pulse animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.6
            }
        }
    }
}

#Preview {
    StartScreen {
        print("Start workout!")
    }
}
