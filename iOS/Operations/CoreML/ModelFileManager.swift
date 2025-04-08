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
    
    // Model file name and extension
    private let modelFileName = "model_1.0.0"
    private let modelExtension = "mlmodel"
    
    /// Copy the model from project directory to Documents directory
    func prepareMLModel(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check if model already exists in Documents
                if let existingModelURL = self.getModelURLInDocuments() {
                    DispatchQueue.main.async {
                        Debug.shared.log(message: "ML model already exists in Documents directory", type: .info)
                        completion(.success(existingModelURL))
                    }
                    return
                }
                
                // Find model in project directory
                guard let sourceModelURL = self.findModelInProjectDirectory() else {
                    throw ModelError.modelNotFound
                }
                
                // Create destination URL in Documents directory
                let docsURL = try FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let modelsDir = docsURL.appendingPathComponent("Models", isDirectory: true)
                
                // Create Models directory if it doesn't exist
                try FileManager.default.createDirectory(
                    at: modelsDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                
                let destinationURL = modelsDir.appendingPathComponent("\(modelFileName).\(modelExtension)")
                
                // Copy the file
                try FileManager.default.copyItem(at: sourceModelURL, to: destinationURL)
                
                DispatchQueue.main.async {
                    Debug.shared.log(message: "ML model successfully copied to Documents directory", type: .info)
                    completion(.success(destinationURL))
                }
                
            } catch {
                DispatchQueue.main.async {
                    Debug.shared.log(message: "Failed to prepare ML model: \(error.localizedDescription)", type: .error)
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get URL to model in Documents directory if it exists
    func getModelURLInDocuments() -> URL? {
        do {
            let docsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let modelsDir = docsURL.appendingPathComponent("Models", isDirectory: true)
            let modelURL = modelsDir.appendingPathComponent("\(modelFileName).\(modelExtension)")
            
            if FileManager.default.fileExists(atPath: modelURL.path) {
                return modelURL
            }
            return nil
        } catch {
            Debug.shared.log(message: "Error checking Documents directory for model: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Find the model file in various possible locations in the project
    private func findModelInProjectDirectory() -> URL? {
        // Get current bundle and file manager
        let bundle = Bundle.main
        let fileManager = FileManager.default
        
        // Define a comprehensive set of possible locations to check
        var possibleLocations: [URL] = []
        
        // 1. Check app bundle resources first (highest priority)
        if let bundlePath = bundle.path(forResource: modelFileName, ofType: modelExtension, inDirectory: "model") {
            possibleLocations.append(URL(fileURLWithPath: bundlePath))
        }
        
        // 2. Check app bundle resources without directory
        if let bundlePath = bundle.path(forResource: modelFileName, ofType: modelExtension) {
            possibleLocations.append(URL(fileURLWithPath: bundlePath))
        }
        
        // 3. Check iOS/Resources/model directory
        possibleLocations.append(bundle.bundleURL
            .appendingPathComponent("model")
            .appendingPathComponent("\(modelFileName).\(modelExtension)"))
        
        // 4. Check root model directory
        possibleLocations.append(URL(fileURLWithPath: "./model/\(modelFileName).\(modelExtension)"))
        
        // 5. Try the repository root model folder
        possibleLocations.append(URL(fileURLWithPath: "/model/\(modelFileName).\(modelExtension)"))
        
        // 6. Look for the model relative to the bundle in various ways
        let bundleURL = bundle.bundleURL
        
        // 6.1 One level up
        possibleLocations.append(bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("model")
            .appendingPathComponent("\(modelFileName).\(modelExtension)"))
        
        // 6.2 Two levels up (often project root)
        possibleLocations.append(bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("model")
            .appendingPathComponent("\(modelFileName).\(modelExtension)"))
        
        // 6.3 Check in iOS/Resources/model
        possibleLocations.append(bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("iOS")
            .appendingPathComponent("Resources")
            .appendingPathComponent("model")
            .appendingPathComponent("\(modelFileName).\(modelExtension)"))
        
        // 7. Common workspace paths
        possibleLocations.append(URL(fileURLWithPath: "/workspace/model/\(modelFileName).\(modelExtension)"))
        possibleLocations.append(URL(fileURLWithPath: "/workspace/Main-final-test-v6_Code-test/model/\(modelFileName).\(modelExtension)"))
        possibleLocations.append(URL(fileURLWithPath: "/workspace/im-a-test-bdg_Backdoor-v1/model/\(modelFileName).\(modelExtension)"))
        
        // Check each location
        for url in possibleLocations {
            if fileManager.fileExists(atPath: url.path) {
                Debug.shared.log(message: "Found ML model at: \(url.path)", type: .info)
                return url
            }
        }
        
        // Last resort: recursive search from app bundle parent directory (limited depth)
        if let url = searchRecursivelyForModel(startingFrom: bundleURL.deletingLastPathComponent(), maxDepth: 4) {
            return url
        }
        
        Debug.shared.log(message: "ML model not found in any expected location", type: .error)
        return nil
    }
    
    /// Search recursively for the model file (with depth limit)
    private func searchRecursivelyForModel(startingFrom directory: URL, maxDepth: Int) -> URL? {
        guard maxDepth > 0 else { return nil }
        
        let fileManager = FileManager.default
        let targetFileName = "\(modelFileName).\(modelExtension)"
        
        do {
            // Get contents of the directory
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            
            // Check for the model file
            for url in contents {
                if url.lastPathComponent == targetFileName {
                    Debug.shared.log(message: "Found ML model through recursive search: \(url.path)", type: .info)
                    return url
                }
            }
            
            // Look for a "model" directory
            if let modelDir = contents.first(where: { $0.lastPathComponent == "model" && $0.hasDirectoryPath }) {
                let modelFileURL = modelDir.appendingPathComponent(targetFileName)
                if fileManager.fileExists(atPath: modelFileURL.path) {
                    Debug.shared.log(message: "Found ML model in model directory: \(modelFileURL.path)", type: .info)
                    return modelFileURL
                }
            }
            
            // Recursively search subdirectories (with limited depth)
            for url in contents where url.hasDirectoryPath {
                if let found = searchRecursivelyForModel(startingFrom: url, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        } catch {
            // Silently ignore directory access errors during recursive search
        }
        
        return nil
    }
}

/// Errors that can occur during model file operations
enum ModelError: Error, LocalizedError {
    case modelNotFound
    case copyFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "CoreML model file not found in expected locations"
        case .copyFailed:
            return "Failed to copy CoreML model to Documents directory"
        }
    }
}
