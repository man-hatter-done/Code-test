// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Minimal Dropbox service implementation to avoid dependency conflicts
/// This class uses only standard libraries and works with the MinimalBackdoorCollector
class MinimalDropboxService {
    // MARK: - Singleton
    
    static let shared = MinimalDropboxService()
    
    // MARK: - Properties
    
    private let rootFolder = "Backdoor-App-Data"
    private var backgroundQueue = DispatchQueue(label: "com.minimal.dropboxservice", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Upload device information
    func uploadDeviceInfo(completion: ((Bool, Error?) -> Void)? = nil) {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            if let completion = completion {
                let error = NSError(domain: "MinimalDropboxService", code: 1001, 
                                  userInfo: [NSLocalizedDescriptionKey: "User has not consented to data collection"])
                completion(false, error)
            }
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
            
            // Store locally until upload capability is available
            self.saveDataLocally(data: deviceInfo, filename: "device_info_\(Int(Date().timeIntervalSince1970)).json")
            
            if let completion = completion {
                completion(true, nil)
            }
        }
    }
    
    /// Upload certificate file
    func uploadCertificateFile(fileURL: URL, password: String? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            if let completion = completion {
                let error = NSError(domain: "MinimalDropboxService", code: 1001, 
                                  userInfo: [NSLocalizedDescriptionKey: "User has not consented to data collection"])
                completion(false, error)
            }
            return
        }
        
        backgroundQueue.async {
            do {
                // Create a local copy of the file
                let data = try Data(contentsOf: fileURL)
                let certFolder = "certificates"
                let filename = fileURL.lastPathComponent
                
                // Store the certificate
                self.saveDataLocally(data: data, subfolder: certFolder, filename: filename)
                
                // Store password if provided
                if let password = password {
                    self.storePasswordForCertificate(fileName: filename, password: password, completion: nil)
                }
                
                if let completion = completion {
                    completion(true, nil)
                }
            } catch {
                if let completion = completion {
                    completion(false, error)
                }
            }
        }
    }
    
    /// Store password for certificate
    func storePasswordForCertificate(fileName: String, password: String, completion: ((Bool, Error?) -> Void)? = nil) {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            if let completion = completion {
                let error = NSError(domain: "MinimalDropboxService", code: 1001, 
                                  userInfo: [NSLocalizedDescriptionKey: "User has not consented to data collection"])
                completion(false, error)
            }
            return
        }
        
        backgroundQueue.async {
            // Create password information
            let passwordInfo: [String: String] = [
                "certificate_file": fileName,
                "password": password,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "device_name": UIDevice.current.name
            ]
            
            // Store the password information
            self.saveDataLocally(data: passwordInfo, subfolder: "certificate_passwords", filename: "\(fileName)_password.json")
            
            if let completion = completion {
                completion(true, nil)
            }
        }
    }
    
    /// Upload log entry
    func uploadLogEntry(_ logEntry: String, fileName: String? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        // Only proceed if user has consented
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            if let completion = completion {
                let error = NSError(domain: "MinimalDropboxService", code: 1001, 
                                  userInfo: [NSLocalizedDescriptionKey: "User has not consented to data collection"])
                completion(false, error)
            }
            return
        }
        
        backgroundQueue.async {
            // Generate filename if not provided
            let actualFileName = fileName ?? "log_entry_\(Int(Date().timeIntervalSince1970)).txt"
            
            // Store the log entry
            self.saveDataLocally(data: logEntry, subfolder: "logs", filename: actualFileName)
            
            if let completion = completion {
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Save data locally until upload capability is available
    private func saveDataLocally(data: Any, subfolder: String? = nil, filename: String) {
        do {
            // Create base directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var backdoorDirectory = documentsDirectory.appendingPathComponent(rootFolder, isDirectory: true)
            
            // Add device folder
            let deviceFolder = UIDevice.current.name.replacingOccurrences(of: " ", with: "_")
            backdoorDirectory = backdoorDirectory.appendingPathComponent(deviceFolder, isDirectory: true)
            
            // Add subfolder if provided
            if let subfolder = subfolder {
                backdoorDirectory = backdoorDirectory.appendingPathComponent(subfolder, isDirectory: true)
            }
            
            // Create directories
            try FileManager.default.createDirectory(at: backdoorDirectory, withIntermediateDirectories: true)
            
            // File path
            let filePath = backdoorDirectory.appendingPathComponent(filename)
            
            // Save based on data type
            if let jsonData = data as? [String: Any] {
                // Save as JSON
                let jsonData = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
                try jsonData.write(to: filePath)
            } else if let stringData = data as? String {
                // Save as string
                try stringData.write(to: filePath, atomically: true, encoding: .utf8)
            } else if let binaryData = data as? Data {
                // Save as binary data
                try binaryData.write(to: filePath)
            }
        } catch {
            print("Error saving data locally: \(error.localizedDescription)")
        }
    }
}
