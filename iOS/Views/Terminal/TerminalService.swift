//
//  TerminalService.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import Foundation
import UIKit

enum TerminalError: Error {
    case invalidURL
    case networkError(String)
    case responseError(String)
    case sessionError(String)
    case parseError(String)
}

typealias TerminalResult<T> = Result<T, TerminalError>

class TerminalService {
    static let shared = TerminalService()
    
    // Hardcoded server credentials as requested
    private let baseURL = "https://terminal-server-tqo6.onrender.com/"
    private let apiKey = "B2D4G5"
    private var sessionId: String?
    private var userId: String?
    private let logger = Debug.shared
    
    private init() {
        logger.log(message: "TerminalService initialized")
    }
    
    /// Creates a new terminal session for the user
    /// - Parameter completion: Called with the session ID or an error
    func createSession(completion: @escaping (TerminalResult<String>) -> Void) {
        // Check if we already have a valid session
        if let existingSession = sessionId {
            // Validate existing session
            validateSession { result in
                switch result {
                case .success(_):
                    // Session is still valid
                    self.logger.log(message: "Using existing terminal session")
                    completion(.success(existingSession))
                case .failure(_):
                    // Session is invalid, create a new one
                    self.logger.log(message: "Terminal session expired, creating new one")
                    self.createNewSession(completion: completion)
                }
            }
        } else {
            // No existing session, create a new one
            self.logger.log(message: "Creating new terminal session")
            createNewSession(completion: completion)
        }
    }
    
    private func createNewSession(completion: @escaping (TerminalResult<String>) -> Void) {
        guard let url = URL(string: "\(baseURL)/create-session") else {
            logger.log(message: "Invalid URL for terminal session creation", type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        // Include device identifier to ensure uniqueness
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let body: [String: Any] = ["userId": deviceId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log(message: "Network error creating terminal session: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                self.logger.log(message: "No data received from terminal session creation", type: .error)
                completion(.failure(TerminalError.responseError("No data received")))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        self.logger.log(message: "Terminal session creation error: \(errorMessage)", type: .error)
                        completion(.failure(TerminalError.responseError(errorMessage)))
                        return
                    }
                    
                    if let newSessionId = json["sessionId"] as? String {
                        self.sessionId = newSessionId
                        self.userId = json["userId"] as? String
                        self.logger.log(message: "Terminal session created successfully", type: .info)
                        completion(.success(newSessionId))
                    } else {
                        self.logger.log(message: "Invalid terminal session response format", type: .error)
                        completion(.failure(TerminalError.responseError("Invalid response format")))
                    }
                } else {
                    self.logger.log(message: "Could not parse terminal session response", type: .error)
                    completion(.failure(TerminalError.responseError("Could not parse response")))
                }
            } catch {
                self.logger.log(message: "JSON parsing error in terminal session response: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.parseError("JSON parsing error: \(error.localizedDescription)")))
            }
        }.resume()
    }
    
    private func validateSession(completion: @escaping (TerminalResult<Bool>) -> Void) {
        guard let sessionId = sessionId else {
            logger.log(message: "No active terminal session to validate", type: .error)
            completion(.failure(TerminalError.sessionError("No active session")))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/session") else {
            logger.log(message: "Invalid URL for terminal session validation", type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log(message: "Network error validating terminal session: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // Session is invalid
                self.sessionId = nil
                self.logger.log(message: "Terminal session expired (HTTP \(httpResponse.statusCode))", type: .warning)
                completion(.failure(TerminalError.sessionError("Session expired")))
                return
            }
            
            self.logger.log(message: "Terminal session validated successfully", type: .info)
            completion(.success(true))
        }.resume()
    }
    
    /// Executes a command in the user's terminal session
    /// - Parameters:
    ///   - command: The command to execute
    ///   - completion: Called with the command output or an error
    func executeCommand(_ command: String, completion: @escaping (TerminalResult<String>) -> Void) {
        logger.log(message: "Executing terminal command: \(command)", type: .info)
        
        // First ensure we have a valid session
        createSession { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                self.executeCommandWithSession(command, sessionId: sessionId, completion: completion)
            case .failure(let error):
                self.logger.log(message: "Failed to create session for command execution: \(error.localizedDescription)", type: .error)
                completion(.failure(error))
            }
        }
    }
    
    private func executeCommandWithSession(_ command: String, sessionId: String, completion: @escaping (TerminalResult<String>) -> Void) {
        guard let url = URL(string: "\(baseURL)/execute-command") else {
            logger.log(message: "Invalid URL for command execution", type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        let body = ["command": command]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log(message: "Network error executing command: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                self.logger.log(message: "No data received from command execution", type: .error)
                completion(.failure(TerminalError.responseError("No data received")))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        self.logger.log(message: "Command execution error: \(errorMessage)", type: .error)
                        completion(.failure(TerminalError.responseError(errorMessage)))
                        return
                    }
                    
                    if let output = json["output"] as? String {
                        self.logger.log(message: "Command executed successfully", type: .info)
                        completion(.success(output))
                    } else {
                        self.logger.log(message: "Invalid command response format", type: .error)
                        completion(.failure(TerminalError.responseError("Invalid response format")))
                    }
                } else {
                    self.logger.log(message: "Could not parse command response", type: .error)
                    completion(.failure(TerminalError.parseError("Could not parse response")))
                }
            } catch {
                self.logger.log(message: "JSON parsing error in command response: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.parseError("JSON parsing error: \(error.localizedDescription)")))
            }
        }.resume()
    }
    
    /// Terminates the current session
    func endSession(completion: @escaping (TerminalResult<Void>) -> Void) {
        guard let sessionId = sessionId else {
            logger.log(message: "No active terminal session to end", type: .info)
            completion(.success(()))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/session") else {
            logger.log(message: "Invalid URL for terminal session termination", type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log(message: "Network error ending terminal session: \(error.localizedDescription)", type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            self.sessionId = nil
            self.logger.log(message: "Terminal session ended successfully", type: .info)
            completion(.success(()))
        }.resume()
    }
}

// Legacy compatibility wrapper
class ProcessUtility {
    static let shared = ProcessUtility()
    private let logger = Debug.shared
    
    private init() {}
    
    /// Executes a shell command on the backend server and returns the output.
    /// - Parameters:
    ///   - command: The shell command to be executed.
    ///   - completion: A closure to be called with the command's output or an error message.
    func executeShellCommand(_ command: String, completion: @escaping (String?) -> Void) {
        logger.log(message: "ProcessUtility executing command: \(command)", type: .info)
        
        TerminalService.shared.executeCommand(command) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let output):
                self.logger.log(message: "ProcessUtility command executed successfully", type: .info)
                completion(output)
            case .failure(let error):
                self.logger.log(message: "ProcessUtility command failed: \(error.localizedDescription)", type: .error)
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
}
