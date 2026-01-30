import SwiftUI

// MARK: - Workout Card View

/// The finished workout card - clean, minimal, bento-style
struct WorkoutCardView: View {
    let workout: CompletedWorkout?
    var onDone: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            CalloutTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Bento stats
                        bentoStats
                        
                        // Exercises list
                        exercisesList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Done") {
                    if let onDone = onDone {
                        onDone()
                    } else {
                        dismiss()
                    }
                }
                .foregroundStyle(CalloutTheme.lime)
                
                Spacer()
                
                Button {
                    // Share action
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(CalloutTheme.dimWhite)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Text(workout?.workoutName.uppercased() ?? "WORKOUT")
                .font(.custom(CalloutTheme.headerFont, size: 28))
                .tracking(4)
                .foregroundStyle(CalloutTheme.white)
                .padding(.top, 20)
            
            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(CalloutTheme.dimWhite)
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Bento Stats
    
    private var bentoStats: some View {
        HStack(spacing: 12) {
            StatBox(title: "TIME", value: formattedDuration)
            StatBox(title: "EXERCISES", value: "\(workout?.totalExercises ?? 0)")
            StatBox(title: "SETS", value: "\(workout?.totalSets ?? 0)")
        }
    }
    
    // MARK: - Exercises List
    
    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(workout?.exercises ?? [], id: \.name) { exercise in
                ExerciseCard(exercise: exercise)
            }
        }
    }
    
    // MARK: - Computed
    
    private var formattedDate: String {
        guard let date = workout?.date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    private var formattedDuration: String {
        guard let duration = workout?.duration else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(CalloutTheme.subtleWhite)
                .tracking(1)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(CalloutTheme.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(CalloutTheme.lime.opacity(0.1))
                .stroke(CalloutTheme.lime.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Exercise Card

struct ExerciseCard: View {
    let exercise: ExerciseData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name
            Text(exercise.name.uppercased())
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(CalloutTheme.lime)
                .tracking(1)
            
            // Sets
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundStyle(CalloutTheme.subtleWhite)
                            .frame(width: 20, alignment: .leading)
                        
                        Text("\(formatWeight(set.weight)) × \(set.reps)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(CalloutTheme.white)
                        
                        // PR indicator
                        if let pr = set.prType {
                            HStack(spacing: 4) {
                                Image(systemName: pr.icon)
                                    .font(.caption2)
                                Text(pr.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(pr.color)
                        }
                    }
                }
            }
            
            // Top set indicator
            if let topSet = exercise.sets.max(by: { ($0.weight * Double($0.reps)) < ($1.weight * Double($1.reps)) }) {
                HStack(spacing: 4) {
                    Text("TOP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(CalloutTheme.lime)
                    
                    Text("\(formatWeight(topSet.weight)) × \(topSet.reps) = \(Int(topSet.weight * Double(topSet.reps)))")
                        .font(.caption)
                        .foregroundStyle(CalloutTheme.dimWhite)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}

#Preview {
    WorkoutCardView(workout: CompletedWorkout(
        date: Date(),
        duration: 1845,
        entries: []
    ))
}
