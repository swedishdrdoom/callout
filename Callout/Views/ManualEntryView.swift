import SwiftUI

// MARK: - Manual Entry Sheet

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: RestLoopViewModel
    
    @State private var weight: String = ""
    @State private var reps: String = ""
    @FocusState private var weightFocused: Bool
    
    private var weightUnit: String {
        UserDefaults.standard.string(forKey: UserDefaultsKey.weightUnit) ?? "kg"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (\(weightUnit))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .focused($weightFocused)
                    }
                    
                    // Reps input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("0", text: $reps)
                            .keyboardType(.numberPad)
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                    
                    // Log button
                    Button {
                        if let w = Double(weight), let r = Int(reps), r > 0 {
                            viewModel.logManualSet(weight: w, reps: r)
                            dismiss()
                        }
                    } label: {
                        Text("LOG SET")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(weight.isEmpty || reps.isEmpty)
                    .opacity(weight.isEmpty || reps.isEmpty ? 0.5 : 1)
                }
                .padding()
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                weightFocused = true
            }
        }
    }
}
