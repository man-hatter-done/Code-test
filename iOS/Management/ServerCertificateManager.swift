// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation

/// Manager for server.crt and server.pem certificate files used by the app
/// These certificates are used for:
/// 1. Server functionality (HTTPS server in Installer class)
/// 2. Offline app signing
class ServerCertificateManager {
    // MARK: - Shared Instance
    
    static let shared = ServerCertificateManager()
    
    // MARK: - Properties
    
    /// Server certificate file paths
    private let serverCrtPath: URL
    private let serverPemPath: URL
    
    /// Last validation time
    private var lastValidationTime: Date?
    
    // MARK: - Initialization
    
    private init() {
        // Get paths from documents directory - these must match the paths in Server+TLS.swift
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        serverCrtPath = docsDir.appendingPathComponent("server.crt")
        serverPemPath = docsDir.appendingPathComponent("server.pem")
        
        // Validate certificates on initialization
        validateCertificates()
    }
    
    // MARK: - Public Methods
    
    /// Validate server certificates and download if missing
    @discardableResult
    func validateCertificates() -> Bool {
        // Check if we've validated recently
        if let lastValidation = lastValidationTime, Date().timeIntervalSince(lastValidation) < 30 {
            Debug.shared.log(message: "Skipping certificate validation - last check was recent", type: .debug)
            return areCertificatesValid()
        }
        
        let isValid = areCertificatesValid()
        
        // If certificates are not valid, try to download new ones
        if !isValid {
            Debug.shared.log(message: "Server certificates missing or invalid, attempting to download", type: .warning)
            downloadCertificates()
        } else {
            Debug.shared.log(message: "Server certificates validated successfully", type: .info)
        }
        
        // Update last validation time
        lastValidationTime = Date()
        
        return areCertificatesValid()
    }
    
    /// Check if server certificates are valid
    func areCertificatesValid() -> Bool {
        let fileManager = FileManager.default
        
        // Check if certificate files exist
        let certExists = fileManager.fileExists(atPath: serverCrtPath.path)
        let keyExists = fileManager.fileExists(atPath: serverPemPath.path)
        
        // Basic validation - check files exist and aren't empty
        var isValid = certExists && keyExists
        
        if isValid {
            do {
                let certAttributes = try fileManager.attributesOfItem(atPath: serverCrtPath.path)
                let keyAttributes = try fileManager.attributesOfItem(atPath: serverPemPath.path)
                
                if let certSize = certAttributes[.size] as? NSNumber,
                   let keySize = keyAttributes[.size] as? NSNumber {
                    isValid = certSize.intValue > 0 && keySize.intValue > 0
                } else {
                    isValid = false
                }
            } catch {
                Debug.shared.log(
                    message: "Error checking certificate sizes: \(error.localizedDescription)", 
                    type: .error
                )
                isValid = false
            }
        }
        
        return isValid
    }
    
    /// Get server certificate paths
    /// - Returns: Tuple with paths to certificate and key files
    func getCertificatePaths() -> (cert: URL, key: URL) {
        return (serverCrtPath, serverPemPath)
    }
    
    // MARK: - Private Methods
    
    /// Download server certificates using the app's existing functionality
    private func downloadCertificates() {
        let semaphore = DispatchSemaphore(value: 0)
        
        getCertificates {
            semaphore.signal()
        }
        
        // Wait for completion with timeout
        _ = semaphore.wait(timeout: .now() + 10)
        
        // Log result after download attempt
        let isValid = areCertificatesValid()
        Debug.shared.log(
            message: "Certificate download completed - Certificates are \(isValid ? "valid" : "still invalid")",
            type: isValid ? .success : .error
        )
    }
}
