//
//  TerminalFileManager.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import Foundation
import UIKit

/// File operation errors specific to terminal file operations
enum FileOperationError: Error {
    case invalidURL
    case noData
    case invalidResponse
    case apiError(String)
    case sessionError(String)
    case parseError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL for file operation"
        case .noData:
            return "No data received during file operation"
        case .invalidResponse:
            return "Invalid response format from file server"
        case .apiError(let message):
            return "API Error: \(message)"
        case .sessionError(let message):
            return "Session Error: \(message)"
        case .parseError(let message):
            return "Parse Error: \(message)"
        }
    }
}

/// Represents a file or directory in the Terminal file system
struct FileItem: Codable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int
    let modified: Date
    
    enum CodingKeys: String, CodingKey {
        case name
        case path
        case isDirectory = "is_dir"
        case size
        case modified
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        size = try container.decode(Int.self, forKey: .size)
        
        // Handle date parsing
        let modifiedString = try container.decode(String.self, forKey: .modified)
        let dateFormatter = ISO8601DateFormatter()
        if let date = dateFormatter.date(from: modifiedString) {
            modified = date
        } else {
            modified = Date()
        }
    }
    
    init?(json: [String: Any]) {
        guard let name = json["name"] as? String,
              let path = json["path"] as? String,
              let isDir = json["is_dir"] as? Bool,
              let size = json["size"] as? Int,
              let modifiedStr = json["modified"] as? String else {
            return nil
        }
        
        self.name = name
        self.path = path
        self.isDirectory = isDir
        self.size = size
        
        let dateFormatter = ISO8601DateFormatter()
        self.modified = dateFormatter.date(from: modifiedStr) ?? Date()
    }
}

typealias FileOperationResult<T> = Result<T, FileOperationError>

/// FileManager for terminal that allows file operations like listing, downloading, uploading, and deleting files
class TerminalFileManager {
    /// Shared instance for convenience
    static let shared = TerminalFileManager()
    
    /// URL of the terminal server
    private let baseURL: String
    
    /// Reference to the terminal service for session management
    private let terminalService: TerminalService
    
    /// Logger for debugging and tracking file operations
    private let logger = Debug.shared
    
    /// Initialize with the server URL
    init(baseURL: String? = nil, terminalService: TerminalService = TerminalService.shared) {
        self.baseURL = baseURL ?? "https://terminal-server-2hg1.onrender.com"
        self.terminalService = terminalService
        logger.log(message: "TerminalFileManager initialized with base URL: \(self.baseURL)", type: .info)
    }
    
    // MARK: - Session Management
    
    /// Get current session ID from TerminalService
    private func getSessionId(completion: @escaping (Result<String, Error>) -> Void) {
        terminalService.createSession { result in
            switch result {
            case .success(let sessionId):
                completion(.success(sessionId))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - File Operations
    
    /// List files and directories at the specified path
    /// - Parameters:
    ///   - path: Path relative to the user's home directory (empty string for home)
    ///   - completion: Called with array of file items or error
    func listFiles(at path: String = "", completion: @escaping (FileOperationResult<[FileItem]>) -> Void) {
        logger.log(message: "Listing files at path: \(path)", type: .info)
        
        getSessionId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                self.makeRequest(
                    endpoint: "/files",
                    method: "GET",
                    sessionId: sessionId,
                    queryParams: ["path": path]
                ) { result in
                    switch result {
                    case .success(let data):
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let error = json["error"] as? String {
                                    self.logger.log(message: "Error listing files: \(error)", type: .error)
                                    completion(.failure(.apiError(error)))
                                    return
                                }
                                
                                if let filesArray = json["files"] as? [[String: Any]] {
                                    let fileItems = filesArray.compactMap { FileItem(json: $0) }
                                    self.logger.log(message: "Successfully listed \(fileItems.count) files at \(path)", type: .info)
                                    completion(.success(fileItems))
                                } else {
                                    self.logger.log(message: "Invalid files array in response", type: .error)
                                    completion(.failure(.invalidResponse))
                                }
                            } else {
                                self.logger.log(message: "Could not parse JSON response for list files", type: .error)
                                completion(.failure(.invalidResponse))
                            }
                        } catch {
                            self.logger.log(message: "JSON parsing error: \(error.localizedDescription)", type: .error)
                            completion(.failure(.parseError(error.localizedDescription)))
                        }
                    case .failure(let error):
                        self.logger.log(message: "Network error listing files: \(error.localizedDescription)", type: .error)
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                self.logger.log(message: "Session error for list files: \(error.localizedDescription)", type: .error)
                if let terminalError = error as? TerminalError {
                    completion(.failure(.sessionError(terminalError.localizedDescription)))
                } else {
                    completion(.failure(.sessionError(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Download a file from the server
    /// - Parameters:
    ///   - path: Path to the file relative to user's home
    ///   - completion: Called with file data or error
    func downloadFile(at path: String, completion: @escaping (FileOperationResult<Data>) -> Void) {
        logger.log(message: "Downloading file at path: \(path)", type: .info)
        
        getSessionId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                self.makeRequest(
                    endpoint: "/files/download",
                    method: "GET",
                    sessionId: sessionId,
                    queryParams: ["path": path]
                ) { result in
                    switch result {
                    case .success(let data):
                        // Check if the response is an error message in JSON format
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? String {
                            self.logger.log(message: "Error downloading file: \(error)", type: .error)
                            completion(.failure(.apiError(error)))
                        } else {
                            self.logger.log(message: "Successfully downloaded file (\(data.count) bytes)", type: .info)
                            completion(.success(data))
                        }
                    case .failure(let error):
                        self.logger.log(message: "Network error downloading file: \(error.localizedDescription)", type: .error)
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                self.logger.log(message: "Session error for download file: \(error.localizedDescription)", type: .error)
                if let terminalError = error as? TerminalError {
                    completion(.failure(.sessionError(terminalError.localizedDescription)))
                } else {
                    completion(.failure(.sessionError(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Upload a file to the server
    /// - Parameters:
    ///   - fileData: The binary data of the file
    ///   - filename: Name for the file
    ///   - path: Directory path where to upload (empty for home)
    ///   - completion: Called with success message or error
    func uploadFile(fileData: Data, filename: String, to path: String = "", completion: @escaping (FileOperationResult<String>) -> Void) {
        logger.log(message: "Uploading file \(filename) to path: \(path)", type: .info)
        
        getSessionId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                guard let url = URL(string: "\(self.baseURL)/files/upload") else {
                    self.logger.log(message: "Invalid URL for file upload", type: .error)
                    completion(.failure(.invalidURL))
                    return
                }
                
                // Create multipart form data
                let boundary = "Boundary-\(UUID().uuidString)"
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
                request.setValue(self.terminalService.apiKey, forHTTPHeaderField: "X-API-Key")
                
                var body = Data()
                
                // Add path parameter
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"path\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(path)\r\n".data(using: .utf8)!)
                
                // Add file data
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                body.append(fileData)
                body.append("\r\n".data(using: .utf8)!)
                
                // End boundary
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                request.httpBody = body
                
                URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.logger.log(message: "Network error uploading file: \(error.localizedDescription)", type: .error)
                        completion(.failure(.apiError(error.localizedDescription)))
                        return
                    }
                    
                    guard let data = data else {
                        self.logger.log(message: "No data received from file upload", type: .error)
                        completion(.failure(.noData))
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let error = json["error"] as? String {
                                self.logger.log(message: "Error uploading file: \(error)", type: .error)
                                completion(.failure(.apiError(error)))
                                return
                            }
                            
                            if let message = json["message"] as? String {
                                self.logger.log(message: "Successfully uploaded file: \(message)", type: .info)
                                completion(.success(message))
                            } else {
                                self.logger.log(message: "File uploaded successfully", type: .info)
                                completion(.success("File uploaded successfully"))
                            }
                        } else {
                            self.logger.log(message: "Could not parse JSON response for file upload", type: .error)
                            completion(.failure(.invalidResponse))
                        }
                    } catch {
                        self.logger.log(message: "JSON parsing error: \(error.localizedDescription)", type: .error)
                        completion(.failure(.parseError(error.localizedDescription)))
                    }
                }.resume()
            case .failure(let error):
                self.logger.log(message: "Session error for upload file: \(error.localizedDescription)", type: .error)
                if let terminalError = error as? TerminalError {
                    completion(.failure(.sessionError(terminalError.localizedDescription)))
                } else {
                    completion(.failure(.sessionError(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Create a new directory
    /// - Parameters:
    ///   - path: Path for the new directory relative to user's home
    ///   - completion: Called with success message or error
    func createDirectory(at path: String, completion: @escaping (FileOperationResult<String>) -> Void) {
        logger.log(message: "Creating directory at path: \(path)", type: .info)
        
        getSessionId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                guard let url = URL(string: "\(self.baseURL)/files/mkdir") else {
                    self.logger.log(message: "Invalid URL for directory creation", type: .error)
                    completion(.failure(.invalidURL))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
                request.setValue(self.terminalService.apiKey, forHTTPHeaderField: "X-API-Key")
                
                let body: [String: Any] = ["path": path]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.logger.log(message: "Network error creating directory: \(error.localizedDescription)", type: .error)
                        completion(.failure(.apiError(error.localizedDescription)))
                        return
                    }
                    
                    guard let data = data else {
                        self.logger.log(message: "No data received from directory creation", type: .error)
                        completion(.failure(.noData))
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let error = json["error"] as? String {
                                self.logger.log(message: "Error creating directory: \(error)", type: .error)
                                completion(.failure(.apiError(error)))
                                return
                            }
                            
                            if let message = json["message"] as? String {
                                self.logger.log(message: "Successfully created directory: \(message)", type: .info)
                                completion(.success(message))
                            } else {
                                self.logger.log(message: "Directory created successfully", type: .info)
                                completion(.success("Directory created successfully"))
                            }
                        } else {
                            self.logger.log(message: "Could not parse JSON response for directory creation", type: .error)
                            completion(.failure(.invalidResponse))
                        }
                    } catch {
                        self.logger.log(message: "JSON parsing error: \(error.localizedDescription)", type: .error)
                        completion(.failure(.parseError(error.localizedDescription)))
                    }
                }.resume()
            case .failure(let error):
                self.logger.log(message: "Session error for create directory: \(error.localizedDescription)", type: .error)
                if let terminalError = error as? TerminalError {
                    completion(.failure(.sessionError(terminalError.localizedDescription)))
                } else {
                    completion(.failure(.sessionError(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Delete a file or directory
    /// - Parameters:
    ///   - path: Path to delete relative to user's home
    ///   - completion: Called with success message or error
    func deleteItem(at path: String, completion: @escaping (FileOperationResult<String>) -> Void) {
        logger.log(message: "Deleting item at path: \(path)", type: .info)
        
        getSessionId { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                self.makeRequest(
                    endpoint: "/files",
                    method: "DELETE",
                    sessionId: sessionId,
                    queryParams: ["path": path]
                ) { result in
                    switch result {
                    case .success(let data):
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let error = json["error"] as? String {
                                    self.logger.log(message: "Error deleting item: \(error)", type: .error)
                                    completion(.failure(.apiError(error)))
                                    return
                                }
                                
                                if let message = json["message"] as? String {
                                    self.logger.log(message: "Successfully deleted item: \(message)", type: .info)
                                    completion(.success(message))
                                } else {
                                    self.logger.log(message: "Item deleted successfully", type: .info)
                                    completion(.success("Item deleted successfully"))
                                }
                            } else {
                                self.logger.log(message: "Could not parse JSON response for item deletion", type: .error)
                                completion(.failure(.invalidResponse))
                            }
                        } catch {
                            self.logger.log(message: "JSON parsing error: \(error.localizedDescription)", type: .error)
                            completion(.failure(.parseError(error.localizedDescription)))
                        }
                    case .failure(let error):
                        self.logger.log(message: "Network error deleting item: \(error.localizedDescription)", type: .error)
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                self.logger.log(message: "Session error for delete item: \(error.localizedDescription)", type: .error)
                if let terminalError = error as? TerminalError {
                    completion(.failure(.sessionError(terminalError.localizedDescription)))
                } else {
                    completion(.failure(.sessionError(error.localizedDescription)))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Make a generic API request
    private func makeRequest(
        endpoint: String,
        method: String,
        sessionId: String,
        queryParams: [String: String] = [:],
        body: [String: Any]? = nil,
        completion: @escaping (FileOperationResult<Data>) -> Void
    ) {
        // Build URL with query parameters
        var urlComponents = URLComponents(string: baseURL + endpoint)
        if !queryParams.isEmpty {
            urlComponents?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents?.url else {
            logger.log(message: "Invalid URL for API request: \(baseURL + endpoint)", type: .error)
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        request.setValue(terminalService.apiKey, forHTTPHeaderField: "X-API-Key")
        
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log(message: "Network error in API request: \(error.localizedDescription)", type: .error)
                completion(.failure(.apiError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                self.logger.log(message: "No data received from API request", type: .error)
                completion(.failure(.noData))
                return
            }
            
            completion(.success(data))
        }.resume()
    }
}

// MARK: - Data Extensions for Multipart Form

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - TerminalService Extension

extension TerminalService {
    // Make apiKey accessible for the TerminalFileManager
    var apiKey: String {
        return "B2D4G5"
    }
}
