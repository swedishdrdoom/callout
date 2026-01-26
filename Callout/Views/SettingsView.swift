import SwiftUI

/// Settings screen with unit and voice configuration
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @AppStorage("voiceTrigger") private var voiceTrigger = "log"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("deepgram_api_key") private var apiKey = ""
    
    @State private var customTrigger = ""
    @State private var showingCustomInput = false
    @State private var showingAPIKeyInput = false
    @State private var tempAPIKey = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    // Unit preference
                    Section {
                        unitRow(unit: "kg", display: "Kilograms (kg)")
                        unitRow(unit: "lbs", display: "Pounds (lbs)")
                    } header: {
                        Text("Weight Unit")
                    }
                    
                    // Voice trigger
                    Section {
                        triggerRow(trigger: "log", display: "\"Log\"")
                        triggerRow(trigger: "set", display: "\"Set\"")
                        triggerRow(trigger: "done", display: "\"Done\"")
                        
                        // Custom option
                        Button {
                            showingCustomInput = true
                        } label: {
                            HStack {
                                Text("Custom...")
                                    .foregroundStyle(.white)
                                Spacer()
                                if !["log", "set", "done"].contains(voiceTrigger) {
                                    Text("\"\(voiceTrigger)\"")
                                        .foregroundStyle(.white.opacity(0.5))
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    } header: {
                        Text("Voice Trigger")
                    } footer: {
                        Text("Say this word followed by weight and reps to log a set")
                    }
                    
                    // Deepgram API Key
                    Section {
                        Button {
                            tempAPIKey = apiKey
                            showingAPIKeyInput = true
                        } label: {
                            HStack {
                                Text("Deepgram API Key")
                                    .foregroundStyle(.white)
                                Spacer()
                                if apiKey.isEmpty {
                                    Text("Not set")
                                        .foregroundStyle(.red.opacity(0.7))
                                } else {
                                    Text("••••\(String(apiKey.suffix(4)))")
                                        .foregroundStyle(.green.opacity(0.7))
                                }
                            }
                        }
                    } header: {
                        Text("Voice Transcription")
                    } footer: {
                        Text("Required for voice input. Get one free at deepgram.com")
                    }
                    
                    // Haptics
                    Section {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptic Feedback", systemImage: "hand.tap.fill")
                                .foregroundStyle(.white)
                        }
                        .tint(.white)
                    } header: {
                        Text("Feedback")
                    }
                    
                    // About
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        HStack {
                            Text("Build")
                                .foregroundStyle(.white)
                            Spacer()
                            Text(buildNumber)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    } header: {
                        Text("About")
                    }
                    
                    // Danger zone
                    Section {
                        Button(role: .destructive) {
                            resetOnboarding()
                        } label: {
                            Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Custom Trigger", isPresented: $showingCustomInput) {
                TextField("Trigger word", text: $customTrigger)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Button("Cancel", role: .cancel) {
                    customTrigger = ""
                }
                
                Button("Save") {
                    if !customTrigger.isEmpty {
                        voiceTrigger = customTrigger
                        HapticManager.shared.setLogged()
                    }
                    customTrigger = ""
                }
            } message: {
                Text("Enter a custom word to trigger set logging")
            }
            .alert("Deepgram API Key", isPresented: $showingAPIKeyInput) {
                TextField("dg_...", text: $tempAPIKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Button("Cancel", role: .cancel) {
                    tempAPIKey = ""
                }
                
                Button("Save") {
                    apiKey = tempAPIKey
                    DeepgramService.shared.setAPIKey(tempAPIKey)
                    HapticManager.shared.setLogged()
                    tempAPIKey = ""
                }
            } message: {
                Text("Enter your Deepgram API key for voice transcription")
            }
        }
    }
    
    // MARK: - Row Builders
    
    private func unitRow(unit: String, display: String) -> some View {
        Button {
            weightUnit = unit
            HapticManager.shared.selectionTap()
        } label: {
            HStack {
                Text(display)
                    .foregroundStyle(.white)
                Spacer()
                if weightUnit == unit {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private func triggerRow(trigger: String, display: String) -> some View {
        Button {
            voiceTrigger = trigger
            HapticManager.shared.selectionTap()
        } label: {
            HStack {
                Text(display)
                    .foregroundStyle(.white)
                Spacer()
                if voiceTrigger == trigger {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        HapticManager.shared.alert()
        dismiss()
    }
}

#Preview {
    SettingsView()
}
