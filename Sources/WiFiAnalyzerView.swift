import SwiftUI
import Charts

struct WiFiAnalyzerView: View {
    @StateObject private var wifiManager = WiFiManager()
    @State private var selectedBand: Int = 0 // 0: 2.4GHz, 1: 5GHz, 2: 6GHz

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("WiFi Analyzer")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Local Airspace Scan (Independent of Starlink)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if wifiManager.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 10)
                }
                
                Button(action: {
                    wifiManager.scanAirspace()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)

            // Current Connection Stats
            HStack(spacing: 20) {
                MetricCard(title: "SSID", value: wifiManager.ssid, unit: "", icon: "wifi", color: .blue)
                MetricCard(title: "Signal (RSSI)", value: "\(wifiManager.rssi)", unit: "dBm", icon: "antenna.radiowaves.left.and.right", color: wifiManager.rssi > -65 ? .green : .orange)
                MetricCard(title: "Noise", value: "\(wifiManager.noise)", unit: "dBm", icon: "waveform.path.ecg", color: .red)
                MetricCard(title: "Channel", value: "\(wifiManager.channel)", unit: wifiManager.phyMode, icon: "number.circle.fill", color: .purple)
            }
            .padding(.horizontal)

            // Band Selector
            Picker("Frequency Band", selection: $selectedBand) {
                Text("2.4 GHz").tag(0)
                Text("5 GHz").tag(1)
                Text("6 GHz").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Chart
            Chart {
                ForEach(currentNetworks(), id: \.self) { network in
                    BarMark(
                        x: .value("Channel", "\(network.channel)"),
                        y: .value("Signal Strength", network.rssi + 100) // Offset to make bars positive for visualization
                    )
                    .foregroundStyle(by: .value("SSID", network.ssid))
                    .annotation(position: .top) {
                        Text(network.ssid)
                            .font(.system(size: 8))
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let val = value.as(Int.self) {
                        AxisValueLabel("\(val - 100) dBm")
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .frame(maxHeight: .infinity)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            wifiManager.startMonitoring()
        }
        .onDisappear {
            wifiManager.stopMonitoring()
        }
    }

    private func currentNetworks() -> [WiFiNetwork] {
        switch selectedBand {
        case 0: return wifiManager.networks24
        case 1: return wifiManager.networks5
        case 2: return wifiManager.networks6
        default: return []
        }
    }
}

// Reuse MetricCard
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
