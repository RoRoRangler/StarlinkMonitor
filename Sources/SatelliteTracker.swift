import Foundation
import CoreLocation
import SwiftSGP4

struct SatellitePosition: Identifiable {
    let id: String
    let name: String
    let azimuth: Double
    let elevation: Double
    let distance: Double // in km
}

class SatelliteTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var visibleSatellites: [SatellitePosition] = []
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isTracking: Bool = false
    
    private var locationManager = CLLocationManager()
    private var tles: [TLE] = []
    private var updateTimer: Timer?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func startTracking() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.startUpdatingLocation()
        }
        
        isTracking = true
        fetchTLEs()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.calculateVisibleSatellites()
        }
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorized {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
        calculateVisibleSatellites()
    }
    
    private func fetchTLEs() {
        guard let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?GROUP=starlink&FORMAT=tle") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let text = String(data: data, encoding: .utf8) else { return }
            
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var parsedTLEs: [TLE] = []
            
            for i in stride(from: 0, to: lines.count - 2, by: 3) {
                let name = lines[i].trimmingCharacters(in: .whitespaces)
                let line1 = lines[i + 1]
                let line2 = lines[i + 2]
                
                do {
                    let tle = try TLE(name: name, lineOne: line1, lineTwo: line2)
                    parsedTLEs.append(tle)
                } catch {
                    // Ignore parse errors
                }
            }
            
            DispatchQueue.main.async {
                self?.tles = parsedTLEs
                self?.calculateVisibleSatellites()
            }
        }.resume()
    }
    
    private func calculateVisibleSatellites() {
        guard let userLoc = userLocation, !tles.isEmpty else { return }
        let now = Date()
        let geodeticUser = GeodeticCoordinate(latitude: userLoc.latitude * .pi / 180, longitude: userLoc.longitude * .pi / 180, altitude: 0)
        
        var visible: [SatellitePosition] = []
        
        for tle in tles {
            do {
                let propagator = try SGP4Propagator(tle: tle)
                let minutes = now.timeIntervalSince(tle.epoch) / 60.0
                let state = try propagator.propagate(minutesSinceEpoch: minutes)
                
                // Convert TEME to ECEF
                let (ecefPos, _) = CoordinateConverter.temeToECEF(position: state.position, velocity: state.velocity, date: now)
                
                // User Geodetic to ECEF (WGS84)
                let a = 6378.137
                let f = 1.0 / 298.257223563
                let e2 = 2 * f - f * f
                let lat = userLoc.latitude * .pi / 180
                let lon = userLoc.longitude * .pi / 180
                let sinLat = sin(lat)
                let cosLat = cos(lat)
                let sinLon = sin(lon)
                let cosLon = cos(lon)
                let N = a / sqrt(1 - e2 * sinLat * sinLat)
                let userX = N * cosLat * cosLon
                let userY = N * cosLat * sinLon
                let userZ = N * (1 - e2) * sinLat
                
                let dx = ecefPos.x - userX
                let dy = ecefPos.y - userY
                let dz = ecefPos.z - userZ
                
                // ECEF to ENU
                let e = -sinLon * dx + cosLon * dy
                let n = -sinLat * cosLon * dx - sinLat * sinLon * dy + cosLat * dz
                let u = cosLat * cosLon * dx + cosLat * sinLon * dy + sinLat * dz
                
                let distance = sqrt(e*e + n*n + u*u)
                let elevation = atan2(u, sqrt(e*e + n*n)) * 180 / .pi
                var azimuth = atan2(e, n) * 180 / .pi
                if azimuth < 0 { azimuth += 360 }
                
                if elevation > 25 { // Above 25 degrees obstruction mask
                    visible.append(SatellitePosition(
                        id: tle.name,
                        name: tle.name,
                        azimuth: azimuth,
                        elevation: elevation,
                        distance: distance
                    ))
                }
            } catch {
                continue
            }
        }
        
        DispatchQueue.main.async {
            self.visibleSatellites = visible
        }
    }
}
