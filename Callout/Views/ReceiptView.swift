import SwiftUI

/// Receipt-style workout summary
/// Thermal printer aesthetic with dotted dividers
struct ReceiptView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        receiptHeader
                        dottedDivider
                        workoutStats
                        dottedDivider
                        exerciseList
                        dottedDivider
                        flagsSection
                        dottedDivider
                        receiptFooter
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: generateShareText()) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Receipt Components
    
    private var receiptHeader: some View {
        VStack(spacing: 8) {
            Text("CALLOUT")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white)
            
            Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
    }
    
    private var workoutStats: some View {
        HStack {
            statItem(label: "DURATION", value: formattedDuration)
            Spacer()
            statItem(label: "SETS", value: "\(workout.totalSets)")
            Spacer()
            statItem(label: "VOLUME", value: formattedVolume)
        }
        .padding(.vertical, 16)
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
    
    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(workout.exercises) { exerciseSession in
                exerciseRow(exerciseSession)
            }
            
            // Show placeholder if empty
            if workout.exercises.isEmpty {
                Text("No exercises logged")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(.vertical, 16)
    }
    
    private func exerciseRow(_ session: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.exercise.name.uppercased())
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            
            ForEach(session.sets) { set in
                HStack {
                    Text("\(set.isWarmup ? "W" : " ")")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    
                    Text("\(set.weight, specifier: "%.1f")")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Text("×")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("\(set.reps)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    if let rpe = set.rpe {
                        Text("@\(rpe, specifier: "%.0f")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    // Flags
                    HStack(spacing: 2) {
                        ForEach(set.flags, id: \.self) { flag in
                            Text(flag.emoji)
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            
            // Top set highlight
            if let topSet = session.topSet {
                HStack {
                    Text("TOP")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.8))
                    
                    Text("\(topSet.weight, specifier: "%.1f") × \(topSet.reps)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.8))
                    
                    Text("= \(Int(topSet.volume))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.5))
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var flagsSection: some View {
        Group {
            let allFlags = workout.exercises.flatMap { $0.sets.flatMap { $0.flags } }
            let uniqueFlags = Set(allFlags)
            
            if !uniqueFlags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTES")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    ForEach(Array(uniqueFlags), id: \.self) { flag in
                        HStack {
                            Text(flag.emoji)
                            Text(flag.displayName)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            }
        }
    }
    
    private var receiptFooter: some View {
        VStack(spacing: 8) {
            Text("THANK YOU FOR TRAINING")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            
            // Barcode-style decoration
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { i in
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: i % 3 == 0 ? 2 : 1, height: 24)
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 20)
    }
    
    private var dottedDivider: some View {
        HStack(spacing: 4) {
            ForEach(0..<40, id: \.self) { _ in
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 2, height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var formattedDuration: String {
        guard let end = workout.endedAt else { return "--:--" }
        let duration = end.timeIntervalSince(workout.startedAt)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var formattedVolume: String {
        let volume = workout.totalVolume
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
    
    private func generateShareText() -> String {
        var text = "CALLOUT WORKOUT\n"
        text += "\(workout.startedAt.formatted(date: .abbreviated, time: .shortened))\n\n"
        
        for session in workout.exercises {
            text += "\(session.exercise.name)\n"
            if let top = session.topSet {
                text += "  Top: \(top.weight) × \(top.reps)\n"
            }
        }
        
        text += "\nTotal: \(workout.totalSets) sets, \(Int(workout.totalVolume)) volume"
        return text
    }
}

#Preview {
    // Sample workout for preview
    var workout = Workout()
    workout.endedAt = Date()
    
    return ReceiptView(workout: workout)
}
