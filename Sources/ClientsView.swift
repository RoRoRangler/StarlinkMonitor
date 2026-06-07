import SwiftUI

struct ClientsView: View {
    @ObservedObject var monitor: TelemetryMonitor
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Connected Devices (\(monitor.clients.count))")
                .font(.largeTitle)
                .bold()
                .padding()
            
            List(monitor.clients, id: \.macAddress) { client in
                HStack {
                    VStack(alignment: .leading) {
                        Text(client.name.isEmpty ? (client.givenName.isEmpty ? "Unknown Device" : client.givenName) : client.name)
                            .font(.headline)
                        Text(client.macAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(client.ipAddress)
                            .font(.subheadline)
                        Text(String(format: "Signal: %.1f dBm", client.signalStrength))
                            .font(.caption)
                            .foregroundColor(client.signalStrength > -60 ? .green : .orange)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(PlainListStyle())
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}
