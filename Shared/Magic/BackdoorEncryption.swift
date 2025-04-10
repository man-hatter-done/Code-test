//
// BackdoorEncryption.swift
//
// Implements custom encryption and decryption for .backdoor files
// Based on a Feistel network with custom padding and permutation
//

import Foundation
import CryptoKit

/// Provides custom encryption and decryption capabilities for .backdoor files
/// This implementation matches the Python reference implementation for compatibility
class BackdoorEncryption {
    
    // Hardcoded secret key for encryption and decryption
    private static let SECRET = "bdg_was_here_2025_backdoor_245".data(using: .utf8)!
    
    // Derive key using SHA256
    private static var KEY: Data {
        return SHA256.hash(data: SECRET).withUnsafeBytes { Data($0) }
    }
    
    /// Pads data to align with block size
    /// - Parameters:
    ///   - data: The data to pad
    ///   - blockSize: Block size (default: 16 bytes)
    /// - Returns: Padded data
    static func pad(_ data: Data, blockSize: Int = 16) -> Data {
        if data.count % blockSize == 0 {
            return data
        }
        
        let paddingLength = blockSize - (data.count % blockSize)
        var paddedData = data
        paddedData.append(contentsOf: [UInt8](repeating: 0, count: paddingLength))
        return paddedData
    }
    
    /// Custom permutation for obfuscation (byte reversal)
    /// - Parameter block: Block to permute
    /// - Returns: Permuted block
    static func permute(_ block: Data) -> Data {
        return Data(block.reversed())
    }
    
    /// Transformation function for Feistel network
    /// - Parameters:
    ///   - data: Input data
    ///   - roundKey: Round key
    /// - Returns: Transformed data
    static func F(_ data: Data, roundKey: Data) -> Data {
        var combined = data
        combined.append(roundKey)
        
        let hash = SHA256.hash(data: combined)
        return hash.withUnsafeBytes { bytes in
            return Data(bytes.prefix(8))
        }
    }
    
    /// Encrypts a single 16-byte block using a Feistel network
    /// - Parameters:
    ///   - block: 16-byte block to encrypt
    ///   - key: Encryption key
    /// - Returns: Encrypted block
    static func encryptBlock(_ block: Data, key: Data) -> Data {
        var L = block.prefix(8)
        var R = block.suffix(8)
        
        for round in 0..<4 {
            // Create round key
            let roundBytes = withUnsafeBytes(of: UInt32(round).bigEndian) { Data($0) }
            var roundKeyInput = key
            roundKeyInput.append(roundBytes)
            let roundKey = SHA256.hash(data: roundKeyInput).withUnsafeBytes { Data($0.prefix(8)) }
            
            // Apply Feistel function
            let FVal = F(R, roundKey: roundKey)
            
            // XOR left side with F output
            var newR = Data(count: 8)
            for i in 0..<8 {
                newR[i] = L[i] ^ FVal[i]
            }
            
            // Swap sides for next round
            L = R
            R = newR
        }
        
        // Combine R and L (note the order is swapped at the end)
        var result = R
        result.append(L)
        return result
    }
    
    /// Decrypts a single 16-byte block using a Feistel network
    /// - Parameters:
    ///   - block: 16-byte block to decrypt
    ///   - key: Decryption key
    /// - Returns: Decrypted block
    static func decryptBlock(_ block: Data, key: Data) -> Data {
        var R = block.prefix(8)
        var L = block.suffix(8)
        
        for round in (0..<4).reversed() {
            // Create round key (same as in encryption)
            let roundBytes = withUnsafeBytes(of: UInt32(round).bigEndian) { Data($0) }
            var roundKeyInput = key
            roundKeyInput.append(roundBytes)
            let roundKey = SHA256.hash(data: roundKeyInput).withUnsafeBytes { Data($0.prefix(8)) }
            
            // Apply Feistel function
            let FVal = F(L, roundKey: roundKey)
            
            // XOR right side with F output
            var newL = Data(count: 8)
            for i in 0..<8 {
                newL[i] = R[i] ^ FVal[i]
            }
            
            // Swap sides for next round
            R = L
            L = newL
        }
        
        // Combine L and R
        var result = L
        result.append(R)
        return result
    }
    
    /// Encrypts data using custom block cipher
    /// - Parameters:
    ///   - data: Data to encrypt
    ///   - key: Optional custom key (uses default if nil)
    /// - Returns: Encrypted data
    static func encryptData(_ data: Data, key: Data? = nil) -> Data {
        let encryptionKey = key ?? KEY
        let paddedData = pad(data)
        
        // Split into 16-byte blocks
        var encryptedData = Data()
        
        for i in stride(from: 0, to: paddedData.count, by: 16) {
            let blockEnd = min(i + 16, paddedData.count)
            let block = paddedData[i..<blockEnd]
            
            // Encrypt and permute each block
            let encryptedBlock = permute(encryptBlock(block, key: encryptionKey))
            encryptedData.append(encryptedBlock)
        }
        
        return encryptedData
    }
    
    /// Decrypts data using custom block cipher
    /// - Parameters:
    ///   - encryptedData: Data to decrypt
    ///   - key: Optional custom key (uses default if nil)
    ///   - originalLength: Length of the original data before padding
    /// - Returns: Decrypted data
    static func decryptData(_ encryptedData: Data, key: Data? = nil, originalLength: Int) -> Data {
        let decryptionKey = key ?? KEY
        var decryptedData = Data()
        
        // Process each 16-byte block
        for i in stride(from: 0, to: encryptedData.count, by: 16) {
            let blockEnd = min(i + 16, encryptedData.count)
            let block = encryptedData[i..<blockEnd]
            
            // Reverse permutation and decrypt
            let decryptedBlock = decryptBlock(permute(block), key: decryptionKey)
            decryptedData.append(decryptedBlock)
        }
        
        // Trim to original length
        return decryptedData.prefix(originalLength)
    }
}
