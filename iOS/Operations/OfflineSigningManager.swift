// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Manager for handling offline app signing functionality
class OfflineSigningManager {
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = OfflineSigningManager()
    
    /// Flag indicating if offline signing is enabled
    private(set) var isOfflineSigningEnabled = true
    
    /// Flag indicating if local certificates have been validated
    private(set) var localCertificatesValidated = false
    
    /// Local certificate paths
    private let serverCertPath: URL
    private let serverKeyPath: URL
    
    /// Last certificate validation time
    private var lastCertificateValidationTime: Date?
    
    // MARK: - Initialization
    
    private init() {
        // Setup local certificate paths
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        serverCertPath = docsDir.appendingPathComponent("server.crt")
        serverKeyPath = docsDir.appendingPathComponent("server.pem")
        
        // Check if local certificates exist
        validateLocalCertificates()
        
        // Listen for network status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: NSNotification.Name("NetworkStatusChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Check if offline signing is available
    var isOfflineSigningAvailable: Bool {
        // Offline signing is only available if:
        // 1. We're offline or offline mode is forced
        // 2. We have valid local certificates
        return (forceOfflineMode || !NetworkMonitor.shared.isConnected) && localCertificatesValidated
    }
    
    /// Force offline mode regardless of connection status
    private(set) var forceOfflineMode = false
    
    /// Toggle forced offline mode
    func toggleForceOfflineMode(_ force: Bool) {
        forceOfflineMode = force
        
        // Log the mode change
        Debug.shared.log(
            message: "Offline signing mode \(force ? "forced" : "automatic")",
            type: .info
        )
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: NSNotification.Name("OfflineModeChanged"),
            object: nil,
            userInfo: ["forceOfflineMode": force]
        )
    }
    
    /// Enable/disable offline signing
    func setOfflineSigningEnabled(_ enabled: Bool) {
        isOfflineSigningEnabled = enabled
        
        // Log the setting change
        Debug.shared.log(
            message: "Offline signing \(enabled ? "enabled" : "disabled")",
            type: .info
        )
        
        // Update user defaults
        UserDefaults.standard.set(enabled, forKey: "offlineSigningEnabled")
        
        // If enabling, validate local certificates
        if enabled {
            validateLocalCertificates()
        }
    }
    
    /// Check if offline signing mode is currently active
    var isOfflineModeActive: Bool {
        return isOfflineSigningEnabled && isOfflineSigningAvailable
    }
    
    /// Show offline mode indicator on view
    func showOfflineModeIndicator(on view: UIView) {
        // Only show indicator if offline mode is active
        guard isOfflineModeActive else { return }
        
        // Check if indicator already exists
        if let existingIndicator = view.viewWithTag(8675) {
            existingIndicator.isHidden = false
            return
        }
        
        // Create offline indicator
        let indicator = createOfflineIndicator()
        indicator.tag = 8675 // Unique tag for finding later
        view.addSubview(indicator)
        
        // Add constraints
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            indicator.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            indicator.heightAnchor.constraint(equalToConstant: 28),
        ])
        
        // Add animation
        animateOfflineIndicator(indicator)
    }
    
    /// Hide offline mode indicator from view
    func hideOfflineModeIndicator(from view: UIView) {
        if let indicator = view.viewWithTag(8675) {
            indicator.isHidden = true
        }
    }
    
    /// Import local certificates
    func importLocalCertificates(certData: Data, keyData: Data, completion: @escaping (Bool, Error?) -> Void) {
        do {
            // Write certificate data to local storage
            try certData.write(to: serverCertPath)
            try keyData.write(to: serverKeyPath)
            
            // Validate certificates
            validateLocalCertificates()
            
            // Check if validation was successful
            if localCertificatesValidated {
                completion(true, nil)
            } else {
                let error = NSError(
                    domain: "com.backdoor.offlineSigning",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Certificate validation failed"]
                )
                completion(false, error)
            }
        } catch {
            Debug.shared.log(message: "Failed to import certificates: \(error.localizedDescription)", type: .error)
            completion(false, error)
        }
    }
    
    /// Get certificates for offline signing
    func getOfflineSigningCertificates() -> (cert: URL?, key: URL?) {
        guard localCertificatesValidated else {
            return (nil, nil)
        }
        
        return (serverCertPath, serverKeyPath)
    }
    
    // MARK: - Private Methods
    
    /// Validate local certificates
    @discardableResult
    private func validateLocalCertificates() -> Bool {
        // Prevent frequent revalidation
        if let lastValidation = lastCertificateValidationTime,
           Date().timeIntervalSince(lastValidation) < 60 { // Only validate once per minute
            return localCertificatesValidated
        }
        
        // Check if certificate files exist
        let fileManager = FileManager.default
        let certExists = fileManager.fileExists(atPath: serverCertPath.path)
        let keyExists = fileManager.fileExists(atPath: serverKeyPath.path)
        
        // Log certificate status
        Debug.shared.log(
            message: "Local certificates: cert \(certExists ? "exists" : "missing"), key \(keyExists ? "exists" : "missing")",
            type: certExists && keyExists ? .info : .warning
        )
        
        // Basic validation - check files exist and aren't empty
        var isValid = certExists && keyExists
        
        if isValid {
            do {
                let certAttributes = try fileManager.attributesOfItem(atPath: serverCertPath.path)
                let keyAttributes = try fileManager.attributesOfItem(atPath: serverKeyPath.path)
                
                if let certSize = certAttributes[.size] as? NSNumber,
                   let keySize = keyAttributes[.size] as? NSNumber {
                    isValid = certSize.intValue > 0 && keySize.intValue > 0
                } else {
                    isValid = false
                }
            } catch {
                Debug.shared.log(message: "Error checking certificate sizes: \(error.localizedDescription)", type: .error)
                isValid = false
            }
        }
        
        // Update validation state
        localCertificatesValidated = isValid
        lastCertificateValidationTime = Date()
        
        return isValid
    }
    
    /// Create offline mode indicator
    private func createOfflineIndicator() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        container.layer.cornerRadius = 14
        
        // Create label
        let label = UILabel()
        label.text = "OFFLINE MODE"
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        
        // Add label to container
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8)
        ])
        
        // Add LED glow effect
        container.addFlowingLEDEffect(
            color: .systemRed,
            intensity: 0.8,
            width: 2,
            speed: 2.0
        )
        
        return container
    }
    
    /// Animate offline indicator
    private func animateOfflineIndicator(_ indicator: UIView) {
        // Add subtle pulse animation
        UIView.animate(withDuration: 1.0, delay: 0, options: [.autoreverse, .repeat, .curveEaseInOut], animations: {
            indicator.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        })
    }
    
    /// Handle network status changes
    @objc private func networkStatusChanged(_ notification: Notification) {
        guard let isConnected = notification.userInfo?["isConnected"] as? Bool else { return }
        
        // Log connection status change
        Debug.shared.log(message: "Network \(isConnected ? "connected" : "disconnected")", type: .info)
        
        // Post notification for UI updates if offline signing is enabled
        if isOfflineSigningEnabled {
            NotificationCenter.default.post(
                name: NSNotification.Name("OfflineModeChanged"),
                object: nil,
                userInfo: ["isOfflineMode": !isConnected || forceOfflineMode]
            )
        }
    }
}

// MARK: - Extension for UIViewController

extension UIViewController {
    /// Update UI for offline mode
    func updateForOfflineMode() {
        let offlineManager = OfflineSigningManager.shared
        
        if offlineManager.isOfflineModeActive {
            offlineManager.showOfflineModeIndicator(on: view)
        } else {
            offlineManager.hideOfflineModeIndicator(from: view)
        }
    }
}
