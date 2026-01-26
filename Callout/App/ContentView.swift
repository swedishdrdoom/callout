//
//  ContentView.swift
//  Callout
//
//  Main content view with navigation
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    /// Whether the user has completed onboarding
    private var hasCompletedOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding ?? false
    }
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(onComplete: completeOnboarding)
            }
        }
        .onAppear {
            ensureProfileExists()
        }
    }
    
    /// Ensure a user profile exists
    private func ensureProfileExists() {
        if profiles.isEmpty {
            let profile = UserProfile()
            modelContext.insert(profile)
        }
    }
    
    /// Mark onboarding as complete
    private func completeOnboarding() {
        if let profile = profiles.first {
            profile.hasCompletedOnboarding = true
            profile.updatedAt = Date()
        }
    }
}

/// Main tab view for the app
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RestLoopView()
                .tabItem {
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(0)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

/// Placeholder for history view
struct HistoryView: View {
    @Query(sort: \SetCard.timestamp, order: .reverse) 
    private var recentSets: [SetCard]
    
    var body: some View {
        NavigationStack {
            List {
                if recentSets.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Your workout history will appear here.")
                    )
                } else {
                    ForEach(groupedByDay, id: \.0) { day, sets in
                        Section(header: Text(day, style: .date)) {
                            ForEach(sets) { set in
                                SetCardRow(set: set)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
    
    /// Group sets by day
    private var groupedByDay: [(Date, [SetCard])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentSets) { set in
            calendar.startOfDay(for: set.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }
}

/// Row view for a set card
struct SetCardRow: View {
    let set: SetCard
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(set.exercise)
                    .font(.headline)
                Text(set.displayString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if set.failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
            
            if set.painFlag != nil {
                Image(systemName: "bandage.fill")
                    .foregroundStyle(.red)
            }
            
            if set.isWarmup {
                Text("W")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview().container)
}
