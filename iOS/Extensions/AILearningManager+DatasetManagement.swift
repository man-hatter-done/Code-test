// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import CoreML

// MARK: - Dataset Management Extension

extension AILearningManager {
    
    /// Incorporate external dataset into training
    func incorporateDataset(_ datasetContent: [String: Any]) -> Bool {
        Debug.shared.log(message: "Incorporating external dataset into AI training", type: .info)
        
        do {
            // Extract training data from dataset
            guard let data = extractTrainingData(from: datasetContent) else {
                Debug.shared.log(message: "Failed to extract training data from dataset", type: .error)
                return false
            }
            
            let trainingData = data.training
            let evaluationData = data.evaluation
            
            // If we have enough data, trigger model training
            if trainingData.count >= 10 {
                // Save datasets for future use
                saveExternalTrainingData(trainingData)
                
                // Trigger training
                let result = trainModelWithAllInteractions()
                
                // Log the result
                if result.success {
                    Debug.shared.log(message: "Successfully incorporated dataset into training, new model version: \(result.version)", type: .info)
                    
                    // Upload logs to Dropbox if user has consented
                    if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
                        logDatasetIncorporation(datasetSize: trainingData.count, success: true, modelVersion: result.version)
                    }
                } else {
                    Debug.shared.log(message: "Failed to incorporate dataset: \(result.errorMessage ?? "Unknown error")", type: .error)
                    
                    // Upload logs to Dropbox if user has consented
                    if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
                        logDatasetIncorporation(datasetSize: trainingData.count, success: false, modelVersion: currentModelVersion)
                    }
                }
                
                return result.success
            } else {
                Debug.shared.log(message: "Dataset too small to incorporate (needs at least 10 records)", type: .warning)
                return false
            }
        } catch {
            Debug.shared.log(message: "Error incorporating dataset: \(error.localizedDescription)", type: .error)
            return false
        }
    }
    
    /// Extract training data from dataset content
    private func extractTrainingData(from dataset: [String: Any]) -> (training: [[String: Any]], evaluation: [[String: Any]])? {
        var trainingData: [[String: Any]] = []
        var evaluationData: [[String: Any]] = []
        
        // Check if dataset contains direct data array
        if let dataArray = dataset["data"] as? [[String: Any]] {
            // Split into training and evaluation (80/20 split)
            let splitIndex = Int(Double(dataArray.count) * 0.8)
            trainingData = Array(dataArray[0..<splitIndex])
            evaluationData = Array(dataArray[splitIndex..<dataArray.count])
        } 
        // Check if dataset has explicit training/evaluation split
        else if let training = dataset["training"] as? [[String: Any]] {
            trainingData = training
            
            if let evaluation = dataset["evaluation"] as? [[String: Any]] {
                evaluationData = evaluation
            }
        }
        // Check if dataset is just a flat dictionary
        else if let items = dataset["items"] as? [[String: Any]] {
            // Split into training and evaluation (80/20 split)
            let splitIndex = Int(Double(items.count) * 0.8)
            trainingData = Array(items[0..<splitIndex])
            evaluationData = Array(items[splitIndex..<items.count])
        }
        // If dataset is in a format we don't recognize
        else {
            // Try to convert the entire dataset to training data
            trainingData = [dataset]
        }
        
        if trainingData.isEmpty {
            return nil
        }
        
        return (training: trainingData, evaluation: evaluationData)
    }
    
    /// Save external training data for future use
    private func saveExternalTrainingData(_ data: [[String: Any]]) {
        // Convert data to interactions
        for item in data {
            // Extract relevant fields from the item
            let userMessage = item["input"] as? String ?? item["query"] as? String ?? item["text"] as? String ?? ""
            let aiResponse = item["output"] as? String ?? item["response"] as? String ?? ""
            let intent = item["intent"] as? String ?? item["category"] as? String ?? "external"
            let confidence = item["confidence"] as? Double ?? 0.9
            
            // Skip if we don't have a valid user message
            if userMessage.isEmpty {
                continue
            }
            
            // Create an interaction record
            let interaction = AIInteraction(
                id: UUID().uuidString,
                timestamp: Date(),
                userMessage: userMessage,
                aiResponse: aiResponse,
                detectedIntent: intent,
                confidenceScore: confidence,
                feedback: AIFeedback(rating: 5, comment: "External dataset"), // Assume high quality
                context: nil,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                modelVersion: currentModelVersion
            )
            
            // Add to stored interactions
            interactionsLock.lock()
            storedInteractions.append(interaction)
            interactionsLock.unlock()
        }
        
        // Save to disk
        saveInteractions()
    }
    
    /// Log dataset incorporation to Dropbox if user has consented
    private func logDatasetIncorporation(datasetSize: Int, success: Bool, modelVersion: String) {
        let logEntry = """
        === DATASET INCORPORATION LOG ===
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        Dataset Size: \(datasetSize) records
        Success: \(success)
        Model Version: \(modelVersion)
        Device: \(UIDevice.current.name)
        System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        """
        
        EnhancedDropboxService.shared.uploadLogEntry(
            logEntry,
            fileName: "dataset_incorporation_\(Int(Date().timeIntervalSince1970)).log"
        )
    }
    
    /// Check online for available datasets based on user behavior
    func checkForAvailableDatasets() {
        // Only proceed if auto-download is enabled and consent was given
        guard UserDefaults.standard.bool(forKey: "AIAutomaticDatasetDownload"),
              UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") else {
            return
        }
        
        Debug.shared.log(message: "Checking for available AI datasets based on user behavior", type: .info)
        
        // Analyze user behavior to determine dataset needs
        let topIntents = getTopUserIntents(limit: 3)
        
        // For each identified intent, check if we need datasets
        for intent in topIntents {
            if shouldDownloadDatasetForIntent(intent) {
                // In a real app, this would make a server request for dataset recommendations
                // For this implementation, we'll simulate finding a dataset
                simulateFindingDatasetForIntent(intent)
            }
        }
    }
    
    /// Get top intents from user interactions
    func getTopUserIntents(limit: Int) -> [String] {
        // Lock to safely access interactions
        interactionsLock.lock()
        defer { interactionsLock.unlock() }
        
        // Get all intents
        let allIntents = storedInteractions.map { $0.detectedIntent }
        
        // Count occurrences of each intent
        var intentCounts: [String: Int] = [:]
        for intent in allIntents {
            intentCounts[intent, default: 0] += 1
        }
        
        // Sort by count and take the top N
        let sortedIntents = intentCounts.sorted { $0.value > $1.value }
        
        // Return top intents (limited to the requested count)
        return sortedIntents.prefix(limit).map { $0.key }
    }
    
    /// Determine if we should download a dataset for an intent
    private func shouldDownloadDatasetForIntent(_ intent: String) -> Bool {
        // In a real app, this would use more sophisticated logic
        // For now, randomly decide based on intent type
        
        // Higher probability for certain intents
        if intent.contains("sign") || intent.contains("install") || intent.contains("navigation") {
            return Double.random(in: 0...1) > 0.7 // 30% chance
        }
        
        // Lower probability for other intents
        return Double.random(in: 0...1) > 0.9 // 10% chance
    }
    
    /// Simulate finding and downloading a dataset for an intent
    private func simulateFindingDatasetForIntent(_ intent: String) {
        Debug.shared.log(message: "Simulating finding dataset for intent: \(intent)", type: .info)
        
        // Convert intent to dataset category
        let category: String
        if intent.contains("sign") {
            category = "app_signing"
        } else if intent.contains("install") {
            category = "app_installation"
        } else if intent.contains("navigation") {
            category = "ui_navigation"
        } else {
            category = "general_assistance"
        }
        
        // Log the intent and category
        let logEntry = """
        === DATASET SEARCH LOG ===
        Timestamp: \(ISO8601DateFormatter().string(from: Date()))
        Intent: \(intent)
        Category: \(category)
        Device: \(UIDevice.current.name)
        """
        
        EnhancedDropboxService.shared.uploadLogEntry(
            logEntry,
            fileName: "dataset_search_\(Int(Date().timeIntervalSince1970)).log"
        )
    }
    
    /// Get performance metrics for the AI
    func getAIPerformanceMetrics() -> (confidenceAverage: Double, errorRate: Double) {
        // Lock to safely access interactions
        interactionsLock.lock()
        defer { interactionsLock.unlock() }
        
        // Need at least 10 interactions to calculate metrics
        if storedInteractions.count < 10 {
            return (confidenceAverage: 0.9, errorRate: 0.1) // Default values
        }
        
        // Get recent interactions
        let recentInteractions = Array(storedInteractions.suffix(50))
        
        // Calculate average confidence
        let confidenceSum = recentInteractions.reduce(0.0) { $0 + $1.confidenceScore }
        let confidenceAverage = confidenceSum / Double(recentInteractions.count)
        
        // Calculate error rate (approximate based on feedback)
        let interactionsWithFeedback = recentInteractions.filter { $0.feedback != nil }
        if interactionsWithFeedback.isEmpty {
            return (confidenceAverage: confidenceAverage, errorRate: 0.1) // Default error rate
        }
        
        let badFeedbackCount = interactionsWithFeedback.filter { $0.feedback?.rating ?? 0 < 3 }.count
        let errorRate = Double(badFeedbackCount) / Double(interactionsWithFeedback.count)
        
        return (confidenceAverage: confidenceAverage, errorRate: errorRate)
    }
    
    /// Get areas where the AI performance is lowest
    func getLowPerformanceAreas(limit: Int) -> [String] {
        // Lock to safely access interactions
        interactionsLock.lock()
        defer { interactionsLock.unlock() }
        
        // Get interactions with feedback
        let interactionsWithFeedback = storedInteractions.filter { $0.feedback != nil }
        
        // Calculate average rating per intent
        var intentRatings: [String: (total: Int, count: Int)] = [:]
        
        for interaction in interactionsWithFeedback {
            let intent = interaction.detectedIntent
            let rating = interaction.feedback?.rating ?? 0
            
            let current = intentRatings[intent] ?? (total: 0, count: 0)
            intentRatings[intent] = (total: current.total + rating, count: current.count + 1)
        }
        
        // Calculate average and sort
        var averageRatings: [(intent: String, average: Double)] = []
        
        for (intent, ratings) in intentRatings {
            if ratings.count >= 3 { // Need at least 3 ratings
                let average = Double(ratings.total) / Double(ratings.count)
                averageRatings.append((intent: intent, average: average))
            }
        }
        
        // Sort by average (ascending) and take top N
        let sortedRatings = averageRatings.sorted { $0.average < $1.average }
        return sortedRatings.prefix(limit).map { $0.intent }
    }
}
