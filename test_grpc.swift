import GRPCCore
import GRPCNIOTransportHTTP2

@main
struct Main {
    static func main() async throws {
        let transport = try HTTP2ClientTransport.Posix(
            target: .ipv4(host: "192.168.100.1", port: 9200)
        )
        let client = GRPCClient(transport: transport)
        print("Success")
    }
}
