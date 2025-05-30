import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    
    // Frequency bands for the equalizer
    private let frequencyBands = ["60Hz", "150Hz", "400Hz", "1kHz", "2.4kHz", "6kHz"]
    
    // Possible EQ values (-6 to +6 dB)
    private let eqValues: [Float] = [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // EQ presets card
                presetCard
                
                // Custom EQ card
                customEQCard
                
                // Advanced EQ toggle (for supported devices)
                if viewModel.connectedDevice?.type.supportsAdvancedEQ == true {
                    advancedEQCard
                }
                
                // Bass enhancement card
                bassEnhancementCard
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - EQ Presets Card
    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Equalizer Presets", systemImage: "music.note.list")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Select a preset or customize your own equalizer settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    ForEach(EqualizerPreset.allCases) { preset in
                        PresetButton(
                            title: preset.rawValue,
                            isSelected: viewModel.equalizerPreset == preset,
                            action: {
                                viewModel.setEqualizerPreset(preset)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Custom EQ Card
    private var customEQCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Custom Equalizer", systemImage: "slider.horizontal.3")
                .font(.headline)
            
            Divider()
            
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(0..<frequencyBands.count, id: \.self) { index in
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: {
                                    viewModel.customEqualizerSettings[index]
                                },
                                set: { newValue in
                                    var updatedValues = viewModel.customEqualizerSettings
                                    updatedValues[index] = newValue
                                    viewModel.setCustomEqualizerValues(updatedValues)
                                }
                            ),
                            in: -6...6,
                            step: 1
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 24)
                        
                        Text("\(Int(viewModel.customEqualizerSettings[index]))dB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(frequencyBands[index])
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 50)
                }
            }
            .padding(.vertical)
            
            Button("Reset to Flat") {
                viewModel.setEqualizerPreset(.balanced)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Advanced EQ Card
    private var advancedEQCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Advanced Settings", systemImage: "gearshape.2")
                .font(.headline)
            
            Divider()
            
            Toggle("Advanced EQ", isOn: Binding(
                get: { viewModel.isAdvancedEQEnabled },
                set: { viewModel.toggleAdvancedEQ($0) }
            ))
            .toggleStyle(.switch)
            
            if viewModel.isAdvancedEQEnabled {
                Text("Advanced EQ provides more precise audio tuning with higher quality processing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Bass Enhancement Card
    private var bassEnhancementCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Bass Enhancement", systemImage: "speaker.wave.3")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Adjust the bass level to enhance low frequencies.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: {
                                // Get average of first two bands (bass frequencies)
                                (viewModel.customEqualizerSettings[0] + viewModel.customEqualizerSettings[1]) / 2
                            },
                            set: { newValue in
                                var updatedValues = viewModel.customEqualizerSettings
                                updatedValues[0] = newValue
                                updatedValues[1] = newValue
                                viewModel.setCustomEqualizerValues(updatedValues)
                            }
                        ),
                        in: -6...6,
                        step: 1
                    )
                    
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EqualizerView()
        .environmentObject(EarbudViewModel(
            bluetoothManager: BluetoothManager(),
            earbudManager: EarbudManager(bluetoothManager: BluetoothManager())
        ))
} 