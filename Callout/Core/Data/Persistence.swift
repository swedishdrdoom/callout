//
//  Persistence.swift
//  Callout
//
//  SwiftData container and persistence management
//

import Foundation
import SwiftData

/// Manages the SwiftData persistence layer
@MainActor
final class PersistenceController {
    /// Shared singleton instance
    static let shared = PersistenceController()
    
    /// The SwiftData model container
    let container: ModelContainer
    
    /// The main model context
    var mainContext: ModelContext {
        container.mainContext
    }
    
    /// Initialize with the production configuration
    private init() {
        let schema = Schema([
            SetCard.self,
            Session.self,
            UserProfile.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Initialize with in-memory storage (for previews and tests)
    static func preview() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)
        
        // Add sample data for previews
        let context = controller.mainContext
        
        // Create sample profile
        let profile = UserProfile(
            preferredUnit: .kg,
            voiceTrigger: .tapLeft,
            hasCompletedOnboarding: true
        )
        context.insert(profile)
        
        // Create sample sets
        let exercises = ["Bench Press", "Barbell Squat", "Deadlift"]
        let sessionId = UUID()
        var timestamp = Date().addingTimeInterval(-3600) // 1 hour ago
        
        for exercise in exercises {
            for setNum in 1...4 {
                let set = SetCard(
                    exercise: exercise,
                    weight: Double(60 + setNum * 10),
                    weightUnit: .kg,
                    reps: setNum == 4 ? 3 : 5,
                    timestamp: timestamp,
                    failed: setNum == 4,
                    failedAtRep: setNum == 4 ? 3 : nil,
                    isWarmup: setNum == 1,
                    sessionId: sessionId
                )
                context.insert(set)
                timestamp = timestamp.addingTimeInterval(180) // 3 minutes between sets
            }
        }
        
        return controller
    }
    
    /// Private initializer for in-memory storage
    private init(inMemory: Bool) {
        let schema = Schema([
            SetCard.self,
            Session.self,
            UserProfile.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

// MARK: - Convenience Methods

extension PersistenceController {
    /// Fetch the user profile, creating one if it doesn't exist
    func fetchOrCreateProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        
        do {
            let profiles = try mainContext.fetch(descriptor)
            if let profile = profiles.first {
                return profile
            }
        } catch {
            print("Failed to fetch profile: \(error)")
        }
        
        // Create new profile
        let newProfile = UserProfile()
        mainContext.insert(newProfile)
        return newProfile
    }
    
    /// Fetch sets for a specific session
    func fetchSets(for sessionId: UUID) -> [SetCard] {
        let descriptor = FetchDescriptor<SetCard>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            print("Failed to fetch sets: \(error)")
            return []
        }
    }
    
    /// Fetch recent sets (today)
    func fetchTodaysSets() -> [SetCard] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<SetCard>(
            predicate: #Predicate { $0.timestamp >= startOfDay },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's sets: \(error)")
            return []
        }
    }
    
    /// Fetch the last set for a specific exercise
    func fetchLastSet(for exercise: String) -> SetCard? {
        let descriptor = FetchDescriptor<SetCard>(
            predicate: #Predicate { $0.exercise == exercise && !$0.isWarmup },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let sets = try mainContext.fetch(descriptor)
            return sets.first
        } catch {
            print("Failed to fetch last set: \(error)")
            return nil
        }
    }
    
    /// Fetch historical sets for an exercise (for ghost data)
    func fetchHistory(for exercise: String, limit: Int = 10) -> [SetCard] {
        let descriptor = FetchDescriptor<SetCard>(
            predicate: #Predicate { $0.exercise == exercise && !$0.isWarmup },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            var limitedDescriptor = descriptor
            limitedDescriptor.fetchLimit = limit
            return try mainContext.fetch(limitedDescriptor)
        } catch {
            print("Failed to fetch history: \(error)")
            return []
        }
    }
    
    /// Save the context
    func save() {
        do {
            try mainContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
