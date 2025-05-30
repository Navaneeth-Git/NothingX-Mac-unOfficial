import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    let device: BluetoothDevice
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Device info card
                deviceInfoCard
                
                // Battery levels
                batteryCard
                
                // Quick controls
                quickControlsCard
                
                // Find my earbuds card
                findMyEarbudsCard
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Device Info Card
    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Device Information", systemImage: "info.circle")
                .font(.headline)
            
            Divider()
            
            HStack(spacing: 20) {
                Image(systemName: "ear.and.waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.name)
                        .font(.title3)
                        .bold()
                    
                    Text("Firmware: \(viewModel.firmwareVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Type: \(device.type.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Battery Card
    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Battery Status", systemImage: "battery.100")
                .font(.headline)
            
            Divider()
            
            HStack(spacing: 20) {
                BatteryView(
                    title: "Left",
                    percentage: viewModel.batteryLevels.left,
                    iconName: "earbuds.case.fill"
                )
                
                Divider()
                    .frame(height: 40)
                
                BatteryView(
                    title: "Right",
                    percentage: viewModel.batteryLevels.right,
                    iconName: "earbuds.case.fill"
                )
                
                Divider()
                    .frame(height: 40)
                
                BatteryView(
                    title: "Case",
                    percentage: viewModel.batteryLevels.case,
                    iconName: "case.fill"
                )
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Controls Card
    private var quickControlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick Controls", systemImage: "slider.horizontal.3")
                .font(.headline)
            
            Divider()
            
            VStack(spacing: 16) {
                // ANC Quick Toggle
                if device.type.supportsANC {
                    HStack {
                        Text("Noise Control")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { viewModel.ancMode },
                            set: { viewModel.setANCMode($0) }
                        )) {
                            Text("Off").tag(ANCMode.off)
                            Text("Transparency").tag(ANCMode.transparency)
                            Text("ANC").tag(ANCMode.high)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }
                }
                
                // In-ear detection toggle
                Toggle("In-ear Detection", isOn: Binding(
                    get: { viewModel.isInEarDetectionEnabled },
                    set: { viewModel.toggleInEarDetection($0) }
                ))
                
                // Low latency mode toggle
                Toggle("Low Latency Mode", isOn: Binding(
                    get: { viewModel.isLowLatencyModeEnabled },
                    set: { viewModel.toggleLowLatencyMode($0) }
                ))
                
                // Personalized ANC toggle
                if device.type.supportsPersonalizedANC {
                    Toggle("Personalized ANC", isOn: Binding(
                        get: { viewModel.isPersonalizedANCEnabled },
                        set: { viewModel.togglePersonalizedANC($0) }
                    ))
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Find My Earbuds Card
    private var findMyEarbudsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Find My Earbuds", systemImage: "location")
                .font(.headline)
            
            Divider()
            
            HStack {
                Text("Play a sound from your earbuds to help locate them")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Play Sound") {
                    viewModel.findMyEarbuds()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Battery View
struct BatteryView: View {
    let title: String
    let percentage: Int
    let iconName: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color(.separatorColor), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(percentage) / 100)
                    .stroke(batteryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(batteryColor)
            }
            
            Text("\(percentage)%")
                .font(.headline)
                .foregroundColor(batteryColor)
        }
    }
    
    private var batteryColor: Color {
        if percentage >= 60 {
            return .green
        } else if percentage >= 30 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    DashboardView(device: BluetoothDevice(id: UUID(), name: "Nothing ear (2)", rssi: -60))
        .environmentObject(EarbudViewModel(
            bluetoothManager: BluetoothManager(),
            earbudManager: EarbudManager(bluetoothManager: BluetoothManager())
        ))
} 