import SwiftUI
import Charts

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let index: Int
    let value: Float
}

struct ChartsView: View {
    @ObservedObject var monitor: TelemetryMonitor
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Network Telemetry")
                    .font(.largeTitle)
                    .bold()
                
                VStack(alignment: .leading) {
                    Text("Ping Latency (ms)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(Array(monitor.pingLatencyHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Latency", value)
                            )
                            .foregroundStyle(Color.blue.gradient)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis(.hidden)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                
                VStack(alignment: .leading) {
                    Text("Ping Drop Rate")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Chart {
                        ForEach(Array(monitor.dropRateHistory.enumerated()), id: \.offset) { index, value in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Drop Rate", value)
                            )
                            .foregroundStyle(Color.red.gradient)
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis(.hidden)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Downlink Throughput")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Chart {
                            ForEach(Array(monitor.downlinkThroughputHistory.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Time", index),
                                    y: .value("bps", value / 1_000_000) // Convert to Mbps
                                )
                                .foregroundStyle(Color.green.opacity(0.3).gradient)
                                
                                LineMark(
                                    x: .value("Time", index),
                                    y: .value("bps", value / 1_000_000)
                                )
                                .foregroundStyle(Color.green)
                            }
                        }
                        .frame(height: 150)
                        .chartXAxis(.hidden)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading) {
                        Text("Uplink Throughput")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Chart {
                            ForEach(Array(monitor.uplinkThroughputHistory.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Time", index),
                                    y: .value("bps", value / 1_000_000) // Convert to Mbps
                                )
                                .foregroundStyle(Color.orange.opacity(0.3).gradient)
                                
                                LineMark(
                                    x: .value("Time", index),
                                    y: .value("bps", value / 1_000_000)
                                )
                                .foregroundStyle(Color.orange)
                            }
                        }
                        .frame(height: 150)
                        .chartXAxis(.hidden)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}
