//
// LibraryViewController+Types.swift
// backdoor
//
// Created by Mentat AI on 2025-04-08.
//

import Foundation

/// Source application version representation
struct SourceAppVersion {
    let version: String
    let downloadURL: URL
    
    // Add any other properties that might be needed based on usage in the code
    
    // Initializer from StoreAppsDataVersion (if this type exists in the codebase)
    init(from storeVersion: Any) {
        if let storeAppsVersion = storeVersion as? [String: Any] {
            self.version = storeAppsVersion["version"] as? String ?? "unknown"
            
            if let urlString = storeAppsVersion["downloadURL"] as? String,
               let url = URL(string: urlString) {
                self.downloadURL = url
            } else {
                // Default URL if none provided
                self.downloadURL = URL(string: "https://example.com")!
            }
        } else {
            // Default values if conversion fails
            self.version = "unknown"
            self.downloadURL = URL(string: "https://example.com")!
        }
    }
}
