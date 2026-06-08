import Foundation
import SwiftData

@Model
class TelemetrySnapshot {
    var timestamp: Date
    var pingLatencyMs: Float
    var downlinkThroughputBps: Float
    var uplinkThroughputBps: Float
    var fractionObstructed: Float
    
    // Optional RV location data
    var latitude: Double?
    var longitude: Double?
    
    init(timestamp: Date = .now, pingLatencyMs: Float, downlinkThroughputBps: Float, uplinkThroughputBps: Float, fractionObstructed: Float, latitude: Double? = nil, longitude: Double? = nil) {
        self.timestamp = timestamp
        self.pingLatencyMs = pingLatencyMs
        self.downlinkThroughputBps = downlinkThroughputBps
        self.uplinkThroughputBps = uplinkThroughputBps
        self.fractionObstructed = fractionObstructed
        self.latitude = latitude
        self.longitude = longitude
    }
}

@Model
class OutageEvent {
    var startTimestamp: Date
    var endTimestamp: Date?
    var cause: String
    var durationSeconds: Double {
        return endTimestamp?.timeIntervalSince(startTimestamp) ?? Date.now.timeIntervalSince(startTimestamp)
    }
    
    init(startTimestamp: Date = .now, cause: String) {
        self.startTimestamp = startTimestamp
        self.cause = cause
    }
}
