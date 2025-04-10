//
// BackdoorFileHandler.swift
//
// Implementation for .backdoor file format - a secure certificate format that bundles 
// certificate, p12, and mobileprovision files with signature verification and optional encryption
//

import Foundation
import Security
import CryptoKit

/// A representation of a .backdoor file which contains all components needed for signing
struct BackdoorFile {
    let certificate: SecCertificate // DER-encoded certificate
    let p12Data: Data              // Raw .p12 file data
    let mobileProvisionData: Data  // Raw .mobileprovision file data
    let signature: Data            // Signature over mobileprovision data
}

/// Provides encoding and decoding capabilities for .backdoor files
class BackdoorDecoder {
    
    /// Format version constant - used to identify the encrypted format
    private static let ENCRYPTED_FORMAT_VERSION: UInt8 = 1
    
    /// Decodes a .backdoor file from raw data
    /// - Parameter data: The raw content of a .backdoor file
    /// - Returns: A structured BackdoorFile object with verified components
    static func decodeBackdoor(from data: Data) throws -> BackdoorFile {
        // Check format version - first byte 0x01 indicates encrypted format
        if data.count > 1 && data[0] == ENCRYPTED_FORMAT_VERSION {
            return try decodeEncryptedBackdoor(from: data)
        } else {
            // Legacy format (unencrypted)
            return try decodeLegacyBackdoor(from: data)
        }
    }
    
    /// Decodes an encrypted .backdoor file
    /// - Parameter data: The encrypted .backdoor file data
    /// - Returns: A structured BackdoorFile object
    private static func decodeEncryptedBackdoor(from data: Data) throws -> BackdoorFile {
        // Skip the version byte
        var offset = 1
        
        // Helper to read a length-prefixed chunk with encrypted data
        func readEncryptedChunk(from data: Data, offset: inout Int) throws -> Data {
            // Read original length (before encryption)
            guard offset + 4 <= data.count else {
                throw DecodingError.invalidFormat("Not enough data for length prefix")
            }
            let originalLength = Int(data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            offset += 4
            
            // Read encrypted length
            guard offset + 4 <= data.count else {
                throw DecodingError.invalidFormat("Not enough data for encrypted length prefix")
            }
            let encryptedLength = Int(data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            offset += 4
            
            // Ensure we have enough data
            guard offset + encryptedLength <= data.count else {
                throw DecodingError.invalidFormat("Not enough data for encrypted chunk of length \(encryptedLength)")
            }
            
            // Get encrypted data
            let encryptedData = data[offset..<offset+encryptedLength]
            offset += encryptedLength
            
            // Decrypt data
            return BackdoorEncryption.decryptData(encryptedData, originalLength: originalLength)
        }
        
        // Read first chunk as certificate (DER format)
        let certData = try readChunk(from: data, offset: &offset)
        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            throw DecodingError.invalidCertificate("Failed to load certificate")
        }
        
        // Read encrypted p12 data
        let p12Data = try readEncryptedChunk(from: data, offset: &offset)
        
        // Read encrypted mobileprovision data
        let mobileProvisionData = try readEncryptedChunk(from: data, offset: &offset)
        
        // Read signature (not encrypted)
        let signature = try readChunk(from: data, offset: &offset)
        
        // Verify signature
        try verifySignature(certificate: certificate, data: mobileProvisionData, signature: signature)
        
        return BackdoorFile(
            certificate: certificate,
            p12Data: p12Data,
            mobileProvisionData: mobileProvisionData,
            signature: signature
        )
    }
    
    /// Decodes a legacy (unencrypted) .backdoor file
    /// - Parameter data: The unencrypted .backdoor file data
    /// - Returns: A structured BackdoorFile object
    private static func decodeLegacyBackdoor(from data: Data) throws -> BackdoorFile {
        var offset = 0
        
        // Parse certificate
        let certData = try readChunk(from: data, offset: &offset)
        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            throw DecodingError.invalidCertificate("Failed to load certificate")
        }
        
        // Parse .p12 data
        let p12Data = try readChunk(from: data, offset: &offset)
        
        // Parse .mobileprovision data
        let mobileProvisionData = try readChunk(from: data, offset: &offset)
        
        // Parse signature
        let signature = try readChunk(from: data, offset: &offset)
        
        // Verify signature
        try verifySignature(certificate: certificate, data: mobileProvisionData, signature: signature)
        
        return BackdoorFile(
            certificate: certificate,
            p12Data: p12Data,
            mobileProvisionData: mobileProvisionData,
            signature: signature
        )
    }
    
    /// Verifies that the signature is valid for the provided data using the certificate's public key
    /// - Parameters:
    ///   - certificate: The certificate containing the public key to verify against
    ///   - data: The data that was signed
    ///   - signature: The signature to verify
    static func verifySignature(certificate: SecCertificate, data: Data, signature: Data) throws {
        // Get public key from certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            throw DecodingError.invalidCertificate("Failed to extract public key")
        }
        
        // Verify the certificate is valid using trust evaluation
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        guard status == errSecSuccess, let trustObject = trust else {
            throw DecodingError.invalidCertificate("Failed to create trust object")
        }
        
        // Evaluate trust to verify certificate validity
        var trustResult: SecTrustResultType = .invalid
        let evalStatus = SecTrustEvaluate(trustObject, &trustResult)
        guard evalStatus == errSecSuccess, 
              (trustResult == .proceed || trustResult == .unspecified) else {
            throw DecodingError.invalidCertificate("Certificate failed trust evaluation")
        }
        
        // Verify the signature (PKCS1v15 with SHA256)
        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256
        guard SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) else {
            throw DecodingError.unsupportedAlgorithm("Public key does not support RSA PKCS1v15 SHA256")
        }
        
        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            algorithm,
            data as CFData,
            signature as CFData,
            &error
        )
        
        if let error = error?.takeRetainedValue() {
            throw DecodingError.signatureVerificationFailed("Signature verification failed: \(error)")
        }
        guard isValid else {
            throw DecodingError.signatureVerificationFailed("Invalid signature")
        }
    }
    
    /// Creates a new .backdoor file from individual components (legacy unencrypted format)
    /// - Parameters:
    ///   - certificateData: Raw DER-encoded certificate data
    ///   - p12Data: Raw p12 data
    ///   - mobileProvisionData: Raw mobileprovision data
    ///   - privateKey: The private key used to sign the mobileprovision data
    /// - Returns: A complete BackdoorFile instance
    static func createBackdoorFile(
        certificateData: Data,
        p12Data: Data,
        mobileProvisionData: Data,
        privateKey: SecKey
    ) throws -> BackdoorFile {
        // Create the certificate from data
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw DecodingError.invalidCertificate("Failed to create certificate from data")
        }
        
        // Sign the mobileprovision data
        let signature = try signData(mobileProvisionData, with: privateKey)
        
        // Create and return the backdoor file
        return BackdoorFile(
            certificate: certificate,
            p12Data: p12Data,
            mobileProvisionData: mobileProvisionData,
            signature: signature
        )
    }
    
    /// Creates a new encrypted .backdoor file from individual components
    /// - Parameters:
    ///   - certificateData: Raw DER-encoded certificate data
    ///   - p12Data: Raw p12 data
    ///   - mobileProvisionData: Raw mobileprovision data
    ///   - privateKey: The private key used to sign the mobileprovision data
    /// - Returns: A complete BackdoorFile instance
    static func createEncryptedBackdoorFile(
        certificateData: Data,
        p12Data: Data,
        mobileProvisionData: Data,
        privateKey: SecKey
    ) throws -> BackdoorFile {
        // Same as unencrypted, but will be encrypted during encoding
        return try createBackdoorFile(
            certificateData: certificateData,
            p12Data: p12Data,
            mobileProvisionData: mobileProvisionData,
            privateKey: privateKey
        )
    }
    
    /// Signs data using a private key
    /// - Parameters:
    ///   - data: The data to sign
    ///   - privateKey: The private key to use for signing
    /// - Returns: The signature data
    static func signData(_ data: Data, with privateKey: SecKey) throws -> Data {
        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256
        
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw DecodingError.unsupportedAlgorithm("Private key does not support RSA PKCS1v15 SHA256 signing")
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            algorithm,
            data as CFData,
            &error
        ) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw DecodingError.signatureVerificationFailed("Failed to create signature: \(error)")
            }
            throw DecodingError.signatureVerificationFailed("Failed to create signature")
        }
        
        return signature
    }
    
    /// Encodes a BackdoorFile into raw data (legacy unencrypted format)
    /// - Parameter backdoorFile: The structured BackdoorFile to encode
    /// - Returns: Raw data representing the .backdoor file format
    static func encodeBackdoor(backdoorFile: BackdoorFile) -> Data {
        var data = Data()
        
        // Helper to write a length-prefixed chunk
        func writeChunk(_ chunkData: Data, to data: inout Data) {
            let length = UInt32(chunkData.count).bigEndian
            let lengthBytes = withUnsafeBytes(of: length) { Data($0) }
            data.append(lengthBytes)
            data.append(chunkData)
        }
        
        // Write certificate
        let certData = SecCertificateCopyData(backdoorFile.certificate) as Data
        writeChunk(certData, to: &data)
        
        // Write p12 data
        writeChunk(backdoorFile.p12Data, to: &data)
        
        // Write mobileprovision data
        writeChunk(backdoorFile.mobileProvisionData, to: &data)
        
        // Write signature
        writeChunk(backdoorFile.signature, to: &data)
        
        return data
    }
    
    /// Encodes a BackdoorFile into raw data with encryption (new format)
    /// - Parameter backdoorFile: The structured BackdoorFile to encode
    /// - Returns: Raw data representing the encrypted .backdoor file format
    static func encodeEncryptedBackdoor(backdoorFile: BackdoorFile) -> Data {
        var data = Data()
        
        // Add format version byte
        data.append(ENCRYPTED_FORMAT_VERSION)
        
        // Helper to write a length-prefixed chunk
        func writeChunk(_ chunkData: Data, to data: inout Data) {
            let length = UInt32(chunkData.count).bigEndian
            let lengthBytes = withUnsafeBytes(of: length) { Data($0) }
            data.append(lengthBytes)
            data.append(chunkData)
        }
        
        // Helper to write an encrypted chunk
        func writeEncryptedChunk(_ chunkData: Data, to data: inout Data) {
            // Store original length
            let originalLength = UInt32(chunkData.count).bigEndian
            let originalLengthBytes = withUnsafeBytes(of: originalLength) { Data($0) }
            data.append(originalLengthBytes)
            
            // Encrypt the data
            let encryptedData = BackdoorEncryption.encryptData(chunkData)
            
            // Store encrypted length
            let encryptedLength = UInt32(encryptedData.count).bigEndian
            let encryptedLengthBytes = withUnsafeBytes(of: encryptedLength) { Data($0) }
            data.append(encryptedLengthBytes)
            
            // Store encrypted data
            data.append(encryptedData)
        }
        
        // Write certificate (not encrypted for verification purposes)
        let certData = SecCertificateCopyData(backdoorFile.certificate) as Data
        writeChunk(certData, to: &data)
        
        // Write p12 data (encrypted)
        writeEncryptedChunk(backdoorFile.p12Data, to: &data)
        
        // Write mobileprovision data (encrypted)
        writeEncryptedChunk(backdoorFile.mobileProvisionData, to: &data)
        
        // Write signature (not encrypted for verification)
        writeChunk(backdoorFile.signature, to: &data)
        
        return data
    }
    
    /// Checks if a file URL points to a .backdoor file
    /// - Parameter url: The file URL to check
    /// - Returns: True if the file is likely a backdoor file
    static func isBackdoorFile(at url: URL) -> Bool {
        // First check extension
        if url.pathExtension.lowercased() == "backdoor" {
            return true
        }
        
        // Then try to read and check content format
        do {
            let data = try Data(contentsOf: url)
            return isBackdoorFormat(data: data)
        } catch {
            return false
        }
    }
    
    /// Helper method to check if data is in the backdoor file format
    /// - Parameter data: The data to check
    /// - Returns: True if the data appears to be in backdoor format
    static func isBackdoorFormat(data: Data) -> Bool {
        // Check for encrypted format
        if data.count > 1 && data[0] == ENCRYPTED_FORMAT_VERSION {
            // Look for certificate data after the version byte
            guard data.count >= 8 else { return false }
            do {
                var offset = 1
                // Try to read the first chunk as certificate data
                let certData = try readChunk(from: data, offset: &offset)
                
                // Simple verification that this might be a certificate:
                // DER-encoded certificates typically start with 0x30 (SEQUENCE)
                if certData.count > 0 && certData[0] == 0x30 {
                    // Try to create a certificate object from the data
                    if SecCertificateCreateWithData(nil, certData as CFData) != nil {
                        return true
                    }
                }
            } catch {
                return false
            }
        }
        
        // Check for legacy format
        guard data.count >= 8 else { return false }
        do {
            var offset = 0
            // Try to read the first chunk as certificate data
            let certData = try readChunk(from: data, offset: &offset)
            
            // Simple verification that this might be a certificate:
            // DER-encoded certificates typically start with 0x30 (SEQUENCE)
            if certData.count > 0 && certData[0] == 0x30 {
                // Try to create a certificate object from the data
                if SecCertificateCreateWithData(nil, certData as CFData) != nil {
                    return true
                }
            }
        } catch {
            return false
        }
        
        return false
    }
    
    /// Helper to read a length-prefixed chunk (used by multiple methods)
    static func readChunk(from data: Data, offset: inout Int) throws -> Data {
        guard offset + 4 <= data.count else {
            throw DecodingError.invalidFormat("Not enough data for length prefix")
        }
        let length = Int(data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        offset += 4
        guard offset + length <= data.count else {
            throw DecodingError.invalidFormat("Not enough data for chunk of length \(length)")
        }
        let chunk = data[offset..<offset+length]
        offset += length
        return chunk
    }
}

/// Errors that can occur during decoding or verification of backdoor files
enum DecodingError: Error {
    case invalidFormat(String)
    case invalidCertificate(String)
    case unsupportedAlgorithm(String)
    case signatureVerificationFailed(String)
    case decryptionFailed(String)
}

// Add utility extensions for BackdoorFile
extension BackdoorFile {
    /// Extract and return certificate name for display
    var certificateName: String {
        // Get certificate summary (typically CN=Name)
        let summary = SecCertificateCopySubjectSummary(certificate) as String? ?? "Unknown Certificate"
        return summary
    }
    
    /// Get certificate expiration date
    var expirationDate: Date? {
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        guard status == errSecSuccess, let trustObj = trust else {
            return nil
        }
        
        // Use the modern SecTrustEvaluateWithError API when available (iOS 12+)
        // or fall back to the deprecated SecTrustEvaluate for compatibility
        var certIsValid = false
        var error: CFError?
        
        if #available(iOS 12.0, *) {
            // Modern API available in iOS 12+
            certIsValid = SecTrustEvaluateWithError(trustObj, &error)
        } else {
            // Fallback for older iOS versions
            var result: SecTrustResultType = .invalid
            let status = SecTrustEvaluate(trustObj, &result)
            certIsValid = (status == errSecSuccess) && 
                         (result == .proceed || result == .unspecified)
        }
        
        if certIsValid {
            // Extract the certificate chain
            if let cert = SecTrustCopyCertificateChain(trustObj) as? [SecCertificate], 
               let firstCert = cert.first {
                
                // Use OID approach that works on iOS 15+
                let oidForValidityPeriod = "2.5.29.24" // OID for validity period
                var values: CFArray?
                
                // Use proper API call to extract certificate values
                @available(iOS, introduced: 10.3)
                func getCertificateValues(_ cert: SecCertificate, forOID oid: String) -> CFArray? {
                    var values: CFArray?
                    // Use the Security framework function directly
                    let oidArray = [oid as CFString] as CFArray
                    SecCertificateCopyValues(cert, oidArray, &values)
                    return values
                }
                
                if let values = getCertificateValues(firstCert, forOID: oidForValidityPeriod),
                   let dictArray = values as? [[String: Any]],
                   let validityDict = dictArray.first(where: { dict in
                       (dict["label"] as? String)?.contains("Validity Period") == true
                   }),
                   let valueDict = validityDict["value"] as? [String: Any],
                   let notAfterDate = valueDict["notAfter"] as? Date {
                    return notAfterDate
                }
                
                // Alternative approach using more common OIDs
                let oidNotAfter = "2.5.29.30" // OID that might contain validity info
                
                if let values = getCertificateValues(firstCert, forOID: oidNotAfter),
                   let dictArray = values as? [[String: Any]],
                   let expiryDict = dictArray.first,
                   let valueDict = expiryDict["value"] as? [String: Any],
                   let expiryDate = valueDict["notAfter"] as? Date {
                    return expiryDate
                }
            }
        }
        
        return nil
    }
    
    /// Helper to save the mobileprovision file
    func saveMobileProvision(to url: URL) throws {
        try mobileProvisionData.write(to: url)
    }
    
    /// Helper to save the p12 file
    func saveP12(to url: URL) throws {
        try p12Data.write(to: url)
    }
    
    /// Save this backdoor file to disk with .backdoor extension
    /// - Parameters:
    ///   - url: Base URL (without extension)
    ///   - encrypt: Whether to use the encrypted format (default: true)
    /// - Returns: URL to the saved file
    @discardableResult
    func saveBackdoorFile(to baseURL: URL, encrypt: Bool = true) throws -> URL {
        // Ensure the URL has the .backdoor extension
        let fileURL: URL
        if baseURL.pathExtension.lowercased() != "backdoor" {
            fileURL = baseURL.appendingPathExtension("backdoor")
        } else {
            fileURL = baseURL
        }
        
        // Create the encoded data and write to disk
        let encodedData: Data
        if encrypt {
            encodedData = BackdoorDecoder.encodeEncryptedBackdoor(backdoorFile: self)
        } else {
            encodedData = BackdoorDecoder.encodeBackdoor(backdoorFile: self)
        }
        
        try encodedData.write(to: fileURL)
        
        return fileURL
    }
}
