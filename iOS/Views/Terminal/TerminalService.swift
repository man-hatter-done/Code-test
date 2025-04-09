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
    case webSocketError(String)
}

typealias TerminalResult<T> = Result<T, TerminalError>

class TerminalService {
    static let shared = TerminalService()
    
    // Hardcoded server credentials as requested
    private let baseURL = "https://terminal-server-2hg1.onrender.com"
    let apiKey = "B2D4G5"
    private var sessionId: String?
    private var userId: String?
    private let logger = Debug.shared
    
    // WebSocket properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var isWebSocketConnected = false
    private var useWebSockets = true
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 5
    private let session = URLSession(configuration: .default)
    
    // Command callbacks and buffers for WebSocket
    private var commandCallbacks: [String: (TerminalResult<String>) -> Void] = [:]
    private var streamHandlers: [String: (String) -> Void] = [:]
    private var commandBuffer: [String: String] = [:]
    
    private init() {
        logger.log(message: "TerminalService initialized")
        setupWebSocketConnection()
    }
    
    // MARK: - WebSocket Setup
    
    private func setupWebSocketConnection() {
        // Convert HTTP URL to WebSocket URL
        var urlString = baseURL
        if urlString.hasPrefix("https://") {
            urlString = "wss://" + urlString.dropFirst(8)
        } else if urlString.hasPrefix("http://") {
            urlString = "ws://" + urlString.dropFirst(7)
        }
        
        guard let url = URL(string: "\(urlString)/terminal-ws") else {
            logger.log(message: "Invalid WebSocket URL", type: .error)
            useWebSockets = false
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        logger.log(message: "Setting up WebSocket connection to \(url.absoluteString)", type: .info)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Set up message receiving
        receiveMessage()
        
        // Schedule a ping to keep connection alive
        schedulePing()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.logger.log(message: "WebSocket message received", type: .debug)
                    self.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.logger.log(message: "WebSocket binary message received", type: .debug)
                        self.handleWebSocketMessage(text)
                    }
                @unknown default:
                    self.logger.log(message: "Unknown WebSocket message type received", type: .warning)
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                self.logger.log(message: "WebSocket receive error: \(error.localizedDescription)", type: .error)
                self.isWebSocketConnected = false
                
                // Try to reconnect
                self.reconnectWebSocket()
            }
        }
    }
    
    private func handleWebSocketMessage(_ messageText: String) {
        guard let data = messageText.data(using: .utf8) else {
            logger.log(message: "Could not convert WebSocket message to data", type: .error)
            return
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.log(message: "Invalid WebSocket message format", type: .error)
                return
            }
            
            // Handle different message types
            if let type = json["type"] as? String {
                switch type {
                case "connected":
                    isWebSocketConnected = true
                    reconnectAttempt = 0
                    logger.log(message: "WebSocket connected successfully", type: .info)
                    
                    // If we have a session ID, join that session
                    if let sessionId = sessionId {
                        sendWebSocketMessage(["action": "join_session", "sessionId": sessionId])
                    }
                    
                case "session_created":
                    if let newSessionId = json["sessionId"] as? String {
                        sessionId = newSessionId
                        userId = json["userId"] as? String
                        logger.log(message: "WebSocket session created: \(newSessionId)", type: .info)
                        
                        // Call any pending session creation callbacks
                        if let commandId = json["commandId"] as? String, let callback = commandCallbacks[commandId] {
                            callback(.success(newSessionId))
                            commandCallbacks.removeValue(forKey: commandId)
                        }
                    }
                    
                case "command_output":
                    if let commandId = json["commandId"] as? String, 
                       let output = json["output"] as? String {
                        
                        // Handle streaming output if a stream handler exists
                        if let streamHandler = streamHandlers[commandId] {
                            streamHandler(output)
                        }
                        
                        // Accumulate output in buffer
                        var currentOutput = commandBuffer[commandId] ?? ""
                        currentOutput += output
                        commandBuffer[commandId] = currentOutput
                        
                        logger.log(message: "Received partial command output via WebSocket", type: .debug)
                    }
                    
                    // Handle session renewal
                    if let renewed = json["sessionRenewed"] as? Bool, renewed,
                       let newSessionId = json["newSessionId"] as? String {
                        sessionId = newSessionId
                        logger.log(message: "Session renewed via WebSocket: \(newSessionId)", type: .info)
                        sendWebSocketMessage(["action": "join_session", "sessionId": newSessionId])
                    }
                    
                case "command_complete":
                    if let commandId = json["commandId"] as? String, let callback = commandCallbacks[commandId] {
                        // Get accumulated output
                        let output = commandBuffer[commandId] ?? ""
                        
                        logger.log(message: "Command completed via WebSocket", type: .info)
                        
                        // Call callback with complete output
                        callback(.success(output))
                        
                        // Clean up
                        commandCallbacks.removeValue(forKey: commandId)
                        streamHandlers.removeValue(forKey: commandId)
                        commandBuffer.removeValue(forKey: commandId)
                    }
                    
                case "command_error":
                    if let commandId = json["commandId"] as? String,
                       let errorMessage = json["error"] as? String,
                       let callback = commandCallbacks[commandId] {
                        
                        logger.log(message: "Command error via WebSocket: \(errorMessage)", type: .error)
                        
                        // Call callback with error
                        callback(.failure(TerminalError.responseError(errorMessage)))
                        
                        // Clean up
                        commandCallbacks.removeValue(forKey: commandId)
                        streamHandlers.removeValue(forKey: commandId)
                        commandBuffer.removeValue(forKey: commandId)
                    }
                    
                case "session_expired":
                    // Session expired, will create new one when needed
                    sessionId = nil
                    logger.log(message: "WebSocket session expired", type: .warning)
                    
                default:
                    logger.log(message: "Unknown WebSocket message type: \(type)", type: .warning)
                }
            }
        } catch {
            logger.log(message: "Error parsing WebSocket message: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func sendWebSocketMessage(_ message: [String: Any]) {
        guard isWebSocketConnected, let webSocketTask = webSocketTask else { 
            logger.log(message: "Cannot send WebSocket message: not connected", type: .warning)
            return 
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            if let messageString = String(data: data, encoding: .utf8) {
                logger.log(message: "Sending WebSocket message: \(message["action"] as? String ?? "unknown")", type: .debug)
                let message = URLSessionWebSocketTask.Message.string(messageString)
                webSocketTask.send(message) { [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.logger.log(message: "WebSocket send error: \(error.localizedDescription)", type: .error)
                        self.isWebSocketConnected = false
                        self.reconnectWebSocket()
                    }
                }
            }
        } catch {
            logger.log(message: "Failed to serialize WebSocket message: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func schedulePing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.isWebSocketConnected else { return }
            
            self.logger.log(message: "Sending WebSocket ping", type: .debug)
            self.webSocketTask?.sendPing { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logger.log(message: "WebSocket ping error: \(error.localizedDescription)", type: .error)
                    self.isWebSocketConnected = false
                    self.reconnectWebSocket()
                }
            }
            
            // Schedule next ping
            self.schedulePing()
        }
    }
    
    private func reconnectWebSocket() {
        guard reconnectAttempt < maxReconnectAttempts else {
            logger.log(message: "Max WebSocket reconnection attempts reached, falling back to HTTP", type: .warning)
            useWebSockets = false
            return
        }
        
        reconnectAttempt += 1
        let delay = pow(2.0, Double(reconnectAttempt - 1))
        
        logger.log(message: "Will attempt to reconnect WebSocket in \(delay) seconds (attempt \(reconnectAttempt))", type: .info)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.isWebSocketConnected else { return }
            self.logger.log(message: "Attempting to reconnect WebSocket (attempt \(self.reconnectAttempt))", type: .info)
            
            // Close existing connection
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            
            // Create new connection
            self.setupWebSocketConnection()
        }
    }
    
    // MARK: - Public API
    
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
        // Use WebSockets if available and connected
        if useWebSockets && webSocketTask != nil && isWebSocketConnected {
            logger.log(message: "Creating new terminal session via WebSocket", type: .info)
            
            let commandId = UUID().uuidString
            commandCallbacks[commandId] = completion
            
            // Create device identifier
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            
            // Send via WebSocket
            sendWebSocketMessage([
                "action": "create_session",
                "userId": deviceId,
                "commandId": commandId,
                "apiKey": apiKey
            ])
            
            // Set a timeout to fall back to HTTP if WebSocket doesn't respond
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self,
                      self.commandCallbacks[commandId] != nil else { return }
                
                // Still waiting for WebSocket, try HTTP
                self.logger.log(message: "WebSocket session creation timed out, falling back to HTTP", type: .warning)
                self.commandCallbacks.removeValue(forKey: commandId)
                self.createNewSessionHTTP(completion: completion)
            }
            
            return
        }
        
        // Fall back to HTTP
        createNewSessionHTTP(completion: completion)
    }
    
    private func createNewSessionHTTP(completion: @escaping (TerminalResult<String>) -> Void) {
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
        
        logger.log(message: "Creating new terminal session via HTTP", type: .info)
        
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
                        
                        // If WebSocket is connected, join the session
                        if self.isWebSocketConnected {
                            self.sendWebSocketMessage(["action": "join_session", "sessionId": newSessionId])
                        }
                        
                        self.logger.log(message: "Terminal session created successfully via HTTP", type: .info)
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
    ///   - streamHandler: Optional handler for real-time streaming output updates (WebSocket only)
    ///   - completion: Called with the final command output or an error
    func executeCommand(
        _ command: String,
        streamHandler: ((String) -> Void)? = nil,
        completion: @escaping (TerminalResult<String>) -> Void
    ) {
        logger.log(message: "Executing terminal command: \(command)", type: .info)
        
        // First ensure we have a valid session
        createSession { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                // Check if WebSocket is available for streaming
                if self.useWebSockets && self.isWebSocketConnected && streamHandler != nil {
                    self.logger.log(message: "Executing command with WebSocket streaming", type: .info)
                    self.executeCommandWithWebSocket(command, sessionId: sessionId, streamHandler: streamHandler, completion: completion)
                } else {
                    // Fall back to HTTP for non-streaming requests
                    self.executeCommandWithSession(command, sessionId: sessionId, completion: completion)
                }
            case .failure(let error):
                self.logger.log(message: "Failed to create session for command execution: \(error.localizedDescription)", type: .error)
                completion(.failure(error))
            }
        }
    }
    
    private func executeCommandWithWebSocket(
        _ command: String,
        sessionId: String,
        streamHandler: ((String) -> Void)?,
        completion: @escaping (TerminalResult<String>) -> Void
    ) {
        let commandId = UUID().uuidString
        
        // Register callbacks
        commandCallbacks[commandId] = completion
        
        // Register stream handler if provided
        if let streamHandler = streamHandler {
            streamHandlers[commandId] = streamHandler
        }
        
        // Send command via WebSocket
        sendWebSocketMessage([
            "action": "execute_command",
            "command": command,
            "sessionId": sessionId,
            "commandId": commandId,
            "apiKey": apiKey
        ])
        
        // Fallback to HTTP if no response after a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self,
                  self.commandCallbacks[commandId] != nil else { return }
            
            // No complete response from WebSocket yet, try HTTP
            self.logger.log(message: "WebSocket command execution taking too long, falling back to HTTP", type: .warning)
            self.commandCallbacks.removeValue(forKey: commandId)
            self.streamHandlers.removeValue(forKey: commandId)
            self.commandBuffer.removeValue(forKey: commandId)
            self.executeCommandWithSession(command, sessionId: sessionId, completion: completion)
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
        
        logger.log(message: "Executing command via HTTP", type: .info)
        
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
                    
                    // Check for session renewal
                    if let renewed = json["sessionRenewed"] as? Bool, renewed,
                       let newSessionId = json["newSessionId"] as? String {
                        self.sessionId = newSessionId
                        
                        // If websocket is connected, join the new session
                        if self.isWebSocketConnected {
                            self.sendWebSocketMessage(["action": "join_session", "sessionId": newSessionId])
                        }
                    }
                    
                    if let output = json["output"] as? String {
                        self.logger.log(message: "Command executed successfully via HTTP", type: .info)
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
        
        // Use WebSockets if available
        if useWebSockets && isWebSocketConnected {
            logger.log(message: "Ending session via WebSocket", type: .info)
            sendWebSocketMessage([
                "action": "end_session",
                "sessionId": sessionId,
                "apiKey": apiKey
            ])
            self.sessionId = nil
            completion(.success(()))
            return
        }
        
        // Fall back to HTTP
        guard let url = URL(string: "\(baseURL)/session") else {
            logger.log(message: "Invalid URL for terminal session termination", type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        logger.log(message: "Ending session via HTTP", type: .info)
        
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
    
    /// Checks if WebSocket connection is active
    var isWebSocketActive: Bool {
        return isWebSocketConnected
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
    
    /// Executes a shell command with real-time output streaming.
    /// - Parameters:
    ///   - command: The shell command to be executed.
    ///   - outputHandler: Real-time handler for command output chunks.
    ///   - completion: A closure to be called when the command completes.
    func executeShellCommandWithStreaming(_ command: String, outputHandler: @escaping (String) -> Void, completion: @escaping (String?) -> Void) {
        logger.log(message: "ProcessUtility executing streaming command: \(command)", type: .info)
        
        TerminalService.shared.executeCommand(command, streamHandler: outputHandler) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let output):
                self.logger.log(message: "ProcessUtility streaming command executed successfully", type: .info)
                completion(output)
            case .failure(let error):
                self.logger.log(message: "ProcessUtility streaming command failed: \(error.localizedDescription)", type: .error)
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
}
