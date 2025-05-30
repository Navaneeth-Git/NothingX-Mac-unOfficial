import SwiftUI

struct ANCView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @State private var isRunningFitTest = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ANC modes
                ancModesCard
                
                // Personalized ANC (if supported)
                if viewModel.connectedDevice?.type.supportsPersonalizedANC == true {
                    personalizedANCCard
                }
                
                // Ear tip fit test (if supported)
                if viewModel.connectedDevice?.type.supportsPersonalizedANC == true {
                    earTipFitTestCard
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $isRunningFitTest) {
            FitTestView()
                .environmentObject(viewModel)
        }
    }
    
    // MARK: - ANC Modes Card
    private var ancModesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Noise Control", systemImage: "ear")
                .font(.headline)
            
            Divider()
            
            if viewModel.connectedDevice?.type.supportsANC == true {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Select your preferred noise control mode.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // ANC Controls
                    VStack(spacing: 16) {
                        ANCModeButton(
                            title: "Active Noise Cancellation",
                            description: "Blocks outside noise",
                            isSelected: viewModel.ancMode.isActive,
                            action: { viewModel.setANCMode(.high) }
                        )
                        
                        if viewModel.ancMode.isActive {
                            // ANC level slider
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ANC Level")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("Low")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Slider(
                                        value: Binding<Double>(
                                            get: {
                                                switch viewModel.ancMode {
                                                case .high: return 3
                                                case .medium: return 2
                                                case .light: return 1
                                                case .off: return 0
                                                case .adaptive: return 4
                                                case .transparency: return 5
                                                default: return 0
                                                }
                                            },
                                            set: { value in
                                                switch Int(value.rounded()) {
                                                case 0: viewModel.setANCMode(.off)
                                                case 1: viewModel.setANCMode(.light)
                                                case 2: viewModel.setANCMode(.medium)
                                                case 3: viewModel.setANCMode(.high)
                                                case 4: viewModel.setANCMode(.adaptive)
                                                case 5: viewModel.setANCMode(.transparency)
                                                default: viewModel.setANCMode(.off)
                                                }
                                            }
                                        ),
                                        in: 0...5,
                                        step: 1
                                    )
                                    
                                    Text("High")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Level indicator
                                HStack {
                                    Text("Current: \(viewModel.ancMode.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .padding(.leading, 24)
                        }
                        
                        ANCModeButton(
                            title: "Transparency",
                            description: "Lets in ambient sound",
                            isSelected: viewModel.ancMode == .transparency,
                            action: { viewModel.setANCMode(.transparency) }
                        )
                        
                        ANCModeButton(
                            title: "Off",
                            description: "No noise control",
                            isSelected: viewModel.ancMode == .off,
                            action: { viewModel.setANCMode(.off) }
                        )
                    }
                }
            } else {
                Text("This device does not support Active Noise Cancellation.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Personalized ANC Card
    private var personalizedANCCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Personalized ANC", systemImage: "person.crop.circle")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Personalized ANC adapts to your ear shape and environment for optimal noise cancellation.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Toggle("Enable Personalized ANC", isOn: Binding(
                    get: { viewModel.isPersonalizedANCEnabled },
                    set: { viewModel.togglePersonalizedANC($0) }
                ))
                .toggleStyle(.switch)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Ear Tip Fit Test Card
    private var earTipFitTestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Ear Tip Fit Test", systemImage: "ear.trianglebadge.exclamationmark")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Test how well your ear tips fit and seal for optimal sound quality and ANC performance.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if viewModel.fitTestStatus == .completed {
                    HStack(spacing: 20) {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: fitTestResultIcon)
                                .font(.system(size: 32))
                                .foregroundColor(fitTestResultColor)
                            
                            Text("Fit Test Result")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(fitTestResultText)
                                .font(.subheadline)
                                .foregroundColor(fitTestResultColor)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(fitTestResultDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Run Test Again") {
                                isRunningFitTest = true
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                } else {
                    Button("Run Ear Tip Fit Test") {
                        isRunningFitTest = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties for Fit Test
    
    private var fitTestResultText: String {
        switch viewModel.fitTestResult {
        case .good:
            return "Good fit detected"
        case .adjustNeeded:
            return "Adjust your earbuds"
        case .poor:
            return "Poor fit detected"
        case .unsupported:
            return "Unsupported"
        }
    }
    
    private var fitTestResultDescription: String {
        switch viewModel.fitTestResult {
        case .good:
            return "Your earbuds have a good seal"
        case .adjustNeeded:
            return "Try adjusting your earbuds for a better seal"
        case .poor:
            return "The seal is poor. Try a different ear tip size"
        case .unsupported:
            return "Fit test is not supported on this device."
        }
    }
    
    private var fitTestResultIcon: String {
        switch viewModel.fitTestResult {
        case .good:
            return "checkmark.circle.fill"
        case .adjustNeeded:
            return "exclamationmark.triangle.fill"
        case .poor:
            return "xmark.circle.fill"
        case .unsupported:
            return "questionmark.circle.fill"
        }
    }
    
    private var fitTestResultColor: Color {
        switch viewModel.fitTestResult {
        case .good:
            return .green
        case .adjustNeeded:
            return .yellow
        case .poor:
            return .red
        case .unsupported:
            return .gray
        }
    }
}

// MARK: - ANC Mode Button
struct ANCModeButton: View {
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .bold()
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(.textBackgroundColor).opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fit Test View
struct FitTestView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var progress: Double = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Ear Tip Fit Test")
                .font(.title2)
                .bold()
                .padding(.top)
            
            // Progress indicator
            if viewModel.fitTestStatus == .inProgress {
                VStack(spacing: 16) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    
                    Text("Testing... \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "ear")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                        .padding()
                    
                    Text("Please keep your earbuds in your ears and stay in a quiet environment.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .onAppear {
                    // Start the test
                    viewModel.runEarTipFitTest()
                    
                    // Simulate progress for UI
                    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                        if progress < 1.0 {
                            progress += 0.01
                        } else {
                            timer?.invalidate()
                            // Wait a bit after reaching 100% to show the result
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                dismiss()
                            }
                        }
                    }
                }
                .onDisappear {
                    timer?.invalidate()
                }
            }
        }
        .frame(width: 400, height: 400)
        .padding()
    }
}

#Preview {
    ANCView()
        .environmentObject(EarbudViewModel(
            bluetoothManager: BluetoothManager(),
            earbudManager: EarbudManager(bluetoothManager: BluetoothManager())
        ))
} 