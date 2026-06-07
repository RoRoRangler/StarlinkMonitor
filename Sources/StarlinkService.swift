import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

/// A service to interact with a Starlink device over its local gRPC interface.
/// This service encapsulates the underlying transport configuration and connection lifecycle.
class StarlinkService {
    
    private let client: GRPCClient<HTTP2ClientTransport.Posix>
    private let deviceClient: SpaceX_API_Device_Device.Client<HTTP2ClientTransport.Posix>
    
    /// Initializes the Starlink Service.
    ///
    /// - Parameters:
    ///   - host: The IP address of the Starlink dish/router. Defaults to "192.168.100.1".
    ///   - port: The gRPC port to connect to. Defaults to 9200.
    init(host: String = "192.168.100.1", port: Int = 9200) throws {
        // Initialize an HTTP2 client transport for local unencrypted gRPC traffic.
        let transport = try HTTP2ClientTransport.Posix(
            target: .ipv4(address: host, port: port),
            transportSecurity: .plaintext
        )
        self.client = GRPCClient(transport: transport)
        self.deviceClient = SpaceX_API_Device_Device.Client(wrapping: self.client)
        
        // The underlying client loop must be run in the background to handle multiplexing.
        Task {
            do {
                try await self.client.runConnections()
            } catch {
                print("StarlinkService client connection loop failed: \(error)")
            }
        }
    }
    
    /// Closes the gRPC client transport.
    func close() {
        self.client.beginGracefulShutdown()
    }
    
    /// Fetches the current status from the Starlink device.
    ///
    /// - Returns: The full response payload from the device containing diagnostics, versioning, and state.
    func getStatus() async throws -> SpaceX_API_Device_Response {
        var requestMessage = SpaceX_API_Device_Request()
        requestMessage.getStatus = SpaceX_API_Device_GetStatusRequest()
        
        let request = ClientRequest(message: requestMessage)
        
        // Execute the RPC call to the dish using the generated grpc-swift wrapper.
        // It provides the response message directly.
        let response = try await self.deviceClient.handle(request: request)
        
        return response
    }
    
    /// Fetches the list of clients currently connected to the Starlink Router.
    func getWifiClients() async throws -> SpaceX_API_Device_WifiGetClientsResponse {
        var requestMessage = SpaceX_API_Device_Request()
        requestMessage.wifiGetClients = SpaceX_API_Device_WifiGetClientsRequest()
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.wifiGetClients
    }
    
    /// Fetches historical telemetry data like latency, drop rates, and throughput.
    func getHistory() async throws -> SpaceX_API_Device_DishGetHistoryResponse {
        var requestMessage = SpaceX_API_Device_Request()
        requestMessage.getHistory = SpaceX_API_Device_GetHistoryRequest()
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.dishGetHistory
    }
    
    /// Fetches the obstruction map (Sky View).
    func getObstructionMap() async throws -> SpaceX_API_Device_DishGetObstructionMapResponse {
        var requestMessage = SpaceX_API_Device_Request()
        requestMessage.dishGetObstructionMap = SpaceX_API_Device_DishGetObstructionMapRequest()
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.dishGetObstructionMap
    }
    
    /// Initiates a speed test.
    func startSpeedtest() async throws -> SpaceX_API_Device_StartSpeedtestResponse {
        var requestMessage = SpaceX_API_Device_Request()
        requestMessage.startSpeedtest = SpaceX_API_Device_StartSpeedtestRequest()
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.startSpeedtest
    }
    
    /// Fetches the status of an ongoing speed test.
    func getSpeedtestStatus() async throws -> SpaceX_API_Device_GetSpeedtestStatusResponse {
        var requestMessage = SpaceX_API_Device_Request()
        requestMessage.getSpeedtestStatus = SpaceX_API_Device_GetSpeedtestStatusRequest()
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.getSpeedtestStatus
    }
    
    /// Stows the dish.
    func stow() async throws -> SpaceX_API_Device_DishStowResponse {
        var requestMessage = SpaceX_API_Device_Request()
        var stowReq = SpaceX_API_Device_DishStowRequest()
        stowReq.unstow = false
        requestMessage.dishStow = stowReq
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.dishStow
    }
    
    /// Unstows the dish.
    func unstow() async throws -> SpaceX_API_Device_DishStowResponse {
        var requestMessage = SpaceX_API_Device_Request()
        var stowReq = SpaceX_API_Device_DishStowRequest()
        stowReq.unstow = true
        requestMessage.dishStow = stowReq
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.dishStow
    }
    
    /// Sets the snow melt mode.
    func setSnowMeltMode(_ mode: SpaceX_API_Device_DishConfig.SnowMeltMode) async throws -> SpaceX_API_Device_DishSetConfigResponse {
        var requestMessage = SpaceX_API_Device_Request()
        var configReq = SpaceX_API_Device_DishSetConfigRequest()
        var config = SpaceX_API_Device_DishConfig()
        config.snowMeltMode = mode
        config.applySnowMeltMode = true
        configReq.dishConfig = config
        requestMessage.dishSetConfig = configReq
        
        let request = ClientRequest(message: requestMessage)
        let response = try await self.deviceClient.handle(request: request)
        
        return response.dishSetConfig
    }
}
