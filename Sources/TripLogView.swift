import SwiftUI
import MapKit
import SwiftData

struct TripLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TelemetrySnapshot.timestamp, order: .reverse) private var snapshots: [TelemetrySnapshot]
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedSnapshot: TelemetrySnapshot?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("RV Mode Trip Log")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Historical connection map using GPS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: {
                    // Zoom to fit all points
                    if !snapshots.isEmpty {
                        position = .automatic
                    }
                }) {
                    Image(systemName: "map")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(.regularMaterial)
            
            Map(position: $position) {
                // Plot all snapshots with GPS coordinates
                ForEach(snapshots) { snap in
                    if let lat = snap.latitude, let lon = snap.longitude {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Circle()
                                .fill(colorForPing(snap.pingLatencyMs))
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                .shadow(radius: 2)
                                .onTapGesture {
                                    selectedSnapshot = snap
                                }
                        }
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .sheet(item: Binding<TelemetrySnapshot?>(
                get: { selectedSnapshot },
                set: { selectedSnapshot = $0 }
            )) { snap in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Telemetry Detail")
                        .font(.headline)
                    Text("Time: \(snap.timestamp.formatted())")
                    Text("Ping: \(String(format: "%.1f", snap.pingLatencyMs)) ms")
                    Text("Downlink: \(String(format: "%.2f", snap.downlinkThroughputBps / 1_000_000)) Mbps")
                    Text("Uplink: \(String(format: "%.2f", snap.uplinkThroughputBps / 1_000_000)) Mbps")
                    
                    Button("Close") {
                        selectedSnapshot = nil
                    }
                    .padding(.top)
                }
                .padding()
                .presentationDetents([.fraction(0.3)])
            }
        }
    }
    
    private func colorForPing(_ ping: Float) -> Color {
        if ping <= 0 { return .gray }
        if ping < 40 { return .green }
        if ping < 80 { return .yellow }
        if ping < 150 { return .orange }
        return .red
    }
}
