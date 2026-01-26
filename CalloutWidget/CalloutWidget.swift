import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct CalloutProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalloutEntry {
        CalloutEntry(date: Date(), exerciseName: "Bench Press", lastSet: "100 × 5", restTime: "2:30")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CalloutEntry) -> Void) {
        let entry = CalloutEntry(
            date: Date(),
            exerciseName: currentExercise,
            lastSet: lastSetString,
            restTime: restTimeString
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalloutEntry>) -> Void) {
        // Update every minute for rest timer
        let currentDate = Date()
        var entries: [CalloutEntry] = []
        
        // Create entries for next 15 minutes
        for minuteOffset in 0..<15 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = CalloutEntry(
                date: entryDate,
                exerciseName: currentExercise,
                lastSet: lastSetString,
                restTime: calculateRestTime(from: lastSetTime, to: entryDate)
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    // MARK: - Shared Data Access
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.callout.shared")
    }
    
    private var currentExercise: String? {
        sharedDefaults?.string(forKey: "currentExercise")
    }
    
    private var lastSetString: String? {
        sharedDefaults?.string(forKey: "lastSet")
    }
    
    private var lastSetTime: Date? {
        sharedDefaults?.object(forKey: "lastSetTime") as? Date
    }
    
    private var restTimeString: String? {
        guard let lastTime = lastSetTime else { return nil }
        return calculateRestTime(from: lastTime, to: Date())
    }
    
    private func calculateRestTime(from start: Date?, to end: Date) -> String? {
        guard let start = start else { return nil }
        let elapsed = Int(end.timeIntervalSince(start))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Timeline Entry

struct CalloutEntry: TimelineEntry {
    let date: Date
    let exerciseName: String?
    let lastSet: String?
    let restTime: String?
    
    var hasActiveSession: Bool {
        exerciseName != nil
    }
}

// MARK: - Small Widget View

struct CalloutWidgetSmallView: View {
    let entry: CalloutEntry
    
    var body: some View {
        ZStack {
            Color.black
            
            if entry.hasActiveSession {
                activeSessionView
            } else {
                idleView
            }
        }
    }
    
    private var activeSessionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise name
            Text(entry.exerciseName ?? "")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Rest timer
            if let rest = entry.restTime {
                Text(rest)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
            }
            
            // Last set
            if let lastSet = entry.lastSet {
                Text(lastSet)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
    }
    
    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Tap to start")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Medium Widget View

struct CalloutWidgetMediumView: View {
    let entry: CalloutEntry
    
    var body: some View {
        ZStack {
            Color.black
            
            if entry.hasActiveSession {
                activeSessionView
            } else {
                idleView
            }
        }
    }
    
    private var activeSessionView: some View {
        HStack {
            // Left side: Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.exerciseName ?? "")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                
                if let lastSet = entry.lastSet {
                    Text("Last: \(lastSet)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("REST")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }
            
            Spacer()
            
            // Right side: Timer
            if let rest = entry.restTime {
                Text(rest)
                    .font(.system(size: 44, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }
    
    private var idleView: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Callout")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("Tap to start training")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Widget Configuration

struct CalloutWidget: Widget {
    let kind: String = "CalloutWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalloutProvider()) { entry in
            if #available(iOS 17.0, *) {
                CalloutWidgetEntryView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                CalloutWidgetEntryView(entry: entry)
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Callout")
        .description("Quick access to your workout")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CalloutWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CalloutEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            CalloutWidgetSmallView(entry: entry)
        case .systemMedium:
            CalloutWidgetMediumView(entry: entry)
        default:
            CalloutWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct CalloutWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalloutWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CalloutWidget()
} timeline: {
    CalloutEntry(date: Date(), exerciseName: nil, lastSet: nil, restTime: nil)
    CalloutEntry(date: Date(), exerciseName: "Bench Press", lastSet: "100 × 5", restTime: "2:34")
}

#Preview("Medium", as: .systemMedium) {
    CalloutWidget()
} timeline: {
    CalloutEntry(date: Date(), exerciseName: nil, lastSet: nil, restTime: nil)
    CalloutEntry(date: Date(), exerciseName: "Bench Press", lastSet: "100 × 5", restTime: "2:34")
}
