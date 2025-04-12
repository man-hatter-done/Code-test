// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit
import SystemConfiguration
import Network

// MARK: - Network Monitoring Extension
extension AppDelegate {
    /// Set up network monitoring to track connectivity changes
    func setupNetworkMonitoring() {
        Debug.shared.log(message: "Setting up enhanced network monitoring", type: .info)
        
        // Use our custom NetworkMonitor singleton that internally uses NWPathMonitor
        // This provides a consistent interface regardless of iOS version
        setupEnhancedNetworkMonitoring()
    }
    
    /// Set up enhanced network monitoring with offline mode support and UI indicators
    private func setupEnhancedNetworkMonitoring() {
        // Initialize the shared NetworkMonitor singleton
        let networkMonitor = NetworkMonitor.shared
        
        // Initialize OfflineSigningManager which depends on NetworkMonitor
        let offlineManager = OfflineSigningManager.shared
        
        // Register for connection status changes
        networkMonitor.connectionStatusChanged = { [weak self] isConnected, connectionType in
            guard let self = self else { return }
            
            // Log connection changes
            Debug.shared.log(
                message: "Network status changed - Connected: \(isConnected), Type: \(connectionType)",
                type: .info
            )
            
            // Update UI based on connection status
            DispatchQueue.main.async {
                // Update status bar color based on connection
                if let window = self.window {
                    if !isConnected {
                        // Add subtle LED pulsing effect to status bar
                        if let statusBarView = window.viewWithTag(9999) {
                            // Update existing status bar view
                            statusBarView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
                        } else {
                            // Create new status bar indicator for offline mode
                            let statusBarFrame = window.windowScene?.statusBarManager?.statusBarFrame ?? CGRect.zero
                            let statusBarView = UIView(frame: statusBarFrame)
                            statusBarView.tag = 9999
                            statusBarView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
                            
                            // Add pulsing animation
                            let animation = CABasicAnimation(keyPath: "opacity")
                            animation.fromValue = 0.4
                            animation.toValue = 0.8
                            animation.duration = 1.5
                            animation.autoreverses = true
                            animation.repeatCount = .infinity
                            statusBarView.layer.add(animation, forKey: "pulseAnimation")
                            
                            // Add status bar view to window
                            window.addSubview(statusBarView)
                        }
                    } else {
                        // Remove offline indicator from status bar
                        if let statusBarView = window.viewWithTag(9999) {
                            UIView.animate(withDuration: 0.3, animations: {
                                statusBarView.alpha = 0
                            }, completion: { _ in
                                statusBarView.removeFromSuperview()
                            })
                        }
                    }
                }
                
                // Show alert for important connection changes if enabled
                if Preferences.showNetworkAlerts {
                    self.showNetworkStatusChangeAlert(isConnected: isConnected, connectionType: connectionType)
                }
                
                // Update the offline signing manager
                if !isConnected {
                    offlineManager.validateLocalCertificates()
                }
                
                // Notify controllers about the network change
                NotificationCenter.default.post(
                    name: Notification.Name("NetworkStatusChanged"),
                    object: nil,
                    userInfo: [
                        "isConnected": isConnected,
                        "connectionType": connectionType.rawValue,
                        "isOfflineSigningAvailable": offlineManager.isOfflineSigningAvailable
                    ]
                )
            }
        }
        
        // Log initial connection status
        Debug.shared.log(
            message: "Initial network status: \(networkMonitor.statusString)",
            type: .info
        )
    }
    
    /// Show an alert for important connection status changes
    private func showNetworkStatusChangeAlert(isConnected: Bool, connectionType: ConnectionType) {
        // Only show alerts for transitions to offline or to expensive connection type
        let shouldShowAlert = !isConnected || connectionType == .cellular
        
        guard shouldShowAlert, let topVC = UIApplication.shared.topMostViewController() else {
            return
        }
        
        // Don't show alert if we're already showing another alert
        if topVC.presentedViewController is UIAlertController {
            return
        }
        
        let alert = UIAlertController(
            title: isConnected ? "Network Connected" : "Network Disconnected",
            message: isConnected ? 
                     "Your device is now connected via \(connectionType)." : 
                     "Your device is now offline. Offline signing mode is available.",
            preferredStyle: .alert
        )
        
        // Add option to enable/disable offline mode if we're offline
        if !isConnected && OfflineSigningManager.shared.isOfflineSigningAvailable {
            alert.addAction(UIAlertAction(title: "Enable Offline Mode", style: .default) { _ in
                OfflineSigningManager.shared.toggleForceOfflineMode(true)
            })
        }
        
        // Add don't show again option
        alert.addAction(UIAlertAction(title: "Don't Show Again", style: .default) { _ in
            Preferences.showNetworkAlerts = false
        })
        
        // Add dismiss action
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        // Present alert
        topVC.present(alert, animated: true)
    }
}

// MARK: - Preferences Extension
extension Preferences {
    /// Whether to show network status change alerts
    static var showNetworkAlerts: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "showNetworkAlerts")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "showNetworkAlerts")
        }
    }
}
