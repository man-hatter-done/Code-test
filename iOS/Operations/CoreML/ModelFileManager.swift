// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Manages ML model file operations and ensures it's available for the app
final class ModelFileManager {
    static let shared = ModelFileManager()
    
    private init() {}
    
    // Default model metadata - used only as fallback naming convention
    private let defaultModelName = "dynamic_model"
    private let modelExtension = "mlmodel"
    
    /// Get or set up the models directory in the Documents folder
    private func getModelDirectory() -> URL? {
        do {
            let docsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            // We'll use two model directories:
            // 1. AIModels - for models created by AILearningManager
            // 2. Models - as a fallback for backward compatibility
            let modelsDir = docsURL.appendingPathComponent("AIModels", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: modelsDir.path) {
                try FileManager.default.createDirectory(
                    at: modelsDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            return modelsDir
            
        } catch {
            Debug.shared.log(message: "Error getting/creating AI models directory: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Check for user-generated models in the documents directory
    func findUserGeneratedModel() -> URL? {
        Debug.shared.log(message: "Looking for user-generated models", type: .info)
        
        guard let modelsDir = getModelDirectory() else {
            return nil
        }
        
        do {
            // Check the directory for model files
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil)
            
            // First look for mlmodel files
            let modelFiles = contents.filter { 
                $0.pathExtension == modelExtension
            }.sorted { (url1, url2) -> Bool in
                // Sort by modification date (newest first)
                guard let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return false
                }
                return date1 > date2
            }
            
            if let latestModel = modelFiles.first {
                Debug.shared.log(message: "Found user-generated model: \(latestModel.lastPathComponent)", type: .info)
                return latestModel
            }
            
            // If no .mlmodel files, check for compiled .mlmodelc directories as fallback
            let compiledModelDirs = contents.filter {
                $0.pathExtension == "mlmodelc" && $0.hasDirectoryPath
            }.sorted { (url1, url2) -> Bool in
                // Sort by modification date (newest first)
                guard let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return false
                }
                return date1 > date2
            }
            
            if let latestCompiledModel = compiledModelDirs.first {
                Debug.shared.log(message: "Found compiled user-generated model: \(latestCompiledModel.lastPathComponent)", type: .info)
                return latestCompiledModel
            }
            
            // Check the legacy Models directory as fallback
            let legacyModelsDir = modelsDir.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
            
            if fileManager.fileExists(atPath: legacyModelsDir.path) {
                let legacyContents = try fileManager.contentsOfDirectory(at: legacyModelsDir, includingPropertiesForKeys: nil)
                let legacyModels = legacyContents.filter { $0.pathExtension == modelExtension }
                
                if let legacyModel = legacyModels.first {
                    Debug.shared.log(message: "Found legacy model: \(legacyModel.lastPathComponent)", type: .info)
                    return legacyModel
                }
            }
            
        } catch {
            Debug.shared.log(message: "Error searching for user-generated models: \(error.localizedDescription)", type: .error)
        }
        
        Debug.shared.log(message: "No user-generated models found", type: .info)
        return nil
    }
    
    /// Create a URL for a new model file with timestamp
    func createModelURL(versionSuffix: String? = nil) -> URL? {
        guard let modelsDir = getModelDirectory() else {
            return nil
        }
        
        // Create a timestamped model name for uniqueness
        let timestamp = Int(Date().timeIntervalSince1970)
        let suffix = versionSuffix ?? "\(timestamp)"
        let modelFileName = "\(defaultModelName)_\(suffix).\(modelExtension)"
        
        return modelsDir.appendingPathComponent(modelFileName)
    }
    
    /// Setup the initial model directory structure
    func setupModelDirectories() {
        // Just ensure the directories exist
        _ = getModelDirectory()
        
        // Create a legacy directory for backward compatibility
        do {
            let docsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let legacyDir = docsURL.appendingPathComponent("Models", isDirectory: true)
            
            if !FileManager.default.fileExists(atPath: legacyDir.path) {
                try FileManager.default.createDirectory(
                    at: legacyDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        } catch {
            Debug.shared.log(message: "Error creating legacy model directory: \(error.localizedDescription)", type: .error)
        }
    }
    
    /// Copy a model file to the models directory
    func copyModelToDocuments(from sourceURL: URL, versionSuffix: String? = nil) -> URL? {
        guard let destinationURL = createModelURL(versionSuffix: versionSuffix) else {
            return nil
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            Debug.shared.log(message: "Successfully copied model to: \(destinationURL.path)", type: .info)
            return destinationURL
        } catch {
            Debug.shared.log(message: "Failed to copy model: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Prepare the model system - now focused on user-generated models
    func prepareMLModel(completion: @escaping (Result<URL?, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Set up the directory structure first
            self.setupModelDirectories()
            
            // Look for existing user-generated models
            if let userModel = self.findUserGeneratedModel() {
                DispatchQueue.main.async {
                    completion(.success(userModel))
                }
                return
            }
            
            // No models found, but directories are ready - that's okay now
            // We'll build a model dynamically later when we have enough data
            DispatchQueue.main.async {
                Debug.shared.log(message: "No models available yet. System prepared for dynamic model creation.", type: .info)
                completion(.success(nil))
            }
        }
    }
}

/// Errors that can occur during model file operations
enum ModelError: Error, LocalizedError {
    case modelNotFound
    case copyFailed
    case directoryCreationFailed
    case insufficientTrainingData
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "No CoreML model available yet - one will be created based on your usage"
        case .copyFailed:
            return "Failed to copy CoreML model to Documents directory"
        case .directoryCreationFailed:
            return "Failed to create directory for AI models"
        case .insufficientTrainingData:
            return "Not enough data available to create a custom AI model yet"
        }
    }
}
