// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit
import CoreData
import UniformTypeIdentifiers

// Extension to fix file import location and structure issues
extension LibraryViewController {
    
    /// Enhanced implementation of handleIPAFile to correctly store app files
    /// - Parameters:
    ///   - destinationURL: The URL of the IPA file to process
    ///   - uuid: Unique identifier for the file
    ///   - dl: AppDownload instance to use for processing
    /// - Throws: Any error encountered during file processing
    func handleIPAFile(destinationURL: URL, uuid: String, dl: AppDownload) throws {
        // Create semaphore for synchronous processing
        let semaphore = DispatchSemaphore(value: 0)
        var functionError: Error?
        
        // Log the operation
        backdoor.Debug.shared.log(message: "Processing IPA file: \(destinationURL.lastPathComponent)", type: .info)
        
        // Import and process the IPA file
        DispatchQueue(label: "AppImport").async {
            // 1. Extract the IPA file
            dl.extractCompressedBundle(packageURL: destinationURL.path) { [weak self] extractedBundlePath, error in
                guard let self = self else { 
                    semaphore.signal()
                    return 
                }
                
                // Handle extraction errors
                if let error = error {
                    backdoor.Debug.shared.log(message: "Failed to extract IPA: \(error)", type: .error)
                    functionError = error
                    semaphore.signal()
                    return
                }
                
                // Ensure we have a valid extracted bundle
                guard let bundlePath = extractedBundlePath else {
                    backdoor.Debug.shared.log(message: "No bundle path returned after extraction", type: .error)
                    functionError = NSError(domain: "LibraryViewController", code: 1001, 
                                          userInfo: [NSLocalizedDescriptionKey: "No valid app bundle found after extraction"])
                    semaphore.signal()
                    return
                }
                
                // 2. Fix the directory structure to ensure .app is in the correct location
                do {
                    let fileManager = FileManager.default
                    let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                    
                    // Create path structures
                    let filesDirectory = documentDirectory.appendingPathComponent("files")
                    let appDirectory = filesDirectory.appendingPathComponent(uuid)
                    
                    // Create directories if needed
                    if !fileManager.fileExists(atPath: filesDirectory.path) {
                        try fileManager.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
                    }
                    
                    if !fileManager.fileExists(atPath: appDirectory.path) {
                        try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                    }
                    
                    // Extract the app bundle name from the path
                    let bundleURL = URL(fileURLWithPath: bundlePath)
                    let appBundleName = bundleURL.lastPathComponent
                    
                    // Check if the app bundle is already in the correct location
                    let correctPath = appDirectory.appendingPathComponent(appBundleName)
                    
                    if bundleURL.path != correctPath.path {
                        backdoor.Debug.shared.log(
                            message: "Moving app bundle to correct location: \(correctPath.path)",
                            type: .info
                        )
                        
                        // Remove any existing file at target location
                        if fileManager.fileExists(atPath: correctPath.path) {
                            try fileManager.removeItem(at: correctPath)
                        }
                        
                        // Move the app bundle to the correct location
                        try fileManager.moveItem(at: bundleURL, to: correctPath)
                        
                        // Update bundlePath to the new location for CoreData entry
                        let updatedBundlePath = correctPath.path
                        
                        // 3. Add the app to CoreData with the correct path
                        dl.addToApps(bundlePath: updatedBundlePath, uuid: uuid, sourceLocation: "Imported") { error in
                            if let error = error {
                                backdoor.Debug.shared.log(message: "Failed to add app to library: \(error)", type: .error)
                                functionError = error
                            } else {
                                backdoor.Debug.shared.log(message: "App successfully added to library with correct path structure", type: .success)
                            }
                            semaphore.signal()
                        }
                    } else {
                        // App is already in the correct location
                        backdoor.Debug.shared.log(message: "App bundle already in correct location", type: .info)
                        
                        // Add to CoreData with existing path
                        dl.addToApps(bundlePath: bundlePath, uuid: uuid, sourceLocation: "Imported") { error in
                            if let error = error {
                                backdoor.Debug.shared.log(message: "Failed to add app to library: \(error)", type: .error)
                                functionError = error
                            } else {
                                backdoor.Debug.shared.log(message: "App successfully added to library", type: .success)
                            }
                            semaphore.signal()
                        }
                    }
                } catch {
                    backdoor.Debug.shared.log(message: "Error fixing app directory structure: \(error)", type: .error)
                    functionError = error
                    semaphore.signal()
                }
            }
        }
        
        // Wait for processing to complete
        semaphore.wait()
        
        // Check for errors
        if let error = functionError {
            backdoor.Debug.shared.log(message: "IPA processing failed: \(error)", type: .error)
            throw error
        }
        
        // Post notification to refresh the UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("lfetch"), object: nil)
        }
    }
    
    /// Show an error alert for import failures
    /// - Parameter message: The error message to display
    private func showImportErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Import Failed",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Applies all import-related fixes
    func applyImportFixes() {
        // Hook into the document picker delegate method
        // This is done at runtime using method swizzling
        Self.swizzleMethods(
            originalClass: LibraryViewController.self,
            originalSelector: #selector(documentPicker(_:didPickDocumentsAt:)),
            swizzledClass: LibraryViewController.self,
            swizzledSelector: #selector(fixedDocumentPicker(_:didPickDocumentsAt:))
        )
        
        // Log that fixes have been applied
        backdoor.Debug.shared.log(message: "Applied import location fixes to LibraryViewController", type: .info)
    }
    
    /// Fixed implementation of document picker delegate method
    @objc func fixedDocumentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }
        
        guard let loaderAlert = self.loaderAlert else {
            backdoor.Debug.shared.log(message: "Loader alert is not initialized.", type: LogType.error)
            return
        }
        
        DispatchQueue.main.async {
            self.present(loaderAlert, animated: true)
        }
        
        let dl = AppDownload()
        let uuid = UUID().uuidString
        
        // Start security-scoped resource access
        var didStartAccess = false
        if selectedFileURL.startAccessingSecurityScopedResource() {
            didStartAccess = true
            backdoor.Debug.shared.log(message: "Successfully started accessing security-scoped resource", type: LogType.info)
        } else {
            backdoor.Debug.shared.log(message: "Failed to start accessing security-scoped resource", type: LogType.warning)
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                // Verify file exists and is valid
                guard FileManager.default.fileExists(atPath: selectedFileURL.path) else {
                    throw NSError(domain: "com.backdoor.import", code: 404, userInfo: [NSLocalizedDescriptionKey: "File does not exist at path"])
                }
                
                // Use enhanced handler for IPA files
                try self?.handleIPAFile(destinationURL: selectedFileURL, uuid: uuid, dl: dl)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.loaderAlert?.dismiss(animated: true)
                    
                    // Show success alert
                    let alert = UIAlertController(
                        title: "Import Successful",
                        message: "The app has been successfully imported",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                
            } catch {
                backdoor.Debug.shared.log(message: "Failed to Import: \(error)", type: LogType.error)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.loaderAlert?.dismiss(animated: true)
                    self.showImportErrorAlert(message: error.localizedDescription)
                }
            }
            
            // End security-scoped resource access if we started it
            if didStartAccess {
                selectedFileURL.stopAccessingSecurityScopedResource()
                backdoor.Debug.shared.log(message: "Stopped accessing security-scoped resource", type: LogType.info)
            }
        }
    }
    
    // MARK: - Swizzling Helper
    
    /// Helper method to swizzle methods at runtime
    private static func swizzleMethods(
        originalClass: AnyClass,
        originalSelector: Selector,
        swizzledClass: AnyClass,
        swizzledSelector: Selector
    ) {
        guard let originalMethod = class_getInstanceMethod(originalClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector) else {
            return
        }
        
        let didAddMethod = class_addMethod(
            originalClass,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )
        
        if didAddMethod {
            // The method didn't exist - just added it
            backdoor.Debug.shared.log(message: "Added method to \(originalClass)", type: .debug)
        } else {
            // The method existed - exchange implementations
            method_exchangeImplementations(originalMethod, swizzledMethod)
            backdoor.Debug.shared.log(message: "Swizzled method on \(originalClass)", type: .debug)
        }
    }
}
