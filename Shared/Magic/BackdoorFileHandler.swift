import Foundation
import Security

struct BackdoorFile {
    let certificate: SecCertificate // DER-encoded certificate
    let p12Data: Data              // Raw .p12 file data
    let mobileProvisionData: Data  // Raw .mobileprovision file data
    let signature: Data            // Signature over mobileprovision data
}

class BackdoorDecoder {
    static func decodeBackdoor(from data: Data) throws -> BackdoorFile {
        var offset = 0
        
        // Helper to read a length-prefixed chunk
        func readChunk(from data: Data, offset: inout Int) throws -> Data {
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
    
    static func verifySignature(certificate: SecCertificate, data: Data, signature: Data) throws {
        // Get public key from certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            throw DecodingError.invalidCertificate("Failed to extract public key")
        }
        
        // Create a trust object to evaluate the certificate (optional, depending on your needs)
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        guard status == errSecSuccess, let trustObject = trust else {
            throw DecodingError.invalidCertificate("Failed to create trust object")
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
    
    // Create an encoder for backdoor files
    static func encodeBackdoor(backdoorFile: BackdoorFile) -> Data {
        var data = Data()
        
        // Helper to write a length-prefixed chunk
        func writeChunk(_ chunkData: Data, to data: inout Data) {
            let length = UInt32(chunkData.count).bigEndian
            var lengthBytes = withUnsafeBytes(of: length) { Data($0) }
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
    
    // Helper method to check if a file is likely a backdoor file format
    static func isBackdoorFormat(data: Data) -> Bool {
        // Basic heuristic: Check if the file starts with a 4-byte length field
        // followed by what appears to be a DER-encoded certificate
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
}

enum DecodingError: Error {
    case invalidFormat(String)
    case invalidCertificate(String)
    case unsupportedAlgorithm(String)
    case signatureVerificationFailed(String)
}

// Add utility extensions for BackdoorFile
extension BackdoorFile {
    // Extract and return certificate name for display
    var certificateName: String {
        // Get certificate summary (typically CN=Name)
        let summary = SecCertificateCopySubjectSummary(certificate) as String? ?? "Unknown Certificate"
        return summary
    }
    
    // Get certificate expiration date
    var expirationDate: Date? {
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        guard status == errSecSuccess, let trustObj = trust else {
            return nil
        }
        
        // Evaluate the trust to get certificate properties
        var result: SecTrustResultType = .invalid
        SecTrustEvaluate(trustObj, &result)
        
        // Get certificate properties
        if let properties = SecTrustCopyProperties(trustObj) as? [[String: Any]],
           let firstCert = properties.first,
           let expirationDate = firstCert["kSecPropertyNotValidAfter"] as? Date {
            return expirationDate
        }
        
        return nil
    }
    
    // Helper to save the mobileprovision file
    func saveMobileProvision(to url: URL) throws {
        try mobileProvisionData.write(to: url)
    }
    
    // Helper to save the p12 file
    func saveP12(to url: URL) throws {
        try p12Data.write(to: url)
    }
}
