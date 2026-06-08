import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: TelemetryMonitor
    @State private var selection: SidebarItem = .overview
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case skyView = "Sky View"
        case clients = "Connected Devices"
        case charts = "Telemetry Charts"
        case controls = "Hardware Controls"
        case router = "Router Settings"
        case tripLog = "RV Trip Log"
        case wifiAnalyzer = "WiFi Analyzer"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: icon(for: item))
                }
            }
            .navigationTitle("Starlink")
            .listStyle(SidebarListStyle())
            
            // Network Configuration at the bottom of the sidebar
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                Text("IP Address:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("192.168.100.1", text: $monitor.ipAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack {
                    Circle()
                        .fill(monitor.isPolling ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(monitor.isPolling ? "Live" : "Offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
        } detail: {
            switch selection {
            case .overview:
                OverviewView(monitor: monitor)
            case .skyView:
                SkyView(monitor: monitor)
            case .clients:
                ClientsView(monitor: monitor)
            case .charts:
                ChartsView(monitor: monitor)
            case .controls:
                ControlsView(monitor: monitor)
            case .router:
                RouterConfigView(monitor: monitor)
            case .tripLog:
                TripLogView()
            case .wifiAnalyzer:
                WiFiAnalyzerView()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            monitor.startPolling()
        }
    }
    
    private func icon(for item: SidebarItem) -> String {
        switch item {
        case .overview: return "antenna.radiowaves.left.and.right"
        case .skyView: return "globe.americas"
        case .clients: return "network"
        case .charts: return "chart.xyaxis.line"
        case .controls: return "slider.horizontal.3"
        case .router: return "network.badge.shield.half.filled"
        case .tripLog: return "map"
        case .wifiAnalyzer: return "wifi.exclamationmark"
        }
    }
}

struct OverviewView: View {
    @ObservedObject var monitor: TelemetryMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("System Overview")
                    .font(.largeTitle)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 20) {
                    OverviewCard(title: "State", value: monitor.state, icon: "info.circle")
                    OverviewCard(title: "Connected Clients", value: "\(monitor.clients.count)", icon: "person.2")
                }
                
                HStack(spacing: 20) {
                    OverviewCard(title: "Hardware Version", value: monitor.hardwareVersion, icon: "cpu")
                    OverviewCard(title: "Software Version", value: monitor.softwareVersion, icon: "applescript")
                }
                
                Spacer()
            }
            .padding(40)
        }
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}
