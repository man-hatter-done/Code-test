//
//  CommandHistory.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import Foundation

class CommandHistory {
    private var commands: [String] = []
    private var currentIndex: Int = -1
    private let maxHistorySize = 100
    private let logger = Debug.shared
    
    func addCommand(_ command: String) {
        // Don't add empty commands
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            return
        }
        
        // Don't add duplicates of the most recent command
        if let lastCommand = commands.last, lastCommand == trimmedCommand {
            currentIndex = commands.count - 1
            return
        }
        
        logger.log(message: "Adding command to history: \(trimmedCommand)", type: .info)
        
        commands.append(trimmedCommand)
        // Limit history size
        if commands.count > maxHistorySize {
            commands.removeFirst()
        }
        currentIndex = commands.count - 1
    }
    
    func getPreviousCommand() -> String? {
        guard !commands.isEmpty, currentIndex >= 0 else {
            return nil
        }
        
        let command = commands[currentIndex]
        // Move back in history if possible
        if currentIndex > 0 {
            currentIndex -= 1
        }
        return command
    }
    
    func getNextCommand() -> String? {
        guard !commands.isEmpty, currentIndex < commands.count - 1 else {
            return nil
        }
        
        currentIndex += 1
        return commands[currentIndex]
    }
    
    func resetIndex() {
        currentIndex = commands.count - 1
    }
    
    func clearHistory() {
        logger.log(message: "Clearing command history", type: .info)
        commands.removeAll()
        currentIndex = -1
    }
    
    /// Save command history to UserDefaults
    func saveHistory() {
        UserDefaults.commandHistory = commands
        logger.log(message: "Saved \(commands.count) commands to history", type: .info)
    }
    
    /// Load command history from UserDefaults
    func loadHistory() {
        if let savedCommands = UserDefaults.commandHistory {
            commands = savedCommands
            currentIndex = commands.count - 1
            logger.log(message: "Loaded \(commands.count) commands from history", type: .info)
        }
    }
}

// Add storage extension for command history
extension UserDefaults {
    // Using regular UserDefaults instead of generic Storage to avoid static property in generic type error
    static var commandHistory: [String]? {
        get {
            return standard.array(forKey: "terminal_command_history") as? [String]
        }
        set {
            standard.set(newValue, forKey: "terminal_command_history")
        }
    }
}
