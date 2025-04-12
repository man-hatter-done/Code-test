// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit
import UniformTypeIdentifiers

/// Extension to fix file upload functionality in Home tab
extension HomeViewController {
    
    /// Enhanced file import function with improved security-scoped resource handling
    @objc func enhancedImportFile() {
        // Improved security-scoped resource access with proper feedback
        let documentTypes = [
            UTType.item,
            UTType.content,
            UTType.compositeContent,
            UTType.archive,
            UTType.zip,
            UTType.data
        ]
        
        // Create document picker with proper configuration
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: documentTypes)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        
        // Apply LED styling to indicate active state
        addLEDEffectsToDocumentPicker(documentPicker)
        
        // Present the document picker
        present(documentPicker, animated: true) {
            // Log the presentation for debugging
            Debug.shared.log(message: "Document picker presented for file import", type: .info)
        }
    }
    
    /// Apply LED effects to document picker for better visibility
    private func addLEDEffectsToDocumentPicker(_ picker: UIDocumentPickerViewController) {
        // We need to wait until the picker is presented to apply effects
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Get the navigation bar from the picker
            if let navigationBar = picker.navigationController?.navigationBar {
                // Add subtle LED effect to navigation bar
                navigationBar.addLEDEffect(
                    color: UIColor.systemBlue,
                    intensity: 0.3,
                    spread: 8,
                    animated: true,
                    animationDuration: 2.0
                )
            }
        }
    }
    
    /// Fixed implementation for document picker delegate method
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // Enable activity indicator to show loading state
        activityIndicator.startAnimating()
        
        // Process documents in background to keep UI responsive
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Use dispatch group to track completion of all imports
            let importGroup = DispatchGroup()
            
            // Track success/failure counts
            var successCount = 0
            var failureCount = 0
            var failures: [String] = []
            
            // Process each URL
            for url in urls {
                importGroup.enter()
                
                // Start accessing security-scoped resource
                let canAccess = url.startAccessingSecurityScopedResource()
                
                if canAccess {
                    Debug.shared.log(message: "Started accessing security-scoped resource for \(url.lastPathComponent)", type: .info)
                } else {
                    Debug.shared.log(message: "Failed to get security-scoped resource access for \(url.lastPathComponent)", type: .warning)
                }
                
                // Use defer to ensure we stop accessing the resource even if an error occurs
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                        Debug.shared.log(message: "Stopped accessing security-scoped resource", type: .debug)
                    }
                }
                
                do {
                    // Check if the file still exists
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        throw FileAppError.fileNotFound(url.lastPathComponent)
                    }
                    
                    // Process the file
                    try self?.processImportedFile(url: url)
                    
                    // Update success counter
                    DispatchQueue.main.async {
                        successCount += 1
                    }
                } catch {
                    // Log error
                    Debug.shared.log(message: "Error importing file \(url.lastPathComponent): \(error.localizedDescription)", type: .error)
                    
                    // Update failure counter
                    DispatchQueue.main.async {
                        failureCount += 1
                        failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                
                // Mark this import as complete
                importGroup.leave()
            }
            
            // When all imports are complete
            importGroup.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                
                // Stop the activity indicator
                self.activityIndicator.stopAnimating()
                
                // Refresh file list
                self.loadFiles()
                
                // Show result with LED indicator
                if failureCount == 0 {
                    // All succeeded
                    self.showLEDSuccessMessage(count: successCount)
                } else if successCount == 0 {
                    // All failed
                    self.showLEDErrorMessage(failures: failures)
                } else {
                    // Mixed results
                    self.showLEDMixedResultMessage(successes: successCount, failures: failureCount)
                }
                
                // Add haptic feedback
                let feedbackType: UINotificationFeedbackGenerator.FeedbackType = failureCount == 0 ? .success : .warning
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(feedbackType)
            }
        }
    }
    
    /// Process a single imported file
    private func processImportedFile(url: URL) throws {
        // Get a unique filename that won't conflict with existing files
        let fileName = getUniqueFileName(for: url.lastPathComponent)
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)
        
        Debug.shared.log(message: "Processing import: \(url.path) to \(destinationURL.path)", type: .info)
        
        // Create files directory if needed
        try FileManager.default.createDirectory(
            at: documentsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Process ZIP files specially
        if url.pathExtension.lowercased() == "zip" {
            try FileManager.default.unzipItem(at: url, to: documentsDirectory)
            return
        }
        
        // For regular files, copy to destination
        try FileManager.default.copyItem(at: url, to: destinationURL)
        
        // Verify the copy was successful
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw FileAppError.fileCreationFailed(fileName)
        }
    }
    
    /// Show a success message with LED effect
    private func showLEDSuccessMessage(count: Int) {
        let message = count == 1 ? "File imported successfully" : "\(count) files imported successfully"
        showLEDIndicator(type: .success, message: message)
    }
    
    /// Show an error message with LED effect
    private func showLEDErrorMessage(failures: [String]) {
        let message = failures.count == 1 ? "Failed to import file: \(failures.first ?? "")" : "Failed to import \(failures.count) files"
        showLEDIndicator(type: .error, message: message)
        
        // For multiple failures, also show a detailed report
        if failures.count > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let detailedAlert = UIAlertController(
                    title: "Import Failures",
                    message: failures.joined(separator: "\n\n"),
                    preferredStyle: .alert
                )
                detailedAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(detailedAlert, animated: true)
            }
        }
    }
    
    /// Show a mixed result message with LED effect
    private func showLEDMixedResultMessage(successes: Int, failures: Int) {
        let message = "Imported \(successes) files successfully, \(failures) failed"
        showLEDIndicator(type: .warning, message: message)
    }
    
    /// Show an LED indicator with message
    private func showLEDIndicator(type: LEDIndicatorType, message: String) {
        // Create container view
        let container = UIView()
        container.backgroundColor = type.backgroundColor
        container.alpha = 0
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        // Create message label
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        // Layout
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15)
        ])
        
        // Add LED glow effect
        container.addLEDEffect(
            color: type.glowColor,
            intensity: 0.7,
            spread: 10,
            animated: true,
            animationDuration: 1.0
        )
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1.0
        }
        
        // Automatically hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.5, animations: {
                container.alpha = 0
            }, completion: { _ in
                container.removeFromSuperview()
            })
        }
    }
    
    /// Override the original importFile to use the enhanced version
    @objc override func importFile() {
        enhancedImportFile()
    }
}

/// LED indicator types if not already defined
fileprivate enum LEDIndicatorType {
    case success
    case error
    case warning
    case info
    
    var backgroundColor: UIColor {
        switch self {
        case .success: return UIColor.systemGreen.withAlphaComponent(0.8)
        case .error: return UIColor.systemRed.withAlphaComponent(0.8)
        case .warning: return UIColor.systemOrange.withAlphaComponent(0.8)
        case .info: return UIColor.systemBlue.withAlphaComponent(0.8)
        }
    }
    
    var glowColor: UIColor {
        switch self {
        case .success: return .systemGreen
        case .error: return .systemRed
        case .warning: return .systemOrange
        case .info: return .systemBlue
        }
    }
}
