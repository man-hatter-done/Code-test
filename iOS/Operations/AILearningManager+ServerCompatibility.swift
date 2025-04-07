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
        
        // Train model using only local data
        let result = trainNewModel()
        
        if result.success {
            Debug.shared.log(message: "Enhanced local training succeeded: model \(result.version)", type: .info)
        } else {
            Debug.shared.log(message: "Enhanced local training failed: \(result.errorMessage ?? "unknown error")", type: .error)
        }
    }
    
    /// Process web search data for learning
    /// Used to improve AI responses based on search queries
    func processWebSearchData(query: String, results: [String]) {
        guard isLearningEnabled else { return }
        
        // Create behavior record for the search
        let searchDetails: [String: String] = [
            "query": query,
            "resultCount": "\(results.count)",
            "topResult": results.first ?? ""
        ]
        
        // Record as a user behavior
        recordUserBehavior(
            action: "web_search",
            screen: "AI Assistant",
            duration: 0,
            details: searchDetails
        )
        
        Debug.shared.log(message: "Processed web search data for learning: \(query)", type: .debug)
    }
    
    /// Collect user data in background for learning
    /// This is a replacement for the server data collection
    func collectUserDataInBackground() {
        // This is handled by local storage now
        // Just log that it was requested
        Debug.shared.log(message: "Background user data collection triggered", type: .debug)
    }
    
    /// Queue interactions for local processing
    private func queueForLocalProcessing() {
        // Local processing is handled directly in the recordInteraction method
        // This method exists for backward compatibility
    }
    
    /// Queue interactions for server sync
    /// This method exists for backward compatibility but does nothing
    private func queueForServerSync() {
        // No-op since server sync is disabled
    }
}
