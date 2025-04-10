// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import CoreML
import UIKit

/// Manages CoreML model loading and prediction operations
final class CoreMLManager {
    // Singleton instance
    static let shared = CoreMLManager()
    
    // Model storage
    private var mlModel: MLModel?
    private var modelLoaded = false
    private var modelURL: URL?
    
    // Public getter for model loaded status
    var isModelLoaded: Bool {
        return modelLoaded
    }
    
    // Queue for thread-safe operations
    private let predictionQueue = DispatchQueue(label: "com.backdoor.coreml.prediction", qos: .userInitiated)
    
    // Private initializer for singleton
    private init() {
        Debug.shared.log(message: "Initializing CoreML Manager for dynamic model loading", type: .info)
        
        // Set up model directories from the start
        ModelFileManager.shared.setupModelDirectories()
        
        // Look for user-generated models first - highest priority
        if let userGeneratedModel = ModelFileManager.shared.findUserGeneratedModel() {
            modelURL = userGeneratedModel
            Debug.shared.log(message: "Found user-generated model at: \(userGeneratedModel.path)", type: .info)
        } else {
            Debug.shared.log(message: "No user-generated models found - will use pattern matching until one is created", type: .info)
            
            // Trigger AILearningManager to collect data for future model training
            DispatchQueue.global(qos: .background).async {
                // Enable learning by default to collect data for model creation
                if !AILearningManager.shared.isLearningEnabled {
                    AILearningManager.shared.setLearningEnabled(true)
                    Debug.shared.log(message: "Enabled AI learning to collect data for model generation", type: .info)
                }
                
                // Check if we have enough data to train a model
                let stats = AILearningManager.shared.getLearningStatistics()
                if stats.totalDataPoints >= 5 {  // Lower threshold for initial model
                    Debug.shared.log(message: "Found \(stats.totalDataPoints) data points, attempting to create initial model", type: .info)
                    
                    // Create initial model
                    self.createInitialModel()
                }
            }
        }
    }
    
    /// Create an initial model from existing data if possible
    private func createInitialModel() {
        Debug.shared.log(message: "Attempting to create initial AI model", type: .info)
        
        AILearningManager.shared.trainModelNow { success, message in
            if success {
                Debug.shared.log(message: "Successfully created initial model: \(message)", type: .info)
                
                // Notify the UI that a model is now available
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("AIModelUpdated"), 
                        object: nil
                    )
                }
                
                // Reload the model
                self.loadModel()
            } else {
                Debug.shared.log(message: "Could not create initial model: \(message)", type: .warning)
            }
        }
    }
    
    /// Find the best available model with prioritized search logic
    private func findBestAvailableModel() -> URL? {
        Debug.shared.log(message: "Looking for best available AI model", type: .info)
        
        // 1. First priority: User-generated models from AILearningManager
        if let userModel = AILearningManager.shared.getLatestModelURL() {
            Debug.shared.log(message: "Found user-trained model via AILearningManager: \(userModel.path)", type: .info)
            return userModel
        }
        
        // 2. Second priority: Any user models in the model directories
        if let userModelFromFileSystem = ModelFileManager.shared.findUserGeneratedModel() {
            Debug.shared.log(message: "Found user-generated model via filesystem search: \(userModelFromFileSystem.path)", type: .info)
            return userModelFromFileSystem
        }
        
        // 3. Check documents directory for models
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let aiModelsDir = documentsDirectory.appendingPathComponent("AIModels", isDirectory: true)
        let legacyModelsDir = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        
        do {
            // Check AIModels directory
            if FileManager.default.fileExists(atPath: aiModelsDir.path) {
                let contents = try FileManager.default.contentsOfDirectory(at: aiModelsDir, includingPropertiesForKeys: nil)
                let models = contents.filter { $0.pathExtension == "mlmodel" || $0.pathExtension == "mlmodelc" }
                if let newestModel = models.first {
                    Debug.shared.log(message: "Found model in AIModels directory: \(newestModel.path)", type: .info)
                    return newestModel
                }
            }
            
            // Check legacy Models directory
            if FileManager.default.fileExists(atPath: legacyModelsDir.path) {
                let contents = try FileManager.default.contentsOfDirectory(at: legacyModelsDir, includingPropertiesForKeys: nil)
                let models = contents.filter { $0.pathExtension == "mlmodel" || $0.pathExtension == "mlmodelc" }
                if let newestModel = models.first {
                    Debug.shared.log(message: "Found model in legacy Models directory: \(newestModel.path)", type: .info)
                    return newestModel
                }
            }
        } catch {
            Debug.shared.log(message: "Error searching for models in documents directory: \(error.localizedDescription)", type: .error)
        }
        
        Debug.shared.log(message: "No models found anywhere - a new one will be generated as the user interacts with the app", type: .info)
        return nil
    }
    
    // Model loading state tracking
    private var isModelLoading = false
    private var hasShownDeferredNotification = false
    
    /// Load the CoreML model asynchronously with safeguards
    func loadModel(completion: ((Bool) -> Void)? = nil) {
        // Skip in safe mode
        if SafeModeLauncher.shared.inSafeMode {
            Debug.shared.log(message: "CoreML model loading skipped in safe mode", type: .info)
            completion?(false)
            return
        }
        
        // Check memory status before attempting to load large model
        if shouldCheckMemory() && isMemoryConstrained() {
            Debug.shared.log(message: "Memory pressure detected - deferring CoreML model loading", type: .warning)
            notifyUserOfDeferredLoading()
            completion?(false)
            return
        }
        
        // Prevent duplicate loading attempts
        if isModelLoading {
            Debug.shared.log(message: "Model loading already in progress", type: .info)
            completion?(false)
            return
        }
        
        // Mark loading as in progress
        isModelLoading = true
        
        // Call the enhanced version that checks for locally trained models
        loadModelWithLocalLearning { [weak self] success in
            self?.isModelLoading = false
            completion?(success)
        }
    }
    
    /// Check if memory is constrained
    private func isMemoryConstrained() -> Bool {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            let memoryUsage = usedMemory / totalMemory
            
            Debug.shared.log(message: "Memory usage: \(Int(memoryUsage * 100))%", type: .info)
            
            return memoryUsage > 0.7 // If using more than 70% of memory
        } else {
            // Log error for debugging purposes
            Debug.shared.log(message: "Failed to get memory info: error \(kerr)", type: .error)
            
            // Default to true (memory is constrained) to be cautious when we can't determine
            return true
        }
    }
    
    /// Determine if we should check memory at all (performance optimization)
    private func shouldCheckMemory() -> Bool {
        // Only check memory on devices that might be constrained
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let totalMemoryGB = Double(totalMemory) / 1024.0 / 1024.0 / 1024.0
        
        // Debug log total device memory
        Debug.shared.log(message: "Device has \(String(format: "%.1f", totalMemoryGB)) GB RAM", type: .info)
        
        // Always check if device has less than 3GB RAM
        return totalMemoryGB < 3.0
    }
    
    /// Notify user that AI features are deferred
    private func notifyUserOfDeferredLoading() {
        // Only show once per session
        if hasShownDeferredNotification {
            return
        }
        
        hasShownDeferredNotification = true
        
        DispatchQueue.main.async {
            // Find top view controller using the shared extension method
            if let topVC = UIApplication.shared.topMostViewController() {
                let alert = UIAlertController(
                    title: "AI Features Delayed",
                    message: "AI features will be available when system resources allow. You can continue using other app features.",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                topVC.present(alert, animated: true)
            }
        }
    }
    
    /// Load the CoreML model with local learning support
    func loadModelWithLocalLearning(completion: ((Bool) -> Void)? = nil) {
        // If model is already loaded, return early
        guard !modelLoaded else {
            Debug.shared.log(message: "Model already loaded", type: .info)
            completion?(true)
            return
        }
        
        // First check for a locally trained model
        if let localModelURL = AILearningManager.shared.getLatestModelURL() {
            Debug.shared.log(message: "Found locally trained model, attempting to load", type: .info)
            loadModelFromURL(localModelURL) { [weak self] success in
                if success {
                    Debug.shared.log(message: "Successfully loaded locally trained model", type: .info)
                    completion?(true)
                } else {
                    Debug.shared.log(message: "Failed to load locally trained model, falling back to default", type: .warning)
                    // Fall back to default model
                    self?.loadDefaultModel(completion: completion)
                }
            }
            return
        }
        
        // No locally trained model, use default
        loadDefaultModel(completion: completion)
    }
    
    /// Load the default CoreML model (now based on user-generated models)
    private func loadDefaultModel(completion: ((Bool) -> Void)? = nil) {
        // First try with existing URL if we have one
        if let modelURL = modelURL {
            loadModelFromURL(modelURL, completion: completion)
            return
        }
        
        // Search for the best available model
        if let bestModelURL = findBestAvailableModel() {
            loadModelFromURL(bestModelURL, completion: completion)
            return
        }
        
        // If no models are available, inform system that we need to generate one
        ModelFileManager.shared.prepareMLModel { [weak self] result in
            switch result {
            case .success(let modelURL):
                if let url = modelURL {
                    // A model was found, load it
                    self?.loadModelFromURL(url, completion: completion)
                } else {
                    // No model available yet - that's expected with the new system
                    Debug.shared.log(message: "No AI model available yet - will use pattern matching until one is created", type: .info)
                    DispatchQueue.main.async {
                        // Schedule creation of an initial model if we have enough data
                        DispatchQueue.global(qos: .background).async {
                            self?.tryGenerateInitialModel()
                        }
                        completion?(false)
                    }
                }
                
            case .failure(let error):
                Debug.shared.log(message: "Failed to prepare model system: \(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }
    
    /// Try to generate an initial model if possible with existing data
    private func tryGenerateInitialModel() {
        // Get statistics on available data
        let stats = AILearningManager.shared.getLearningStatistics()
        
        // If we have enough data to attempt model creation
        if stats.totalDataPoints >= 5 {
            Debug.shared.log(message: "Found \(stats.totalDataPoints) data points - attempting to create initial AI model", type: .info)
            
            // Train with reduced requirements
            AILearningManager.shared.trainModelNow { success, message in
                if success {
                    Debug.shared.log(message: "Successfully created initial model: \(message)", type: .info)
                    
                    // Reload the model
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        self?.loadModel()
                    }
                } else {
                    Debug.shared.log(message: "Could not create initial model: \(message)", type: .warning)
                }
            }
        } else {
            Debug.shared.log(message: "Not enough data to create initial model (\(stats.totalDataPoints) points). Need more user interactions.", type: .info)
        }
    }
    
    /// Load model from the specified URL with memory safety and progress indication
    private func loadModelFromURL(_ url: URL, completion: ((Bool) -> Void)? = nil) {
        // Show loading indicator for large files after a small delay
        var loadingAlert: UIAlertController?
        var loadingAlertPresented = false
        
        // Only show UI after a brief delay if loading is still ongoing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            if self?.isModelLoading == true {
                // Find appropriate view controller to present on
                // Using the shared extension method to find top view controller
                guard let topVC = UIApplication.shared.topMostViewController() else {
                    return
                }
                
                // Don't interrupt if user is already looking at something
                if topVC.presentedViewController != nil {
                    return
                }
                
                // Create alert with progress indicator
                loadingAlert = UIAlertController(
                    title: "Loading AI Model",
                    message: "Please wait while AI features are prepared...",
                    preferredStyle: .alert
                )
                
                // Add activity indicator
                let indicator = UIActivityIndicatorView(style: .medium)
                indicator.translatesAutoresizingMaskIntoConstraints = false
                loadingAlert?.view.addSubview(indicator)
                indicator.startAnimating()
                
                // Position indicator
                NSLayoutConstraint.activate([
                    indicator.centerXAnchor.constraint(equalTo: loadingAlert!.view.centerXAnchor),
                    indicator.topAnchor.constraint(equalTo: loadingAlert!.view.topAnchor, constant: 80),
                    indicator.widthAnchor.constraint(equalToConstant: 40),
                    indicator.heightAnchor.constraint(equalToConstant: 40)
                ])
                
                // Add cancel button
                loadingAlert?.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                    self?.isModelLoading = false
                    completion?(false)
                })
                
                if let alert = loadingAlert {
                    topVC.present(alert, animated: true)
                    loadingAlertPresented = true
                }
            }
        }
        
        // Set up memory pressure observer
        var memoryObserver: NSObjectProtocol?
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                Debug.shared.log(message: "Memory warning during model loading, canceling", type: .warning)
                
                // Clean up - ensure UI operations happen on main thread
                if loadingAlertPresented {
                    DispatchQueue.main.async {
                        loadingAlert?.dismiss(animated: true)
                    }
                }
                
                if let observer = memoryObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
                
                self?.isModelLoading = false
                completion?(false)
            }
        
        // Perform actual loading in background
        predictionQueue.async { [weak self] in
            do {
                // Check file size before loading
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attributes[.size] as? NSNumber {
                        let fileSizeMB = Double(truncating: fileSize) / 1024.0 / 1024.0
                        Debug.shared.log(message: "Model file size: \(String(format: "%.1f", fileSizeMB)) MB", type: .info)
                        
                        // Extra warning for very large models
                        if fileSizeMB > 300 {
                            Debug.shared.log(message: "Warning: Very large model file, performance may be affected", type: .warning)
                        }
                    }
                } catch {
                    Debug.shared.log(message: "Could not determine model file size", type: .warning)
                }
                
                // Actual model loading
                let compiledModelURL = try MLModel.compileModel(at: url)
                let model = try MLModel(contentsOf: compiledModelURL)
                
                // Remove observer as loading succeeded
                if let observer = memoryObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
                
                // Dismiss loading alert
                DispatchQueue.main.async {
                    if loadingAlertPresented {
                        loadingAlert?.dismiss(animated: true)
                    }
                    
                    self?.mlModel = model
                    self?.modelLoaded = true
                    Debug.shared.log(message: "CoreML model loaded successfully from: \(url.path)", type: .info)
                    completion?(true)
                }
            } catch {
                // Remove observer on failure
                if let observer = memoryObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
                
                // Dismiss loading alert
                DispatchQueue.main.async {
                    if loadingAlertPresented {
                        loadingAlert?.dismiss(animated: true)
                    }
                    
                    Debug.shared.log(message: "Failed to load CoreML model: \(error)", type: .error)
                    completion?(false)
                }
            }
        }
    }
    
    /// Analyzes user input to determine intent with ML model
    func predictIntent(from text: String, completion: @escaping (Result<PredictionResult, PredictionError>) -> Void) {
        // Ensure model is loaded before attempting prediction
        if !modelLoaded {
            loadModel { [weak self] success in
                if success {
                    self?.performPrediction(text: text, completion: completion)
                } else {
                    // No model loaded, but that's expected in the dynamic model approach
                    // Return a softer error that indicates we're still gathering data
                    let parameters: [String: Any] = ["text": text]
                    
                    // Allow the app to function with pattern matching by providing a friendly error
                    let result = PredictionResult(
                        intent: "pattern_matching",
                        confidence: 0.5,
                        text: text,
                        parameters: parameters,
                        probabilities: ["pattern_matching": 1.0]
                    )
                    
                    completion(.success(result))
                }
            }
        } else {
            performPrediction(text: text, completion: completion)
        }
    }
    
    /// Performs sentiment analysis on text
    func analyzeSentiment(from text: String, completion: @escaping (Result<SentimentResult, PredictionError>) -> Void) {
        // Ensure model is loaded before attempting prediction
        if !modelLoaded {
            loadModel { [weak self] success in
                if success {
                    self?.performSentimentAnalysisInternal(text: text, completion: completion)
                } else {
                    // No model loaded, provide a neutral default sentiment
                    // This allows the app to keep functioning while we collect data
                    let result = SentimentResult(
                        sentiment: .neutral,
                        score: 0.5,  // Changed from confidence to score to match struct parameter name
                        text: text
                    )
                    
                    completion(.success(result))
                }
            }
        } else {
            performSentimentAnalysisInternal(text: text, completion: completion)
        }
    }
    
    /// Performs sentiment analysis with the model
    /// This method is deprecated - use analyzeSentiment(from:completion:) instead
    @available(*, deprecated, message: "Use analyzeSentiment(from:completion:) instead")
    func performSentimentAnalysis(text: String, completion: @escaping (Result<SentimentResult, PredictionError>) -> Void) {
        // Forward to the current implementation
        analyzeSentiment(from: text, completion: completion)
    }
    
    /// Non-overloaded version for internal use
    private func internalAnalyzeSentiment(text: String, completion: @escaping (Result<SentimentResult, PredictionError>) -> Void) {
        analyzeSentiment(from: text, completion: completion)
    }
    
    /// Performs sentiment analysis with pattern matching fallback
    private func performSentimentAnalysisInternal(text: String, completion: @escaping (Result<SentimentResult, PredictionError>) -> Void) {
        // If model isn't loaded, provide a reasonable default based on text analysis
        guard modelLoaded, let model = mlModel else {
            // Simple pattern matching for sentiment
            var sentiment: SentimentType = .neutral
            var confidence: Double = 0.5
            
            // Count positive and negative terms
            let lowercasedText = text.lowercased()
            let positiveTerms = ["good", "great", "excellent", "amazing", "love", "thanks", "thank", "awesome", "perfect", "happy"]
            let negativeTerms = ["bad", "terrible", "horrible", "awful", "hate", "slow", "problem", "issue", "error", "wrong", "not working"]
            
            var positiveCount = 0
            var negativeCount = 0
            
            for term in positiveTerms {
                if lowercasedText.contains(term) {
                    positiveCount += 1
                }
            }
            
            for term in negativeTerms {
                if lowercasedText.contains(term) {
                    negativeCount += 1
                }
            }
            
            // Determine sentiment based on counts
            if positiveCount > negativeCount {
                sentiment = .positive
                confidence = min(0.7, 0.5 + Double(positiveCount - negativeCount) * 0.05)
            } else if negativeCount > positiveCount {
                sentiment = .negative
                confidence = min(0.7, 0.5 + Double(negativeCount - positiveCount) * 0.05)
            }
            
            let result = SentimentResult(sentiment: sentiment, score: confidence, text: text)
            completion(.success(result))
            return
        }
        
        // Standard prediction with the model
        predictionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.modelNotLoaded))
                }
                return
            }
            
            // Attempt to use CoreML model
            do {
                // Get model description
                let modelDescription = model.modelDescription
                
                // Check input features
                guard let inputDescription = modelDescription.inputDescriptionsByName.first else {
                    throw PredictionError.invalidModelFormat
                }
                
                let featureName = inputDescription.key
                var inputFeatures: [String: MLFeatureValue] = [:]
                
                // Create string input for sentiment analysis
                inputFeatures[featureName] = MLFeatureValue(string: text)
                
                // Create input from features
                let provider = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
                
                // Make prediction
                let prediction = try model.prediction(from: provider)
                
                // Process output to determine sentiment
                var sentiment: SentimentType = .neutral
                var confidence: Double = 0.5
                
                // Try to extract sentiment from output
                if let sentimentOutput = prediction.featureValue(for: "sentiment")?.stringValue {
                    switch sentimentOutput.lowercased() {
                    case "positive":
                        sentiment = .positive
                    case "negative":
                        sentiment = .negative
                    default:
                        sentiment = .neutral
                    }
                    
                    // Try to get confidence
                    if let confidenceValue = prediction.featureValue(for: "confidence")?.doubleValue {
                        confidence = confidenceValue
                    }
                } else {
                    // Use pattern matching as fallback
                    let lowercasedText = text.lowercased()
                    let positiveTerms = ["good", "great", "excellent", "amazing", "love", "thanks", "thank", "awesome", "perfect", "happy"]
                    let negativeTerms = ["bad", "terrible", "horrible", "awful", "hate", "slow", "problem", "issue", "error", "wrong", "not working"]
                    
                    var positiveCount = 0
                    var negativeCount = 0
                    
                    for term in positiveTerms {
                        if lowercasedText.contains(term) {
                            positiveCount += 1
                        }
                    }
                    
                    for term in negativeTerms {
                        if lowercasedText.contains(term) {
                            negativeCount += 1
                        }
                    }
                    
                    if positiveCount > negativeCount {
                        sentiment = .positive
                        confidence = min(0.7, 0.5 + Double(positiveCount - negativeCount) * 0.05)
                    } else if negativeCount > positiveCount {
                        sentiment = .negative
                        confidence = min(0.7, 0.5 + Double(negativeCount - positiveCount) * 0.05)
                    }
                }
                
                let result = SentimentResult(sentiment: sentiment, score: confidence, text: text)
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
                
            } catch {
                // Fall back to pattern matching
                let result = self.fallbackSentimentAnalysis(text: text)
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            }
        }
    }
    
    /// Fallback sentiment analysis for when ML model is unavailable
    private func fallbackSentimentAnalysis(text: String) -> SentimentResult {
        let lowercasedText = text.lowercased()
        let positiveTerms = ["good", "great", "excellent", "amazing", "love", "thanks", "thank", "awesome", "perfect", "happy"]
        let negativeTerms = ["bad", "terrible", "horrible", "awful", "hate", "slow", "problem", "issue", "error", "wrong", "not working"]
        
        var positiveCount = 0
        var negativeCount = 0
        
        for term in positiveTerms {
            if lowercasedText.contains(term) {
                positiveCount += 1
            }
        }
        
        for term in negativeTerms {
            if lowercasedText.contains(term) {
                negativeCount += 1
            }
        }
        
        var sentiment: SentimentType = .neutral
        var confidence: Double = 0.5
        
        if positiveCount > negativeCount {
            sentiment = .positive
            confidence = min(0.7, 0.5 + Double(positiveCount - negativeCount) * 0.05)
        } else if negativeCount > positiveCount {
            sentiment = .negative
            confidence = min(0.7, 0.5 + Double(negativeCount - positiveCount) * 0.05)
        }
        
        return SentimentResult(sentiment: sentiment, score: confidence, text: text)
    }
    
    // MARK: - Private Methods
    
    /// Execute prediction on loaded model with pattern matching fallback
    private func performPrediction(text: String, completion: @escaping (Result<PredictionResult, PredictionError>) -> Void) {
        predictionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(.modelNotLoaded))
                }
                return
            }
            
            // If no model is loaded, use pattern matching
            guard let model = self.mlModel else {
                DispatchQueue.main.async {
                    // Use pattern matching as fallback
                    let patternResult = self.performPatternMatchingPrediction(text: text)
                    completion(.success(patternResult))
                    
                    // Collect this interaction for future model training
                    AILearningManager.shared.collectUserDataInBackground()
                }
                return
            }
            
            do {
                // Create prediction input based on model metadata
                // This uses a flexible approach to handle various model input types
                let modelDescription = model.modelDescription
                
                // Check model input features
                guard let inputDescription = modelDescription.inputDescriptionsByName.first else {
                    throw PredictionError.invalidModelFormat
                }
                
                let featureName = inputDescription.key
                let featureType = inputDescription.value.type
                
                var inputFeatures: [String: MLFeatureValue] = [:]
                
                // Handle different input feature types
                switch featureType {
                case .string:
                    // Text classification models typically use string inputs
                    inputFeatures[featureName] = MLFeatureValue(string: text)
                    
                case .dictionary:
                    // Some NLP models use dictionary inputs
                    inputFeatures[featureName] = try MLFeatureValue(dictionary: ["text": NSNumber(value: 1)])
                    
                case .multiArray:
                    // For models that expect text to be pre-encoded (we just use a placeholder here)
                    // In a real implementation, we would properly encode the text
                    Debug.shared.log(message: "Model requires multiArray input, using placeholder", type: .warning)
                    let placeholder = try MLMultiArray(shape: [1], dataType: .double)
                    placeholder[0] = NSNumber(value: 1.0)
                    inputFeatures[featureName] = MLFeatureValue(multiArray: placeholder)
                    
                default:
                    throw PredictionError.unsupportedInputType
                }
                
                // Create input from features
                let provider = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
                
                // Make prediction
                let prediction = try model.prediction(from: provider)
                
                // Process prediction outputs
                let result = try self.processOutputs(prediction: prediction, text: text)
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch let error as PredictionError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    Debug.shared.log(message: "CoreML prediction failed: \(error)", type: .error)
                    completion(.failure(.predictionFailed(error)))
                }
            }
        }
    }
    
    /// Perform pattern matching based intent prediction when ML model is unavailable
    private func performPatternMatchingPrediction(text: String) -> PredictionResult {
        let lowercasedText = text.lowercased()
        
        // Default values
        var intent = "unknown"
        var confidence: Double = 0.5
        var parameters: [String: Any] = ["text": text]
        
        // Check for greetings
        if lowercasedText.contains("hello") || lowercasedText.contains("hi ") || lowercasedText == "hi" || lowercasedText.contains("hey") {
            intent = "greeting"
            confidence = 0.8
        }
        // Check for help requests
        else if lowercasedText.contains("help") || lowercasedText.contains("how do i") || lowercasedText.contains("how to") {
            intent = "help"
            confidence = 0.7
        }
        // Check for navigation requests
        else if let range = lowercasedText.range(of: "(?:go\\s+to|navigate\\s+to|open|show)\\s+(?:the\\s+)?([^?]+?)\\s+(?:tab|screen|page|section)", options: .regularExpression) {
            intent = "navigate"
            
            let destination = String(lowercasedText[range]).replacing(regularExpression: "(?:go\\s+to|navigate\\s+to|open|show)\\s+(?:the\\s+)?|\\s+(?:tab|screen|page|section)", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            parameters["destination"] = destination
            confidence = 0.65
        }
        // Check for app installation or signing
        else if lowercasedText.contains("sign") && (lowercasedText.contains("app") || lowercasedText.contains("ipa")) {
            intent = "sign_app"
            
            if let range = lowercasedText.range(of: "sign\\s+(the\\s+)?app\\s+(?:called\\s+|named\\s+)?([^?]+)", options: .regularExpression) {
                let appName = String(lowercasedText[range]).replacing(regularExpression: "sign\\s+(the\\s+)?app\\s+(?:called\\s+|named\\s+)?", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                parameters["appName"] = appName
            }
            
            confidence = 0.6
        }
        else if lowercasedText.contains("install") && (lowercasedText.contains("app") || lowercasedText.contains("ipa")) {
            intent = "install"
            
            if let range = lowercasedText.range(of: "install\\s+(?:the\\s+)?app\\s+(?:called\\s+|named\\s+)?([^?]+)", options: .regularExpression) {
                let appName = String(lowercasedText[range]).replacing(regularExpression: "install\\s+(?:the\\s+)?app\\s+(?:called\\s+|named\\s+)?", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                parameters["appName"] = appName
            }
            
            confidence = 0.6
        }
        // Check for questions
        else if lowercasedText.contains("?") {
            intent = "question"
            
            // Extract topic from question
            let topic = lowercasedText.replacing(regularExpression: "\\?|what|how|when|where|why|who|is|are|can|could|would|will|should", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            parameters["topic"] = topic
            
            confidence = 0.55
        }
        
        // Create a dictionary of all possible intents with probabilities
        var probabilities: [String: Double] = [
            intent: confidence
        ]
        
        // Add some low-probability alternatives
        if intent != "greeting" { probabilities["greeting"] = 0.1 }
        if intent != "help" { probabilities["help"] = 0.1 }
        if intent != "navigate" { probabilities["navigate"] = 0.1 }
        if intent != "sign_app" { probabilities["sign_app"] = 0.1 }
        if intent != "install" { probabilities["install"] = 0.1 }
        if intent != "question" { probabilities["question"] = 0.1 }
        
        // Record this pattern match for learning
        DispatchQueue.global(qos: .background).async {
            AILearningManager.shared.recordInteraction(
                userMessage: text,
                aiResponse: "Pattern-matched response for \(intent)",
                intent: intent,
                confidence: confidence
            )
        }
        
        return PredictionResult(
            intent: intent,
            confidence: confidence,
            text: text, // Add the text parameter
            parameters: parameters,
            probabilities: probabilities
        )
    }
    
    /// Process model outputs into a structured result
    private func processOutputs(prediction: MLFeatureProvider, text: String) throws -> PredictionResult {
        // Default values
        var intent = "unknown"
        var confidence: Double = 0.0
        var parameters: [String: Any] = [:]
        var probabilities: [String: Double] = [:]
        
        // Try to extract output features from the prediction
        for featureName in prediction.featureNames {
            guard let feature = prediction.featureValue(for: featureName) else { continue }
            
            switch feature.type {
            case .string:
                // If output is a string, it's likely a classification label (intent)
                // Check if the string value is not empty
                if !feature.stringValue.isEmpty {
                    intent = feature.stringValue
                }
                
            case .dictionary:
                // Some models output probabilities as a dictionary
                if let dict = feature.dictionaryValue as? [String: Double] {
                    probabilities = dict
                    
                    // Find highest probability label
                    if let topPair = dict.max(by: { $0.value < $1.value }) {
                        intent = topPair.key
                        confidence = topPair.value
                    }
                }
                
            case .multiArray:
                // Some models output probability arrays
                if let multiArray = feature.multiArrayValue {
                    // Convert multiArray to dictionary of probabilities
                    // This is a simplified version - we'd need model metadata to map indices to labels
                    let count = multiArray.count
                    
                    for i in 0..<count {
                        let index = i
                        let value = multiArray[index].doubleValue
                        if value != 0 { // Assuming 0 means no value, adjust as needed
                            probabilities["class_\(i)"] = value
                            
                            // Track highest confidence
                            if value > confidence {
                                confidence = value
                                intent = "class_\(i)"
                            }
                        }
                    }
                }
                
            default:
                continue
            }
        }
        
        // Extract potential parameters from the text based on the intent
        parameters = extractParameters(from: text, intent: intent)
        
        return PredictionResult(
            intent: intent,
            confidence: confidence,
            text: text,
            parameters: parameters,
            probabilities: probabilities
        )
    }
    
    /// Extract parameters from text based on the predicted intent
    private func extractParameters(from text: String, intent: String) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // Use regex to extract structured data from the text
        switch intent.lowercased() {
        case "sign_app", "signing":
            // Extract app name
            let appNameMatches = text.extractMatch(pattern: "(?i)sign\\s+(?:the\\s+)?app\\s+(?:called\\s+|named\\s+)?([^?.,]+)", groupIndex: 1)
            if let appName = appNameMatches {
                parameters["appName"] = appName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        case "navigate", "navigation":
            // Extract destination
            let destinationMatches = text.extractMatch(pattern: "(?i)(?:go\\s+to|navigate\\s+to|open|show)\\s+(?:the\\s+)?([^?.,]+?)\\s+(?:tab|screen|page|section)", groupIndex: 1)
            if let destination = destinationMatches {
                parameters["destination"] = destination.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        case "add_source", "source":
            // Extract URL
            let urlMatches = text.extractMatch(pattern: "(?i)add\\s+(?:a\\s+)?(?:new\\s+)?source\\s+(?:with\\s+url\\s+|at\\s+|from\\s+)?([^?.,\\s]+)", groupIndex: 1)
            if let url = urlMatches {
                parameters["url"] = url.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        case "install_app", "install":
            // Extract app name
            let appNameMatches = text.extractMatch(pattern: "(?i)install\\s+(?:the\\s+)?app\\s+(?:called\\s+|named\\s+)?([^?.,]+)", groupIndex: 1)
            if let appName = appNameMatches {
                parameters["appName"] = appName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        case "question", "query":
            // Extract question topic
            let topicMatches = text.extractMatch(pattern: "(?i)(?:about|regarding|related\\s+to)\\s+([^?.,]+)", groupIndex: 1)
            if let topic = topicMatches {
                parameters["topic"] = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        case "greeting", "hello":
            // No parameters needed for greetings
            break
            
        case "help", "assistance":
            // Extract the type of help needed if specified
            if let helpTopic = text.extractMatch(pattern: "(?i)help\\s+(?:me\\s+)?(?:with\\s+)?(.+)", groupIndex: 1) {
                parameters["topic"] = helpTopic.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        case "search":
            // Extract search query
            if let query = text.extractMatch(pattern: "(?i)(?:search|find|look\\s+for)\\s+(.+)", groupIndex: 1) {
                parameters["query"] = query.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        case "generate", "create":
            // Extract creation type and content
            if let createType = text.extractMatch(pattern: "(?i)(?:generate|create)\\s+(?:a\\s+)?(?:new\\s+)?([\\w\\s]+?)\\s+(?:for|with|that)\\s+(.+)", groupIndex: 1) {
                parameters["type"] = createType.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let content = text.extractMatch(pattern: "(?i)(?:generate|create)\\s+(?:a\\s+)?(?:new\\s+)?[\\w\\s]+?\\s+(?:for|with|that)\\s+(.+)", groupIndex: 1) {
                    parameters["content"] = content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
        default:
            // For unknown intents, try to extract common patterns
            extractCommonParameters(from: text, into: &parameters)
        }
        
        return parameters
    }
    
    /// Extract common parameters from any text
    private func extractCommonParameters(from text: String, into parameters: inout [String: Any]) {
        // Look for app names
        if let appName = text.extractMatch(pattern: "(?i)\\b(?:app|application)\\s+(?:called|named)\\s+\"?([^\".,?!]+)\"?", groupIndex: 1) {
            parameters["appName"] = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Look for URLs
        if let url = text.extractMatch(pattern: "(?i)(?:https?://|www\\.)([^\\s.,]+\\.[^\\s.,]+[^\\s.,?!]*)", groupIndex: 0) {
            parameters["url"] = url.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Look for file paths
        if let filePath = text.extractMatch(pattern: "(?i)(?:file|path)\\s+(?:at|in)?\\s+\"?([^\".,:;?!]+)\"?", groupIndex: 1) {
            parameters["filePath"] = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Performs sentiment analysis on text (private implementation)
    private func performSentimentAnalysisLegacy(text: String, completion: @escaping (Result<SentimentResult, PredictionError>) -> Void) {
        predictionQueue.async { [weak self] in
            guard let self = self, let model = self.mlModel else {
                DispatchQueue.main.async {
                    completion(.failure(.modelNotLoaded))
                }
                return
            }
            
            do {
                // Similar approach to intent prediction but simplified for sentiment
                let modelDescription = model.modelDescription
                
                guard let inputDescription = modelDescription.inputDescriptionsByName.first else {
                    throw PredictionError.invalidModelFormat
                }
                
                let featureName = inputDescription.key
                let provider = try MLDictionaryFeatureProvider(dictionary: [
                    featureName: MLFeatureValue(string: text)
                ])
                
                // Make prediction
                let prediction = try model.prediction(from: provider)
                
                // Process sentiment outputs - simplified for common sentiment models
                var sentiment = SentimentType.neutral
                var score: Double = 0.5
                
                for featureName in prediction.featureNames {
                    guard let feature = prediction.featureValue(for: featureName) else { continue }
                    
                    // Check if the feature matches one of our sentiment values
                    if feature.type == .string && ["positive", "negative", "neutral"].contains(feature.stringValue.lowercased()) {
                        // Direct sentiment classification
                        sentiment = SentimentType(rawValue: feature.stringValue.lowercased()) ?? .neutral
                        score = sentiment == .neutral ? 0.5 : (sentiment == .positive ? 0.75 : 0.25)
                    } else if let value = feature.dictionaryValue as? [String: Double] {
                        // Probabilities for each sentiment
                        if let positive = value["positive"], let negative = value["negative"] {
                            score = positive
                            sentiment = positive > negative ? .positive : (negative > positive ? .negative : .neutral)
                        }
                    } else if feature.type == .int64 {
                        // Some models use integers (0, 1, 2) for sentiment
                        let sentimentValue = Int(feature.int64Value)
                        switch sentimentValue {
                        case 0: sentiment = .negative; score = 0.25
                        case 1: sentiment = .neutral; score = 0.5
                        case 2: sentiment = .positive; score = 0.75
                        default: sentiment = .neutral; score = 0.5
                        }
                    }
                }
                
                let result = SentimentResult(
                    sentiment: sentiment,
                    score: score,
                    text: text
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch let error as PredictionError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    Debug.shared.log(message: "CoreML sentiment analysis failed: \(error)", type: .error)
                    completion(.failure(.predictionFailed(error)))
                }
            }
        }
    }
}

// Import the extension containing extractMatch from AppContextManager+AIIntegration.swift
// Note: The extractMatch method is defined elsewhere in the project
// We avoid redeclaration by using that implementation instead

// MARK: - Models

/// Result of intent prediction
struct PredictionResult {
    let intent: String
    let confidence: Double
    let text: String
    let parameters: [String: Any]
    let probabilities: [String: Double]
}

/// Result of sentiment analysis
struct SentimentResult {
    let sentiment: SentimentType
    let score: Double
    let text: String
}

/// Types of sentiment
enum SentimentType: String {
    case positive
    case negative
    case neutral
}

/// Errors that can occur during prediction
enum PredictionError: Error, LocalizedError {
    case modelNotLoaded
    case modelNotFound
    case invalidModelFormat
    case unsupportedInputType
    case unsupportedOperation
    case predictionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "CoreML model is not loaded"
        case .modelNotFound:
            return "CoreML model could not be found"
        case .invalidModelFormat:
            return "CoreML model has an invalid format"
        case .unsupportedInputType:
            return "CoreML model has an unsupported input type"
        case .unsupportedOperation:
            return "Operation not supported on this iOS version"
        case let .predictionFailed(error):
            return "Prediction failed: \(error.localizedDescription)"
        }
    }
}
