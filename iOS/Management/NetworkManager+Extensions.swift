// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly
// permitted under the terms of the Proprietary Software License.

import Foundation

// Add missing functionality to iOSNetworkManager
extension iOSNetworkManager {
    /// Clears all cached network responses
    /// - Note: This implementation matches the expected behavior from AppPerformanceOptimizer
    func clearCache() {
        // Clear URLCache to remove any cached responses
        URLCache.shared.removeAllCachedResponses()
        
        // Log the action
        Debug.shared.log(message: "Network cache cleared", type: .info)
        
        // Cancel any ongoing operations
        cancelAllOperations()
    }
}
