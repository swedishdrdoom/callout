import SwiftUI

// MARK: - Design Constants

enum CalloutTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04)  // Near black
    static let lime = Color(red: 0.52, green: 0.80, blue: 0.09)        // Lime green #84CC16
    static let white = Color.white
    static let dimWhite = Color.white.opacity(0.6)
    static let subtleWhite = Color.white.opacity(0.3)
    
    // Typography
    static let headerFont = "Unbounded-Bold"
}

// MARK: - Main View

/// The active workout screen
/// Timer at top, voice log blocks, big callout button, finish button
struct MainView: View {
    let onFinish: (CompletedWorkout) -> Void
    let onCancel: () -> Void
    
    @State private var viewModel = MainViewModel()
    
    var body: some View {
        ZStack {
            CalloutTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Top bar with cancel
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CalloutTheme.dimWhite)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // Session timer
                Text(viewModel.formattedTime)
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundStyle(CalloutTheme.white)
                    .padding(.top, 20)
                
                // Voice log grid (GitHub-style blocks)
                VoiceLogGrid(entries: viewModel.entries)
                    .frame(maxHeight: 180)
                
                Spacer()
                
                // Big callout button
                Button {
                    viewModel.toggleRecording()
                } label: {
                    ZStack {
                        // Outer pulse ring when recording
                        if viewModel.isRecording {
                            Circle()
                                .stroke(CalloutTheme.lime.opacity(0.3), lineWidth: 2)
                                .frame(width: 150, height: 150)
                                .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                                .opacity(viewModel.isRecording ? 0 : 1)
                                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: viewModel.isRecording)
                        }
                        
                        Circle()
                            .fill(viewModel.isRecording ? CalloutTheme.lime : CalloutTheme.lime.opacity(0.15))
                            .frame(width: 130, height: 130)
                        
                        Circle()
                            .stroke(CalloutTheme.lime, lineWidth: 3)
                            .frame(width: 130, height: 130)
                        
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(viewModel.isRecording ? .black : CalloutTheme.lime)
                                .symbolEffect(.variableColor, isActive: viewModel.isRecording)
                            
                            Text(viewModel.isRecording ? "STOP" : "CALLOUT")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(viewModel.isRecording ? .black : CalloutTheme.lime)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Status text
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(CalloutTheme.dimWhite)
                    .frame(height: 20)
                    .padding(.top, 8)
                
                Spacer()
                
                // Finish button
                Button {
                    if let workout = viewModel.buildCompletedWorkout() {
                        onFinish(workout)
                    }
                } label: {
                    Text("FINISH WORKOUT")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CalloutTheme.lime, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.startSession()
        }
    }
}

// MARK: - View Model

@Observable
@MainActor
final class MainViewModel {
    
    // MARK: - State
    
    private(set) var isRecording = false
    private(set) var sessionStartTime: Date?
    private(set) var entries: [VoiceEntry] = []
    
    // Timer for UI updates
    private var timer: Timer?
    private(set) var timerTick: Int = 0  // Forces UI refresh
    
    // MARK: - Services
    
    private let recorder = VoiceRecorder()
    
    // MARK: - Computed
    
    var formattedTime: String {
        // Reference timerTick to trigger updates
        _ = timerTick
        guard let start = sessionStartTime else { return "0:00" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var statusText: String {
        if isRecording {
            return "Listening..."
        } else if entries.isEmpty {
            return "Tap to log your first set"
        } else {
            return "Tap to add more"
        }
    }
    
    var entriesCount: Int {
        entries.count
    }
    
    // MARK: - Actions
    
    func startSession() {
        sessionStartTime = Date()
        entries = []
        startTimer()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timerTick += 1
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        HapticManager.shared.recordingStarted()
        
        Task {
            do {
                try await recorder.start()
            } catch {
                isRecording = false
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        HapticManager.shared.recordingStopped()
        
        guard let audioURL = recorder.stop() else { return }
        
        // Optimistic: Add entry immediately
        let entry = VoiceEntry(id: UUID(), timestamp: Date(), status: .pending)
        entries.append(entry)
        HapticManager.shared.setLogged()
        
        // Process in background
        processAudio(url: audioURL, entryId: entry.id)
    }
    
    private func processAudio(url: URL, entryId: UUID) {
        Task { [weak self] in
            defer { try? FileManager.default.removeItem(at: url) }
            
            guard let audioData = try? Data(contentsOf: url) else { return }
            
            do {
                let result = try await self?.sendToBackend(audioData: audioData)
                self?.updateEntry(id: entryId, with: result)
            } catch {
                self?.markEntryFailed(id: entryId)
            }
        }
    }
    
    private func sendToBackend(audioData: Data) async throws -> BackendResponse {
        let url = URL(string: "\(Configuration.backendBaseURL)/api/understand")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        request.timeoutInterval = 15
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(BackendResponse.self, from: data)
    }
    
    private func updateEntry(id: UUID, with response: BackendResponse?) {
        guard let index = entries.firstIndex(where: { $0.id == id }),
              let response = response else { return }
        
        entries[index].transcript = response.transcript
        entries[index].interpreted = response.interpreted
        entries[index].status = .completed
    }
    
    private func markEntryFailed(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].status = .failed
    }
    
    /// Build the completed workout for the results screen
    func buildCompletedWorkout() -> CompletedWorkout? {
        guard let start = sessionStartTime else { return nil }
        
        timer?.invalidate()
        timer = nil
        
        return CompletedWorkout(
            date: start,
            duration: Date().timeIntervalSince(start),
            entries: entries
        )
    }
}

// MARK: - Models

struct VoiceEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    var transcript: String?
    var interpreted: InterpretedData?
    var status: EntryStatus
    
    enum EntryStatus {
        case pending
        case completed
        case failed
    }
}

struct BackendResponse: Decodable {
    let transcript: String
    let interpreted: InterpretedData
}

struct InterpretedData: Decodable {
    let type: String
    let weight: Double?
    let unit: String?
    let reps: Int?
    let name: String?
    let text: String?
    let pr: String?  // "weight", "reps", or null
}

struct CompletedWorkout {
    let date: Date
    let duration: TimeInterval
    let entries: [VoiceEntry]
    
    /// Intelligent workout name based on exercises performed
    var workoutName: String {
        let exerciseNames = exercises.map { $0.name.lowercased() }
        
        if exerciseNames.isEmpty {
            return "Workout"
        }
        
        // Categorize exercises
        var pushCount = 0
        var pullCount = 0
        var legsCount = 0
        
        let pushKeywords = ["bench", "press", "chest", "tricep", "dip", "pushup", "push up", "ohp", "overhead", "shoulder", "incline", "decline", "fly", "flye"]
        let pullKeywords = ["row", "pull", "lat", "bicep", "curl", "chin", "back", "deadlift", "face pull", "pulldown", "shrug"]
        let legsKeywords = ["squat", "leg", "lunge", "calf", "calves", "hamstring", "quad", "glute", "hip thrust", "rdl", "romanian"]
        
        for name in exerciseNames {
            if pushKeywords.contains(where: { name.contains($0) }) {
                pushCount += 1
            }
            if pullKeywords.contains(where: { name.contains($0) }) {
                pullCount += 1
            }
            if legsKeywords.contains(where: { name.contains($0) }) {
                legsCount += 1
            }
        }
        
        let total = exerciseNames.count
        let threshold = 0.6 // 60% of exercises should match for a category
        
        // Check for dominant category
        if Double(pushCount) / Double(total) >= threshold {
            return "Push Day"
        }
        if Double(pullCount) / Double(total) >= threshold {
            return "Pull Day"
        }
        if Double(legsCount) / Double(total) >= threshold {
            return "Leg Day"
        }
        
        // Check for combinations
        let upperCount = pushCount + pullCount
        if Double(upperCount) / Double(total) >= threshold && legsCount == 0 {
            return "Upper Body"
        }
        if Double(legsCount) / Double(total) >= threshold {
            return "Lower Body"
        }
        
        // Full body or mixed
        if pushCount > 0 && pullCount > 0 && legsCount > 0 {
            return "Full Body"
        }
        
        // Specific workout types
        if exerciseNames.contains(where: { $0.contains("bench") }) && 
           exerciseNames.contains(where: { $0.contains("squat") }) &&
           exerciseNames.contains(where: { $0.contains("deadlift") }) {
            return "Powerlifting"
        }
        
        return "Mixed Workout"
    }
    
    var exercises: [ExerciseData] {
        var result: [ExerciseData] = []
        var currentExercise: ExerciseData?
        
        for entry in entries {
            guard let interpreted = entry.interpreted else { continue }
            
            switch interpreted.type {
            case "exercise":
                if let current = currentExercise {
                    result.append(current)
                }
                currentExercise = ExerciseData(name: interpreted.name ?? "Unknown", sets: [])
                
            case "set":
                var prType: PRType? = nil
                if let pr = interpreted.pr {
                    prType = PRType(rawValue: "PR: \(pr.capitalized)")
                }
                let set = SetData(
                    weight: interpreted.weight ?? 0,
                    reps: interpreted.reps ?? 0,
                    unit: interpreted.unit ?? "kg",
                    prType: prType
                )
                if currentExercise != nil {
                    currentExercise?.sets.append(set)
                } else {
                    // No exercise set, create generic one
                    currentExercise = ExerciseData(name: "Exercise", sets: [set])
                }
                
            default:
                break
            }
        }
        
        if let current = currentExercise {
            result.append(current)
        }
        
        return result
    }
    
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    var totalExercises: Int {
        exercises.count
    }
}

struct ExerciseData {
    let name: String
    var sets: [SetData]
}

struct SetData {
    let weight: Double
    let reps: Int
    let unit: String
    var prType: PRType? = nil
}

enum PRType: String {
    case weight = "PR: Weight"
    case reps = "PR: Reps"
    
    var icon: String { "trophy.fill" }
    var color: Color { Color(red: 1.0, green: 0.84, blue: 0) } // Gold
}

#Preview {
    MainView()
}
