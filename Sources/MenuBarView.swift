import SwiftUI
import Charts

struct MenuBarView: View {
    @ObservedObject var monitor: TelemetryMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(monitor.state.lowercased() == "connected" ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text("Starlink \(monitor.state)")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 5)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Downlink")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", (monitor.downlinkThroughputHistory.last ?? 0) / 1_000_000)) Mbps")
                        .font(.title3)
                        .bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Ping")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.0f", monitor.pingLatencyHistory.last ?? 0)) ms")
                        .font(.title3)
                        .bold()
                }
            }
            
            if !monitor.pingLatencyHistory.isEmpty {
                Chart {
                    ForEach(Array(monitor.pingLatencyHistory.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Ping", value)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                }
                .frame(height: 60)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
            
            Divider()
            
            HStack {
                Button(action: {
                    Task {
                        do {
                            let service = try StarlinkService(host: monitor.ipAddress)
                            _ = try await service.startSpeedtest()
                        } catch {}
                    }
                }) {
                    Text("Run Speedtest")
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(width: 250)
    }
}
