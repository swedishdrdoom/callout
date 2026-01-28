import SwiftUI

// MARK: - Design Constants

enum CalloutTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04)  // Near black
    static let lime = Color(red: 0.52, green: 0.80, blue: 0.09)        // Lime green #84CC16
    static let white = Color.white
    static let dimWhite = Color.white.opacity(0.6)
    static let subtleWhite = Color.white.opacity(0.3)
}

// MARK: - Main View

/// The main workout screen - radically simple
/// Just a big speak button, timer, and finish
struct MainView: View {
    @State private var viewModel = MainViewModel()
    
    var body: some View {
        ZStack {
            CalloutTheme.background.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Session timer
                Text(viewModel.formattedTime)
                    .font(.system(size: 72, weight: .light, design: .monospaced))
                    .foregroundStyle(CalloutTheme.white)
                
                Spacer()
                
                // Big speak button
                Button {
                    viewModel.toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? CalloutTheme.lime : CalloutTheme.lime.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .stroke(CalloutTheme.lime, lineWidth: 3)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(viewModel.isRecording ? .black : CalloutTheme.lime)
                            .symbolEffect(.variableColor, isActive: viewModel.isRecording)
                    }
                }
                
                // Status text
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(CalloutTheme.dimWhite)
                    .frame(height: 20)
                
                Spacer()
                
                // Entries count
                if viewModel.entriesCount > 0 {
                    Text("\(viewModel.entriesCount) entries logged")
                        .font(.caption)
                        .foregroundStyle(CalloutTheme.subtleWhite)
                }
                
                // Finish button
                Button {
                    viewModel.finishWorkout()
                } label: {
                    Text("FINISH")
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
        .sheet(isPresented: $viewModel.showingReceipt) {
            WorkoutCardView(workout: viewModel.completedWorkout)
        }
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
    var showingReceipt = false
    var completedWorkout: CompletedWorkout?
    
    // MARK: - Services
    
    private let recorder = VoiceRecorder()
    
    // MARK: - Computed
    
    var formattedTime: String {
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
            return "Tap to speak"
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
        Task.detached(priority: .userInitiated) { [weak self] in
            defer { try? FileManager.default.removeItem(at: url) }
            
            guard let audioData = try? Data(contentsOf: url) else { return }
            
            do {
                let result = try await self?.sendToBackend(audioData: audioData)
                await MainActor.run {
                    self?.updateEntry(id: entryId, with: result)
                }
            } catch {
                await MainActor.run {
                    self?.markEntryFailed(id: entryId)
                }
            }
        }
    }
    
    private func sendToBackend(audioData: Data) async throws -> BackendResponse {
        let url = URL(string: "http://139.59.185.244:3100/api/understand")!
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
    
    func finishWorkout() {
        guard let start = sessionStartTime else { return }
        
        // Build completed workout from entries
        completedWorkout = CompletedWorkout(
            date: start,
            duration: Date().timeIntervalSince(start),
            entries: entries
        )
        showingReceipt = true
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
