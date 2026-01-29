import Foundation

/// Local-first data persistence using JSON files
/// Designed for offline-first operation with future sync capability
/// Uses background queue for disk I/O and in-memory cache for fast reads
final class PersistenceManager {
    static let shared = PersistenceManager()
    
    // MARK: - File Paths
    
    private let fileManager = FileManager.default
    
    /// Background queue for all disk I/O operations
    private let diskQueue = DispatchQueue(label: "com.callout.persistence", qos: .utility)
    
    /// In-memory cache for fast reads
    private var historyIndexCache: HistoryIndex?
    private var workoutsCache: [UUID: Workout] = [:]
    private let cacheLock = NSLock()
    
    private lazy var documentsDirectory: URL = {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()
    
    private lazy var calloutDirectory: URL = {
        documentsDirectory.appendingPathComponent("Callout", isDirectory: true)
    }()
    
    private lazy var workoutsDirectory: URL = {
        calloutDirectory.appendingPathComponent("Workouts", isDirectory: true)
    }()
    
    private lazy var exercisesFile: URL = {
        calloutDirectory.appendingPathComponent("exercises.json")
    }()
    
    private lazy var historyIndexFile: URL = {
        calloutDirectory.appendingPathComponent("history-index.json")
    }()
    
    // MARK: - Initialization
    
    private init() {
        ensureDirectoriesExist()
        // Pre-load history index into cache on init
        diskQueue.async { [weak self] in
            self?.warmUpCache()
        }
    }
    
    private func ensureDirectoriesExist() {
        try? fileManager.createDirectory(at: calloutDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: workoutsDirectory, withIntermediateDirectories: true)
    }
    
    /// Pre-load frequently accessed data into memory
    private func warmUpCache() {
        let index = loadHistoryIndexFromDisk()
        cacheLock.lock()
        historyIndexCache = index
        cacheLock.unlock()
    }
    
    // MARK: - Workout Persistence
    
    /// Save a workout to disk (async on background queue for zero main-thread lag)
    func save(workout: Workout) throws {
        // Update in-memory cache immediately for fast reads
        cacheLock.lock()
        workoutsCache[workout.id] = workout
        cacheLock.unlock()
        
        // Persist to disk on background queue
        let workoutToSave = workout // Capture value explicitly for Sendable
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            
            let filename = "\(workoutToSave.id.uuidString).json"
            let fileURL = self.workoutsDirectory.appendingPathComponent(filename)
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            do {
                let data = try encoder.encode(workoutToSave)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                #if DEBUG
                print("[PersistenceManager] Failed to save workout: \(error)")
                #endif
            }
            
            // Update index
            self.updateHistoryIndex(adding: workoutToSave)
        }
    }
    
    /// Load a specific workout by ID (checks cache first)
    func loadWorkout(id: UUID) throws -> Workout? {
        // Check cache first for fast reads
        cacheLock.lock()
        if let cached = workoutsCache[id] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        let filename = "\(id.uuidString).json"
        let fileURL = workoutsDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let workout = try decoder.decode(Workout.self, from: data)
        
        // Cache for future reads
        cacheLock.lock()
        workoutsCache[id] = workout
        cacheLock.unlock()
        
        return workout
    }
    
    /// Load all workouts (sorted by date, most recent first)
    func loadAllWorkouts() throws -> [Workout] {
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
    func deleteWorkout(id: UUID) throws {
        let filename = "\(id.uuidString).json"
        let fileURL = workoutsDirectory.appendingPathComponent(filename)
        try fileManager.removeItem(at: fileURL)
        updateHistoryIndex(removing: id)
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
    
    /// Load history index - uses in-memory cache for fast reads
    private func loadHistoryIndex() -> HistoryIndex {
        cacheLock.lock()
        if let cached = historyIndexCache {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        // Fallback to disk if cache miss
        let index = loadHistoryIndexFromDisk()
        
        cacheLock.lock()
        historyIndexCache = index
        cacheLock.unlock()
        
        return index
    }
    
    /// Load history index directly from disk (called by background operations)
    private func loadHistoryIndexFromDisk() -> HistoryIndex {
        guard fileManager.fileExists(atPath: historyIndexFile.path),
              let data = try? Data(contentsOf: historyIndexFile) else {
            return HistoryIndex(
                workoutIds: [],
                lastWorkoutDate: nil,
                exerciseLastPerformed: [:],
                exerciseHistory: [:]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(HistoryIndex.self, from: data)) ?? HistoryIndex(
            workoutIds: [],
            lastWorkoutDate: nil,
            exerciseLastPerformed: [:],
            exerciseHistory: [:]
        )
    }
    
    /// Save history index - updates cache immediately, persists to disk on background
    private func saveHistoryIndex(_ index: HistoryIndex) {
        // Update cache immediately
        cacheLock.lock()
        historyIndexCache = index
        cacheLock.unlock()
        
        // Already on disk queue from updateHistoryIndex, just write
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(index) {
            try? data.write(to: historyIndexFile, options: .atomic)
        }
    }
    
    private func updateHistoryIndex(adding workout: Workout) {
        var index = loadHistoryIndex()
        
        if !index.workoutIds.contains(workout.id) {
            index.workoutIds.append(workout.id)
        }
        
        if let lastDate = index.lastWorkoutDate {
            if workout.startedAt > lastDate {
                index.lastWorkoutDate = workout.startedAt
            }
        } else {
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
        
        saveHistoryIndex(index)
    }
    
    private func updateHistoryIndex(removing workoutId: UUID) {
        var index = loadHistoryIndex()
        index.workoutIds.removeAll { $0 == workoutId }
        saveHistoryIndex(index)
    }
    
    // MARK: - Ghost Data Queries
    
    /// Get the last time an exercise was performed with top set info
    func getLastPerformance(for exerciseName: String) -> GhostSet? {
        let index = loadHistoryIndex()
        guard let history = index.exerciseHistory[exerciseName],
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
    func getExerciseHistory(_ exerciseName: String, limit: Int = 20) -> [ExerciseHistoryEntry] {
        let index = loadHistoryIndex()
        guard let history = index.exerciseHistory[exerciseName] else {
            return []
        }
        return Array(history.suffix(limit))
    }
    
    // MARK: - Export
    
    /// Export all data as JSON for backup/transfer
    func exportAllData() throws -> Data {
        struct ExportData: Codable {
            let exportedAt: Date
            let workouts: [Workout]
            let index: HistoryIndex
        }
        
        let workouts = try loadAllWorkouts()
        let index = loadHistoryIndex()
        
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
    func exportAsCSV() throws -> String {
        let workouts = try loadAllWorkouts()
        
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
