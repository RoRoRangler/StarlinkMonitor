import SwiftUI

struct ControlsView: View {
    @ObservedObject var monitor: TelemetryMonitor
    
    @State private var isRunningSpeedtest: Bool = false
    @State private var speedtestResult: String = ""
    @State private var actionMessage: String = ""
    @State private var snowMeltMode: SpaceX_API_Device_DishConfig.SnowMeltMode = .auto
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Hardware Controls")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 10)
            
            if !actionMessage.isEmpty {
                Text(actionMessage)
                    .foregroundColor(.blue)
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Physical Adjustments")
                    .font(.title2)
                    .bold()
                
                HStack(spacing: 20) {
                    Button(action: { performAction { try await $0.stow() } }) {
                        Label("Stow Dish", systemImage: "arrow.down.to.line.compact")
                            .frame(width: 140, height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: { performAction { try await $0.unstow() } }) {
                        Label("Unstow Dish", systemImage: "arrow.up.to.line.compact")
                            .frame(width: 140, height: 40)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Thermal Control")
                    .font(.title2)
                    .bold()
                
                HStack {
                    Text("Snow Melt Mode:")
                    Picker("", selection: $snowMeltMode) {
                        Text("Auto").tag(SpaceX_API_Device_DishConfig.SnowMeltMode.auto)
                        Text("Always On").tag(SpaceX_API_Device_DishConfig.SnowMeltMode.alwaysOn)
                        Text("Always Off").tag(SpaceX_API_Device_DishConfig.SnowMeltMode.alwaysOff)
                    }
                    .frame(width: 150)
                    .onChange(of: snowMeltMode) { newValue in
                        performAction { try await $0.setSnowMeltMode(newValue) }
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Speed Diagnostics")
                    .font(.title2)
                    .bold()
                
                HStack(spacing: 20) {
                    Button(action: runSpeedtest) {
                        if isRunningSpeedtest {
                            ProgressView().scaleEffect(0.5)
                                .frame(width: 140, height: 40)
                        } else {
                            Label("Run Speedtest", systemImage: "network")
                                .frame(width: 140, height: 40)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isRunningSpeedtest)
                    
                    Text(speedtestResult)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func performAction(_ action: @escaping (StarlinkService) async throws -> Any) {
        actionMessage = "Sending command..."
        Task {
            do {
                let service = try StarlinkService(host: monitor.ipAddress)
                let _ = try await action(service)
                await MainActor.run { actionMessage = "Command succeeded!" }
                // Clear message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { actionMessage = "" }
            } catch {
                await MainActor.run { actionMessage = "Command failed: \(error.localizedDescription)" }
            }
        }
    }
    
    private func runSpeedtest() {
        isRunningSpeedtest = true
        speedtestResult = "Starting test..."
        
        Task {
            do {
                let service = try StarlinkService(host: monitor.ipAddress)
                _ = try await service.startSpeedtest()
                
                var completed = false
                var attempts = 0
                while !completed && attempts < 15 {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    attempts += 1
                    
                    let _ = try await service.getSpeedtestStatus()
                    
                    await MainActor.run {
                        self.speedtestResult = "Test in progress... (Step \(attempts)/15)"
                    }
                }
                
                await MainActor.run {
                    self.speedtestResult = "Completed."
                    self.isRunningSpeedtest = false
                }
            } catch {
                await MainActor.run {
                    self.speedtestResult = "Error: \(error.localizedDescription)"
                    self.isRunningSpeedtest = false
                }
            }
        }
    }
}
