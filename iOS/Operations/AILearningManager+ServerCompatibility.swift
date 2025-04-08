// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation

/// Extension providing server compatibility methods for AILearningManager
/// These methods support legacy code that expected server functionality
/// but now operate in a server-independent way
extension AILearningManager {
    
    /// This struct represents basic information about a trained model
    struct ModelInfo {
        let version: String
        let date: Date?
        let size: Int64?
    }
    
    /// Struct for model upload results
    struct ModelUploadResult {
        let success: Bool
        let message: String
    }
    
    /// Check if a trained model is available for upload
    /// Since server sync is disabled, this always returns false
    func isTrainedModelAvailableForUpload() -> Bool {
        return false
    }
    
    /// Get information about the current local model
    /// Used for display in the UI
    func getTrainedModelInfo() -> ModelInfo {
        let modelPath = modelsDirectory.appendingPathComponent("model_\(currentModelVersion).mlmodel")
        
        // Get file attributes if file exists
        var fileSize: Int64? = nil
        var modDate: Date? = nil
        
        if FileManager.default.fileExists(atPath: modelPath.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: modelPath.path)
                fileSize = attributes[.size] as? Int64
                modDate = attributes[.modificationDate] as? Date
            } catch {
                Debug.shared.log(message: "Error getting model file attributes: \(error)", type: .error)
            }
        }
        
        return ModelInfo(
            version: currentModelVersion,
            date: modDate,
            size: fileSize
        )
    }
    
    /// Simulate a model upload operation
    /// Since server sync is disabled, this returns a failure result
    func uploadTrainedModelToServer() async -> ModelUploadResult {
        return ModelUploadResult(
            success: false,
            message: "Server sync is disabled. Using local model only."
        )
    }
    
    /// Perform enhanced local model training
    /// This replaces the server-dependent model training with a fully local approach
    func performEnhancedLocalTraining() {
        Debug.shared.log(message: "Starting enhanced local model training", type: .info)
        
        // Delegate to internal implementation
        enhancedLocalTraining()
        
        Debug.shared.log(message: "Enhanced local training requested", type: .info)
    }
    
    /// Process web search data for learning
    /// Used to improve AI responses based on search queries
    /// Public API method - delegates to internal implementation
    func processWebSearchData(query: String, results: [String]) {
        // Delegate to the internal implementation in ModelUpload
        handleWebSearchData(query: query, results: results)
        
        // Additional logging specific to this context
        Debug.shared.log(message: "Processed web search data for learning: \(query)", type: .debug)
    }
    
    /// Log data collection events - safe replacement to avoid redeclarations
    private func logDataCollectionEvents() {
        Debug.shared.log(message: "Internal background user data collection triggered", type: .debug)
        Debug.shared.log(message: "Background user data collection triggered", type: .debug)
    }
    
    // Note: The queueForLocalProcessing method has been moved to AILearningManager+ServerSync.swift
    // to resolve duplicate method declarations
    
    /// Queue interactions for server sync
    /// This method exists for backward compatibility but does nothing
    private func queueForServerSync() {
        // No-op since server sync is disabled
    }
}
