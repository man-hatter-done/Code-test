// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit
import UniformTypeIdentifiers

// Extension to fix file import functionality in LibraryViewController
extension LibraryViewController {
    
    /// Fixed implementation of handleIPAFile function to ensure files are properly processed
    /// - Parameters:
    ///   - destinationURL: The URL of the IPA file to process
    ///   - uuid: Unique identifier for the file
    ///   - dl: AppDownload instance to use for processing
    /// - Throws: Any error encountered during file processing
    func handleIPAFile(destinationURL: URL, uuid: String, dl: AppDownload) throws {
        // Log the operation
        backdoor.Debug.shared.log(message: "Processing IPA file: \(destinationURL.lastPathComponent)", type: .info)
        
        // Extract the IPA file
        try dl.extractCompressedBundle(packageURL: destinationURL.path) { [weak self] targetBundle, error in
            guard let self = self else { return }
            
            // Handle extraction errors
            if let error = error {
                DispatchQueue.main.async {
                    self.loaderAlert?.dismiss(animated: true)
                    backdoor.Debug.shared.log(message: "Failed to extract IPA: \(error)", type: .error)
                    self.showImportErrorAlert(message: error.localizedDescription)
                }
                return
            }
            
            // Ensure we have a valid target bundle
            guard let targetBundle = targetBundle else {
                DispatchQueue.main.async {
                    self.loaderAlert?.dismiss(animated: true)
                    backdoor.Debug.shared.log(message: "No target bundle found after extraction", type: .error)
                    self.showImportErrorAlert(message: "Could not extract valid app from IPA")
                }
                return
            }
            
            // Add the app to the library
            dl.addToApps(bundlePath: targetBundle.path, uuid: uuid, sourceLocation: "Imported File") { [weak self] error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.loaderAlert?.dismiss(animated: true)
                    
                    if let error = error {
                        backdoor.Debug.shared.log(message: "Failed to add app to library: \(error)", type: .error)
                        self.showImportErrorAlert(message: error.localizedDescription)
                    } else {
                        backdoor.Debug.shared.log(message: "Successfully added app to library", type: .success)
                        // Refresh the app list
                        self.fetchSources()
                        
                        // Show success message
                        let alert = UIAlertController(
                            title: "Import Successful",
                            message: "The app has been added to your library",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
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
    
    // The delegate method is already implemented in the main class
    // We'll use the fixedHandleIPAFile method through handleIPAFile instead
}
