// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import Network

/// Network connectivity status
enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
}

/// Class for monitoring network connectivity status
class NetworkMonitor {
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = NetworkMonitor()
    
    /// Network path monitor
    private let monitor = NWPathMonitor()
    
    /// Monitor queue
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    /// Current connection status
    private(set) var isConnected = false
    
    /// Current connection type
    private(set) var connectionType: ConnectionType = .unknown
    
    /// Current connection status description
    var statusString: String {
        if isConnected {
            let connectionTypeString: String
            switch connectionType {
            case .wifi: connectionTypeString = "WiFi"
            case .cellular: connectionTypeString = "Cellular"
            case .ethernet: connectionTypeString = "Ethernet"
            case .unknown: connectionTypeString = "Unknown"
            }
            return "Connected (\(connectionTypeString))"
        } else {
            return "Offline"
        }
    }
    
    /// Date of last connection change
    private(set) var lastConnectionChangeTime = Date()
    
    /// Callback for connection status changes
    var connectionStatusChanged: ((Bool, ConnectionType) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network status
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Update connection status
            let previouslyConnected = self.isConnected
            self.isConnected = path.status == .satisfied
            
            // Update connection type
            if self.isConnected {
                self.updateConnectionType(path)
            }
            
            // Set last change time
            if previouslyConnected != self.isConnected {
                self.lastConnectionChangeTime = Date()
                
                // Debug log
                Debug.shared.log(
                    message: "Network connection changed: \(self.statusString)",
                    type: .info
                )
                
                // Notify observers
                DispatchQueue.main.async {
                    self.connectionStatusChanged?(self.isConnected, self.connectionType)
                    
                    // Post notification for broader app awareness
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NetworkStatusChanged"),
                        object: nil,
                        userInfo: [
                            "isConnected": self.isConnected,
                            "connectionType": self.connectionType
                        ]
                    )
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network status
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Check if the current connection is expensive (cellular)
    var isExpensiveConnection: Bool {
        return connectionType == .cellular
    }
    
    // MARK: - Private Methods
    
    /// Update the current connection type based on the network path
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    /// Check if the device has been offline for a significant period
    func hasBeenOfflineForExtendedPeriod() -> Bool {
        guard !isConnected else { return false }
        
        // Consider "extended" to be 5 minutes or more
        let offlineDuration = Date().timeIntervalSince(lastConnectionChangeTime)
        return offlineDuration >= 300 // 5 minutes in seconds
    }
}
