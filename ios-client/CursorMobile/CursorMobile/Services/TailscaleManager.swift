import Foundation
import Network

/// Represents a discovered Napp Trapp server on the Tailscale network
struct TailscaleServer: Identifiable, Equatable {
    let id = UUID()
    let hostname: String
    let ip: String
    let port: Int
    var serverUrl: String { "http://\(ip):\(port)" }
    
    static func == (lhs: TailscaleServer, rhs: TailscaleServer) -> Bool {
        lhs.ip == rhs.ip && lhs.port == rhs.port
    }
}

/// Response from the /discover endpoint
struct DiscoverResponse: Codable {
    let service: String
    let version: String
    let hostname: String
    let port: Int
}

/// Response from the /api/system/tailscale endpoint
struct TailscaleStatusResponse: Codable {
    let available: Bool
    let connected: Bool
    let ip: String?
    let ipv6: String?
    let hostname: String?
    let magicDNSHostname: String?
    let tailnetName: String?
    let connectionUrl: String?
    let magicDNSUrl: String?
    let port: Int?
    let peers: [TailscalePeer]?
    let backendState: String?
    let magicDNSEnabled: Bool?
    let message: String?
}

struct TailscalePeer: Codable {
    let hostname: String
    let dnsName: String
    let ip: String
    let os: String
    let online: Bool
    let active: Bool
}

/// Manages Tailscale network detection and server discovery
/// 
/// When the device is connected to a Tailscale VPN, this manager:
/// 1. Detects the Tailscale network interface (100.x.y.z)
/// 2. Probes known peer IPs for Napp Trapp servers via the /discover endpoint
/// 3. Retrieves peer lists from connected servers for broader discovery
@MainActor
class TailscaleManager: ObservableObject {
    static let shared = TailscaleManager()
    
    /// Whether the device appears to be on a Tailscale network
    @Published private(set) var isTailscaleActive = false
    
    /// The device's Tailscale IP address (100.x.y.z)
    @Published private(set) var tailscaleIP: String?
    
    /// Discovered Napp Trapp servers on the Tailscale network
    @Published private(set) var discoveredServers: [TailscaleServer] = []
    
    /// Whether a discovery scan is in progress
    @Published private(set) var isScanning = false
    
    /// Peer IPs obtained from a connected server
    private var knownPeerIPs: [String] = []
    
    /// Default Napp Trapp port
    private let defaultPort = 3847
    
    /// Discovery timeout per probe (seconds)
    private let probeTimeout: TimeInterval = 1.5
    
    /// Shared ephemeral session for probing (avoids creating a session per probe)
    private lazy var probeSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = probeTimeout
        config.timeoutIntervalForResource = probeTimeout
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config)
    }()
    
    private init() {
        checkTailscaleNetwork()
    }
    
    // MARK: - Network Detection
    
    /// Check if the device has a Tailscale network interface (100.x.y.z)
    func checkTailscaleNetwork() {
        var foundTailscaleIP: String?
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            isTailscaleActive = false
            tailscaleIP = nil
            return
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    socklen_t(0),
                    NI_NUMERICHOST
                )
                
                let address = String(cString: hostname)
                
                // Tailscale uses the CGNAT range: 100.64.0.0/10 (100.64.x.x - 100.127.x.x)
                if address.hasPrefix("100.") {
                    let parts = address.split(separator: ".")
                    if parts.count == 4, let secondOctet = Int(parts[1]) {
                        if secondOctet >= 64 && secondOctet <= 127 {
                            foundTailscaleIP = address
                        }
                    }
                }
            }
            
            guard let next = interface.ifa_next else { break }
            ptr = next
        }
        
        isTailscaleActive = foundTailscaleIP != nil
        tailscaleIP = foundTailscaleIP
        
        if let ip = foundTailscaleIP {
            print("[TailscaleManager] Tailscale network detected, device IP: \(ip)")
        } else {
            print("[TailscaleManager] No Tailscale network detected")
        }
    }
    
    // MARK: - Server Discovery
    
    /// Scan for Napp Trapp servers on the Tailscale network
    /// Uses known peer IPs (from previously connected servers), saved hosts,
    /// and subnet scanning as a fallback for fresh installs
    func discoverServers() async {
        guard isTailscaleActive else {
            print("[TailscaleManager] Cannot scan - Tailscale not active")
            return
        }
        
        isScanning = true
        discoveredServers = []
        
        var ipsToProbe: Set<String> = []
        
        // 1. Add known peer IPs (from a previously connected server)
        for ip in knownPeerIPs {
            ipsToProbe.insert(ip)
        }
        
        // 2. Add Tailscale IPs from saved hosts
        let savedHosts = SavedHostsManager.shared.savedHosts
        for host in savedHosts {
            if let url = URL(string: host.serverUrl),
               let hostStr = url.host,
               TailscaleManager.isTailscaleIP(hostStr) {
                ipsToProbe.insert(hostStr)
            }
        }
        
        // 3. If we have no specific IPs to probe (fresh install), do a subnet scan
        //    around the device's own Tailscale IP. Tailscale assigns IPs from 100.64.0.0/10
        //    and peers in the same tailnet often share the same /16 or nearby ranges.
        if ipsToProbe.isEmpty, let deviceIP = tailscaleIP {
            let candidateIPs = generateSubnetScanIPs(aroundIP: deviceIP)
            for ip in candidateIPs {
                ipsToProbe.insert(ip)
            }
            print("[TailscaleManager] Fresh install: generated \(candidateIPs.count) candidate IPs from subnet scan")
        }
        
        print("[TailscaleManager] Probing \(ipsToProbe.count) Tailscale IPs for servers...")
        
        // Probe all IPs concurrently with a concurrency limit to avoid overwhelming the network
        let maxConcurrency = 50
        var found: [TailscaleServer] = []
        
        await withTaskGroup(of: TailscaleServer?.self) { group in
            var pending = 0
            var iterator = ipsToProbe.makeIterator()
            
            // Seed initial batch
            while pending < maxConcurrency, let ip = iterator.next() {
                group.addTask { [self] in
                    await self.probeServer(ip: ip, port: self.defaultPort)
                }
                pending += 1
            }
            
            // Process results and add more tasks
            for await result in group {
                pending -= 1
                if let server = result {
                    if !found.contains(server) {
                        found.append(server)
                    }
                }
                // Add next IP to probe
                if let ip = iterator.next() {
                    group.addTask { [self] in
                        await self.probeServer(ip: ip, port: self.defaultPort)
                    }
                    pending += 1
                }
            }
        }
        
        discoveredServers = found
        print("[TailscaleManager] Discovery complete. Found \(discoveredServers.count) server(s)")
        isScanning = false
    }
    
    /// Probe a single Tailscale IP and add it as a discovered server if found
    /// Useful for the "Enter IP" feature in the UI
    func probeSpecificIP(_ ip: String) async -> TailscaleServer? {
        guard TailscaleManager.isTailscaleIP(ip) || !ip.isEmpty else { return nil }
        
        let server = await probeServer(ip: ip, port: defaultPort)
        if let server = server {
            // Add to discovered servers if not already there
            if !discoveredServers.contains(server) {
                discoveredServers.append(server)
            }
        }
        return server
    }
    
    /// Generate candidate IPs to scan around the device's own Tailscale IP
    /// Strategy:
    ///   - Full /24 of the device's own IP (254 IPs)
    ///   - Sweep .1 addresses across adjacent /24 blocks in the same /16 (255 IPs)
    ///   - Sweep .1 addresses across adjacent /16 blocks (64 IPs)
    /// Total: ~573 IPs, probed concurrently in ~2-3 seconds
    private func generateSubnetScanIPs(aroundIP deviceIP: String) -> [String] {
        let parts = deviceIP.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return [] }
        
        let a = parts[0]  // Always 100
        let b = parts[1]  // 64-127
        let c = parts[2]  // 0-255
        let d = parts[3]  // 0-255
        
        var candidates: Set<String> = []
        
        // 1. Full /24 scan of the device's own subnet
        for i in 1...254 {
            if i != d {
                candidates.insert("\(a).\(b).\(c).\(i)")
            }
        }
        
        // 2. Try .1 on every /24 in the same /16
        for thirdOctet in 0...255 {
            if thirdOctet != c {
                candidates.insert("\(a).\(b).\(thirdOctet).1")
            }
        }
        
        // 3. Try .1.1 on adjacent /16 blocks (within Tailscale CGNAT range 64-127)
        for secondOctet in 64...127 {
            if secondOctet != b {
                candidates.insert("\(a).\(secondOctet).1.1")
            }
        }
        
        // Remove the device's own IP
        candidates.remove(deviceIP)
        
        return Array(candidates)
    }
    
    /// Probe a specific IP:port for a Napp Trapp server
    private nonisolated func probeServer(ip: String, port: Int) async -> TailscaleServer? {
        let urlString = "http://\(ip):\(port)/discover"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        request.httpMethod = "GET"
        
        do {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 1.5
            config.timeoutIntervalForResource = 1.5
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let discoverResponse = try JSONDecoder().decode(DiscoverResponse.self, from: data)
            
            guard discoverResponse.service == "napp-trapp" else {
                return nil
            }
            
            return TailscaleServer(
                hostname: discoverResponse.hostname,
                ip: ip,
                port: discoverResponse.port
            )
        } catch {
            // Expected for non-server IPs - don't log
            return nil
        }
    }
    
    // MARK: - Peer List Management
    
    /// Update the known peer list from a connected server's Tailscale status
    /// Call this after successfully connecting to a server
    func updatePeerList(from apiService: APIService) async {
        do {
            let data = try await apiService.getTailscaleStatus()
            if let peers = data.peers {
                let peerIPs = peers
                    .filter { $0.online || $0.active }
                    .compactMap { $0.ip.isEmpty ? nil : $0.ip }
                
                knownPeerIPs = peerIPs
                print("[TailscaleManager] Updated peer list: \(peerIPs.count) peers")
                
                // Persist peer IPs for offline discovery
                UserDefaults.standard.set(peerIPs, forKey: "tailscale-known-peers")
            }
        } catch {
            print("[TailscaleManager] Failed to fetch peer list: \(error.localizedDescription)")
            
            // Fall back to persisted peers
            if let saved = UserDefaults.standard.stringArray(forKey: "tailscale-known-peers") {
                knownPeerIPs = saved
            }
        }
    }
    
    /// Load persisted peer IPs from previous sessions
    func loadPersistedPeers() {
        if let saved = UserDefaults.standard.stringArray(forKey: "tailscale-known-peers") {
            knownPeerIPs = saved
            print("[TailscaleManager] Loaded \(saved.count) persisted peer IPs")
        }
    }
    
    /// Check if an IP address is a Tailscale address
    static func isTailscaleIP(_ ip: String) -> Bool {
        guard ip.hasPrefix("100.") else { return false }
        let parts = ip.split(separator: ".")
        guard parts.count == 4, let secondOctet = Int(parts[1]) else { return false }
        return secondOctet >= 64 && secondOctet <= 127
    }
}
