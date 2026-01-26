import SwiftUI

/// Main workout interface - the "rest loop"
/// Minimal dark interface focused on rest timing and set logging
struct RestLoopView: View {
    @State private var viewModel = RestLoopViewModel()
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Exercise name header
                exerciseHeader
                
                Spacer()
                
                // Rest timer (counting up)
                restTimer
                
                // Ghost data from last session
                ghostDataView
                
                Spacer()
                
                // Voice input indicator
                voiceIndicator
                
                // Log set button (tap fallback)
                logSetButton
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showingReceipt) {
            ReceiptView(workout: viewModel.currentWorkout)
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Subviews
    
    private var exerciseHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentExercise?.name ?? "No Exercise")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("Set \(viewModel.currentSetNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button {
                viewModel.showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.top)
    }
    
    private var restTimer: some View {
        VStack(spacing: 8) {
            Text("REST")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2)
            
            Text(viewModel.formattedRestTime)
                .font(.system(size: 80, weight: .light, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: viewModel.restSeconds)
        }
    }
    
    private var ghostDataView: some View {
        Group {
            if let ghost = viewModel.ghostSet {
                VStack(spacing: 4) {
                    Text("LAST TIME")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(1)
                    
                    HStack(spacing: 4) {
                        Text("\(ghost.weight, specifier: "%.1f")")
                            .foregroundStyle(.white.opacity(0.5))
                        Text("×")
                            .foregroundStyle(.white.opacity(0.3))
                        Text("\(ghost.reps)")
                            .foregroundStyle(.white.opacity(0.5))
                        
                        if ghost.wasPersonalRecord {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow.opacity(0.6))
                        }
                    }
                    .font(.title3.monospaced())
                }
                .padding(.top, 20)
            }
        }
    }
    
    private var voiceIndicator: some View {
        HStack(spacing: 12) {
            // Mic button
            Button {
                viewModel.toggleVoiceInput()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isListening ? Color.red : Color.white.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: viewModel.isListening ? "waveform" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.isListening ? .white : .white.opacity(0.6))
                        .symbolEffect(.variableColor, isActive: viewModel.isListening)
                }
            }
            
            if viewModel.isListening {
                Text("Listening...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            } else if viewModel.isProcessing {
                ProgressView()
                    .tint(.white.opacity(0.6))
                Text("Processing...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.bottom, 20)
    }
    
    private var logSetButton: some View {
        Button {
            viewModel.showManualEntry()
        } label: {
            Text("LOG SET")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom)
    }
}

// MARK: - ViewModel

@Observable
final class RestLoopViewModel {
    // State
    var currentExercise: Exercise? = .benchPress
    var currentSetNumber: Int = 1
    var restSeconds: Int = 0
    var isListening: Bool = false
    var isProcessing: Bool = false
    var showingReceipt: Bool = false
    var showingSettings: Bool = false
    var ghostSet: GhostSet? = GhostSet(weight: 100, reps: 8, wasPersonalRecord: false)
    var currentWorkout: Workout = Workout()
    
    private var restTimer: Timer?
    
    var formattedRestTime: String {
        let minutes = restSeconds / 60
        let seconds = restSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init() {
        startRestTimer()
    }
    
    func startRestTimer() {
        restSeconds = 0
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.restSeconds += 1
        }
    }
    
    func toggleVoiceInput() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        isListening = true
        HapticManager.shared.recordingStarted()
        // Voice recording would start here
    }
    
    private func stopListening() {
        isListening = false
        isProcessing = true
        HapticManager.shared.recordingStopped()
        
        // Simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isProcessing = false
            self?.logSet(weight: 100, reps: 8)
        }
    }
    
    func logSet(weight: Double, reps: Int) {
        let set = WorkSet(weight: weight, reps: reps)
        // Add to current exercise session
        currentSetNumber += 1
        startRestTimer()
        HapticManager.shared.setLogged()
    }
    
    func showManualEntry() {
        // Would show manual entry sheet
        HapticManager.shared.tap()
    }
    
    func finishWorkout() {
        currentWorkout.endedAt = Date()
        showingReceipt = true
        HapticManager.shared.workoutCompleted()
    }
}

#Preview {
    RestLoopView()
}
