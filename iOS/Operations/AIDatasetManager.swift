// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Manager class for AI dataset operations
class AIDatasetManager {
    // MARK: - Singleton
    
    static let shared = AIDatasetManager()
    
    // MARK: - Properties
    
    private let datasetsDirectory: URL
    private let downloadQueue = OperationQueue()
    
    // MARK: - Initialization
    
    private init() {
        // Set up directory for storing datasets
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        datasetsDirectory = documentsDirectory.appendingPathComponent("AIDatasets", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: datasetsDirectory, withIntermediateDirectories: true)
        
        // Configure download queue
        downloadQueue.maxConcurrentOperationCount = 2
        downloadQueue.qualityOfService = .utility
        
        // Set up automatic dataset checking
        setupAutomaticDatasetChecking()
    }
    
    // MARK: - Public Methods
    
    /// Get list of available datasets
    func getAvailableDatasets(completion: @escaping (Result<[AIDataset], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(AIDatasetError.invalidData("Manager was deallocated")))
                }
                return
            }
            
            do {
                // Get list of dataset files in the directory
                let fileManager = FileManager.default
                let files = try fileManager.contentsOfDirectory(at: self.datasetsDirectory, includingPropertiesForKeys: nil)
                
                // Only include JSON and CSV files
                let datasetFiles = files.filter { $0.pathExtension == "json" || $0.pathExtension == "csv" }
                
                // Create dataset objects for each file
                var datasets: [AIDataset] = []
                for fileURL in datasetFiles {
                    if let dataset = self.createDatasetFromFile(fileURL) {
                        datasets.append(dataset)
                    }
                }
                
                // Sort by date (newest first)
                datasets.sort { $0.dateAdded > $1.dateAdded }
                
                DispatchQueue.main.async {
                    completion(.success(datasets))
                }
            } catch {
                Debug.shared.log(message: "Error loading datasets: \(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Import a dataset from a local file
    func importDataset(from fileURL: URL, completion: @escaping (Result<AIDataset, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(AIDatasetError.invalidData("Manager was deallocated")))
                }
                return
            }
            
            do {
                // Validate file format
                let fileExtension = fileURL.pathExtension.lowercased()
                guard fileExtension == "json" || fileExtension == "csv" else {
                    throw AIDatasetError.invalidFormat("Only JSON and CSV formats are supported")
                }
                
                // Generate a unique name for the dataset
                let fileName = UUID().uuidString + "." + fileExtension
                let destinationURL = self.datasetsDirectory.appendingPathComponent(fileName)
                
                // Copy the file
                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                
                // Create dataset object
                if let dataset = self.createDatasetFromFile(destinationURL) {
                    // If consent was given, log the dataset upload
                    if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
                        self.logDatasetActivity(action: "import", dataset: dataset)
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(dataset))
                    }
                } else {
                    throw AIDatasetError.invalidData("Could not create dataset from the file")
                }
            } catch {
                Debug.shared.log(message: "Error importing dataset: \(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Use a dataset for AI model training
    func useDatasetForTraining(_ dataset: AIDataset, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(AIDatasetError.invalidData("Manager was deallocated")))
                }
                return
            }
            
            do {
                // Read the dataset file
                let fileURL = self.datasetsDirectory.appendingPathComponent(dataset.fileName)
                let fileData = try Data(contentsOf: fileURL)
                
                // Parse the dataset
                let trainingData: [String: Any]
                if dataset.format == "json" {
                    if let jsonData = try JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
                        trainingData = jsonData
                    } else if let jsonArray = try JSONSerialization.jsonObject(with: fileData) as? [[String: Any]] {
                        trainingData = ["data": jsonArray]
                    } else {
                        throw AIDatasetError.invalidData("Could not parse JSON dataset")
                    }
                } else if dataset.format == "csv" {
                    // Convert CSV to a dictionary for training
                    // This is a simplified implementation
                    let csvString = String(data: fileData, encoding: .utf8) ?? ""
                    let rows = csvString.components(separatedBy: .newlines)
                    if rows.isEmpty {
                        throw AIDatasetError.invalidData("Empty CSV file")
                    }
                    
                    let headers = rows[0].components(separatedBy: ",")
                    var records: [[String: String]] = []
                    
                    for i in 1..<rows.count {
                        let row = rows[i]
                        if row.isEmpty { continue }
                        
                        let values = row.components(separatedBy: ",")
                        var record: [String: String] = [:]
                        
                        for j in 0..<min(headers.count, values.count) {
                            record[headers[j]] = values[j]
                        }
                        
                        records.append(record)
                    }
                    
                    trainingData = ["data": records]
                } else {
                    throw AIDatasetError.invalidFormat("Unsupported format: \(dataset.format)")
                }
                
                // Pass the data to AILearningManager for training
                let trainSuccess = AILearningManager.shared.incorporateDataset(trainingData)
                
                if trainSuccess {
                    // Log the activity if consent was given
                    if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
                        self.logDatasetActivity(action: "train", dataset: dataset)
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                } else {
                    throw AIDatasetError.trainingFailed("Failed to incorporate dataset into AI model")
                }
            } catch {
                Debug.shared.log(message: "Error using dataset for training: \(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Delete a dataset
    func deleteDataset(_ dataset: AIDataset, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(AIDatasetError.invalidData("Manager was deallocated")))
                }
                return
            }
            
            do {
                let fileURL = self.datasetsDirectory.appendingPathComponent(dataset.fileName)
                try FileManager.default.removeItem(at: fileURL)
                
                // Log the activity if consent was given
                if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
                    self.logDatasetActivity(action: "delete", dataset: dataset)
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                Debug.shared.log(message: "Error deleting dataset: \(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Search for datasets available online
    func searchOnlineDatasets(completion: @escaping (Result<[AIDatasetInfo], Error>) -> Void) {
        // Simulate an API call to a dataset repository
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            // Create example datasets
            let exampleDatasets: [AIDatasetInfo] = [
                AIDatasetInfo(
                    name: "NLP Conversation Dataset",
                    description: "A dataset of natural language conversations for training chatbots",
                    url: URL(string: "https://example.com/datasets/nlp_conversations.json")!,
                    size: 2_500_000,
                    category: "Natural Language Processing"
                ),
                AIDatasetInfo(
                    name: "iOS User Interaction Patterns",
                    description: "Common iOS app interaction patterns and user behaviors",
                    url: URL(string: "https://example.com/datasets/ios_patterns.json")!,
                    size: 1_200_000,
                    category: "User Behavior"
                ),
                AIDatasetInfo(
                    name: "Technical Support Queries",
                    description: "Questions and answers related to technical support for apps",
                    url: URL(string: "https://example.com/datasets/tech_support.json")!,
                    size: 3_800_000,
                    category: "Support"
                ),
                AIDatasetInfo(
                    name: "App Installation Feedback",
                    description: "User feedback during app installation processes",
                    url: URL(string: "https://example.com/datasets/installation_feedback.csv")!,
                    size: 900_000,
                    category: "Feedback"
                ),
                AIDatasetInfo(
                    name: "Feature Request Analysis",
                    description: "Analysis of common feature requests for mobile apps",
                    url: URL(string: "https://example.com/datasets/feature_requests.json")!,
                    size: 1_700_000,
                    category: "User Research"
                )
            ]
            
            DispatchQueue.main.async {
                completion(.success(exampleDatasets))
            }
        }
    }
    
    /// Download a dataset from a URL
    func downloadDataset(from url: URL, completion: @escaping (Result<AIDataset, Error>) -> Void) {
        // Create download task
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(AIDatasetError.downloadFailed("Manager was deallocated")))
                }
                return
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(AIDatasetError.downloadFailed("No file was downloaded")))
                }
                return
            }
            
            do {
                // Get file extension from URL or response
                let fileExtension: String
                if let mimeType = response?.mimeType {
                    if mimeType.contains("json") {
                        fileExtension = "json"
                    } else if mimeType.contains("csv") {
                        fileExtension = "csv"
                    } else {
                        throw AIDatasetError.invalidFormat("Unsupported file format: \(mimeType)")
                    }
                } else {
                    // Try to get from URL
                    fileExtension = url.pathExtension.lowercased()
                    if fileExtension != "json" && fileExtension != "csv" {
                        throw AIDatasetError.invalidFormat("Only JSON and CSV formats are supported")
                    }
                }
                
                // Generate a name for the dataset
                let fileName = "downloaded_\(ISO8601DateFormatter().string(from: Date())).\(fileExtension)"
                let destinationURL = self.datasetsDirectory.appendingPathComponent(fileName)
                
                // Move downloaded file to datasets directory
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                
                // Create dataset object
                if let dataset = self.createDatasetFromFile(destinationURL) {
                    // Update dataset name based on content if possible
                    self.updateDatasetName(dataset)
                    
                    // If consent was given, log the dataset download
                    if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
                        self.logDatasetActivity(action: "download", dataset: dataset, sourceURL: url.absoluteString)
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(dataset))
                    }
                } else {
                    throw AIDatasetError.invalidData("Could not create dataset from the downloaded file")
                }
            } catch {
                Debug.shared.log(message: "Error saving downloaded dataset: \(error.localizedDescription)", type: .error)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Create a dataset object from a file
    private func createDatasetFromFile(_ fileURL: URL) -> AIDataset? {
        do {
            let fileManager = FileManager.default
            
            // Get file attributes
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            let creationDate = attributes[.creationDate] as? Date ?? Date()
            
            // Count records
            let recordCount = try countRecordsInFile(fileURL)
            
            // Create dataset object
            let dataset = AIDataset(
                id: UUID().uuidString,
                name: fileURL.deletingPathExtension().lastPathComponent,
                fileName: fileURL.lastPathComponent,
                format: fileURL.pathExtension.lowercased(),
                size: fileSize,
                dateAdded: creationDate,
                recordCount: recordCount,
                url: fileURL
            )
            
            return dataset
        } catch {
            Debug.shared.log(message: "Error creating dataset from file: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
    
    /// Count records in a dataset file
    private func countRecordsInFile(_ fileURL: URL) throws -> Int {
        let fileExtension = fileURL.pathExtension.lowercased()
        let fileData = try Data(contentsOf: fileURL)
        
        if fileExtension == "json" {
            if let jsonArray = try JSONSerialization.jsonObject(with: fileData) as? [[String: Any]] {
                return jsonArray.count
            } else if let jsonDict = try JSONSerialization.jsonObject(with: fileData) as? [String: Any],
                      let dataArray = jsonDict["data"] as? [[String: Any]] {
                return dataArray.count
            } else {
                return 1 // Assume it's a single record if not an array
            }
        } else if fileExtension == "csv" {
            let csvString = String(data: fileData, encoding: .utf8) ?? ""
            let rows = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
            return max(0, rows.count - 1) // Subtract 1 for header row
        } else {
            return 0
        }
    }
    
    /// Update dataset name based on content
    private func updateDatasetName(_ dataset: AIDataset) {
        do {
            // Try to read the file
            let fileData = try Data(contentsOf: dataset.url)
            
            // Extract a name from the dataset content
            var name = dataset.name
            
            if dataset.format == "json" {
                if let jsonDict = try JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
                    if let datasetName = jsonDict["name"] as? String {
                        name = datasetName
                    } else if let datasetTitle = jsonDict["title"] as? String {
                        name = datasetTitle
                    }
                }
            }
            
            // Update the dataset name if found in content
            if name != dataset.name {
                dataset.name = name
            }
        } catch {
            Debug.shared.log(message: "Error updating dataset name: \(error.localizedDescription)", type: .error)
        }
    }
    
    /// Log dataset activity to Dropbox
    private func logDatasetActivity(action: String, dataset: AIDataset, sourceURL: String? = nil) {
        let timestamp = Date()
        
        // Create the log entry
        var logEntry = """
        === DATASET ACTIVITY LOG ===
        Timestamp: \(ISO8601DateFormatter().string(from: timestamp))
        Action: \(action)
        Dataset: \(dataset.name)
        Format: \(dataset.format)
        Size: \(dataset.formattedSize)
        Records: \(dataset.recordCount)
        File: \(dataset.fileName)
        Device: \(UIDevice.current.name)
        """
        
        // Add source URL if available
        if let sourceURL = sourceURL {
            logEntry += "\nSource URL: \(sourceURL)"
        }
        
        // Upload to Dropbox
        EnhancedDropboxService.shared.uploadLogEntry(
            logEntry,
            fileName: "dataset_\(action)_\(Int(timestamp.timeIntervalSince1970)).log"
        )
    }
    
    // MARK: - Automatic Dataset Checking
    
    /// Set up automatic dataset checking
    private func setupAutomaticDatasetChecking() {
        // Check periodically for needed datasets
        let timer = Timer.scheduledTimer(timeInterval: 24 * 60 * 60, target: self, selector: #selector(checkForNeededDatasets), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        
        // Also check when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkForNeededDatasets),
            name: Notification.Name("AppDidBecomeActive"),
            object: nil
        )
    }
    
    @objc private func checkForNeededDatasets() {
        // Check if AI should look for new datasets
        AILearningManager.shared.checkForAvailableDatasets()
    }
}
