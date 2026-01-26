import SwiftUI

// MARK: - View Model

@Observable
final class RestLoopViewModel {
    var currentExercise: String = "Bench Press"
    var lastSet: SetData? = SetData(weight: 185, reps: 8, unit: .lbs)
    var ghostSet: SetData? = SetData(weight: 185, reps: 10, unit: .lbs) // Last session's comparable set
    var restSeconds: Int = 0
    var isListening: Bool = false
    var isWorkoutActive: Bool = true
    
    private var timer: Timer?
    
    struct SetData {
        let weight: Double
        let reps: Int
        let unit: WeightUnit
        
        var formatted: String {
            let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 
                ? String(format: "%.0f", weight) 
                : String(format: "%.1f", weight)
            return "\(weightStr) \(unit.symbol) × \(reps)"
        }
    }
    
    enum WeightUnit: String {
        case kg, lbs
        var symbol: String { rawValue }
    }
    
    func startRestTimer() {
        restSeconds = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.restSeconds += 1
        }
    }
    
    func stopRestTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func logSet() {
        // Trigger voice input or manual entry
        startRestTimer()
    }
    
    func toggleListening() {
        isListening.toggle()
    }
    
    func endWorkout() {
        stopRestTimer()
        isWorkoutActive = false
    }
    
    var formattedRestTime: String {
        let minutes = restSeconds / 60
        let seconds = restSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Main View

struct RestLoopView: View {
    @State private var viewModel = RestLoopViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                Spacer()
                
                // Main content area
                mainContent
                
                Spacer()
                
                // Voice input area
                voiceInputSection
                
                // Log Set button
                logSetButton
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentExercise)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                if let lastSet = viewModel.lastSet {
                    Text("Last: \(lastSet.formatted)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            Button {
                viewModel.endWorkout()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 32) {
            // Rest Timer (counting UP)
            restTimerDisplay
            
            // Ghost data from last session
            ghostDataDisplay
        }
    }
    
    private var restTimerDisplay: some View {
        VStack(spacing: 8) {
            Text("REST")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2)
            
            Text(viewModel.formattedRestTime)
                .font(.system(size: 72, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: viewModel.restSeconds)
        }
    }
    
    private var ghostDataDisplay: some View {
        Group {
            if let ghost = viewModel.ghostSet {
                VStack(spacing: 4) {
                    Text("LAST SESSION")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(1.5)
                    
                    Text(ghost.formatted)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.05))
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Voice Input
    
    private var voiceInputSection: some View {
        VStack(spacing: 12) {
            // Listening indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isListening ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isListening)
                
                Text(viewModel.isListening ? "Listening..." : "Say \"Log\" or tap below")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Mic button
            Button {
                viewModel.toggleListening()
            } label: {
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                    .font(.title2)
                    .foregroundStyle(viewModel.isListening ? .green : .white.opacity(0.6))
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(.white.opacity(viewModel.isListening ? 0.15 : 0.08))
                    )
            }
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Log Set Button
    
    private var logSetButton: some View {
        Button {
            viewModel.logSet()
        } label: {
            Text("LOG SET")
                .font(.headline)
                .fontWeight(.semibold)
                .tracking(1)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                )
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    RestLoopView()
}
