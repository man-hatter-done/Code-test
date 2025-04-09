// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation

/// File operation errors specific to terminal file operations
enum TerminalFileError: Error {
    case invalidURL
    case noData
    case invalidResponse
    case apiError(String)
    case sessionError(String)
    case parseError(String)
    case fileNotFound(String)
    case unknownError(String)
    case failure(String)
    
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
        case .fileNotFound(let message):
            return "File not found: \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        case .failure(let message):
            return "Operation failed: \(message)"
        }
    }
}
