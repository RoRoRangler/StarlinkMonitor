import SwiftUI

struct RouterConfigView: View {
    @ObservedObject var monitor: TelemetryMonitor
    
    @State private var showingEditSheet = false
    @State private var newSSID = ""
    @State private var newPassword = ""
    
    var body: some View {
        VStack {
            Text("Router Configuration")
                .font(.largeTitle)
                .padding()
            
            if let config = monitor.routerWifiConfig {
                List {
                    Section(header: Text("Networks")) {
                        if config.networks.isEmpty {
                            Text("No networks found.")
                        } else {
                            ForEach(config.networks, id: \.ipv4) { network in
                                ForEach(network.basicServiceSets, id: \.bssid) { bss in
                                    VStack(alignment: .leading) {
                                        Text(bss.ssid.isEmpty ? "Hidden Network" : bss.ssid)
                                            .font(.headline)
                                        Text("Band: \(String(describing: bss.band))")
                                            .font(.subheadline)
                                        Text("BSSID: \(bss.bssid)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Settings")) {
                        Text("Country Code: \(config.countryCode.isEmpty ? "Unknown" : config.countryCode)")
                    }
                }
            } else {
                Text("Loading Router Configuration...")
                    .foregroundColor(.gray)
                    .padding()
            }
            
            Spacer()
        }
    }
}
