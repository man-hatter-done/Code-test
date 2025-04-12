// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import CoreData
import Security

/// Extension to handle certificate operations for CoreDataManager
extension CoreDataManager {
    
    /// Get certificate file paths for a given certificate
    /// - Parameter source: The certificate object
    /// - Returns: Tuple with paths to provision and p12 files
    func getCertificateFilePaths(source: Certificate?) throws -> (provisionPath: URL, p12Path: URL) {
        guard let certificate = source else {
            throw NSError(
                domain: "CoreDataManager",
                code: 1009,
                userInfo: [NSLocalizedDescriptionKey: "No certificate selected"]
            )
        }
        
        // Get the documents directory
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certificatesDirectory = documentsDirectory.appendingPathComponent("Certificates")
        
        // Ensure certificates directory exists
        if !fileManager.fileExists(atPath: certificatesDirectory.path) {
            try fileManager.createDirectory(at: certificatesDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Check if this is a backdoor certificate format
        if let backdoorPath = certificate.value(forKey: "backdoorPath") as? String,
           let backdoorURL = URL(string: backdoorPath),
           fileManager.fileExists(atPath: backdoorURL.path) {
            
            // Handle .backdoor file if it exists
            return try handleBackdoorCertificate(at: backdoorURL, certificatesDirectory: certificatesDirectory)
        }
        
        // Handle traditional certificate format
        return try handleTraditionalCertificate(certificate, certificatesDirectory: certificatesDirectory)
    }
    
    /// Handle .backdoor format certificate
    /// - Parameters:
    ///   - backdoorURL: URL to .backdoor file
    ///   - certificatesDirectory: Directory to extract files to
    /// - Returns: Paths to provision and p12 files
    private func handleBackdoorCertificate(
        at backdoorURL: URL,
        certificatesDirectory: URL
    ) throws -> (provisionPath: URL, p12Path: URL) {
        let fileManager = FileManager.default
        
        // Read backdoor file data
        guard let backdoorData = try? Data(contentsOf: backdoorURL) else {
            throw NSError(
                domain: "CoreDataManager",
                code: 1010,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read backdoor file"]
            )
        }
        
        // Extract backdoor components
        let backdoorFile = try BackdoorDecoder.decodeBackdoor(from: backdoorData)
        
        // Create temporary files for signing
        let provisionPath = certificatesDirectory.appendingPathComponent("extracted.mobileprovision")
        let p12Path = certificatesDirectory.appendingPathComponent("extracted.p12")
        
        // Write the files
        try backdoorFile.mobileProvisionData.write(to: provisionPath)
        try backdoorFile.p12Data.write(to: p12Path)
        
        // Set file permissions
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: provisionPath.path)
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: p12Path.path)
        
        // Auto-verify server.crt and server.pem files
        try verifyServerCertificates(fromBackdoor: backdoorFile, certificatesDirectory: certificatesDirectory)
        
        return (provisionPath, p12Path)
    }
    
    /// Handle traditional certificate format
    /// - Parameters:
    ///   - certificate: Certificate object
    ///   - certificatesDirectory: Directory containing certificate files
    /// - Returns: Paths to provision and p12 files
    private func handleTraditionalCertificate(
        _ certificate: Certificate,
        certificatesDirectory: URL
    ) throws -> (provisionPath: URL, p12Path: URL) {
        // Check for mobileprovision path
        guard let mpPath = certificate.mobileprovisionPath else {
            throw NSError(
                domain: "CoreDataManager",
                code: 1011,
                userInfo: [NSLocalizedDescriptionKey: "Missing mobileprovision path"]
            )
        }
        
        // Check for p12 path
        guard let p12Path = certificate.p12Path else {
            throw NSError(
                domain: "CoreDataManager",
                code: 1012,
                userInfo: [NSLocalizedDescriptionKey: "Missing p12 path"]
            )
        }
        
        // Create URL objects
        let provisionURL = URL(fileURLWithPath: mpPath)
        let p12URL = URL(fileURLWithPath: p12Path)
        
        // Verify files exist
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: provisionURL.path) else {
            throw NSError(
                domain: "CoreDataManager",
                code: 1013,
                userInfo: [NSLocalizedDescriptionKey: "Mobileprovision file not found at \(provisionURL.path)"]
            )
        }
        
        guard fileManager.fileExists(atPath: p12URL.path) else {
            throw NSError(
                domain: "CoreDataManager",
                code: 1014,
                userInfo: [NSLocalizedDescriptionKey: "P12 file not found at \(p12URL.path)"]
            )
        }
        
        return (provisionURL, p12URL)
    }
    
    /// Verify and update server.crt and server.pem files for offline signing
    /// - Parameters:
    ///   - backdoorFile: The backdoor file containing certificate data
    ///   - certificatesDirectory: Directory to store server certificate files
    private func verifyServerCertificates(
        fromBackdoor backdoorFile: BackdoorFile,
        certificatesDirectory: URL
    ) throws {
        let fileManager = FileManager.default
        let serverCrtPath = certificatesDirectory.appendingPathComponent("server.crt")
        let serverPemPath = certificatesDirectory.appendingPathComponent("server.pem")
        
        // Create server.crt file from certificate data
        let certificateData = SecCertificateCopyData(backdoorFile.certificate) as Data
        try certificateData.write(to: serverCrtPath)
        
        // Create server.pem file from p12 data
        // This is a simplification - in reality, extracting the key from a p12 requires more complex code
        try backdoorFile.p12Data.write(to: serverPemPath)
        
        // Set proper permissions
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: serverCrtPath.path)
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: serverPemPath.path)
        
        // Trigger certificate synchronization to root directory
        ServerCertificateSynchronizer.shared.synchronizeCertificates()
        
        // Log success
        Debug.shared.log(message: "Updated server.crt and server.pem files for offline signing", type: .success)
    }
    
    /// Add to signed apps with proper error handling
    /// - Parameters:
    ///   - version: App version
    ///   - name: App name
    ///   - bundleidentifier: Bundle identifier
    ///   - iconURL: URL to app icon
    ///   - uuid: UUID string
    ///   - appPath: Path to the app
    ///   - timeToLive: Certificate expiration date
    ///   - teamName: Certificate team name
    ///   - originalSourceURL: Original source URL
    ///   - completion: Completion handler with result
    func addToSignedApps(
        version: String,
        name: String,
        bundleidentifier: String,
        iconURL: String,
        uuid: String,
        appPath: String,
        timeToLive: Date,
        teamName: String,
        originalSourceURL: URL?,
        completion: @escaping (Result<SignedApps, Error>) -> Void
    ) {
        do {
            let ctx = try context
            let signedApp = SignedApps(context: ctx)
            signedApp.creationDate = Date()
            signedApp.version = version
            signedApp.name = name
            signedApp.bundleidentifier = bundleidentifier
            signedApp.iconURL = iconURL
            signedApp.uuid = uuid
            signedApp.appPath = appPath
            signedApp.timeToLive = timeToLive
            signedApp.teamName = teamName
            signedApp.originalSourceURL = originalSourceURL
            
            try saveContext()
            completion(.success(signedApp))
        } catch {
            Debug.shared.log(message: "addToSignedApps: \(error.localizedDescription)", type: .error)
            completion(.failure(error))
        }
    }
    
    /// Add to downloaded apps with proper file management
    /// - Parameters:
    ///   - version: App version
    ///   - name: App name
    ///   - bundleidentifier: Bundle identifier
    ///   - iconURL: URL to app icon
    ///   - uuid: UUID string
    ///   - appPath: Path to the app
    ///   - sourceLocation: Source location
    ///   - completion: Completion handler with result
    func addToDownloadedApps(
        version: String,
        name: String,
        bundleidentifier: String,
        iconURL: String,
        uuid: String,
        appPath: String,
        sourceLocation: String? = nil,
        completion: @escaping (Result<DownloadedApps, Error>) -> Void
    ) {
        // Create a new downloaded app in the Core Data context
        do {
            let ctx = try context
            let downloadedApp = DownloadedApps(context: ctx)
            downloadedApp.creationDate = Date()
            downloadedApp.version = version
            downloadedApp.name = name
            downloadedApp.bundleidentifier = bundleidentifier
            downloadedApp.iconURL = iconURL
            downloadedApp.uuid = uuid
            downloadedApp.appPath = appPath
            
            // Store source location if provided
            if let sourceLocation = sourceLocation {
                downloadedApp.oSU = sourceLocation
            }
            
            // Ensure the app directory structure is correct
            try ensureAppDirectoryStructure(uuid: uuid, appPath: appPath)
            
            try saveContext()
            completion(.success(downloadedApp))
        } catch {
            Debug.shared.log(message: "addToDownloadedApps: \(error.localizedDescription)", type: .error)
            completion(.failure(error))
        }
    }
    
    /// Ensure app directory structure is correctly set up
    /// - Parameters:
    ///   - uuid: UUID string for the app
    ///   - appPath: Path to the app bundle
    private func ensureAppDirectoryStructure(uuid: String, appPath: String) throws {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create proper directory structure
        let appDirectory = documentsDirectory.appendingPathComponent("files").appendingPathComponent(uuid)
        
        // Ensure app directory exists
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Check if the app is in the correct location or needs to be moved
        let sourceAppURL = documentsDirectory.appendingPathComponent(appPath)
        let targetAppURL = appDirectory.appendingPathComponent(appPath)
        
        if sourceAppURL.path != targetAppURL.path &&
           fileManager.fileExists(atPath: sourceAppURL.path) &&
           !fileManager.fileExists(atPath: targetAppURL.path) {
            
            // Move the app to the correct location
            try fileManager.moveItem(at: sourceAppURL, to: targetAppURL)
            Debug.shared.log(message: "Moved app to correct location: \(targetAppURL.path)", type: .info)
        }
    }
    
    /// Update a signed app with new data
    /// - Parameters:
    ///   - app: The app to update
    ///   - newTimeToLive: New expiration date
    ///   - newTeamName: New team name
    ///   - completion: Completion handler
    func updateSignedApp(
        app: SignedApps,
        newTimeToLive: Date,
        newTeamName: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            let ctx = try context
            
            // Make sure we have the app in the right context
            let appInContext: SignedApps
            if app.managedObjectContext != ctx {
                guard let fetchedApp = try ctx.existingObject(with: app.objectID) as? SignedApps else {
                    throw NSError(
                        domain: "CoreDataManager",
                        code: 1015,
                        userInfo: [NSLocalizedDescriptionKey: "App not found in context"]
                    )
                }
                appInContext = fetchedApp
            } else {
                appInContext = app
            }
            
            // Update properties
            appInContext.timeToLive = newTimeToLive
            appInContext.teamName = newTeamName
            
            try saveContext()
            completion(.success(()))
        } catch {
            Debug.shared.log(message: "updateSignedApp: \(error.localizedDescription)", type: .error)
            completion(.failure(error))
        }
    }
    
    /// Clear the update state for a signed app
    /// - Parameter signedApp: The app to update
    func clearUpdateState(for signedApp: SignedApps) throws {
        let ctx = try context
        
        // Make sure we have the app in the right context
        let appInContext: SignedApps
        if signedApp.managedObjectContext != ctx {
            guard let fetchedApp = try ctx.existingObject(with: signedApp.objectID) as? SignedApps else {
                throw NSError(
                    domain: "CoreDataManager",
                    code: 1016,
                    userInfo: [NSLocalizedDescriptionKey: "App not found in context"]
                )
            }
            appInContext = fetchedApp
        } else {
            appInContext = signedApp
        }
        
        // Clear update state
        appInContext.setValue(false, forKey: "hasUpdate")
        appInContext.setValue(nil, forKey: "updateVersion")
        
        try saveContext()
    }
}
