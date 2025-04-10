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
            let payload = createWebhookPayload()
            
            // Create the URL from the webhook endpoint string
            guard let webhookEndpoint = URL(string: webhookURL) else {
                Debug.shared.log(message: "Invalid webhook URL", type: .error)
                return
            }
            
            // Send the webhook data
            sendWebhookData(to: webhookEndpoint, payload: payload)
        } else {
            Debug.shared.log(message: "Webhook data already sent, skipping", type: .debug)
        }
    }
    
    /// Creates a structured payload for the webhook with device and app information
    /// - Returns: Dictionary containing the payload data
    private func createWebhookPayload() -> [String: Any] {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Create a structured payload with relevant information
        let payload: [String: Any] = [
            "event": "app_launch",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
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
        
        return payload
    }
    
    /// Sends the webhook data to the specified endpoint
    /// - Parameters:
    ///   - endpoint: The URL endpoint to send data to
    ///   - payload: The data payload to send
    private func sendWebhookData(to endpoint: URL, payload: [String: Any]) {
        // Create the URL request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Convert payload to JSON data
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            
            // Create URLSession task
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    Debug.shared.log(message: "Webhook error: \(error.localizedDescription)", type: .error)
                    return
                }
                
                // Check for successful response
                guard let httpResponse = response as? HTTPURLResponse else {
                    Debug.shared.log(message: "Invalid response from webhook", type: .error)
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    Debug.shared.log(message: "Webhook data sent successfully", type: .success)
                    
                    // Mark as sent in UserDefaults
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: self.hasSentWebhookKey)
                    }
                } else {
                    Debug.shared.log(
                        message: "Webhook request failed with status code: \(httpResponse.statusCode)",
                        type: .error
                    )
                }
            }
            
            // Execute the request
            task.resume()
            
        } catch {
            Debug.shared.log(message: "Failed to create webhook request: \(error.localizedDescription)", type: .error)
        }
    }
}
