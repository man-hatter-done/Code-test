// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly
// permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

// MARK: - Webhook Extension for AppDelegate
extension AppDelegate {
    /// Set up and send analytics data to the webhook endpoint
    /// This endpoint is not a webhook in the traditional sense, but a REST API endpoint
    /// that receives POST requests with JSON content
    func setupAndSendWebhook() {
        Debug.shared.log(message: "Setting up webhook data submission", type: .info)
        
        // Only send webhook data if we haven't sent it before or if in development mode
        let userDefaults = UserDefaults.standard
        let hasSent = userDefaults.bool(forKey: hasSentWebhookKey)
        let isDevelopment = ProcessInfo.processInfo.environment["DEVELOPMENT"] != nil
        
        if !hasSent || isDevelopment {
            // Prepare the webhook payload with device and app information
            let payload = createAppLaunchPayload()
            
            // Create the URL from the webhook endpoint string
            guard let webhookEndpoint = URL(string: webhookURL) else {
                Debug.shared.log(message: "Invalid webhook URL", type: .error)
                return
            }
            
            // Use the NetworkManager to send the webhook data
            NetworkManager.shared.sendWebhookDataAsJSON(to: webhookEndpoint, data: payload) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(_):
                    Debug.shared.log(message: "Webhook data sent successfully", type: .success)
                    
                    // Mark as sent in UserDefaults
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: self.hasSentWebhookKey)
                    }
                    
                case .failure(let error):
                    Debug.shared.log(message: "Webhook error: \(error.localizedDescription)", type: .error)
                }
            }
        } else {
            Debug.shared.log(message: "Webhook data already sent, skipping", type: .debug)
        }
    }
    
    /// Creates a structured payload for the app launch webhook with device and app information
    /// - Returns: Dictionary containing the payload data
    private func createAppLaunchPayload() -> [String: Any] {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Create the base payload using NetworkManager's helper method
        let basePayload = NetworkManager.shared.createWebhookPayload(
            eventType: "app_launch",
            data: [:]
        )
        
        // Create a structured payload with app-specific information
        var payload = basePayload
        var eventData: [String: Any] = [
            "app_info": [
                "version": appVersion,
                "build": buildNumber,
                "bundle_id": Bundle.main.bundleIdentifier ?? "Unknown"
            ],
            "device_info": [
                "model": device.model,
                "system_name": device.systemName,
                "system_version": device.systemVersion,
                "identifier": UUID().uuidString // Anonymous identifier
            ],
            "settings": [
                "theme": Preferences.preferredInterfaceStyle,
                "language": Locale.preferredLanguages.first ?? "en"
            ]
        ]
        
        // Update the data in the payload
        payload["data"] = eventData
        
        return payload
    }
}
