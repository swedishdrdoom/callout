import SwiftUI

/// 3-screen onboarding flow
/// Collects unit preference and voice trigger configuration
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var selectedUnit: WeightUnit = .kg
    @State private var selectedTrigger: VoiceTrigger = .log
    @State private var customTrigger: String = ""
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @AppStorage("voiceTrigger") private var voiceTrigger = "log"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    unitSelectionPage.tag(0)
                    voiceTriggerPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Page indicator
                pageIndicator
                    .padding(.bottom, 20)
                
                // Continue button
                continueButton
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Page 1: Unit Selection
    
    private var unitSelectionPage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("WEIGHT UNIT")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(2)
                
                Text("How do you measure?")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 16) {
                unitOption(unit: .kg)
                unitOption(unit: .lbs)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func unitOption(unit: WeightUnit) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedUnit = unit
            }
            HapticManager.shared.selection()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.displayName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    
                    Text(unit.example)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                if selectedUnit == unit {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedUnit == unit ? .white.opacity(0.15) : .white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedUnit == unit ? .white.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Page 2: Voice Trigger
    
    private var voiceTriggerPage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("VOICE TRIGGER")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(2)
                
                Text("Say this to log a set")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("Example: \"Log 100kg for 8\"")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            VStack(spacing: 12) {
                ForEach(VoiceTrigger.allCases, id: \.self) { trigger in
                    triggerOption(trigger: trigger)
                }
                
                // Custom trigger input
                if selectedTrigger == .custom {
                    TextField("Custom trigger word", text: $customTrigger)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.1))
                        )
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func triggerOption(trigger: VoiceTrigger) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTrigger = trigger
            }
            HapticManager.shared.selection()
        } label: {
            HStack {
                Text(trigger.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if selectedTrigger == trigger {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTrigger == trigger ? .white.opacity(0.15) : .white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedTrigger == trigger ? .white.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Page 3: Ready
    
    private var readyPage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                
                Text("You're Ready")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            // Settings summary
            VStack(spacing: 16) {
                summaryRow(label: "Weight Unit", value: selectedUnit.displayName)
                summaryRow(label: "Voice Trigger", value: effectiveTrigger)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
            )
            .padding(.horizontal, 40)
            
            Text("You can change these anytime in Settings")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
            
            Spacer()
        }
    }
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .font(.body)
    }
    
    private var effectiveTrigger: String {
        if selectedTrigger == .custom && !customTrigger.isEmpty {
            return "\"\(customTrigger)\""
        }
        return "\"\(selectedTrigger.rawValue)\""
    }
    
    // MARK: - Navigation
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? .white : .white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentPage == index ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }
    
    private var continueButton: some View {
        Button {
            if currentPage < 2 {
                withAnimation {
                    currentPage += 1
                }
                HapticManager.shared.tap()
            } else {
                completeOnboarding()
            }
        } label: {
            Text(currentPage == 2 ? "Start Training" : "Continue")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func completeOnboarding() {
        // Save preferences
        weightUnit = selectedUnit.rawValue
        voiceTrigger = selectedTrigger == .custom ? customTrigger : selectedTrigger.rawValue
        
        HapticManager.shared.workoutCompleted()
        
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Supporting Types

enum WeightUnit: String, CaseIterable {
    case kg, lbs
    
    var displayName: String {
        switch self {
        case .kg: return "Kilograms (kg)"
        case .lbs: return "Pounds (lbs)"
        }
    }
    
    var example: String {
        switch self {
        case .kg: return "100kg, 60kg, 20kg"
        case .lbs: return "225lbs, 135lbs, 45lbs"
        }
    }
}

enum VoiceTrigger: String, CaseIterable {
    case log = "Log"
    case set = "Set"
    case done = "Done"
    case custom = "Custom"
    
    var displayName: String {
        switch self {
        case .custom: return "Custom..."
        default: return "\"\(rawValue)\""
        }
    }
}

#Preview {
    OnboardingView()
}
