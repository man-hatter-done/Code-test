// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly
// permitted under the terms of the Proprietary Software License.

import Foundation

/// Base NetworkManager class for handling network requests
class NetworkManager {
    /// Shared singleton instance
    static let shared = NetworkManager()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Set of active tasks for tracking and cancellation
    private var activeTasks = Set<URLSessionTask>()
    private let taskLock = NSLock()
    
    /// Sends a URL request and returns the response data or error
    /// - Parameters:
    ///   - request: The URL request to send
    ///   - completion: Callback with Result containing either the data or an error
    func sendRequest(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer {
                // Remove task from tracking when complete
                guard let self = self else { return }
                self.taskLock.lock()
                self.activeTasks.remove(task)
                self.taskLock.unlock()
            }
            
            // Handle errors
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Validate response status code
            if let httpResponse = response as? HTTPURLResponse, 
               !(200...299).contains(httpResponse.statusCode) {
                // Create custom error for non-success HTTP status
                let responseError = NSError(
                    domain: "NetworkManager",
                    code: httpResponse.statusCode,
                    userInfo: [
                        NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)",
                        "statusCode": httpResponse.statusCode
                    ]
                )
                completion(.failure(responseError))
                return
            }
            
            // Return data if available, or error if not
            if let data = data {
                completion(.success(data))
            } else {
                let noDataError = NSError(
                    domain: "NetworkManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No data received"]
                )
                completion(.failure(noDataError))
            }
        }
        
        // Track the task for potential cancellation
        taskLock.lock()
        activeTasks.insert(task)
        taskLock.unlock()
        
        // Start the request
        task.resume()
    }
    
    /// Sends a GET request to the specified URL
    /// - Parameters:
    ///   - url: The URL to request
    ///   - headers: Optional HTTP headers
    ///   - completion: Callback with Result containing either the data or an error
    func get(from url: URL, headers: [String: String]? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add headers if provided
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        sendRequest(request, completion: completion)
    }
    
    /// Sends a POST request with JSON data to the specified URL
    /// - Parameters:
    ///   - url: The URL to request
    ///   - jsonData: The JSON data to send in the request body
    ///   - headers: Optional HTTP headers
    ///   - completion: Callback with Result containing either the data or an error
    func post(to url: URL, jsonData: Data, headers: [String: String]? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        // Add content type if not specified
        var allHeaders = headers ?? [:]
        if allHeaders["Content-Type"] == nil {
            allHeaders["Content-Type"] = "application/json"
        }
        
        // Add headers
        allHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        sendRequest(request, completion: completion)
    }
    
    /// Cancels all active network operations
    func cancelAllOperations() {
        taskLock.lock()
        defer { taskLock.unlock() }
        
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
}
