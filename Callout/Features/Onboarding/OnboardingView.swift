import SwiftUI

// MARK: - View Model

@Observable
final class OnboardingViewModel {
    var currentPage: Int = 0
    var selectedUnit: WeightUnit = .lbs
    var voiceTrigger: String = "Log"
    var customTriggerText: String = ""
    var isShowingCustomTrigger: Bool = false
    
    enum WeightUnit: String, CaseIterable {
        case kg = "Kilograms"
        case lbs = "Pounds"
        
        var symbol: String {
            switch self {
            case .kg: return "kg"
            case .lbs: return "lbs"
            }
        }
        
        var example: String {
            switch self {
            case .kg: return "60 kg × 10"
            case .lbs: return "135 lbs × 10"
            }
        }
    }
    
    let voiceTriggerOptions = ["Log", "Set", "Done", "Custom"]
    
    var effectiveTrigger: String {
        voiceTrigger == "Custom" ? customTriggerText : voiceTrigger
    }
    
    func nextPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = min(currentPage + 1, 2)
        }
    }
    
    func previousPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = max(currentPage - 1, 0)
        }
    }
    
    func completeOnboarding() {
        // Save preferences and dismiss
        UserDefaults.standard.set(selectedUnit.rawValue, forKey: "weightUnit")
        UserDefaults.standard.set(effectiveTrigger, forKey: "voiceTrigger")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Main View

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page indicator
                pageIndicator
                    .padding(.top, 20)
                
                // Content
                TabView(selection: $viewModel.currentPage) {
                    unitSelectionPage
                        .tag(0)
                    
                    voiceTriggerPage
                        .tag(1)
                    
                    readyPage
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentPage)
                
                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == viewModel.currentPage ? .white : .white.opacity(0.3))
                    .frame(width: index == viewModel.currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentPage)
            }
        }
    }
    
    // MARK: - Page 1: Unit Selection
    
    private var unitSelectionPage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "scalemass")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("Choose Your Units")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("You can change this later in settings")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            VStack(spacing: 12) {
                ForEach(OnboardingViewModel.WeightUnit.allCases, id: \.self) { unit in
                    unitOptionButton(unit)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            Spacer()
        }
    }
    
    private func unitOptionButton(_ unit: OnboardingViewModel.WeightUnit) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedUnit = unit
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(unit.rawValue)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("e.g. \(unit.example)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: viewModel.selectedUnit == unit ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(viewModel.selectedUnit == unit ? .white : .white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.selectedUnit == unit ? .white.opacity(0.15) : .white.opacity(0.05))
                    .stroke(viewModel.selectedUnit == unit ? .white.opacity(0.4) : .white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Page 2: Voice Trigger
    
    private var voiceTriggerPage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("Voice Trigger")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Say this word to start logging a set")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                // Trigger options grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.voiceTriggerOptions, id: \.self) { trigger in
                        triggerOptionButton(trigger)
                    }
                }
                
                // Custom trigger input
                if viewModel.voiceTrigger == "Custom" {
                    TextField("Enter trigger word", text: $viewModel.customTriggerText)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.1))
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.2), value: viewModel.voiceTrigger)
            
            // Example
            VStack(spacing: 8) {
                Text("Example:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                
                Text("\"\(viewModel.effectiveTrigger.isEmpty ? "..." : viewModel.effectiveTrigger), 135 for 10\"")
                    .font(.headline)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 8)
            
            Spacer()
            Spacer()
        }
    }
    
    private func triggerOptionButton(_ trigger: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.voiceTrigger = trigger
            }
        } label: {
            Text(trigger)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.voiceTrigger == trigger ? .white.opacity(0.15) : .white.opacity(0.05))
                        .stroke(viewModel.voiceTrigger == trigger ? .white.opacity(0.4) : .white.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Page 3: Ready
    
    private var readyPage: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                Text("You're Ready")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Start a workout and say\n\"\(viewModel.effectiveTrigger)\" to log sets")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Summary
            VStack(spacing: 16) {
                summaryRow(icon: "scalemass", label: "Units", value: viewModel.selectedUnit.symbol)
                summaryRow(icon: "waveform", label: "Trigger", value: "\"\(viewModel.effectiveTrigger)\"")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
            Spacer()
        }
    }
    
    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Navigation
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if viewModel.currentPage > 0 {
                Button {
                    viewModel.previousPage()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            Button {
                if viewModel.currentPage == 2 {
                    viewModel.completeOnboarding()
                    dismiss()
                } else {
                    viewModel.nextPage()
                }
            } label: {
                Text(viewModel.currentPage == 2 ? "Get Started" : "Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
