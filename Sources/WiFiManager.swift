import Foundation
import CoreWLAN
import CoreLocation

struct WiFiNetwork: Identifiable, Hashable {
    let id = UUID()
    let ssid: String
    let bssid: String
    let rssi: Int
    let channel: Int
    
    var band: String {
        if channel <= 14 { return "2.4 GHz" }
        else if channel <= 165 { return "5 GHz" }
        else { return "6 GHz" }
    }
}

class WiFiManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var ssid: String = "Unknown"
    @Published var bssid: String = "Unknown"
    @Published var rssi: Int = 0
    @Published var noise: Int = 0
    @Published var channel: Int = 0
    @Published var phyMode: String = "Unknown"
    @Published var transmitRate: Double = 0.0
    
    @Published var networks24: [WiFiNetwork] = []
    @Published var networks5: [WiFiNetwork] = []
    @Published var networks6: [WiFiNetwork] = []
    @Published var isScanning: Bool = false
    
    private var timer: Timer?
    private var scanTimer: Timer?
    private var locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorized {
            scanAirspace()
        }
    }
    
    func startMonitoring() {
        updateStats()
        scanAirspace()
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.scanAirspace()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    private func updateStats() {
        guard let interface = CWWiFiClient.shared().interface() else { return }
        
        DispatchQueue.main.async {
            self.ssid = interface.ssid() ?? "Unknown"
            self.bssid = interface.bssid() ?? "Unknown"
            self.rssi = interface.rssiValue()
            self.noise = interface.noiseMeasurement()
            self.channel = interface.wlanChannel()?.channelNumber ?? 0
            self.transmitRate = interface.transmitRate()
            
            switch interface.activePHYMode() {
            case .mode11a: self.phyMode = "802.11a"
            case .mode11b: self.phyMode = "802.11b"
            case .mode11g: self.phyMode = "802.11g"
            case .mode11n: self.phyMode = "Wi-Fi 4 (802.11n)"
            case .mode11ac: self.phyMode = "Wi-Fi 5 (802.11ac)"
            case .mode11ax: self.phyMode = "Wi-Fi 6 (802.11ax)"
            default: self.phyMode = "Unknown"
            }
        }
    }
    
    func scanAirspace() {
        guard !isScanning else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let interface = CWWiFiClient.shared().interface() else {
                DispatchQueue.main.async { self.isScanning = false }
                return
            }
            
            do {
                let networks = try interface.scanForNetworks(withName: nil)
                var scanned: [WiFiNetwork] = []
                for net in networks {
                    let ssid = net.ssid ?? "Hidden Network"
                    let bssid = net.bssid ?? "Unknown"
                    let rssi = net.rssiValue
                    let channel = net.wlanChannel?.channelNumber ?? 0
                    scanned.append(WiFiNetwork(ssid: ssid, bssid: bssid, rssi: rssi, channel: channel))
                }
                
                scanned.sort { $0.rssi > $1.rssi }
                
                let nets24 = scanned.filter { $0.band == "2.4 GHz" }
                let nets5 = scanned.filter { $0.band == "5 GHz" }
                let nets6 = scanned.filter { $0.band == "6 GHz" }
                
                DispatchQueue.main.async {
                    self.networks24 = nets24
                    self.networks5 = nets5
                    self.networks6 = nets6
                    self.isScanning = false
                }
            } catch {
                print("Scan failed: \(error)")
                DispatchQueue.main.async { self.isScanning = false }
            }
        }
    }
}
