// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation

// Extension for iOSNetworkManager to ensure proper JSON formatting for webhook requests
extension iOSNetworkManager {
    
    /// Ensures that data sent to webhook endpoints is properly formatted as JSON
    /// - Parameters:
    ///   - url: The webhook URL
    ///   - data: The data to send
    ///   - completion: The completion handler to call when the request completes
    func sendWebhookDataAsJSON(to url: URL, data: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        // First verify this is the webhook endpoint
        if url.absoluteString.contains("webhook-data-viewer.onrender.com/api/webhook") {
            do {
                // Ensure data is properly formatted as JSON
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
                
                // Create a request with the proper content type header
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                
                // Log the request for debugging
                backdoor.Debug.shared.log(message: "Sending webhook data as JSON", type: .info)
                
                // Send the request
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    // Verify we got a success response
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode),
                          let responseData = data else {
                        completion(.failure(NSError(domain: "WebhookError", 
                                                   code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "Invalid response from webhook"])))
                        return
                    }
                    
                    completion(.success(responseData))
                }.resume()
                
            } catch {
                completion(.failure(error))
            }
        } else {
            // If not the webhook URL, use standard performRequest method
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: data)
                
                iOSNetworkManager.shared.sendRequest(request) { (result: Result<Data, Error>) in
                    completion(result)
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Helper method to create a standardized webhook payload
    /// - Parameters:
    ///   - eventType: The type of event
    ///   - data: The data associated with the event
    /// - Returns: A dictionary that can be serialized to JSON
    func createWebhookPayload(eventType: String, data: [String: Any]) -> [String: Any] {
        return [
            "event": eventType,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "data": data
        ]
    }
}
