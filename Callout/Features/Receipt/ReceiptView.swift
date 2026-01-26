import SwiftUI

// MARK: - View Model

@Observable
final class ReceiptViewModel {
    var workoutDate: Date = Date()
    var duration: TimeInterval = 3420 // 57 minutes
    var exercises: [ExerciseSummary] = [
        ExerciseSummary(name: "Bench Press", topSet: "185 lbs × 8", totalVolume: 4440, setCount: 4),
        ExerciseSummary(name: "Incline DB Press", topSet: "65 lbs × 10", totalVolume: 2600, setCount: 3),
        ExerciseSummary(name: "Cable Flyes", topSet: "30 lbs × 12", totalVolume: 1080, setCount: 3),
        ExerciseSummary(name: "Tricep Pushdown", topSet: "50 lbs × 15", totalVolume: 2250, setCount: 3)
    ]
    var flags: [WorkoutFlag] = [
        WorkoutFlag(type: .pain, note: "Left shoulder tight on last set")
    ]
    var totalVolume: Double = 10370
    var unit: String = "lbs"
    
    struct ExerciseSummary: Identifiable {
        let id = UUID()
        let name: String
        let topSet: String
        let totalVolume: Double
        let setCount: Int
    }
    
    struct WorkoutFlag: Identifiable {
        let id = UUID()
        let type: FlagType
        let note: String
        
        enum FlagType {
            case pain, failure, pr
            
            var icon: String {
                switch self {
                case .pain: return "exclamationmark.triangle"
                case .failure: return "xmark.circle"
                case .pr: return "star.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .pain: return .orange
                case .failure: return .red
                case .pr: return .yellow
                }
            }
        }
    }
    
    var formattedDate: String {
        workoutDate.formatted(date: .abbreviated, time: .omitted)
    }
    
    var formattedTime: String {
        workoutDate.formatted(date: .omitted, time: .shortened)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
    
    var formattedTotalVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: totalVolume)) ?? "\(Int(totalVolume))"
    }
    
    func share() {
        // Generate shareable text/image
    }
    
    func dismiss() {
        // Navigate back or to home
    }
}

// MARK: - Main View

struct ReceiptView: View {
    @State private var viewModel = ReceiptViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Receipt paper style container
                    receiptContent
                        .background(receiptBackground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Receipt Content
    
    private var receiptContent: some View {
        VStack(spacing: 24) {
            // Header
            receiptHeader
            
            dottedDivider
            
            // Exercises list
            exercisesList
            
            dottedDivider
            
            // Totals
            totalsSection
            
            // Flags (if any)
            if !viewModel.flags.isEmpty {
                dottedDivider
                flagsSection
            }
            
            dottedDivider
            
            // Footer
            receiptFooter
        }
        .padding(24)
    }
    
    // MARK: - Header
    
    private var receiptHeader: some View {
        VStack(spacing: 8) {
            Text("CALLOUT")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.white)
            
            Text("WORKOUT COMPLETE")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
            
            HStack(spacing: 16) {
                Text(viewModel.formattedDate)
                Text("•")
                Text(viewModel.formattedTime)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.top, 4)
        }
    }
    
    // MARK: - Exercises List
    
    private var exercisesList: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.exercises) { exercise in
                exerciseRow(exercise)
            }
        }
    }
    
    private func exerciseRow(_ exercise: ReceiptViewModel.ExerciseSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(exercise.setCount) sets")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            HStack {
                Text("TOP:")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                
                Text(exercise.topSet)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.white)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Totals
    
    private var totalsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("DURATION")
                    .font(.caption)
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                
                Spacer()
                
                Text(viewModel.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("TOTAL VOLUME")
                    .font(.caption)
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                
                Spacer()
                
                Text("\(viewModel.formattedTotalVolume) \(viewModel.unit)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Flags
    
    private var flagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.caption)
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
            
            ForEach(viewModel.flags) { flag in
                HStack(spacing: 8) {
                    Image(systemName: flag.type.icon)
                        .font(.caption)
                        .foregroundStyle(flag.type.color)
                    
                    Text(flag.note)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Footer
    
    private var receiptFooter: some View {
        VStack(spacing: 20) {
            Text("*** THANK YOU ***")
                .font(.caption)
                .fontDesign(.monospaced)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))
            
            HStack(spacing: 16) {
                Button {
                    viewModel.share()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white)
                        )
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var dottedDivider: some View {
        HStack(spacing: 4) {
            ForEach(0..<30, id: \.self) { _ in
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 3, height: 3)
            }
        }
    }
    
    private var receiptBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(white: 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    ReceiptView()
}
