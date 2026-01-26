import Foundation

/// Local-first data persistence using JSON files
/// Designed for offline-first operation with future sync capability
actor PersistenceManager {
    static let shared = PersistenceManager()
    
    // MARK: - File Paths
    
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var calloutDirectory: URL {
        documentsDirectory.appendingPathComponent("Callout", isDirectory: true)
    }
    
    private var workoutsDirectory: URL {
        calloutDirectory.appendingPathComponent("Workouts", isDirectory: true)
    }
    
    private var exercisesFile: URL {
        calloutDirectory.appendingPathComponent("exercises.json")
    }
    
    private var historyIndexFile: URL {
        calloutDirectory.appendingPathComponent("history-index.json")
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await ensureDirectoriesExist()
        }
    }
    
    private func ensureDirectoriesExist() {
        try? fileManager.createDirectory(at: calloutDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: workoutsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Workout Persistence
    
    /// Save a workout to disk
    func save(workout: Workout) async throws {
        let filename = "\(workout.id.uuidString).json"
        let fileURL = workoutsDirectory.appendingPathComponent(filename)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(workout)
        try data.write(to: fileURL, options: .atomic)
        
        // Update index
        await updateHistoryIndex(adding: workout)
    }
    
    /// Load a specific workout by ID
    func loadWorkout(id: UUID) async throws -> Workout? {
        let filename = "\(id.uuidString).json"
        let fileURL = workoutsDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(Workout.self, from: data)
    }
    
    /// Load all workouts (sorted by date, most recent first)
    func loadAllWorkouts() async throws -> [Workout] {
        let files = try fileManager.contentsOfDirectory(at: workoutsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var workouts: [Workout] = []
        
        for file in files {
            if let data = try? Data(contentsOf: file),
               let workout = try? decoder.decode(Workout.self, from: data) {
                workouts.append(workout)
            }
        }
        
        return workouts.sorted { $0.startedAt > $1.startedAt }
    }
    
    /// Delete a workout
    func deleteWorkout(id: UUID) async throws {
        let filename = "\(id.uuidString).json"
        let fileURL = workoutsDirectory.appendingPathComponent(filename)
        try fileManager.removeItem(at: fileURL)
        await updateHistoryIndex(removing: id)
    }
    
    // MARK: - History Index (Fast Lookups)
    
    struct HistoryIndex: Codable {
        var workoutIds: [UUID]
        var lastWorkoutDate: Date?
        var exerciseLastPerformed: [String: Date]
        var exerciseHistory: [String: [ExerciseHistoryEntry]]
    }
    
    struct ExerciseHistoryEntry: Codable {
        let workoutId: UUID
        let date: Date
        let topSetWeight: Double
        let topSetReps: Int
        let totalSets: Int
        let totalVolume: Double
    }
    
    private func loadHistoryIndex() async throws -> HistoryIndex {
        guard fileManager.fileExists(atPath: historyIndexFile.path) else {
            return HistoryIndex(
                workoutIds: [],
                lastWorkoutDate: nil,
                exerciseLastPerformed: [:],
                exerciseHistory: [:]
            )
        }
        
        let data = try Data(contentsOf: historyIndexFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HistoryIndex.self, from: data)
    }
    
    private func saveHistoryIndex(_ index: HistoryIndex) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(index)
        try data.write(to: historyIndexFile, options: .atomic)
    }
    
    private func updateHistoryIndex(adding workout: Workout) async {
        guard var index = try? await loadHistoryIndex() else { return }
        
        if !index.workoutIds.contains(workout.id) {
            index.workoutIds.append(workout.id)
        }
        
        if index.lastWorkoutDate == nil || workout.startedAt > index.lastWorkoutDate! {
            index.lastWorkoutDate = workout.startedAt
        }
        
        // Update exercise history
        for session in workout.exercises {
            let exerciseName = session.exercise.name
            index.exerciseLastPerformed[exerciseName] = workout.startedAt
            
            if let topSet = session.topSet {
                let entry = ExerciseHistoryEntry(
                    workoutId: workout.id,
                    date: workout.startedAt,
                    topSetWeight: topSet.weight,
                    topSetReps: topSet.reps,
                    totalSets: session.sets.count,
                    totalVolume: session.totalVolume
                )
                
                if index.exerciseHistory[exerciseName] == nil {
                    index.exerciseHistory[exerciseName] = []
                }
                index.exerciseHistory[exerciseName]?.append(entry)
            }
        }
        
        try? await saveHistoryIndex(index)
    }
    
    private func updateHistoryIndex(removing workoutId: UUID) async {
        guard var index = try? await loadHistoryIndex() else { return }
        index.workoutIds.removeAll { $0 == workoutId }
        try? await saveHistoryIndex(index)
    }
    
    // MARK: - Ghost Data Queries
    
    /// Get the last time an exercise was performed with top set info
    func getLastPerformance(for exerciseName: String) async -> GhostSet? {
        guard let index = try? await loadHistoryIndex(),
              let history = index.exerciseHistory[exerciseName],
              let lastEntry = history.last else {
            return nil
        }
        
        // Check if this was a PR (simplified: just check if it's the best weight×reps)
        let wasPersonalRecord = history.allSatisfy { entry in
            entry.topSetWeight * Double(entry.topSetReps) <= lastEntry.topSetWeight * Double(lastEntry.topSetReps)
        }
        
        return GhostSet(
            weight: lastEntry.topSetWeight,
            reps: lastEntry.topSetReps,
            wasPersonalRecord: wasPersonalRecord
        )
    }
    
    /// Get exercise history for analysis
    func getExerciseHistory(_ exerciseName: String, limit: Int = 20) async -> [ExerciseHistoryEntry] {
        guard let index = try? await loadHistoryIndex(),
              let history = index.exerciseHistory[exerciseName] else {
            return []
        }
        return Array(history.suffix(limit))
    }
    
    // MARK: - Export
    
    /// Export all data as JSON for backup/transfer
    func exportAllData() async throws -> Data {
        struct ExportData: Codable {
            let exportedAt: Date
            let workouts: [Workout]
            let index: HistoryIndex
        }
        
        let workouts = try await loadAllWorkouts()
        let index = try await loadHistoryIndex()
        
        let export = ExportData(
            exportedAt: Date(),
            workouts: workouts,
            index: index
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(export)
    }
    
    /// Export as CSV (simple format)
    func exportAsCSV() async throws -> String {
        let workouts = try await loadAllWorkouts()
        
        var csv = "Date,Exercise,Set,Weight,Reps,RPE,Flags\n"
        
        for workout in workouts {
            let dateStr = workout.startedAt.ISO8601Format()
            
            for session in workout.exercises {
                for (index, set) in session.sets.enumerated() {
                    let rpeStr = set.rpe.map { String(format: "%.1f", $0) } ?? ""
                    let flagsStr = set.flags.map { $0.rawValue }.joined(separator: "|")
                    
                    csv += "\(dateStr),\(session.exercise.name),\(index + 1),\(set.weight),\(set.reps),\(rpeStr),\(flagsStr)\n"
                }
            }
        }
        
        return csv
    }
}
