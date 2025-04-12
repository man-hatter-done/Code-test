// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import Security

/// Manages synchronization between certificate storage locations in the app
/// The app uses server.crt and server.pem in two different locations:
/// 1. Root documents directory (for server functionality)
/// 2. Certificates directory (for offline signing)
class ServerCertificateSynchronizer {
    // MARK: - Shared Instance
    
    static let shared = ServerCertificateSynchronizer()
    
    // MARK: - Properties
    
    /// Root document directory paths for server certificates
    private let rootServerCrtPath: URL
    private let rootServerPemPath: URL
    
    /// Last synchronization time
    private var lastSyncTime: Date?
    
    // MARK: - Initialization
    
    private init() {
        // Get root documents directory
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Set paths for server certificate files in root directory
        rootServerCrtPath = docsDir.appendingPathComponent("server.crt")
        rootServerPemPath = docsDir.appendingPathComponent("server.pem")
        
        // Perform initial synchronization
        synchronizeCertificates()
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCertificateChange),
            name: Notification.Name.certificateFetch,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Synchronize certificates between storage locations
    /// - Returns: True if valid certificates are available
    @discardableResult
    func synchronizeCertificates() -> Bool {
        Debug.shared.log(message: "Synchronizing server certificates", type: .info)
        
        // Check if we've synchronized recently
        if let lastSync = lastSyncTime, Date().timeIntervalSince(lastSync) < 30 {
            Debug.shared.log(message: "Skipping certificate sync - last sync was recent", type: .debug)
            return areRootCertificatesValid()
        }
        
        // Try to copy from Certificates directory to root if needed
        if !areRootCertificatesValid() {
            copyCertificatesFromSubdirectoryToRoot()
        }
        
        // Try to copy from root to Certificates directory if needed
        if areRootCertificatesValid() {
            copyCertificatesFromRootToSubdirectory()
        }
        
        // Update last sync time
        lastSyncTime = Date()
        
        // Return current validation status
        let isValid = areRootCertificatesValid()
        Debug.shared.log(
            message: "Certificate synchronization complete - Root certificates \(isValid ? "valid" : "invalid")",
            type: isValid ? .info : .warning
        )
        
        return isValid
    }
    
    /// Check if certificates in root directory are valid
    func areRootCertificatesValid() -> Bool {
        let fileManager = FileManager.default
        
        // Check if certificate files exist
        let certExists = fileManager.fileExists(atPath: rootServerCrtPath.path)
        let keyExists = fileManager.fileExists(atPath: rootServerPemPath.path)
        
        // Basic validation - check files exist and aren't empty
        var isValid = certExists && keyExists
        
        if isValid {
            do {
                let certAttributes = try fileManager.attributesOfItem(atPath: rootServerCrtPath.path)
                let keyAttributes = try fileManager.attributesOfItem(atPath: rootServerPemPath.path)
                
                if let certSize = certAttributes[.size] as? NSNumber,
                   let keySize = keyAttributes[.size] as? NSNumber {
                    isValid = certSize.intValue > 0 && keySize.intValue > 0
                } else {
                    isValid = false
                }
            } catch {
                Debug.shared.log(
                    message: "Error checking root certificate sizes: \(error.localizedDescription)", 
                    type: .error
                )
                isValid = false
            }
        }
        
        return isValid
    }
    
    /// Get root server certificate paths
    /// - Returns: Tuple with paths to certificate and key files
    func getRootCertificatePaths() -> (cert: URL, key: URL) {
        return (rootServerCrtPath, rootServerPemPath)
    }
    
    // MARK: - Private Methods
    
    /// Find the most recently modified certificate directory
    private func findMostRecentCertificateDirectory() -> URL? {
        let fileManager = FileManager.default
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certsDir = docsDir.appendingPathComponent("Certificates")
        
        // Check if Certificates directory exists
        guard fileManager.fileExists(atPath: certsDir.path) else {
            return nil
        }
        
        do {
            // Get all subdirectories in Certificates directory
            let contents = try fileManager.contentsOfDirectory(
                at: certsDir,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            // Find most recently modified directory
            let sortedContents = contents.sorted { (url1, url2) -> Bool in
                do {
                    let values1 = try url1.resourceValues(forKeys: [.contentModificationDateKey])
                    let values2 = try url2.resourceValues(forKeys: [.contentModificationDateKey])
                    
                    if let date1 = values1.contentModificationDate,
                       let date2 = values2.contentModificationDate {
                        return date1 > date2
                    }
                } catch {
                    // Ignore errors and continue
                }
                return false
            }
            
            // Return most recent directory that has valid certificates
            for directory in sortedContents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    // Check if both certificate files exist in this directory
                    let certPath = directory.appendingPathComponent("server.crt")
                    let pemPath = directory.appendingPathComponent("server.pem")
                    
                    if fileManager.fileExists(atPath: certPath.path) && 
                       fileManager.fileExists(atPath: pemPath.path) {
                        return directory
                    }
                    
                    // Look for p12 and/or backdoor files as alternative sources
                    let backdoorFiles = try? fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil,
                        options: []
                    ).filter { $0.pathExtension.lowercased() == "backdoor" }
                    
                    if let backdoorFile = backdoorFiles?.first {
                        return directory
                    }
                    
                    // Check for provision and p12 combination
                    let provisionFiles = try? fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil,
                        options: []
                    ).filter { $0.pathExtension.lowercased() == "mobileprovision" }
                    
                    let p12Files = try? fileManager.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil,
                        options: []
                    ).filter { $0.pathExtension.lowercased() == "p12" }
                    
                    if provisionFiles?.first != nil && p12Files?.first != nil {
                        return directory
                    }
                }
            }
            
            return nil
        } catch {
            Debug.shared.log(
                message: "Error finding certificate directories: \(error.localizedDescription)",
                type: .error
            )
            return nil
        }
    }
    
    /// Copy certificates from Certificates directory to root
    private func copyCertificatesFromSubdirectoryToRoot() {
        let fileManager = FileManager.default
        
        // Find the most recent certificate directory
        guard let certDir = findMostRecentCertificateDirectory() else {
            Debug.shared.log(message: "No certificate directories found", type: .warning)
            return
        }
        
        // Check for server.crt and server.pem in the certificate directory
        let certPath = certDir.appendingPathComponent("server.crt")
        let pemPath = certDir.appendingPathComponent("server.pem")
        
        let certExists = fileManager.fileExists(atPath: certPath.path)
        let pemExists = fileManager.fileExists(atPath: pemPath.path)
        
        if certExists && pemExists {
            // Copy files to root documents directory
            do {
                if fileManager.fileExists(atPath: rootServerCrtPath.path) {
                    try fileManager.removeItem(at: rootServerCrtPath)
                }
                
                if fileManager.fileExists(atPath: rootServerPemPath.path) {
                    try fileManager.removeItem(at: rootServerPemPath)
                }
                
                try fileManager.copyItem(at: certPath, to: rootServerCrtPath)
                try fileManager.copyItem(at: pemPath, to: rootServerPemPath)
                
                Debug.shared.log(
                    message: "Copied server certificates from \(certDir.lastPathComponent) to root",
                    type: .info
                )
            } catch {
                Debug.shared.log(
                    message: "Error copying certificates to root: \(error.localizedDescription)",
                    type: .error
                )
            }
        } else {
            // Try to extract from backdoor file if available
            let backdoorFiles = try? fileManager.contentsOfDirectory(
                at: certDir,
                includingPropertiesForKeys: nil,
                options: []
            ).filter { $0.pathExtension.lowercased() == "backdoor" }
            
            if let backdoorFilePath = backdoorFiles?.first {
                extractAndCopyFromBackdoorFile(at: backdoorFilePath)
            } else {
                // Try to extract from p12 and mobileprovision if available
                let provisionFiles = try? fileManager.contentsOfDirectory(
                    at: certDir,
                    includingPropertiesForKeys: nil,
                    options: []
                ).filter { $0.pathExtension.lowercased() == "mobileprovision" }
                
                let p12Files = try? fileManager.contentsOfDirectory(
                    at: certDir,
                    includingPropertiesForKeys: nil,
                    options: []
                ).filter { $0.pathExtension.lowercased() == "p12" }
                
                if let provisionPath = provisionFiles?.first, let p12Path = p12Files?.first {
                    copyFromProvisionAndP12(provisionPath: provisionPath, p12Path: p12Path)
                }
            }
        }
    }
    
    /// Copy certificates from root to Certificates directory
    private func copyCertificatesFromRootToSubdirectory() {
        let fileManager = FileManager.default
        
        // Ensure certificates exist at root level
        guard fileManager.fileExists(atPath: rootServerCrtPath.path) &&
              fileManager.fileExists(atPath: rootServerPemPath.path) else {
            return
        }
        
        // Create a new certificate directory or find most recent
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certsDir = docsDir.appendingPathComponent("Certificates")
        
        do {
            // Create Certificates directory if it doesn't exist
            if !fileManager.fileExists(atPath: certsDir.path) {
                try fileManager.createDirectory(at: certsDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Create new UUID for certificate directory
            let uuid = UUID().uuidString
            let certDir = certsDir.appendingPathComponent(uuid)
            
            // Create certificate directory if it doesn't exist
            if !fileManager.fileExists(atPath: certDir.path) {
                try fileManager.createDirectory(at: certDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Copy files to certificate directory
            let certPath = certDir.appendingPathComponent("server.crt")
            let pemPath = certDir.appendingPathComponent("server.pem")
            
            try fileManager.copyItem(at: rootServerCrtPath, to: certPath)
            try fileManager.copyItem(at: rootServerPemPath, to: pemPath)
            
            Debug.shared.log(
                message: "Copied server certificates from root to \(uuid)",
                type: .info
            )
        } catch {
            Debug.shared.log(
                message: "Error copying certificates to subdirectory: \(error.localizedDescription)",
                type: .error
            )
        }
    }
    
    /// Extract certificates from a backdoor file and copy to root
    private func extractAndCopyFromBackdoorFile(at backdoorFilePath: URL) {
        do {
            // Read backdoor file data
            let backdoorData = try Data(contentsOf: backdoorFilePath)
            let backdoorFile = try BackdoorDecoder.decodeBackdoor(from: backdoorData)
            
            // Extract certificate data
            let certificateData = SecCertificateCopyData(backdoorFile.certificate) as Data
            
            // Write files to root documents directory
            try certificateData.write(to: rootServerCrtPath)
            try backdoorFile.p12Data.write(to: rootServerPemPath)
            
            Debug.shared.log(
                message: "Extracted and copied certificates from backdoor file to root",
                type: .info
            )
        } catch {
            Debug.shared.log(
                message: "Error extracting from backdoor file: \(error.localizedDescription)",
                type: .error
            )
        }
    }
    
    /// Copy mobileprovision and p12 files to root as server certificates
    private func copyFromProvisionAndP12(provisionPath: URL, p12Path: URL) {
        do {
            // Read files
            let provisionData = try Data(contentsOf: provisionPath)
            let p12Data = try Data(contentsOf: p12Path)
            
            // Write files to root documents directory
            try provisionData.write(to: rootServerCrtPath)
            try p12Data.write(to: rootServerPemPath)
            
            Debug.shared.log(
                message: "Copied provision and p12 files to root as server certificates",
                type: .info
            )
        } catch {
            Debug.shared.log(
                message: "Error copying provision and p12: \(error.localizedDescription)",
                type: .error
            )
        }
    }
    
    // MARK: - Notification Handlers
    
    /// Handle certificate change notifications
    @objc private func handleCertificateChange(_ notification: Notification) {
        // Synchronize certificates when certificate list changes
        DispatchQueue.global(qos: .utility).async {
            self.synchronizeCertificates()
        }
    }
}
