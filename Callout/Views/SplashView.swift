import SwiftUI

/// Animated splash screen for branding
/// Quick and snappy - shows for ~1.2 seconds
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var showTagline = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Main logo text
                Text("CALLOUT")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                // Tagline
                Text("LOG IT. LIFT IT.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(y: textOffset)
                    .opacity(showTagline ? 1 : 0)
            }
        }
        .onAppear {
            // Logo scales up and fades in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            // Tagline slides up after a brief delay
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOffset = 0
                showTagline = true
            }
        }
    }
}

#Preview {
    SplashView()
}
