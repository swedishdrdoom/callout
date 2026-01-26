import SwiftUI

// MARK: - View Model

@Observable
final class SettingsViewModel {
    var selectedUnit: WeightUnit = .lbs
    var voiceTrigger: String = "Log"
    var customTriggerText: String = ""
    
    enum WeightUnit: String, CaseIterable, Identifiable {
        case kg = "Kilograms"
        case lbs = "Pounds"
        
        var id: String { rawValue }
        
        var symbol: String {
            switch self {
            case .kg: return "kg"
            case .lbs: return "lbs"
            }
        }
    }
    
    let voiceTriggerOptions = ["Log", "Set", "Done", "Custom"]
    
    var effectiveTrigger: String {
        voiceTrigger == "Custom" ? customTriggerText : voiceTrigger
    }
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let unitRaw = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: unitRaw) {
            selectedUnit = unit
        }
        
        if let trigger = UserDefaults.standard.string(forKey: "voiceTrigger") {
            if voiceTriggerOptions.contains(trigger) {
                voiceTrigger = trigger
            } else {
                voiceTrigger = "Custom"
                customTriggerText = trigger
            }
        }
    }
    
    func saveUnit(_ unit: WeightUnit) {
        selectedUnit = unit
        UserDefaults.standard.set(unit.rawValue, forKey: "weightUnit")
    }
    
    func saveTrigger(_ trigger: String) {
        voiceTrigger = trigger
        UserDefaults.standard.set(effectiveTrigger, forKey: "voiceTrigger")
    }
    
    func saveCustomTrigger() {
        UserDefaults.standard.set(customTriggerText, forKey: "voiceTrigger")
    }
}

// MARK: - Main View

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Units section
                        unitsSection
                        
                        // Voice trigger section
                        voiceTriggerSection
                        
                        // About section
                        aboutSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Units Section
    
    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Units", icon: "scalemass")
            
            VStack(spacing: 0) {
                ForEach(Array(SettingsViewModel.WeightUnit.allCases.enumerated()), id: \.element.id) { index, unit in
                    Button {
                        viewModel.saveUnit(unit)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.rawValue)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                
                                Text(unit.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            if viewModel.selectedUnit == unit {
                                Image(systemName: "checkmark")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                    }
                    
                    if index < SettingsViewModel.WeightUnit.allCases.count - 1 {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Voice Trigger Section
    
    private var voiceTriggerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Voice Trigger", icon: "waveform")
            
            VStack(spacing: 0) {
                ForEach(Array(viewModel.voiceTriggerOptions.enumerated()), id: \.element) { index, trigger in
                    Button {
                        viewModel.saveTrigger(trigger)
                    } label: {
                        HStack {
                            Text(trigger)
                                .font(.body)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            if viewModel.voiceTrigger == trigger {
                                Image(systemName: "checkmark")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                    }
                    
                    if index < viewModel.voiceTriggerOptions.count - 1 {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
                
                // Custom input field
                if viewModel.voiceTrigger == "Custom" {
                    Divider()
                        .background(.white.opacity(0.1))
                    
                    HStack {
                        TextField("Enter trigger word", text: $viewModel.customTriggerText)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(.white)
                            .onChange(of: viewModel.customTriggerText) { _, _ in
                                viewModel.saveCustomTrigger()
                            }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.voiceTrigger)
            
            // Helper text
            Text("Say \"\(viewModel.effectiveTrigger.isEmpty ? "..." : viewModel.effectiveTrigger)\" followed by your set info")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 4)
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("About", icon: "info.circle")
            
            VStack(spacing: 0) {
                aboutRow(label: "Version", value: viewModel.appVersion)
                
                Divider()
                    .background(.white.opacity(0.1))
                
                aboutRow(label: "Build", value: viewModel.buildNumber)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            
            // App tagline
            Text("Voice-first workout logging")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Components
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 4)
    }
    
    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
