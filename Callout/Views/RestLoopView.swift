import SwiftUI

// MARK: - RestLoopView

/// Main workout interface - the "rest loop"
/// Minimal dark interface focused on rest timing and set logging
struct RestLoopView: View {
    
    // MARK: - Properties
    
    @State private var viewModel = RestLoopViewModel()
    
    // MARK: - Body
    
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
        .alert("API Key Required", isPresented: $viewModel.showingAPIKeyAlert) {
            Button("Open Settings") {
                viewModel.showingSettings = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Voice transcription requires a Deepgram API key. Add one in Settings.")
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
            
            // Use TimelineView to isolate timer updates and prevent full view re-renders
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                // Reference context.date to ensure SwiftUI re-evaluates on each tick
                let _ = context.date
                Text(viewModel.formattedRestTime)
                    .font(.system(size: 72, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
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

/// View model for the rest loop interface
/// Handles voice input, timer management, and workout state coordination
@Observable
@MainActor
final class RestLoopViewModel {
    
    // MARK: - Services
    
    let session = WorkoutSession.shared
    private let recorder = VoiceRecorder()
    private let transcription = DeepgramService.shared
    private let airpods = AirPodController.shared
    private let widgetData = WidgetDataManager.shared
    
    // MARK: - UI State
    
    var isListening = false
    var isProcessing = false
    var showingReceipt = false
    var showingSettings = false
    var showingManualEntry = false
    var showingAPIKeyAlert = false
    var lastFeedback: String?
    var feedbackIsError = false
    
    // MARK: - Private Properties
    
    /// Cached weight unit to avoid repeated UserDefaults reads
    @ObservationIgnored
    private lazy var weightUnit: String = {
        UserDefaults.standard.string(forKey: UserDefaultsKey.weightUnit) ?? "kg"
    }()
    
    // Pre-allocated formatters for performance
    private static let timeFormatter: (Int, Int) -> String = { minutes, seconds in
        String(format: "%d:%02d", minutes, seconds)
    }
    
    private static let weightFormatterWhole: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()
    
    private static let weightFormatterDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()
    
    /// Computed directly from session - no Timer needed, TimelineView handles updates
    var formattedRestTime: String {
        let total = Int(session.restElapsed)
        let minutes = total / 60
        let seconds = total % 60
        return Self.timeFormatter(minutes, seconds)
    }
    
    func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return Self.weightFormatterWhole.string(from: NSNumber(value: weight)) ?? "\(Int(weight))"
        }
        return Self.weightFormatterDecimal.string(from: NSNumber(value: weight)) ?? String(format: "%.1f", weight)
    }
    
    // MARK: - Lifecycle
    
    /// Called when view appears - sets up services and auto-starts session
    func onAppear() {
        setupAirPodCallbacks()
        airpods.activate()
        
        // Auto-start session if not already active
        if !session.isActive {
            session.startSession()
        }
        
        // Pre-warm haptics for immediate feedback
        HapticManager.shared.prepareAll()
    }
    
    /// Called when view disappears - cleans up AirPod controller
    func onDisappear() {
        airpods.deactivate()
    }
    
    private func setupAirPodCallbacks() {
        airpods.onTriggerActivated = { [weak self] in
            Task { @MainActor in
                self?.startListening()
            }
        }
        airpods.onTriggerReleased = { [weak self] in
            Task { @MainActor in
                self?.stopListening()
            }
        }
    }
    
    // MARK: - Voice Input
    
    /// Toggle voice input on/off
    func toggleVoiceInput() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        // Check for API key
        guard transcription.hasAPIKey else {
            showingAPIKeyAlert = true
            return
        }
        
        // Prevent starting while already listening
        guard !isListening else { return }
        isListening = true
        lastFeedback = nil
        
        HapticManager.shared.recordingStarted()
        
        Task {
            do {
                try await recorder.start()
                #if DEBUG
                print("[RestLoopVM] Recording started")
                #endif
            } catch {
                showError("Microphone access required")
                isListening = false
            }
        }
    }
    
    private func stopListening() {
        guard isListening else { return }
        isListening = false
        
        HapticManager.shared.recordingStopped()
        
        guard let audioURL = recorder.stop() else {
            showError("No audio recorded")
            return
        }
        
        #if DEBUG
        print("[RestLoopVM] Recording stopped")
        #endif
        
        // OPTIMISTIC UI: Immediately show feedback and reset timer
        // Don't wait for backend - user sees instant response
        session.logPendingSet()  // Create placeholder entry
        showFeedback("✓ Logged")
        HapticManager.shared.setLogged()
        
        // Process in background - fire and forget
        processAudioInBackground(at: audioURL)
    }
    
    /// Fire-and-forget background processing
    /// User already got feedback, this just updates the actual data
    private func processAudioInBackground(at url: URL) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            do {
                // Read audio data
                let audioData = try Data(contentsOf: url)
                
                #if DEBUG
                print("[RestLoopVM] Sending \(audioData.count) bytes to backend...")
                #endif
                
                // Send to backend for transcription + LLM interpretation
                let result = try await self.sendToBackend(audioData: audioData)
                
                // Update session with interpreted result
                await MainActor.run {
                    self.handleBackendResult(result)
                }
                
            } catch {
                #if DEBUG
                print("[RestLoopVM] Background processing failed: \(error)")
                #endif
                // Silent fail - user already got "Logged" feedback
                // Entry will show as "pending" in receipt if backend fails
            }
            
            // Clean up audio file
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    /// Send audio to backend and get interpreted result
    private func sendToBackend(audioData: Data) async throws -> BackendResult {
        // Try the new /api/understand endpoint first (transcribe + LLM)
        let url = URL(string: "\(Configuration.backendBaseURL)/api/understand")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 15 // Reasonable timeout for background
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "Backend", code: -1)
        }
        
        return try JSONDecoder().decode(BackendResult.self, from: data)
    }
    
    /// Handle the interpreted result from backend
    private func handleBackendResult(_ result: BackendResult) {
        #if DEBUG
        print("[RestLoopVM] Backend result: \(result.transcript) → \(result.interpreted)")
        #endif
        
        // Update the session with properly interpreted data
        switch result.interpreted.type {
        case "set":
            if let weight = result.interpreted.weight,
               let reps = result.interpreted.reps {
                session.updateLastPendingSet(weight: weight, reps: reps, unit: result.interpreted.unit)
            }
        case "exercise":
            if let name = result.interpreted.name {
                session.setCurrentExercise(name)
            }
        case "repeat":
            session.repeatLastSet()
        default:
            // Unknown - leave as pending
            break
        }
        
        updateWidgetData()
    }
    
    private func showFeedback(_ message: String) {
        lastFeedback = message
        feedbackIsError = false
        
        // Clear after delay using structured concurrency
        let currentMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if lastFeedback == currentMessage {
                lastFeedback = nil
            }
        }
    }
    
    private func showError(_ message: String) {
        lastFeedback = message
        feedbackIsError = true
        HapticManager.shared.error()
        
        // Clear after delay using structured concurrency
        let currentMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if lastFeedback == currentMessage {
                lastFeedback = nil
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
    
    /// Log a set manually with given weight and reps
    /// - Parameters:
    ///   - weight: The weight lifted
    ///   - reps: Number of repetitions
    func logManualSet(weight: Double, reps: Int) {
        session.logSet(weight: weight, reps: reps)
        showFeedback("✓ \(formatWeight(weight)) × \(reps)")
        updateWidgetData()
    }
    
    // MARK: - Workout Management
    
    /// End the current workout and show receipt
    func finishWorkout() {
        session.endSession()
        showingReceipt = true
        widgetData.clearSession()
    }
}

#Preview {
    RestLoopView()
}
