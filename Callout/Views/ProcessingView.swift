import SwiftUI

/// "Crunching" screen shown while LLM processes voice logs
/// Displays while waiting for backend to finish analysis
struct ProcessingView: View {
    @State private var rotation: Double = 0
    @State private var dots: String = ""
    
    var body: some View {
        ZStack {
            CalloutTheme.background.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated icon
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(CalloutTheme.lime.opacity(0.2), lineWidth: 4)
                        .frame(width: 120, height: 120)
                    
                    // Spinning arc
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(CalloutTheme.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotation))
                    
                    // Center icon
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundStyle(CalloutTheme.lime)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                
                VStack(spacing: 12) {
                    Text("Crunching your workout\(dots)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(CalloutTheme.white)
                    
                    Text("Analyzing voice logs...")
                        .font(.subheadline)
                        .foregroundStyle(CalloutTheme.dimWhite)
                }
                
                Spacer()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Spin animation
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Dots animation
            animateDots()
        }
    }
    
    private func animateDots() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
    }
}

#Preview {
    ProcessingView()
}
