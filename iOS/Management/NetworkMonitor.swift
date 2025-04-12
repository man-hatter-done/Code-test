// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Network
import Foundation

/// Connection type enum for network status
enum ConnectionType: String {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case loopback = "Loopback"
    case unknown = "Unknown"
}

/// Network connectivity monitoring class
class NetworkMonitor {
    // MARK: - Shared Instance
    
    static let shared = NetworkMonitor()
    
    // MARK: - Properties
    
    /// The NWPathMonitor instance
    private let monitor = NWPathMonitor()
    
    /// The dispatch queue for network monitoring
    private let queue = DispatchQueue(label: "com.backdoor.NetworkMonitor")
    
    /// Current network connection status
    private(set) var isConnected = false
    
    /// Current connection type
    private(set) var connectionType: ConnectionType = .unknown
    
    /// A string representation of the status for logging
    var statusString: String {
        return isConnected ? "Connected via \(connectionType.rawValue)" : "Disconnected"
    }
    
    /// Callback for connection status changes
    var connectionStatusChanged: ((Bool, ConnectionType) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Methods
    
    /// Start the network monitoring
    private func startMonitoring() {
        Debug.shared.log(message: "Starting network monitoring", type: .info)
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Update connection status
            let newConnectionStatus = path.status == .satisfied
            
            // Determine connection type
            let newConnectionType = self.getConnectionType(path)
            
            // Check if the status or type changed
            let statusChanged = newConnectionStatus != self.isConnected || newConnectionType != self.connectionType
            
            // Update stored values
            self.isConnected = newConnectionStatus
            self.connectionType = newConnectionType
            
            // Only notify if there was a change
            if statusChanged {
                Debug.shared.log(
                    message: "Network status changed: \(self.statusString)",
                    type: .info
                )
                
                // Call the callback on the main thread
                DispatchQueue.main.async {
                    self.connectionStatusChanged?(self.isConnected, self.connectionType)
                }
            }
        }
        
        // Start monitoring on the dedicated queue
        monitor.start(queue: queue)
    }
    
    /// Stop the network monitoring
    func stopMonitoring() {
        monitor.cancel()
        Debug.shared.log(message: "Network monitoring stopped", type: .info)
    }
    
    // MARK: - Helper Methods
    
    /// Get the connection type from a network path
    /// - Parameter path: The network path
    /// - Returns: The connection type
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.loopback) {
            return .loopback
        } else {
            return .unknown
        }
    }
    
    /// Check if a specific host is reachable
    /// - Parameter host: The host to check
    /// - Parameter port: The port to check (default: 443)
    /// - Parameter completion: Callback with the result
    func checkReachability(host: String, port: Int = 443, completion: @escaping (Bool) -> Void) {
        let hostEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)))
        let connection = NWConnection(to: hostEndpoint, using: .tcp)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // Connection established successfully
                connection.cancel()
                completion(true)
            case .failed, .cancelled:
                // Connection failed or was cancelled
                completion(false)
            default:
                // Other states like preparing, waiting, etc.
                break
            }
        }
        
        // Start the connection attempt with a 5-second timeout
        connection.start(queue: queue)
        
        // Set a timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            connection.cancel()
            completion(false)
        }
    }
}
