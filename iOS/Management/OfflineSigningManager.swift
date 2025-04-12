// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import Security

/// Manager for offline signing functionality 
class OfflineSigningManager {
    // MARK: - Shared Instance
    
    static let shared = OfflineSigningManager()
    
    // MARK: - Properties
    
    /// Whether offline mode is forcibly enabled by user
    private(set) var forceOfflineMode = false
    
    /// Whether offline mode is currently active (either forced or due to network status)
    var isOfflineModeActive: Bool {
        return forceOfflineMode || !NetworkMonitor.shared.isConnected
    }
    
    /// Whether offline signing is available (proper certificates exist)
    var isOfflineSigningAvailable: Bool {
        let certificates = getOfflineSigningCertificates()
        return certificates.cert != nil && certificates.key != nil
    }
    
    // MARK: - Certificate Paths
    
    /// Local certificate and key paths for offline signing
    private var localCertPaths: (cert: URL?, key: URL?) = (nil, nil)
    
    // MARK: - Certificate Management
    
    /// Toggle force offline mode
    /// - Parameter enabled: Whether to force offline mode
    func toggleForceOfflineMode(_ enabled: Bool) {
        forceOfflineMode = enabled
        
        // Log the mode change
        Debug.shared.log(
            message: "Offline signing mode \(enabled ? "enabled" : "disabled")",
            type: .info
        )
        
        // Validate certificates when enabling
        if enabled {
            validateLocalCertificates()
        }
        
        // Post notification about mode change
        NotificationCenter.default.post(
            name: Notification.Name("OfflineModeChanged"),
            object: nil,
            userInfo: ["isEnabled": enabled]
        )
    }
    
    /// Validate local certificates and cache their paths
    func validateLocalCertificates() {
        // Use ServerCertificateManager to validate the certificates
        let isValid = ServerCertificateManager.shared.validateCertificates()
        
        if isValid {
            // Get the certificate paths from the manager
            let paths = ServerCertificateManager.shared.getCertificatePaths()
            localCertPaths.cert = paths.cert
            localCertPaths.key = paths.key
            
            Debug.shared.log(
                message: "Using validated server certificates for offline signing",
                type: .info
            )
        } else {
            // Clear certificate paths if they're not valid
            localCertPaths.cert = nil
            localCertPaths.key = nil
            
            Debug.shared.log(
                message: "Server certificates are not valid for offline signing",
                type: .warning
            )
        }
    }
    
    /// Get the paths to offline signing certificates
    /// - Returns: Tuple with paths to certificate and key files
    func getOfflineSigningCertificates() -> (cert: URL?, key: URL?) {
        if localCertPaths.cert == nil || localCertPaths.key == nil {
            validateLocalCertificates()
        }
        
        return localCertPaths
    }
    
    /// Import certificates for offline signing
    /// - Parameters:
    ///   - certURL: URL to the certificate file
    ///   - keyURL: URL to the key file
    func importOfflineCertificates(certURL: URL, keyURL: URL) throws {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certsDir = documentsDir.appendingPathComponent("Certificates")
        
        do {
            // Create certificates directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: certsDir.path) {
                try FileManager.default.createDirectory(at: certsDir, withIntermediateDirectories: true)
            }
            
            // Copy certificate file
            let destCertPath = certsDir.appendingPathComponent("server.crt")
            if FileManager.default.fileExists(atPath: destCertPath.path) {
                try FileManager.default.removeItem(at: destCertPath)
            }
            try FileManager.default.copyItem(at: certURL, to: destCertPath)
            
            // Copy key file
            let destKeyPath = certsDir.appendingPathComponent("server.pem")
            if FileManager.default.fileExists(atPath: destKeyPath.path) {
                try FileManager.default.removeItem(at: destKeyPath)
            }
            try FileManager.default.copyItem(at: keyURL, to: destKeyPath)
            
            // Update cached paths
            localCertPaths = (destCertPath, destKeyPath)
            
            Debug.shared.log(
                message: "Successfully imported offline signing certificates",
                type: .success
            )
        } catch {
            Debug.shared.log(
                message: "Failed to import offline certificates: \(error.localizedDescription)",
                type: .error
            )
            throw error
        }
    }
    
    /// Generate and save self-signed certificate for offline signing
    func generateOfflineCertificates() throws {
        // This is a placeholder for certificate generation logic
        // In a real implementation, this would generate a self-signed certificate and private key
        
        Debug.shared.log(
            message: "Certificate generation not implemented - please manually add server.crt and server.pem files",
            type: .warning
        )
        
        throw NSError(
            domain: "OfflineSigningManager",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Certificate generation not implemented"]
        )
    }
}
