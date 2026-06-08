import SwiftUI
import Combine

@MainActor
class TelemetryMonitor: ObservableObject {
    @Published var ipAddress: String = "192.168.100.1" {
        didSet {
            UserDefaults.standard.set(ipAddress, forKey: "starlinkIP")
            updateService()
            restartPolling()
        }
    }
    
    // Dish Status
    @Published var hardwareVersion: String = "Loading..."
    @Published var softwareVersion: String = "Loading..."
    @Published var state: String = "Connecting..."
    @Published var isPolling: Bool = false
    
    // Clients
    @Published var clients: [SpaceX_API_Device_WifiClient] = []
    
    // History
    @Published var pingLatencyHistory: [Float] = []
    @Published var dropRateHistory: [Float] = []
    @Published var downlinkThroughputHistory: [Float] = []
    @Published var uplinkThroughputHistory: [Float] = []
    
    // Tracking
    @Published var boresightAzimuthDeg: Double = 0
    @Published var boresightElevationDeg: Double = 0
    
    // Sky View
    @Published var obstructionMap: SpaceX_API_Device_DishGetObstructionMapResponse? = nil
    
    private var pollingTask: Task<Void, Never>?
    private var loopCounter: Int = 0
    private var activeService: StarlinkService?
    
    init() {
        if let savedIP = UserDefaults.standard.string(forKey: "starlinkIP") {
            self.ipAddress = savedIP
        }
        updateService()
    }
    
    private func updateService() {
        activeService?.close()
        do {
            activeService = try StarlinkService(host: ipAddress)
        } catch {
            print("Failed to initialize StarlinkService: \(error)")
        }
    }
    
    func startPolling() {
        guard pollingTask == nil else { return }
        isPolling = true
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchTelemetry()
                
                // Fetch obstruction map every 15 iterations (approx 30 seconds)
                if loopCounter % 15 == 0 {
                    await fetchObstructionMap()
                }
                loopCounter += 1
                
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }
    
    private func restartPolling() {
        stopPolling()
        startPolling()
    }
    
    private func fetchObstructionMap() async {
        guard let service = activeService else { return }
        do {
            let map = try await service.getObstructionMap()
            await MainActor.run {
                self.obstructionMap = map
            }
        } catch {
            print("Failed to fetch obstruction map: \(error)")
        }
    }
    
    private func fetchTelemetry() async {
        guard let service = activeService else {
            self.state = "Error: Service not initialized"
            return
        }
        do {
            async let statusResponse = service.getStatus()
            async let clientsResponse = service.getWifiClients()
            async let historyResponse = service.getHistory()
            
            let (status, clientsRes, history) = try await (statusResponse, clientsResponse, historyResponse)
            
            self.hardwareVersion = status.dishGetStatus.deviceInfo.hardwareVersion
            self.softwareVersion = status.dishGetStatus.deviceInfo.softwareVersion
            self.state = String(describing: status.dishGetStatus.deviceState)
            
            self.clients = clientsRes.clients
            
            // Only take the last 60 data points for UI responsiveness
            self.pingLatencyHistory = Array(history.popPingLatencyMs.suffix(60))
            self.dropRateHistory = Array(history.popPingDropRate.suffix(60))
            self.downlinkThroughputHistory = Array(history.downlinkThroughputBps.suffix(60))
            self.uplinkThroughputHistory = Array(history.uplinkThroughputBps.suffix(60))
            
            self.boresightAzimuthDeg = Double(status.dishGetStatus.boresightAzimuthDeg)
            self.boresightElevationDeg = Double(status.dishGetStatus.boresightElevationDeg)
            
        } catch {
            self.state = "Error: \(error.localizedDescription)"
        }
    }
}
