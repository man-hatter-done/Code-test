// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import AlertKit
import Foundation
import Nuke
import UIKit

extension SourceAppViewController: DownloadDelegate {
    func stopDownload(uuid: String) {
        DispatchQueue.main.async {
            if let task = DownloadTaskManager.shared.task(for: uuid) {
                if let cell = task.cell {
                    cell.stopDownload()
                }
                DownloadTaskManager.shared.removeTask(uuid: uuid)
            }
        }
    }

    func startDownload(uuid: String, indexPath _: IndexPath) {
        DispatchQueue.main.async {
            if let task = DownloadTaskManager.shared.task(for: uuid) {
                if let cell = task.cell {
                    cell.startDownload()
                }
                DownloadTaskManager.shared.updateTask(uuid: uuid, state: .inProgress(progress: 0.0))
            }
        }
    }

    func updateDownloadProgress(progress: Double, uuid: String) {
        DownloadTaskManager.shared.updateTask(uuid: uuid, state: .inProgress(progress: progress))
    }
}

extension SourceAppViewController {
    func startDownloadIfNeeded(
        for indexPath: IndexPath,
        in tableView: UITableView,
        downloadURL: URL?,
        appUUID: String?,
        sourceLocation: String
    ) {
        guard let downloadURL = downloadURL,
              let appUUID = appUUID,
              let cell = tableView.cellForRow(at: indexPath) as? AppTableViewCell else {
            return
        }

        setupCellForDownload(cell)
        let animationView = showDownloadAnimation(in: cell)
        
        // Add to task manager
        DownloadTaskManager.shared.addTask(uuid: appUUID, cell: cell, dl: cell.appDownload!)

        // Use NetworkManager to handle the download with improved error handling
        Task {
            do {
                let downloadedURL = try await downloadFile(downloadURL: downloadURL, appUUID: appUUID, indexPath: indexPath)
                try verifyDownloadedFile(at: downloadedURL)
                
                // Extract and process the bundle
                await processDownloadedBundle(
                    cell: cell,
                    animationView: animationView,
                    downloadedURL: downloadedURL,
                    appUUID: appUUID,
                    sourceLocation: sourceLocation
                )
            } catch {
                await handleDownloadError(error, cell: cell, animationView: animationView, appUUID: appUUID, downloadURL: downloadURL)
            }
        }
    }
    
    // MARK: - Private Download Helper Methods
    
    private func setupCellForDownload(_ cell: AppTableViewCell) {
        if cell.appDownload == nil {
            cell.appDownload = AppDownload()
            cell.appDownload?.dldelegate = self
        }
    }
    
    private func showDownloadAnimation(in cell: AppTableViewCell) -> UIView {
        // Show download animation in cell
        let animationView = cell.addAnimatedIcon(
            systemName: "arrow.down.circle",
            tintColor: .systemBlue,
            size: CGSize(width: 40, height: 40)
        )
        
        // Position animation in the cell
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            animationView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            animationView.widthAnchor.constraint(equalToConstant: 40),
            animationView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return animationView
    }
    
    private func downloadFile(downloadURL: URL, appUUID: String, indexPath: IndexPath) async throws -> URL {
        // Create a temporary file path for the download
        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent("app_\(appUUID).ipa")
        
        // Start download and show progress
        self.startDownload(uuid: appUUID, indexPath: indexPath)
        
        // Download file with URLSession
        let request = URLRequest(url: downloadURL)
        let (tempFileURL, _) = try await URLSession.shared.download(for: request)
        try FileManager.default.moveItem(at: tempFileURL, to: filePath)
        
        return filePath
    }
    
    private func verifyDownloadedFile(at url: URL) throws {
        let fileData = try Data(contentsOf: url)
        let checksum = CryptoHelper.shared.crc32(of: fileData)
        Debug.shared.log(message: "Download completed with checksum: \(checksum)", type: .info)
    }
    
    private func processDownloadedBundle(
        cell: AppTableViewCell,
        animationView: UIView,
        downloadedURL: URL,
        appUUID: String,
        sourceLocation: String
    ) async {
        cell.appDownload?.extractCompressedBundle(packageURL: downloadedURL.path) { targetBundle, error in
            // Remove animation when processing is complete
            DispatchQueue.main.async {
                animationView.removeFromSuperview()
            }
            
            if let error = error {
                self.handleExtractionError(error, cell: cell, appUUID: appUUID)
            } else if let targetBundle = targetBundle {
                self.processExtractedBundle(
                    targetBundle: targetBundle, 
                    cell: cell,
                    appUUID: appUUID,
                    sourceLocation: sourceLocation
                )
            }
        }
    }
    
    private func handleExtractionError(_ error: Error, cell: AppTableViewCell, appUUID: String) {
        DownloadTaskManager.shared.updateTask(uuid: appUUID, state: .failed(error: error))
        Debug.shared.log(message: "Extraction error: \(error.localizedDescription)", type: .error)
        
        showStatusAnimation(
            in: cell,
            systemName: "exclamationmark.circle",
            tintColor: .systemRed
        )
    }
    
    private func processExtractedBundle(
        targetBundle: String,
        cell: AppTableViewCell,
        appUUID: String,
        sourceLocation: String
    ) {
        cell.appDownload?.addToApps(bundlePath: targetBundle, uuid: appUUID, sourceLocation: sourceLocation) { error in
            if let error = error {
                DownloadTaskManager.shared.updateTask(uuid: appUUID, state: .failed(error: error))
                Debug.shared.log(message: "Failed to add app: \(error.localizedDescription)", type: .error)
            } else {
                DownloadTaskManager.shared.updateTask(uuid: appUUID, state: .completed)
                Debug.shared.log(message: "Done", type: .success)
                
                self.showStatusAnimation(
                    in: cell,
                    systemName: "checkmark.circle",
                    tintColor: .systemGreen
                )
                
                self.handleImmediateInstallIfNeeded(appUUID: appUUID)
            }
        }
    }
    
    private func handleImmediateInstallIfNeeded(appUUID: String) {
        // Check if immediate install is enabled
        if UserDefaults.standard.signingOptions.immediatelyInstallFromSource {
            DispatchQueue.main.async {
                let downloadedApps = CoreDataManager.shared.getDatedDownloadedApps()
                if let downloadedApp = downloadedApps.first(where: { $0.uuid == appUUID }) {
                    NotificationCenter.default.post(
                        name: Notification.Name("InstallDownloadedApp"),
                        object: nil,
                        userInfo: ["downloadedApp": downloadedApp]
                    )
                }
            }
        }
    }
    
    private func handleDownloadError(
        _ error: Error,
        cell: AppTableViewCell,
        animationView: UIView,
        appUUID: String,
        downloadURL: URL
    ) async {
        // Handle download errors with enhanced error reporting
        DownloadTaskManager.shared.updateTask(uuid: appUUID, state: .failed(error: error))
        
        // Remove animation
        await MainActor.run {
            animationView.removeFromSuperview()
        }
        
        // Log detailed error information
        logDownloadError(error, downloadURL: downloadURL)
        
        // Show error animation
        showStatusAnimation(
            in: cell,
            systemName: "exclamationmark.circle",
            tintColor: .systemRed
        )
    }
    
    private func logDownloadError(_ error: Error, downloadURL: URL) {
        if let networkError = error as? NetworkError {
            Debug.shared.log(
                message: "Network download error: \(networkError.localizedDescription)",
                type: .error
            )
            
            // Add detailed error diagnostics
            switch networkError {
            case .httpError(let statusCode):
                Debug.shared.log(message: "HTTP error status: \(statusCode)", type: .error)
            case .invalidURL:
                Debug.shared.log(message: "Invalid download URL: \(downloadURL)", type: .error)
            default:
                Debug.shared.log(
                    message: "Download failed with error: \(error.localizedDescription)",
                    type: .error
                )
            }
        } else {
            Debug.shared.log(message: "Download failed: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func showStatusAnimation(
        in cell: AppTableViewCell,
        systemName: String,
        tintColor: UIColor
    ) {
        let animation = cell.addAnimatedIcon(
            systemName: systemName,
            tintColor: tintColor,
            size: CGSize(width: 40, height: 40)
        )
        
        animation.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animation.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            animation.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            animation.widthAnchor.constraint(equalToConstant: 40),
            animation.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Remove animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            animation.removeFromSuperview()
        }
    }
}

protocol DownloadDelegate: AnyObject {
    func updateDownloadProgress(progress: Double, uuid: String)
    func stopDownload(uuid: String)
}

// This extension is moved to UIApplication+TopViewController.swift to avoid redeclaration
