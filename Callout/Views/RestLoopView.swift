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
                // Top bar with settings
                topBar
                
                // Exercise name header
                exerciseHeader
                
                Spacer()
                
                // Rest timer (counting up)
                restTimer
                
                // Ghost data from last session
                ghostDataView
                
                Spacer()
                
                // Live transcription preview
                transcriptionPreview
                
                // Voice input indicator
                voiceIndicator
                
                // Feedback text (what was understood)
                feedbackText
                
                // Log set button (tap fallback)
                logSetButton
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $viewModel.showingReceipt) {
            ReceiptView(workout: viewModel.session.currentWorkout ?? Workout())
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showingManualEntry) {
            ManualEntryView(viewModel: viewModel)
        }
    }
    
    // MARK: - Subviews
    
    private var topBar: some View {
        HStack {
            // Finish workout button (when active)
            if viewModel.session.isActive {
                Button {
                    viewModel.finishWorkout()
                } label: {
                    Text("Finish")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
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
        .padding(.top, 8)
    }
    
    private var exerciseHeader: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(viewModel.session.currentExercise?.name ?? "Say an exercise")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            if viewModel.session.currentExercise != nil {
                Text("Set \(viewModel.session.currentSetNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.top, 20)
    }
    
    private var restTimer: some View {
        VStack(spacing: 8) {
            Text("REST")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.4))
                .tracking(2)
            
            Text(viewModel.formattedRestTime)
                .font(.system(size: 72, weight: .light, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: viewModel.restSeconds)
        }
    }
    
    private var ghostDataView: some View {
        Group {
            if let ghost = viewModel.session.ghostSet {
                VStack(spacing: 4) {
                    Text("LAST TIME")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(1)
                    
                    HStack(spacing: 4) {
                        Text(viewModel.formatWeight(ghost.weight))
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
    
    private var transcriptionPreview: some View {
        Group {
            if viewModel.isListening && !viewModel.liveTranscription.isEmpty {
                Text(viewModel.liveTranscription)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 8)
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
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: viewModel.isListening ? "waveform" : "mic.fill")
                        .font(.title)
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
        .padding(.bottom, 12)
    }
    
    private var feedbackText: some View {
        Group {
            if let feedback = viewModel.lastFeedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(viewModel.feedbackIsError ? .red.opacity(0.8) : .green.opacity(0.8))
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: viewModel.lastFeedback)
    }
    
    private var logSetButton: some View {
        Button {
            viewModel.showingManualEntry = true
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
    // Services
    let session = WorkoutSession.shared
    private let speech = SpeechRecognitionService.shared
    private let airpods = AirPodController.shared
    private let widgetData = WidgetDataManager.shared
    
    // UI State
    var isListening = false
    var isProcessing = false
    var showingReceipt = false
    var showingSettings = false
    var showingManualEntry = false
    var lastFeedback: String?
    var feedbackIsError = false
    var liveTranscription: String = ""
    
    // Timer
    var restSeconds: Int = 0
    private var restTimer: Timer?
    
    private var weightUnit: String {
        UserDefaults.standard.string(forKey: "weightUnit") ?? "kg"
    }
    
    var formattedRestTime: String {
        let minutes = restSeconds / 60
        let seconds = restSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
    
    // MARK: - Lifecycle
    
    func onAppear() {
        setupAirPodCallbacks()
        airpods.activate()
        startRestTimer()
        startTranscriptionObserver()
        
        // Auto-start session if not already active
        if !session.isActive {
            session.startSession()
        }
        
        // Request speech authorization
        Task {
            await speech.requestAuthorization()
        }
    }
    
    func onDisappear() {
        airpods.deactivate()
        stopRestTimer()
    }
    
    private func setupAirPodCallbacks() {
        airpods.onTriggerActivated = { [weak self] in
            self?.startListening()
        }
        airpods.onTriggerReleased = { [weak self] in
            self?.stopListening()
        }
    }
    
    private func startTranscriptionObserver() {
        // Observe live transcription changes
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            self.liveTranscription = self.speech.currentTranscription
        }
    }
    
    // MARK: - Rest Timer
    
    private func startRestTimer() {
        restSeconds = Int(session.restElapsed)
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.restSeconds = Int(self?.session.restElapsed ?? 0)
        }
    }
    
    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
    
    // MARK: - Voice Input
    
    func toggleVoiceInput() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        guard !isListening else { return }
        isListening = true
        lastFeedback = nil
        liveTranscription = ""
        
        HapticManager.shared.recordingStarted()
        
        Task {
            do {
                try await speech.startListening()
            } catch {
                await MainActor.run {
                    showError("Speech recognition unavailable: \(error.localizedDescription)")
                    isListening = false
                }
            }
        }
    }
    
    private func stopListening() {
        guard isListening else { return }
        isListening = false
        
        HapticManager.shared.recordingStopped()
        
        // Get final transcription
        let transcription = speech.stopListening()
        
        guard !transcription.isEmpty else {
            showError("Didn't catch that")
            return
        }
        
        // Process the command
        processTranscription(transcription)
    }
    
    private func processTranscription(_ transcription: String) {
        isProcessing = true
        
        // Process the command
        let result = session.processVoiceInput(transcription)
        
        handleProcessResult(result, transcription: transcription)
        isProcessing = false
        
        // Update widget
        updateWidgetData()
        
        // Clear live transcription
        liveTranscription = ""
    }
    
    private func handleProcessResult(_ result: WorkoutSession.ProcessResult, transcription: String) {
        switch result {
        case .exerciseChanged(let name):
            showFeedback("→ \(name)")
            
        case .setLogged(let set):
            showFeedback("✓ \(formatWeight(set.weight)) × \(set.reps)")
            
        case .flagAdded(let flag):
            showFeedback("+ \(flag.displayName)")
            
        case .notUnderstood(let text):
            showError("? \"\(text)\"")
            
        case .error(let message):
            showError(message)
            
        case .empty:
            showError("Didn't hear anything")
        }
    }
    
    private func showFeedback(_ message: String) {
        lastFeedback = message
        feedbackIsError = false
        
        // Clear after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.lastFeedback == message {
                self?.lastFeedback = nil
            }
        }
    }
    
    private func showError(_ message: String) {
        lastFeedback = message
        feedbackIsError = true
        HapticManager.shared.error()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.lastFeedback == message {
                self?.lastFeedback = nil
            }
        }
    }
    
    // MARK: - Widget
    
    private func updateWidgetData() {
        if let exercise = session.currentExercise {
            widgetData.setCurrentExercise(exercise.name)
        }
        
        if let lastSet = session.lastLoggedSet {
            widgetData.setLastSet(
                weight: lastSet.weight,
                reps: lastSet.reps,
                unit: weightUnit
            )
        }
    }
    
    // MARK: - Manual Entry
    
    func logManualSet(weight: Double, reps: Int) {
        session.logSet(weight: weight, reps: reps)
        showFeedback("✓ \(formatWeight(weight)) × \(reps)")
        updateWidgetData()
    }
    
    // MARK: - Finish Workout
    
    func finishWorkout() {
        session.endSession()
        showingReceipt = true
        widgetData.clearSession()
    }
}

// MARK: - Manual Entry Sheet

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: RestLoopViewModel
    
    @State private var weight: String = ""
    @State private var reps: String = ""
    @FocusState private var weightFocused: Bool
    
    private var weightUnit: String {
        UserDefaults.standard.string(forKey: "weightUnit") ?? "kg"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (\(weightUnit))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .focused($weightFocused)
                    }
                    
                    // Reps input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("0", text: $reps)
                            .keyboardType(.numberPad)
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Log button
                    Button {
                        if let w = Double(weight), let r = Int(reps), r > 0 {
                            viewModel.logManualSet(weight: w, reps: r)
                            dismiss()
                        }
                    } label: {
                        Text("LOG SET")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(weight.isEmpty || reps.isEmpty)
                    .opacity(weight.isEmpty || reps.isEmpty ? 0.5 : 1)
                }
                .padding()
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                weightFocused = true
            }
        }
    }
}

#Preview {
    RestLoopView()
}
