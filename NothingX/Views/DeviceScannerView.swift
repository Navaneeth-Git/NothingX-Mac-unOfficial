import SwiftUI

struct DeviceScannerView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Connect to Device")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button {
                    viewModel.stopScanning()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Bluetooth state warning
            if viewModel.bluetoothState != .poweredOn {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Bluetooth is \(bluetoothStateDescription). Scanning may not work.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Device list
            List {
                if viewModel.discoveredDevices.isEmpty {
                    if viewModel.bluetoothState == .poweredOn {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            
                            Text("Scanning for devices...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Please enable Bluetooth to scan for devices")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(viewModel.discoveredDevices) { device in
                        DeviceRow(device: device)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                connectToDevice(device)
                            }
                    }
                }
            }
            .listStyle(.plain)
            
            // Footer
            HStack {
                Button("Cancel") {
                    viewModel.stopScanning()
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: refreshDevices) {
                    HStack {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Refresh")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.bluetoothState != .poweredOn || isRefreshing)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .onAppear {
            if viewModel.bluetoothState == .poweredOn {
                viewModel.startScanning()
            }
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
    
    private var bluetoothStateDescription: String {
        switch viewModel.bluetoothState {
        case .poweredOff:
            return "turned off"
        case .unauthorized:
            return "not authorized"
        case .unsupported:
            return "not supported"
        case .resetting:
            return "resetting"
        case .unknown:
            return "in an unknown state"
        default:
            return "not ready"
        }
    }
    
    private func connectToDevice(_ device: BluetoothDevice) {
        viewModel.connect(to: device)
        viewModel.stopScanning()
        dismiss()
    }
    
    private func refreshDevices() {
        isRefreshing = true
        viewModel.stopScanning()
        
        // Add a small delay to visually indicate refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.startScanning()
            isRefreshing = false
        }
    }
}

// Device row view
struct DeviceRow: View {
    let device: BluetoothDevice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                
                Text("Signal: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(device.type.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DeviceScannerView()
        .environmentObject(EarbudViewModel(
            bluetoothManager: BluetoothManager(),
            earbudManager: EarbudManager(bluetoothManager: BluetoothManager())
        ))
} 