import SwiftUI

struct GesturesView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Gesture explanation
                gestureExplanationCard
                
                // Left earbud gestures
                earbudGestureCard(
                    title: "Left Earbud Gestures",
                    gestures: viewModel.leftEarbudGestures,
                    side: .left
                )
                
                // Right earbud gestures
                earbudGestureCard(
                    title: "Right Earbud Gestures",
                    gestures: viewModel.rightEarbudGestures,
                    side: .right
                )
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Gesture Explanation Card
    private var gestureExplanationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Touch Controls", systemImage: "hand.tap")
                .font(.headline)
            
            Divider()
            
            Text("Customize touch controls for your earbuds. Select the actions you want to perform with different gestures.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Gesture illustrations
            HStack(spacing: 24) {
                GestureExplanationView(
                    title: "Single Tap",
                    description: "Tap once",
                    iconName: "1.circle"
                )
                
                GestureExplanationView(
                    title: "Double Tap",
                    description: "Tap twice quickly",
                    iconName: "2.circle"
                )
                
                GestureExplanationView(
                    title: "Triple Tap",
                    description: "Tap three times quickly",
                    iconName: "3.circle"
                )
                
                GestureExplanationView(
                    title: "Hold",
                    description: "Touch and hold",
                    iconName: "hand.tap.fill"
                )
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Earbud Gesture Card
    private func earbudGestureCard(
        title: String,
        gestures: [GestureType: GestureAction],
        side: EarbudSide
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: side == .left ? "ear.and.waveform.left" : "ear.and.waveform.right")
                .font(.headline)
            
            Divider()
            
            VStack(spacing: 16) {
                ForEach(GestureType.allCases) { gestureType in
                    HStack {
                        Text(gestureType.rawValue)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { gestures[gestureType] ?? .none },
                            set: { viewModel.setGestureAction(for: side, gestureType: gestureType, action: $0) }
                        )) {
                            ForEach(GestureAction.allCases) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    
                    if gestureType != GestureType.allCases.last {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Gesture Explanation View
struct GestureExplanationView: View {
    let title: String
    let description: String
    let iconName: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.caption)
                .bold()
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    GesturesView()
        .environmentObject(EarbudViewModel(
            bluetoothManager: BluetoothManager(),
            earbudManager: EarbudManager(bluetoothManager: BluetoothManager())
        ))
} 