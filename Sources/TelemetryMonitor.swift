import SwiftUI
import Combine
import SwiftData

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
    
    // Sky View & GPS
    @Published var obstructionMap: SpaceX_API_Device_DishGetObstructionMapResponse? = nil
    @Published var tracker = SatelliteTracker()
    
    // Router Config
    @Published var routerWifiConfig: SpaceX_API_Device_WifiConfig? = nil
    
    // SwiftData
    var modelContainer: ModelContainer?
    private var lastSnapshotTime: Date = .now
    private var currentOutage: OutageEvent?
    
    private var pollingTask: Task<Void, Never>?
    private var loopCounter: Int = 0
    private var activeService: StarlinkService?
    private var routerService: StarlinkService?
    
    init() {
        if let savedIP = UserDefaults.standard.string(forKey: "starlinkIP") {
            self.ipAddress = savedIP
        }
        updateService()
    }
    
    private func updateService() {
        activeService?.close()
        routerService?.close()
        do {
            activeService = try StarlinkService(host: ipAddress)
            routerService = try StarlinkService(host: "192.168.1.1") // Default Router IP
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
                
                // Fetch obstruction map and router config every 15 iterations (approx 30 seconds)
                if loopCounter % 15 == 0 {
                    await fetchObstructionMap()
                    await fetchRouterConfig()
                }
                loopCounter += 1
                
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
        tracker.startTracking()
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
        tracker.stopTracking()
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
    
    private func fetchRouterConfig() async {
        guard let router = routerService else { return }
        do {
            let configRes = try await router.getWifiConfig()
            await MainActor.run {
                self.routerWifiConfig = configRes.wifiConfig
            }
        } catch {
            print("Failed to fetch router config: \(error)")
        }
    }
    
    func updateRouterWifiConfig(_ config: SpaceX_API_Device_WifiConfig) async throws {
        guard let router = routerService else { throw NSError(domain: "RouterConfig", code: 1, userInfo: [NSLocalizedDescriptionKey: "Router service not initialized"]) }
        let _ = try await router.setWifiConfig(config: config)
        await fetchRouterConfig()
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
            let isConnected = status.dishGetStatus.outage.cause == .unknown
            self.state = isConnected ? "Connected" : String(describing: status.dishGetStatus.outage.cause).capitalized
            
            self.clients = clientsRes.clients
            
            // Only take the last 60 data points for UI responsiveness
            self.pingLatencyHistory = Array(history.popPingLatencyMs.suffix(60))
            self.dropRateHistory = Array(history.popPingDropRate.suffix(60))
            self.downlinkThroughputHistory = Array(history.downlinkThroughputBps.suffix(60))
            self.uplinkThroughputHistory = Array(history.uplinkThroughputBps.suffix(60))
            
            self.boresightAzimuthDeg = Double(status.dishGetStatus.boresightAzimuthDeg)
            self.boresightElevationDeg = Double(status.dishGetStatus.boresightElevationDeg)
            
            await handleTelemetryData(status: status, history: history)
            
        } catch {
            self.state = "Error: \(error.localizedDescription)"
            await handleOutage(cause: error.localizedDescription)
        }
    }
    
    private func handleTelemetryData(status: SpaceX_API_Device_Response, history: SpaceX_API_Device_DishGetHistoryResponse) async {
        let isConnected = status.dishGetStatus.outage.cause == .unknown
        
        if isConnected {
            if let outage = currentOutage {
                outage.endTimestamp = .now
                if let context = modelContainer?.mainContext {
                    try? context.save()
                }
                NotificationManager.shared.sendRestoredNotification(durationSeconds: outage.durationSeconds)
                currentOutage = nil
            }
            
            // Save snapshot every 5 minutes
            if Date.now.timeIntervalSince(lastSnapshotTime) >= 300 {
                let snapshot = TelemetrySnapshot(
                    pingLatencyMs: history.popPingLatencyMs.last ?? 0,
                    downlinkThroughputBps: history.downlinkThroughputBps.last ?? 0,
                    uplinkThroughputBps: history.uplinkThroughputBps.last ?? 0,
                    fractionObstructed: status.dishGetStatus.obstructionStats.fractionObstructed,
                    latitude: tracker.userLocation?.latitude,
                    longitude: tracker.userLocation?.longitude
                )
                if let context = modelContainer?.mainContext {
                    context.insert(snapshot)
                    try? context.save()
                }
                lastSnapshotTime = .now
            }
            
            // Check for severe ping spikes
            if let ping = history.popPingLatencyMs.last, ping > 200 {
                await handleOutage(cause: "High Ping: \(String(format: "%.0f", ping))ms")
            }
        } else {
            await handleOutage(cause: "State: \(String(describing: status.dishGetStatus.outage.cause))")
        }
    }
    
    private func handleOutage(cause: String) async {
        if currentOutage == nil {
            let outage = OutageEvent(cause: cause)
            currentOutage = outage
            if let context = modelContainer?.mainContext {
                context.insert(outage)
                try? context.save()
            }
            NotificationManager.shared.sendOutageNotification(cause: cause)
        }
    }
}
