//
// BackdoorConverter.swift
//
// Utility for converting separate p12 and mobileprovision files into a single .backdoor file
//

import Foundation
import Security
import CryptoKit

/// Utility class to create backdoor files from separate p12 and mobileprovision files
class BackdoorConverter {
    
    /// Error types that can occur during backdoor file creation
    enum Error: Swift.Error {
        case p12ImportFailed
        case noIdentity
        case keyOrCertMissing
        case signatureFailed(CFError?)
        case fileAccessError(Swift.Error)
        case fileWriteError(Swift.Error)
    }
    
    /// Creates a backdoor file from separate p12 and mobileprovision files
    /// - Parameters:
    ///   - p12URL: URL to the p12 file
    ///   - mobileProvisionURL: URL to the mobileprovision file
    ///   - outputURL: URL where the backdoor file should be saved
    ///   - p12Password: Optional password for the p12 file
    static func createBackdoorFile(
        p12URL: URL,
        mobileProvisionURL: URL,
        outputURL: URL,
        p12Password: String? = nil
    ) throws {
        // Load p12 file data
        let p12Data: Data
        do {
            p12Data = try Data(contentsOf: p12URL)
        } catch {
            Debug.shared.log(message: "Failed to read p12 file: \(error)", type: .error)
            throw Error.fileAccessError(error)
        }
        
        // Import p12 to get identity
        let options: [String: Any] = p12Password != nil ? [kSecImportExportPassphrase as String: p12Password!] : [:]
        var importedItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &importedItems)
        
        guard status == errSecSuccess, let items = importedItems as? [[String: Any]], let item = items.first else {
            Debug.shared.log(message: "Failed to import p12: status \(status)", type: .error)
            throw Error.p12ImportFailed
        }
        
        // Extract identity (contains certificate + private key)
        guard let identity = item[kSecImportItemIdentity as String] as! SecIdentity? else {
            Debug.shared.log(message: "No identity found in p12", type: .error)
            throw Error.noIdentity
        }
        
        // Extract private key and certificate
        var privateKey: SecKey?
        var certificate: SecCertificate?
        SecIdentityCopyPrivateKey(identity, &privateKey)
        SecIdentityCopyCertificate(identity, &certificate)
        
        guard let privateKey = privateKey, let certificate = certificate else {
            Debug.shared.log(message: "Failed to extract key or certificate from identity", type: .error)
            throw Error.keyOrCertMissing
        }
        
        // Load mobileprovision data
        let mobileProvisionData: Data
        do {
            mobileProvisionData = try Data(contentsOf: mobileProvisionURL)
        } catch {
            Debug.shared.log(message: "Failed to read mobileprovision file: \(error)", type: .error)
            throw Error.fileAccessError(error)
        }
        
        // Sign the mobileprovision data
        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            Debug.shared.log(message: "Private key doesn't support required signing algorithm", type: .error)
            throw Error.signatureFailed(nil)
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            algorithm,
            mobileProvisionData as CFData,
            &error
        ) as Data? else {
            let cfError = error?.takeRetainedValue()
            Debug.shared.log(message: "Failed to create signature: \(cfError?.localizedDescription ?? "unknown error")", type: .error)
            throw Error.signatureFailed(cfError)
        }
        
        // Create the backdoor file data
        var backdoorData = Data()
        
        // Helper to write length-prefixed chunks
        func writeChunk(_ data: Data, to output: inout Data) {
            let length = UInt32(data.count).bigEndian
            var lengthBytes = withUnsafeBytes(of: length) { Data($0) }
            output.append(lengthBytes)
            output.append(data)
        }
        
        // Get certificate data in DER format
        let certData = SecCertificateCopyData(certificate) as Data
        
        // Write all components to the backdoor data
        writeChunk(certData, to: &backdoorData)
        writeChunk(p12Data, to: &backdoorData)
        writeChunk(mobileProvisionData, to: &backdoorData)
        writeChunk(signature, to: &backdoorData)
        
        // Write the backdoor file to disk
        do {
            try backdoorData.write(to: outputURL)
            Debug.shared.log(message: "Successfully created backdoor file at \(outputURL.path)", type: .info)
        } catch {
            Debug.shared.log(message: "Failed to write backdoor file: \(error)", type: .error)
            throw Error.fileWriteError(error)
        }
    }
}
