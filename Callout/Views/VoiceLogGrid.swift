import SwiftUI

/// GitHub contribution-style grid for voice log entries
/// Each block represents one voice capture with timestamp
struct VoiceLogGrid: View {
    let entries: [VoiceEntry]
    
    // Grid configuration
    private let columns = 7
    private let maxRows = 4
    private let blockSize: CGFloat = 28
    private let spacing: CGFloat = 6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            if !entries.isEmpty {
                HStack {
                    Text("Voice Logs")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(CalloutTheme.dimWhite)
                    
                    Spacer()
                    
                    Text("\(entries.count) captured")
                        .font(.caption)
                        .foregroundStyle(CalloutTheme.subtleWhite)
                }
            }
            
            // Grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(blockSize), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    VoiceLogBlock(entry: entry, index: index)
                }
                
                // Fill remaining slots with empty blocks (up to max visible)
                let emptySlots = max(0, min(columns * maxRows, columns * maxRows - entries.count))
                ForEach(0..<emptySlots, id: \.self) { _ in
                    EmptyBlock()
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Voice Log Block

struct VoiceLogBlock: View {
    let entry: VoiceEntry
    let index: Int
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(blockColor)
                .frame(width: 28, height: 28)
            
            // Status indicator for pending
            if entry.status == .pending {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    .scaleEffect(0.5)
            }
            
            // Failure indicator
            if entry.status == .failed {
                Image(systemName: "exclamationmark")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.black.opacity(0.6))
            }
        }
        .scaleEffect(appeared ? 1.0 : 0.5)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
    
    private var blockColor: Color {
        switch entry.status {
        case .pending:
            return CalloutTheme.lime.opacity(0.4)
        case .completed:
            return CalloutTheme.lime
        case .failed:
            return Color.orange
        }
    }
}

// MARK: - Empty Block

struct EmptyBlock: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(CalloutTheme.white.opacity(0.05))
            .frame(width: 28, height: 28)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        CalloutTheme.background.ignoresSafeArea()
        
        VoiceLogGrid(entries: [
            VoiceEntry(id: UUID(), timestamp: Date(), status: .completed),
            VoiceEntry(id: UUID(), timestamp: Date(), status: .completed),
            VoiceEntry(id: UUID(), timestamp: Date(), status: .pending),
            VoiceEntry(id: UUID(), timestamp: Date(), status: .completed),
            VoiceEntry(id: UUID(), timestamp: Date(), status: .failed),
        ])
    }
    .preferredColorScheme(.dark)
}
