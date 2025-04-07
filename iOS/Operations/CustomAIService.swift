// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit
import CoreML
import NaturalLanguage

// Search query types for specialized searches
enum SearchQueryType {
    case general
    case academic
    case news
    case technical
    case reference
}

/// Custom AI service that replaces the OpenRouter API with a local AI implementation
final class CustomAIService {
    // Singleton instance for app-wide use
    static let shared = CustomAIService()
    
    // Flag to track if CoreML is initialized
    private var isCoreMLInitialized = false

    private init() {
        Debug.shared.log(message: "Initializing custom AI service", type: .info)
        // Initialize CoreML in background to avoid startup delay
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.initializeCoreML()
        }
    }
    
    /// Initialize CoreML model
    private func initializeCoreML() {
        Debug.shared.log(message: "Starting CoreML initialization for AI service", type: .info)
        
        // Check if CoreML is already loaded by the manager
        if CoreMLManager.shared.isModelLoaded {
            self.isCoreMLInitialized = true
            Debug.shared.log(message: "CoreML model already loaded via manager, AI service ready", type: .info)
            return
        }
        
        // Listen for CoreML model load completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoreMLModelLoaded),
            name: Notification.Name("CoreMLModelLoaded"),
            object: nil
        )
        
        // Listen for AI capabilities enhancement
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAICapabilitiesEnhanced),
            name: Notification.Name("AICapabilitiesEnhanced"),
            object: nil
        )
        
        // Start loading the model if it's not already being loaded
        // This provides a backup initialization path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Ensure the model file is ready
            ModelFileManager.shared.prepareMLModel { [weak self] result in
                switch result {
                case .success(let modelURL):
                    Debug.shared.log(message: "ML model prepared at: \(modelURL.path)", type: .info)
                    
                    // Load the model
                    CoreMLManager.shared.loadModel { success in
                        if success && !(self?.isCoreMLInitialized ?? false) {
                            self?.isCoreMLInitialized = true
                            Debug.shared.log(message: "CoreML model successfully initialized via backup path", type: .info)
                        } else if !success {
                            Debug.shared.log(message: "CoreML model failed to initialize, falling back to pattern matching", type: .warning)
                            self?.isCoreMLInitialized = false
                        }
                    }
                    
                case .failure(let error):
                    Debug.shared.log(message: "Failed to prepare ML model: \(error.localizedDescription), falling back to pattern matching", type: .error)
                    self?.isCoreMLInitialized = false
                }
            }
        }
    }
    
    /// Handle CoreML model load completion notification
    @objc private func handleCoreMLModelLoaded() {
        if !isCoreMLInitialized {
            isCoreMLInitialized = true
            Debug.shared.log(message: "CoreML model loaded notification received, enabling ML capabilities", type: .info)
        }
    }
    
    /// Handle AI capabilities enhancement notification
    @objc private func handleAICapabilitiesEnhanced() {
        if !isCoreMLInitialized && CoreMLManager.shared.isModelLoaded {
            isCoreMLInitialized = true
            Debug.shared.log(message: "AI capabilities enhanced, ML features now available", type: .info)
        }
    }

    enum ServiceError: Error, LocalizedError {
        case processingError(String)
        case contextMissing

        var errorDescription: String? {
            switch self {
                case let .processingError(reason):
                    return "Processing error: \(reason)"
                case .contextMissing:
                    return "App context is missing or invalid"
            }
        }
    }

    // Maintained for compatibility with existing code
    struct AIMessagePayload {
        let role: String
        let content: String
    }

    /// Process user input and generate an AI response
    func getAIResponse(messages: [AIMessagePayload], context: AppContext, completion: @escaping (Result<String, ServiceError>) -> Void) {
        // Log the request
        Debug.shared.log(message: "Processing AI request with \(messages.count) messages", type: .info)

        // Get the user's last message
        guard let lastUserMessage = messages.last(where: { $0.role == "user" })?.content else {
            completion(.failure(.processingError("No user message found")))
            return
        }

        // Use a background thread for processing to keep UI responsive
        DispatchQueue.global(qos: .userInitiated).async {
            // Check for search commands first
            let searchCommandPatterns = [
                "\\[web search:([^\\]]+)\\]",
                "\\[deep search:([^\\]]+)\\]",
                "\\[academic search:([^\\]]+)\\]",
                "\\[news search:([^\\]]+)\\]",
                "\\[specialized search:([^\\]]+)\\]"
            ]
            
            for pattern in searchCommandPatterns {
                if let range = lastUserMessage.range(of: pattern, options: .regularExpression) {
                    if let queryRange = lastUserMessage.range(of: "\\[\\w+ search:([^\\]]+)\\]", options: .regularExpression) {
                        // Extract the command type and query
                        let command = String(lastUserMessage[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let queryMatch = lastUserMessage[queryRange]
                        
                        // Extract the actual query from the command
                        if let colonIndex = queryMatch.firstIndex(of: ":"),
                           let endBracketIndex = queryMatch.lastIndex(of: "]") {
                            let startIndex = queryMatch.index(after: colonIndex)
                            let query = String(queryMatch[startIndex..<endBracketIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Process based on command type
                            if command.contains("web search") {
                                // Regular web search
                                self.performWebSearch(query: query) { searchResult in
                                    completion(.success(searchResult))
                                }
                                return
                            } else if command.contains("deep search") {
                                // Deep search
                                let depth: SearchDepth = command.contains("specialized") ? .specialized : .deep
                                self.performDeepSearch(query: query, depth: depth) { searchResult in
                                    completion(.success(searchResult))
                                }
                                return
                            } else if command.contains("academic search") {
                                // Academic search
                                self.performAcademicSearch(query: query) { searchResult in
                                    completion(.success(searchResult))
                                }
                                return
                            } else if command.contains("news search") {
                                // News search
                                self.performNewsSearch(query: query) { searchResult in
                                    completion(.success(searchResult))
                                }
                                return
                            }
                        }
                    }
                }
            }
            
            // Get conversation history for context
            let conversationContext = self.extractConversationContext(messages: messages)
            
            // Process the language of the message using our NaturalLanguageHelper
            // Identify the language of the message
            let detectedLanguage = NaturalLanguageHelper.shared.detectLanguage(in: lastUserMessage)
            
            Debug.shared.log(message: "Detected message language: \(detectedLanguage)", type: .debug)
            
            // Set language context for better response generation
            var contextDict: [String: Any] = [:]
            contextDict["detectedLanguage"] = detectedLanguage
            
            // Also extract entities for better context understanding
            let entities = NaturalLanguageHelper.shared.extractEntities(from: lastUserMessage)
            if !entities.isEmpty {
                contextDict["entities"] = entities
                Debug.shared.log(message: "Detected entities: \(entities)", type: .debug)
            }
            
            // Get sentiment score
            let sentimentScore = NaturalLanguageHelper.shared.analyzeSentiment(in: lastUserMessage)
            contextDict["sentiment"] = sentimentScore
            Debug.shared.log(message: "Message sentiment score: \(sentimentScore)", type: .debug)
            
            // Record interaction for learning purposes
            if AILearningManager.shared.isLearningEnabled {
                // Record this interaction for future learning
                DispatchQueue.global(qos: .background).async {
                    AILearningManager.shared.collectUserDataInBackground()
                }
            }
            
            // Check if we should use CoreML-enhanced analysis
            if self.isCoreMLInitialized {
                // Use CoreML for enhanced intent analysis
                self.analyzeUserIntentWithML(message: lastUserMessage) { messageIntent in
                    // Use CoreML for enhanced response generation
                    self.generateResponseWithML(
                        intent: messageIntent,
                        userMessage: lastUserMessage,
                        conversationHistory: messages,
                        conversationContext: conversationContext,
                        appContext: context
                    ) { response in
                        // Record the interaction for learning
                        if AILearningManager.shared.isLearningEnabled {
                            let intent = self.getIntentString(from: messageIntent)
                            let confidence = 0.85 // Using fixed value since we're using ML
                            AILearningManager.shared.recordInteraction(
                                userMessage: lastUserMessage,
                                aiResponse: response,
                                intent: intent,
                                confidence: confidence
                            )
                        }
                        
                        // Check if the response contains a search command
                        self.processResponseForSearchCommands(response: response) { result in
                            // Add a small delay to simulate processing time
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                completion(.success(result))
                            }
                        }
                    }
                }
            } else {
                // Fall back to pattern matching if CoreML isn't available
                let messageIntent = self.analyzeUserIntent(message: lastUserMessage)
                
                // Generate response based on intent and context
                let response = self.generateResponse(
                    intent: messageIntent,
                    userMessage: lastUserMessage,
                    conversationHistory: messages,
                    conversationContext: conversationContext,
                    appContext: context
                )
                
                // Record the interaction for learning
                if AILearningManager.shared.isLearningEnabled {
                    let intent = self.getIntentString(from: messageIntent)
                    let confidence = 0.7 // Lower confidence for pattern matching
                    AILearningManager.shared.recordInteraction(
                        userMessage: lastUserMessage,
                        aiResponse: response,
                        intent: intent,
                        confidence: confidence
                    )
                }

                // Check if the response contains a search command
                self.processResponseForSearchCommands(response: response) { result in
                    // Add a small delay to simulate processing time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        completion(.success(result))
                    }
                }
            }
        }
    }
    
    /// Process a response string for embedded search commands and execute them if found
    private func processResponseForSearchCommands(response: String, completion: @escaping (String) -> Void) {
        // Define the pattern to match search commands
        let patterns = [
            "\\[web search:([^\\]]+)\\]",
            "\\[deep search:([^\\]]+)\\]",
            "\\[academic search:([^\\]]+)\\]",
            "\\[news search:([^\\]]+)\\]",
            "\\[specialized search:([^\\]]+)\\]"
        ]
        
        // Check for search commands
        for pattern in patterns {
            if let range = response.range(of: pattern, options: .regularExpression),
               let queryRange = response.range(of: "\\[\\w+ search:([^\\]]+)\\]", options: .regularExpression) {
                let command = String(response[range])
                
                // Extract the query portion
                if let colonIndex = command.firstIndex(of: ":"),
                   let endBracketIndex = command.lastIndex(of: "]") {
                    let startIndex = command.index(after: colonIndex)
                    let query = String(command[startIndex..<endBracketIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove the command from the response
                    var cleanedResponse = response
                    cleanedResponse.removeSubrange(queryRange)
                    
                    // Execute the search based on command type
                    if command.contains("web search") {
                        self.performWebSearch(query: query) { searchResult in
                            completion(cleanedResponse + "\n\n" + searchResult)
                        }
                        return
                    } else if command.contains("deep search") {
                        let depth: SearchDepth = command.contains("specialized") ? .specialized : .deep
                        self.performDeepSearch(query: query, depth: depth) { searchResult in
                            completion(cleanedResponse + "\n\n" + searchResult)
                        }
                        return
                    } else if command.contains("academic search") {
                        self.performAcademicSearch(query: query) { searchResult in
                            completion(cleanedResponse + "\n\n" + searchResult)
                        }
                        return
                    } else if command.contains("news search") {
                        self.performNewsSearch(query: query) { searchResult in
                            completion(cleanedResponse + "\n\n" + searchResult)
                        }
                        return
                    }
                }
            }
        }
        
        // If no search commands found, return the original response
        completion(response)
    }
    
    /// Convert MessageIntent to string representation for learning
    private func getIntentString(from intent: MessageIntent) -> String {
        switch intent {
        case .greeting:
            return "greeting"
        case .generalHelp:
            return "help"
        case .question(let topic):
            return "question:\(topic)"
        case .appNavigation(let destination):
            return "navigate:\(destination)"
        case .appInstall(let appName):
            return "install:\(appName)"
        case .appSign(let appName):
            return "sign:\(appName)"
        case .sourceAdd(let url):
            return "add_source:\(url)"
        case .webSearch(let query):
            return "search:\(query)"
        case .unknown:
            return "unknown"
        }
    }
    
    // Extract meaningful context from conversation history
    private func extractConversationContext(messages: [AIMessagePayload]) -> String {
        // Get the last 5 messages for context (or fewer if there aren't 5)
        let contextMessages = messages.suffix(min(5, messages.count))
        
        return contextMessages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
    }

    // MARK: - Intent Analysis

    enum MessageIntent {
        case question(topic: String)
        case appNavigation(destination: String)
        case appInstall(appName: String)
        case appSign(appName: String)
        case sourceAdd(url: String)
        case webSearch(query: String)
        case generalHelp
        case greeting
        case unknown
    }

    func analyzeUserIntent(message: String) -> MessageIntent {
        let lowercasedMessage = message.lowercased()

        // Check for greetings
        if lowercasedMessage.contains("hello") || lowercasedMessage.contains("hi ") || lowercasedMessage == "hi" || lowercasedMessage.contains("hey") {
            return .greeting
        }

        // Check for help requests
        if lowercasedMessage.contains("help") || lowercasedMessage.contains("how do i") || lowercasedMessage.contains("how to") {
            return .generalHelp
        }
        
        // Check for web search requests
        if let match = lowercasedMessage.range(of: "(?:search|google|look up|find)\\s+(?:for\\s+)?(?:information\\s+about\\s+)?([^?.,]+)", options: .regularExpression) {
            let query = String(lowercasedMessage[match]).replacing(regularExpression: "(?:search|google|look up|find)\\s+(?:for\\s+)?(?:information\\s+about\\s+)?", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .webSearch(query: query)
        }

        // Use regex patterns to identify specific intents
        if let match = lowercasedMessage.range(of: "sign\\s+(the\\s+)?app\\s+(?:called\\s+|named\\s+)?([^?]+)", options: .regularExpression) {
            let appName = String(lowercasedMessage[match]).replacing(regularExpression: "sign\\s+(the\\s+)?app\\s+(?:called\\s+|named\\s+)?", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .appSign(appName: appName)
        }

        if let match = lowercasedMessage.range(of: "(?:go\\s+to|navigate\\s+to|open|show)\\s+(?:the\\s+)?([^?]+?)\\s+(?:tab|screen|page|section)", options: .regularExpression) {
            let destination = String(lowercasedMessage[match]).replacing(regularExpression: "(?:go\\s+to|navigate\\s+to|open|show)\\s+(?:the\\s+)?|\\s+(?:tab|screen|page|section)", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .appNavigation(destination: destination)
        }

        if let match = lowercasedMessage.range(of: "add\\s+(?:a\\s+)?(?:new\\s+)?source\\s+(?:with\\s+url\\s+|at\\s+|from\\s+)?([^?]+)", options: .regularExpression) {
            let url = String(lowercasedMessage[match]).replacing(regularExpression: "add\\s+(?:a\\s+)?(?:new\\s+)?source\\s+(?:with\\s+url\\s+|at\\s+|from\\s+)?", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .sourceAdd(url: url)
        }

        if let match = lowercasedMessage.range(of: "install\\s+(?:the\\s+)?app\\s+(?:called\\s+|named\\s+)?([^?]+)", options: .regularExpression) {
            let appName = String(lowercasedMessage[match]).replacing(regularExpression: "install\\s+(?:the\\s+)?app\\s+(?:called\\s+|named\\s+)?", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .appInstall(appName: appName)
        }

        // If it contains a question mark, assume it's a question
        if lowercasedMessage.contains("?") {
            // Extract topic from question
            let topic = lowercasedMessage.replacing(regularExpression: "\\?|what|how|when|where|why|who|is|are|can|could|would|will|should", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .question(topic: topic)
        }

        // Default case
        return .unknown
    }

    // MARK: - Response Generation

    func generateResponse(intent: MessageIntent, userMessage: String, conversationHistory: [AIMessagePayload], conversationContext: String, appContext: AppContext) -> String {
        // Get context information
        let contextInfo = appContext.currentScreen
        // Get available commands for use in help responses
        let commandsList = AppContextManager.shared.availableCommands()
        
        // Get additional context from the app
        let additionalContext = CustomAIContextProvider.shared.getContextSummary()

        switch intent {
            case .greeting:
                return "Hello! I'm your Backdoor assistant. I can help you sign apps, manage sources, and navigate through the app. How can I assist you today?"

            case .generalHelp:
                let availableCommandsText = commandsList.isEmpty ?
                    "" :
                    "\n\nAvailable commands: " + commandsList.joined(separator: ", ")

                return """
                I'm here to help you with Backdoor! Here are some things I can do:

                • Sign apps with your certificates
                • Add new sources for app downloads
                • Help you navigate through different sections
                • Install apps from your sources
                • Provide information about Backdoor's features\(availableCommandsText)

                What would you like help with specifically?
                """

            case let .question(topic):
                // Handle different topics the user might ask about
                if topic.contains("certificate") || topic.contains("cert") {
                    return "Certificates are used to sign apps so they can be installed on your device. You can manage your certificates in the Settings tab. If you need to add a new certificate, go to Settings > Certificates and tap the + button. Would you like me to help you navigate there? [navigate to:certificates]"
                } else if topic.contains("sign") {
                    return "To sign an app, first navigate to the Library tab where your downloaded apps are listed. Select the app you want to sign, then tap the Sign button. Make sure you have a valid certificate set up first. Would you like me to help you navigate to the Library? [navigate to:library]"
                } else if topic.contains("source") || topic.contains("repo") {
                    return "Sources are repositories where you can find apps to download. To add a new source, go to the Sources tab and tap the + button. Enter the URL of the source you want to add. Would you like me to help you navigate to the Sources tab? [navigate to:sources]"
                } else if topic.contains("backdoor") || topic.contains("app") {
                    return "Backdoor is an app signing tool that allows you to sign and install apps using your own certificates. It helps you manage app sources, download apps, and sign them for installation on your device. \(additionalContext) Is there something specific about Backdoor you'd like to know?"
                } else {
                    // General response when we don't have specific information about the topic
                    return "That's a good question about \(topic). Based on the current state of the app, I can see you're on the \(contextInfo) screen. \(additionalContext) Would you like me to help you navigate somewhere specific or perform an action related to your question?"
                }

            case let .appNavigation(destination):
                return "I'll help you navigate to the \(destination) section. [navigate to:\(destination)]"

            case let .appSign(appName):
                return "I'll help you sign the app \"\(appName)\". Let's get started with the signing process. [sign app:\(appName)]"

            case let .appInstall(appName):
                return "I'll help you install \"\(appName)\". First, let me check if it's available in your sources. [install app:\(appName)]"

            case let .sourceAdd(url):
                return "I'll add the source from \"\(url)\" to your repositories. [add source:\(url)]"

            case let .webSearch(query):
                let searchDepth = determineSearchDepth(for: query)
                let queryType = getSearchType(from: query)
                
                switch searchDepth {
                case .standard:
                    return "Let me search the web for information about \"\(query)\". [web search:\(query)]"
                case .enhanced:
                    return "Let me perform an enhanced search to find better information about \"\(query)\". [deep search:\(query)]"
                case .deep:
                    return "I'll perform a comprehensive deep search to find detailed information about \"\(query)\". [deep search:\(query)]"
                case .specialized:
                    if queryType == .academic {
                        return "I'll search academic sources for scholarly information about \"\(query)\". [academic search:\(query)]"
                    } else if queryType == .news {
                        return "I'll search news sources for the latest information about \"\(query)\". [news search:\(query)]"
                    } else {
                        return "I'll perform a specialized search to find the most relevant information about \"\(query)\". [specialized search:\(query)]"
                    }
                }
                
            case .unknown:
                // Extract any potential commands from the message using regex
                let commandPattern = "(sign|navigate to|install|add source|search)\\s+([\\w\\s.:/\\-]+)"
                if let match = userMessage.range(of: commandPattern, options: .regularExpression) {
                    let commandText = String(userMessage[match])
                    let components = commandText.split(separator: " ", maxSplits: 1).map(String.init)

                    if components.count == 2 {
                        let command = components[0]
                        let parameter = components[1].trimmingCharacters(in: .whitespacesAndNewlines)

                        return "I'll help you with that request. [\(command):\(parameter)]"
                    }
                }

                // Check if the message contains keywords related to app functionality
                let appKeywords = ["sign", "certificate", "source", "install", "download", "app", "library", "settings"]
                let containsAppKeywords = appKeywords.contains { userMessage.lowercased().contains($0) }
                
                if containsAppKeywords {
                    return """
                    I understand you need assistance with Backdoor. Based on your current context (\(contextInfo)), here are some actions I can help with:

                    - Sign apps
                    - Install apps
                    - Add sources
                    - Navigate to different sections

                    \(additionalContext)
                    
                    Please let me know specifically what you'd like to do.
                    """
                } else {
                    // For completely unrelated queries, provide a friendly response
                    return """
                    I'm your Backdoor assistant, focused on helping you with app signing, installation, and management. 
                    
                    \(additionalContext)
                    
                    If you have questions about using Backdoor, I'm here to help! What would you like to know about the app?
                    """
                }
        }
    }
}

// Helper extension for string regex replacement
extension String {
    func replacing(regularExpression pattern: String, with replacement: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(self.startIndex..., in: self)
            return regex.stringByReplacingMatches(in: self, range: range, withTemplate: replacement)
        } catch {
            return self
        }
    }
}
