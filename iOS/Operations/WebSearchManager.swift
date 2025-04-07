// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit
import NaturalLanguage

// MARK: - Data Structures

/// Source type for categorizing search results
enum SourceType {
    case web
    case academic
    case news
    case social
    case database
    case unknown
}

/// Search depth levels for different search intensities
enum SearchDepth: Int {
    case standard = 0    // Basic search
    case enhanced = 1    // Follow top links
    case deep = 2        // Follow multiple links with recursive crawling
    case specialized = 3 // Domain-specific searches (academic, news, etc.)
}

/// Basic search result model
struct WebSearchResult {
    let title: String
    let description: String
    let url: URL
    var sourceType: SourceType = .web
}

/// Enhanced search result with additional metadata
struct DeepSearchResult {
    var title: String = ""
    var description: String = ""
    var url: URL?
    var keywords: [String] = []
    var sentiment: Double = 0.0
    var relatedContent: [String: String] = [:]
    var sourceType: SourceType = .web
    var contentSummary: String = ""
    var extractedDate: Date?
    var confidence: Double = 0.0
    var relevanceScore: Double = 0.0
    var entities: [String: String] = [:]
    var pageRank: Int = 0
    
    // Convert from basic search result
    init(from basicResult: WebSearchResult) {
        self.title = basicResult.title
        self.description = basicResult.description
        self.url = basicResult.url
        self.sourceType = basicResult.sourceType
        
        // Default confidence based on having minimal information
        self.confidence = 0.4
    }
    
    // Empty initializer
    init() {}
}

/// Structure to hold extracted page data
struct PageData {
    var content: String
    var keywords: [String]
    var sentiment: Double = 0.0
    var relatedContent: [String: String] = [:]
    var entities: [String: String] = [:]
    var links: [URL] = []
    var imageURLs: [URL] = []
    var extractedDate: Date?
}

/// Search cache entry
struct SearchCacheEntry {
    let results: [DeepSearchResult]
    let timestamp: Date
    let query: String
    let depth: SearchDepth
}

/// Possible search errors
enum SearchError: Error {
    case invalidQuery
    case networkError(Error)
    case parsingError
    case emptyResults
    case rateLimitExceeded
    case accessDenied
    case timeout
    case crawlFailed
    case unsupportedSourceType
}

// MARK: - Main Manager Class

/// Enhanced web search manager with deep search capabilities
class WebSearchManager {
    // Singleton instance
    static let shared = WebSearchManager()
    
    // Configuration properties
    private let maxConcurrentRequests = 5
    private let requestTimeout: TimeInterval = 10
    private let maxCacheAgeMins: Double = 30
    private let maxSearchDepth = 3
    private let maxResultsPerSearch = 20
    
    // API keys (would normally be stored securely)
    private let googleAPIKey = "GOOGLE_API_KEY_PLACEHOLDER"
    private let bingAPIKey = "BING_API_KEY_PLACEHOLDER"
    private let newsAPIKey = "NEWS_API_KEY_PLACEHOLDER"
    
    // Search cache
    private var searchCache: [String: SearchCacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.backdoor.searchCacheQueue")
    
    // Active search sessions
    private var activeSessions: [UUID: URLSessionTask] = [:]
    private let sessionQueue = DispatchQueue(label: "com.backdoor.sessionQueue")
    
    // Privacy settings manager
    private let privacyManager = SearchPrivacyManager()
    
    // Private initializer for singleton pattern
    private init() {
        // Clean cache periodically
        Timer.scheduledTimer(withTimeInterval: 60*10, repeats: true) { [weak self] _ in
            self?.cleanCache()
        }
    }
    
    // MARK: - Public API
    
    /// Performs a standard web search for the given query
    /// - Parameters:
    ///   - query: The search query string
    ///   - completion: Callback with search results or error
    func performSearch(query: String, completion: @escaping (Result<[WebSearchResult], Error>) -> Void) {
        Debug.shared.log(message: "Performing standard web search for: \(query)", type: .info)
        
        // Check privacy settings before proceeding
        guard privacyManager.isSearchEnabled else {
            Debug.shared.log(message: "Search disabled by privacy settings", type: .warning)
            completion(.failure(SearchError.accessDenied))
            return
        }
        
        // Create a search-safe URL query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(SearchError.invalidQuery))
            return
        }
        
        // Use a mix of search engines, starting with DuckDuckGo for privacy
        let searchURLString = "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json"
        guard let searchURL = URL(string: searchURLString) else {
            completion(.failure(SearchError.invalidQuery))
            return
        }
        
        // Create a unique ID for this search session
        let sessionID = UUID()
        
        // Configure search request
        var request = URLRequest(url: searchURL)
        request.timeoutInterval = requestTimeout
        
        // Create and configure the search task
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            // Clean up session
            self?.sessionQueue.sync {
                self?.activeSessions[sessionID] = nil
            }
            
            // Handle network errors
            if let error = error {
                Debug.shared.log(message: "Search network error: \(error.localizedDescription)", type: .error)
                completion(.failure(SearchError.networkError(error)))
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    completion(.failure(SearchError.rateLimitExceeded))
                    return
                }
                if httpResponse.statusCode >= 400 {
                    completion(.failure(SearchError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil))))
                    return
                }
            }
            
            // Ensure we have data
            guard let data = data else {
                Debug.shared.log(message: "No data returned from search", type: .error)
                completion(.failure(SearchError.emptyResults))
                return
            }
            
            // Process the search results
            self?.processSearchResults(data: data, query: query, completion: completion)
        }
        
        // Store the task
        sessionQueue.sync {
            activeSessions[sessionID] = task
        }
        
        // Start the search
        task.resume()
    }
    
    /// Performs a deep search with configurable depth and specialized sources
    /// - Parameters:
    ///   - query: The search query string
    ///   - depth: How deep to search (affects crawling depth and source diversity)
    ///   - sourceTypes: What types of sources to include
    ///   - completion: Callback with enhanced search results or error
    func performDeepSearch(
        query: String,
        depth: SearchDepth = .enhanced,
        sourceTypes: [SourceType] = [.web, .news, .academic],
        completion: @escaping (Result<[DeepSearchResult], Error>) -> Void
    ) {
        Debug.shared.log(message: "Performing deep search for: \(query) with depth: \(depth)", type: .info)
        
        // Check privacy settings
        guard privacyManager.isDeepSearchEnabled else {
            Debug.shared.log(message: "Deep search disabled by privacy settings", type: .warning)
            completion(.failure(SearchError.accessDenied))
            return
        }
        
        // Check cache first
        let cacheKey = "\(query)-\(depth)-\(sourceTypes.map { $0.hashValue }.reduce(0, +))"
        if let cachedResults = getCachedResults(for: cacheKey) {
            Debug.shared.log(message: "Using cached deep search results for: \(query)", type: .info)
            completion(.success(cachedResults))
            return
        }
        
        // Initial search
        performSearch(query: query) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let initialResults):
                // Process initial results
                var deepResults: [DeepSearchResult] = initialResults.map { DeepSearchResult(from: $0) }
                
                // For basic search depth, just enhance the metadata and return
                if depth == .standard {
                    self.enhanceResultsMetadata(deepResults: &deepResults, query: query)
                    
                    // Cache results
                    self.cacheDeepSearchResults(deepResults, for: cacheKey, query: query, depth: depth)
                    
                    // Return results
                    completion(.success(deepResults))
                    return
                }
                
                // For deeper searches, perform additional processing
                let group = DispatchGroup()
                
                // Determine how many results to deeply process based on depth
                let resultsToProcess: Int
                switch depth {
                case .standard:
                    resultsToProcess = 0  // Already handled above
                case .enhanced:
                    resultsToProcess = min(3, initialResults.count)
                case .deep:
                    resultsToProcess = min(5, initialResults.count)
                case .specialized:
                    resultsToProcess = min(3, initialResults.count)
                }
                
                // Process selected results more deeply
                for index in 0..<resultsToProcess {
                    guard index < deepResults.count, let url = deepResults[index].url else { continue }
                    
                    group.enter()
                    
                    // Determine crawl depth based on search depth
                    let crawlDepth: Int
                    switch depth {
                    case .standard:
                        crawlDepth = 0
                    case .enhanced:
                        crawlDepth = 1
                    case .deep:
                        crawlDepth = self.maxSearchDepth
                    case .specialized:
                        crawlDepth = 2
                    }
                    
                    // Crawl the page with appropriate depth
                    self.crawlPage(url: url, depth: crawlDepth) { pageData in
                        if let data = pageData {
                            DispatchQueue.global(qos: .utility).async {
                                // Update the result with the crawled data
                                deepResults[index].keywords = data.keywords
                                deepResults[index].sentiment = data.sentiment
                                deepResults[index].relatedContent = data.relatedContent
                                deepResults[index].entities = data.entities
                                
                                // Generate summary if content is available
                                if !data.content.isEmpty {
                                    deepResults[index].contentSummary = self.generateSummary(from: data.content)
                                }
                                
                                // Extract date if available
                                deepResults[index].extractedDate = data.extractedDate
                                
                                // Increase confidence as we have more data
                                deepResults[index].confidence = 0.7 + (Double(data.relatedContent.count) * 0.05)
                                
                                // Calculate relevance score
                                deepResults[index].relevanceScore = self.calculateRelevanceScore(
                                    query: query,
                                    result: deepResults[index],
                                    pageData: data
                                )
                                
                                group.leave()
                            }
                        } else {
                            // If crawling failed, just leave the group
                            group.leave()
                        }
                    }
                }
                
                // For specialized searches, add results from specialized sources
                if depth == .specialized {
                    group.enter()
                    self.performSpecializedSearch(query: query, sourceTypes: sourceTypes) { specializedResults in
                        deepResults.append(contentsOf: specializedResults)
                        group.leave()
                    }
                }
                
                // After all deep searches complete
                group.notify(queue: .main) {
                    // Sort by relevance
                    deepResults.sort { $0.relevanceScore > $1.relevanceScore }
                    
                    // Limit results count
                    if deepResults.count > self.maxResultsPerSearch {
                        deepResults = Array(deepResults.prefix(self.maxResultsPerSearch))
                    }
                    
                    // Cache results
                    self.cacheDeepSearchResults(deepResults, for: cacheKey, query: query, depth: depth)
                    
                    // Log search data for AI learning
                    self.logSearchDataForLearning(query: query, results: deepResults, depth: depth)
                    
                    completion(.success(deepResults))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Cancel an active search session
    func cancelAllSearches() {
        sessionQueue.sync {
            for (_, task) in activeSessions {
                task.cancel()
            }
            activeSessions.removeAll()
        }
    }
    
    /// Format deep search results as a readable string
    func formatDeepSearchResults(_ results: [DeepSearchResult]) -> String {
        var formattedResults = ""
        
        for (index, result) in results.prefix(5).enumerated() {
            formattedResults += "\(index + 1). \(result.title)\n"
            
            // Add summary if available
            if !result.contentSummary.isEmpty {
                formattedResults += "   Summary: \(result.contentSummary)\n"
            } else if !result.description.isEmpty {
                formattedResults += "   \(result.description)\n"
            }
            
            // Add URL
            if let url = result.url {
                formattedResults += "   Source: \(url.absoluteString)\n"
            }
            
            // Add key entities if available
            if !result.entities.isEmpty {
                let topEntities = Array(result.entities.prefix(3))
                formattedResults += "   Key topics: \(topEntities.map { $0.key }.joined(separator: ", "))\n"
            }
            
            // Add date if available
            if let date = result.extractedDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formattedResults += "   Date: \(formatter.string(from: date))\n"
            }
            
            formattedResults += "\n"
        }
        
        if results.count > 5 {
            formattedResults += "...and \(results.count - 5) more results."
        }
        
        return formattedResults
    }
    
    // MARK: - Private Methods - Search Processing
    
    /// Process standard search results from raw data
    private func processSearchResults(data: Data, query: String, completion: @escaping (Result<[WebSearchResult], Error>) -> Void) {
        do {
            // Try to parse the JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = extractSearchResults(from: json) {
                
                // Log the success and number of results
                Debug.shared.log(message: "Found \(results.count) search results for query: \(query)", type: .info)
                
                // Send the results to AI learning for improvement
                if !results.isEmpty {
                    let resultURLs = results.map { $0.url.absoluteString }
                    DispatchQueue.global(qos: .background).async {
                        AILearningManager.shared.processWebSearchData(query: query, results: resultURLs)
                    }
                }
                
                completion(.success(results))
            } else {
                Debug.shared.log(message: "Failed to parse search results", type: .error)
                completion(.failure(SearchError.parsingError))
            }
        } catch {
            Debug.shared.log(message: "Search result parsing error: \(error.localizedDescription)", type: .error)
            completion(.failure(SearchError.parsingError))
        }
    }
    
    /// Extract structured search results from DuckDuckGo response
    private func extractSearchResults(from json: [String: Any]) -> [WebSearchResult]? {
        var results: [WebSearchResult] = []
        
        // Extract the AbstractText if available (featured snippet)
        if let abstractText = json["AbstractText"] as? String,
           !abstractText.isEmpty,
           let abstractURL = json["AbstractURL"] as? String,
           let url = URL(string: abstractURL) {
            
            let abstractSource = json["AbstractSource"] as? String ?? "Source"
            let result = WebSearchResult(
                title: abstractSource,
                description: abstractText,
                url: url,
                sourceType: detectSourceType(url: url, title: abstractSource)
            )
            results.append(result)
        }
        
        // Extract Related Topics (main results)
        if let relatedTopics = json["RelatedTopics"] as? [[String: Any]] {
            for topic in relatedTopics {
                if let text = topic["Text"] as? String,
                   let urlString = (topic["FirstURL"] as? String) ?? ((topic["Results"] as? [[String: Any]])?.first?["FirstURL"] as? String),
                   let url = URL(string: urlString) {
                    
                    // Split text into title and description if possible
                    var title = text
                    var description = ""
                    
                    if let separatorRange = text.range(of: " - ") {
                        title = String(text[..<separatorRange.lowerBound])
                        description = String(text[separatorRange.upperBound...])
                    }
                    
                    let result = WebSearchResult(
                        title: title,
                        description: description,
                        url: url,
                        sourceType: detectSourceType(url: url, title: title)
                    )
                    results.append(result)
                }
            }
        }
        
        return results
    }
    
    /// Detect the source type based on URL and title
    private func detectSourceType(url: URL, title: String) -> SourceType {
        let domain = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        // Academic sources
        if domain.contains("scholar.google") || 
           domain.contains("sciencedirect") ||
           domain.contains("researchgate") ||
           domain.contains("academia.edu") ||
           domain.contains("ieee.org") ||
           domain.contains("ncbi.nlm.nih.gov") ||
           domain.contains("arxiv.org") {
            return .academic
        }
        
        // News sources
        if domain.contains("news") ||
           domain.contains("nytimes") ||
           domain.contains("reuters") ||
           domain.contains("bbc") ||
           domain.contains("cnn") ||
           domain.contains("washingtonpost") ||
           domain.contains("theguardian") ||
           path.contains("/news/") {
            return .news
        }
        
        // Social media
        if domain.contains("twitter") ||
           domain.contains("facebook") ||
           domain.contains("linkedin") ||
           domain.contains("instagram") ||
           domain.contains("reddit") ||
           domain.contains("medium.com") {
            return .social
        }
        
        // Database sources
        if domain.contains("database") ||
           domain.contains("data.gov") ||
           domain.contains("census.gov") ||
           domain.contains("statista") ||
           domain.contains("kaggle") {
            return .database
        }
        
        // Default to web
        return .web
    }
    
    // MARK: - Private Methods - Deep Search
    
    /// Web crawling function to follow links for deeper context
    private func crawlPage(url: URL, depth: Int, completion: @escaping (PageData?) -> Void) {
        // Skip if depth is 0 or privacy disallows crawling
        guard depth > 0, privacyManager.isCrawlingEnabled else {
            completion(nil)
            return
        }
        
        Debug.shared.log(message: "Crawling page: \(url.absoluteString), depth: \(depth)", type: .debug)
        
        // Use URLSession to fetch content
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { 
                completion(nil)
                return
            }
            
            // Handle errors
            guard let data = data, error == nil else {
                Debug.shared.log(message: "Error crawling page: \(error?.localizedDescription ?? "unknown error")", type: .error)
                completion(nil)
                return
            }
            
            // Extract HTML content
            if let htmlString = String(data: data, encoding: .utf8) {
                // Parse content using regex
                let extractedText = self.extractMainContent(from: htmlString)
                let links = self.extractLinks(from: htmlString, baseURL: url)
                let imageURLs = self.extractImages(from: htmlString, baseURL: url)
                let date = self.extractDate(from: htmlString)
                
                // Process extracted content with NLP
                let keywords = self.extractKeywords(from: extractedText)
                let entities = NaturalLanguageHelper.shared.extractEntities(from: extractedText)
                let sentiment = NaturalLanguageHelper.shared.analyzeSentiment(in: extractedText)
                
                // Create page data
                var pageData = PageData(
                    content: extractedText,
                    keywords: keywords,
                    sentiment: sentiment,
                    entities: entities.reduce(into: [:]) { $0[$1] = "entity" },
                    links: links,
                    imageURLs: imageURLs,
                    extractedDate: date
                )
                
                // Follow links if depth allows (recursive crawling)
                if depth > 1 && !links.isEmpty {
                    let linksToFollow = min(3, links.count) // Limit number of links to follow
                    let subGroup = DispatchGroup()
                    var relatedContent: [String: String] = [:]
                    
                    // Only follow a few links to avoid excessive crawling
                    for link in links.prefix(linksToFollow) {
                        subGroup.enter()
                        self.crawlPage(url: link, depth: depth - 1) { subData in
                            if let subContent = subData?.content {
                                relatedContent[link.absoluteString] = subContent
                            }
                            subGroup.leave()
                        }
                    }
                    
                    // Wait for all sub-crawls to complete
                    subGroup.notify(queue: .global()) {
                        pageData.relatedContent = relatedContent
                        completion(pageData)
                    }
                } else {
                    completion(pageData)
                }
            } else {
                Debug.shared.log(message: "Could not decode HTML from \(url.absoluteString)", type: .error)
                completion(nil)
            }
        }.resume()
    }
    
    /// Perform specialized search using specific APIs based on source type
    private func performSpecializedSearch(query: String, sourceTypes: [SourceType], completion: @escaping ([DeepSearchResult]) -> Void) {
        let group = DispatchGroup()
        var specializedResults: [DeepSearchResult] = []
        let resultsLock = NSLock()
        
        // Academic search
        if sourceTypes.contains(.academic) {
            group.enter()
            searchAcademic(query: query) { results in
                resultsLock.lock()
                specializedResults.append(contentsOf: results)
                resultsLock.unlock()
                group.leave()
            }
        }
        
        // News search
        if sourceTypes.contains(.news) {
            group.enter()
            searchNews(query: query) { results in
                resultsLock.lock()
                specializedResults.append(contentsOf: results)
                resultsLock.unlock()
                group.leave()
            }
        }
        
        // Complete when all searches are done
        group.notify(queue: .global()) {
            completion(specializedResults)
        }
    }
    
    /// Search academic sources
    private func searchAcademic(query: String, completion: @escaping ([DeepSearchResult]) -> Void) {
        // This would normally use a specialized API like Semantic Scholar
        // For now, use a simplified implementation
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion([])
            return
        }
        
        // Placeholder academic search
        let searchURL = URL(string: "https://api.semanticscholar.org/graph/v1/paper/search?query=\(encodedQuery)&limit=3")!
        
        URLSession.shared.dataTask(with: searchURL) { data, response, error in
            var results: [DeepSearchResult] = []
            
            // Process response here (implementation would depend on API)
            // This is a placeholder for demonstration
            
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let papers = json["data"] as? [[String: Any]] {
                
                for paper in papers {
                    if let title = paper["title"] as? String,
                       let year = paper["year"] as? Int,
                       let url = paper["url"] as? String,
                       let url = URL(string: url) {
                        
                        var result = DeepSearchResult()
                        result.title = title
                        result.url = url
                        result.sourceType = .academic
                        result.extractedDate = Calendar.current.date(from: DateComponents(year: year))
                        result.confidence = 0.85 // Academic sources often have higher reliability
                        
                        if let abstract = paper["abstract"] as? String {
                            result.description = abstract
                            result.contentSummary = abstract
                        }
                        
                        if let authors = paper["authors"] as? [[String: String]] {
                            let authorNames = authors.compactMap { $0["name"] }
                            result.entities = authorNames.reduce(into: [:]) { $0[$1] = "author" }
                        }
                        
                        results.append(result)
                    }
                }
            }
            
            completion(results)
        }.resume()
    }
    
    /// Search news sources
    private func searchNews(query: String, completion: @escaping ([DeepSearchResult]) -> Void) {
        // This would normally use a specialized API like News API
        // For now, use a simplified implementation
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion([])
            return
        }
        
        // Placeholder news search
        let searchURL = URL(string: "https://newsapi.org/v2/everything?q=\(encodedQuery)&apiKey=\(newsAPIKey)&pageSize=5")!
        
        URLSession.shared.dataTask(with: searchURL) { data, response, error in
            var results: [DeepSearchResult] = []
            
            // Process response here (implementation would depend on API)
            // This is a placeholder for demonstration
            
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let articles = json["articles"] as? [[String: Any]] {
                
                for article in articles {
                    if let title = article["title"] as? String,
                       let description = article["description"] as? String,
                       let urlString = article["url"] as? String,
                       let url = URL(string: urlString) {
                        
                        var result = DeepSearchResult()
                        result.title = title
                        result.description = description
                        result.url = url
                        result.sourceType = .news
                        
                        if let publishedAt = article["publishedAt"] as? String {
                            let dateFormatter = ISO8601DateFormatter()
                            result.extractedDate = dateFormatter.date(from: publishedAt)
                        }
                        
                        if let source = article["source"] as? [String: Any], let sourceName = source["name"] as? String {
                            result.entities["source"] = sourceName
                        }
                        
                        results.append(result)
                    }
                }
            }
            
            completion(results)
        }.resume()
    }
    
    // MARK: - Private Methods - Content Extraction
    
    /// Extract the main content from HTML
    private func extractMainContent(from html: String) -> String {
        // Remove scripts, styles, and headers
        var cleanedHtml = html
            .replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<header[^>]*>.*?</header>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<nav[^>]*>.*?</nav>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<footer[^>]*>.*?</footer>", with: "", options: .regularExpression)
        
        // Extract text from main content tags
        var mainContent = ""
        
        // Try to find article or main content
        if let articleRange = cleanedHtml.range(of: "<article[^>]*>(.*?)</article>", options: .regularExpression) {
            mainContent = String(cleanedHtml[articleRange])
        } else if let mainRange = cleanedHtml.range(of: "<main[^>]*>(.*?)</main>", options: .regularExpression) {
            mainContent = String(cleanedHtml[mainRange])
        } else if let contentRange = cleanedHtml.range(of: "class=[\"']content[\"'][^>]*>(.*?)</div>", options: .regularExpression) {
            mainContent = String(cleanedHtml[contentRange])
        } else {
            // Fallback to body
            if let bodyRange = cleanedHtml.range(of: "<body[^>]*>(.*?)</body>", options: .regularExpression) {
                mainContent = String(cleanedHtml[bodyRange])
            } else {
                mainContent = cleanedHtml
            }
        }
        
        // Remove remaining HTML tags
        let textContent = mainContent
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
        
        // Clean up extra whitespace
        let cleanText = textContent
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanText
    }
    
    /// Extract links from HTML
    private func extractLinks(from html: String, baseURL: URL) -> [URL] {
        var links: [URL] = []
        let pattern = "<a[^>]+href=[\"']([^\"']+)[\"'][^>]*>"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let urlString = String(html[range])
                    
                    // Handle relative URLs
                    if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
                        if let url = URL(string: urlString) {
                            links.append(url)
                        }
                    } else if !urlString.hasPrefix("#") && !urlString.hasPrefix("javascript:") {
                        if let url = URL(string: urlString, relativeTo: baseURL)?.absoluteURL {
                            links.append(url)
                        }
                    }
                }
            }
        } catch {
            Debug.shared.log(message: "Error extracting links: \(error.localizedDescription)", type: .error)
        }
        
        // Remove duplicates
        return Array(Set(links))
    }
    
    /// Extract images from HTML
    private func extractImages(from html: String, baseURL: URL) -> [URL] {
        var images: [URL] = []
        let pattern = "<img[^>]+src=[\"']([^\"']+)[\"'][^>]*>"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let urlString = String(html[range])
                    
                    // Handle relative URLs
                    if urlString.hasPrefix("http") || urlString.hasPrefix("https") {
                        if let url = URL(string: urlString) {
                            images.append(url)
                        }
                    } else if !urlString.hasPrefix("data:") {
                        if let url = URL(string: urlString, relativeTo: baseURL)?.absoluteURL {
                            images.append(url)
                        }
                    }
                }
            }
        } catch {
            Debug.shared.log(message: "Error extracting images: \(error.localizedDescription)", type: .error)
        }
        
        // Remove duplicates
        return Array(Set(images))
    }
    
    /// Extract date from HTML
    private func extractDate(from html: String) -> Date? {
        // Try common date meta tags
        let patterns = [
            "<meta[^>]+property=[\"']article:published_time[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+name=[\"']publication_date[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<time[^>]+datetime=[\"']([^\"']+)[\"']",
            "<span[^>]+class=[\"']date[\"'][^>]*>([^<]+)</span>"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html) {
                        let dateStr = String(html[range])
                        
                        // Try several date formats
                        let dateFormatters = [
                            ISO8601DateFormatter(),
                            DateFormatter().apply { $0.dateFormat = "yyyy-MM-dd" },
                            DateFormatter().apply { $0.dateFormat = "MMMM d, yyyy" },
                            DateFormatter().apply { $0.dateFormat = "dd/MM/yyyy" }
                        ]
                        
                        for formatter in dateFormatters {
                            if let date = formatter.date(from: dateStr) {
                                return date
                            }
                        }
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    /// Extract keywords from text
    private func extractKeywords(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        
        // Use NLP to extract keywords
        let tagger = NLTagger(tagSchemes: [.nameType, .lemma])
        tagger.string = text
        
        var keywords: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
            if let tag = tag {
                let word = String(text[tokenRange]).lowercased()
                if word.count > 3 && !self.isStopWord(word) {
                    keywords.append(word)
                }
            }
            return true
        }
        
        // Count occurrences and find most frequent
        var wordCounts: [String: Int] = [:]
        for word in keywords {
            wordCounts[word, default: 0] += 1
        }
        
        // Sort by frequency
        let sortedWords = wordCounts.sorted { $0.value > $1.value }.map { $0.key }
        
        // Return top keywords
        return Array(sortedWords.prefix(10))
    }
    
    /// Check if a word is a common stop word
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = ["the", "and", "or", "but", "for", "nor", "on", "at", "to", "from", "by", "with", 
                         "about", "against", "between", "into", "through", "during", "before", "after", 
                         "above", "below", "under", "over", "again", "further", "then", "once", "here", 
                         "there", "when", "where", "why", "how", "all", "any", "both", "each", "few", 
                         "more", "most", "other", "some", "such", "only", "own", "same", "than", "too", 
                         "very", "can", "will", "just", "should", "now"]
        
        return stopWords.contains(word)
    }
    
    /// Generate a summary from text
    private func generateSummary(from text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        // Simple extractive summarization - take first few sentences
        let sentences = text.components(separatedBy: ".").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Determine number of sentences to include based on text length
        var sentencesToInclude = 2
        if text.count > 2000 {
            sentencesToInclude = 4
        } else if text.count > 1000 {
            sentencesToInclude = 3
        }
        
        // Get a subset of sentences
        let summary = sentences.prefix(sentencesToInclude).joined(separator: ". ")
        
        // Add period if missing
        return summary.hasSuffix(".") ? summary : summary + "."
    }
    
    // MARK: - Private Methods - Relevance and Ranking
    
    /// Calculate relevance score for a search result
    private func calculateRelevanceScore(query: String, result: DeepSearchResult, pageData: PageData) -> Double {
        var score: Double = 0.0
        
        // Base score from initial result position
        score += max(0.1, result.confidence)
        
        // Split query into terms
        let queryTerms = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !self.isStopWord($0) }
        
        // Check title match
        let titleWords = result.title.lowercased().components(separatedBy: .whitespacesAndNewlines)
        for term in queryTerms {
            if titleWords.contains(where: { $0.contains(term) }) {
                score += 0.2
            }
        }
        
        // Check content match
        let contentMatchCount = queryTerms.reduce(0) { count, term in
            return count + (pageData.content.lowercased().components(separatedBy: term).count - 1)
        }
        score += min(0.3, Double(contentMatchCount) * 0.01)
        
        // Keyword match
        for keyword in pageData.keywords {
            if queryTerms.contains(keyword.lowercased()) {
                score += 0.1
            }
        }
        
        // Recency bonus (if date is available)
        if let date = result.extractedDate {
            let now = Date()
            let ageInDays = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
            if ageInDays < 30 {
                score += 0.1
            } else if ageInDays < 180 {
                score += 0.05
            }
        }
        
        // Source type bonus
        switch result.sourceType {
        case .academic:
            score += 0.15  // Academic sources tend to be more authoritative
        case .news:
            score += 0.1   // News can be relevant for current events
        default:
            break
        }
        
        // Content richness (related content, entities)
        score += min(0.2, Double(pageData.relatedContent.count) * 0.05)
        score += min(0.2, Double(pageData.entities.count) * 0.02)
        
        // Link richness (internal crawling indicates depth)
        score += min(0.1, Double(pageData.links.count) * 0.005)
        
        return score
    }
    
    /// Enhance metadata for search results
    private func enhanceResultsMetadata(deepResults: inout [DeepSearchResult], query: String) {
        // Extract potential entities from the query
        let queryEntities = NaturalLanguageHelper.shared.extractEntities(from: query)
        
        for i in 0..<deepResults.count {
            // Add query entities
            for entity in queryEntities {
                deepResults[i].entities[entity] = "query_entity"
            }
            
            // Simple relevance scoring for basic results
            var score = 0.5 // Base score
            
            // Title match boost
            if deepResults[i].title.lowercased().contains(query.lowercased()) {
                score += 0.3
            }
            
            // Description match boost
            if deepResults[i].description.lowercased().contains(query.lowercased()) {
                score += 0.2
            }
            
            // Source type boost
            switch deepResults[i].sourceType {
            case .academic:
                score += 0.15
            case .news:
                score += 0.1
            default:
                break
            }
            
            deepResults[i].relevanceScore = score
        }
    }
    
    // MARK: - Private Methods - Caching
    
    /// Get cached search results if available
    private func getCachedResults(for key: String) -> [DeepSearchResult]? {
        var results: [DeepSearchResult]?
        
        cacheQueue.sync {
            if let entry = searchCache[key], 
               Date().timeIntervalSince(entry.timestamp) < (maxCacheAgeMins * 60) {
                results = entry.results
            }
        }
        
        return results
    }
    
    /// Cache deep search results
    private func cacheDeepSearchResults(_ results: [DeepSearchResult], for key: String, query: String, depth: SearchDepth) {
        // Only cache if allowed by privacy settings
        guard privacyManager.isSearchCachingEnabled else {
            return
        }
        
        cacheQueue.sync {
            let entry = SearchCacheEntry(
                results: results,
                timestamp: Date(),
                query: query,
                depth: depth
            )
            searchCache[key] = entry
        }
    }
    
    /// Clean expired entries from cache
    private func cleanCache() {
        cacheQueue.sync {
            let now = Date()
            let keysToRemove = searchCache.filter { 
                now.timeIntervalSince($0.value.timestamp) > (maxCacheAgeMins * 60)
            }.map { $0.key }
            
            for key in keysToRemove {
                searchCache.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Private Methods - Learning
    
    /// Log search data for AI learning
    private func logSearchDataForLearning(query: String, results: [DeepSearchResult], depth: SearchDepth) {
        // Only log if learning is enabled
        guard AILearningManager.shared.isLearningEnabled else {
            return
        }
        
        // Record in AI learning system
        DispatchQueue.global(qos: .utility).async {
            // Extract URLs
            let resultURLs = results.compactMap { $0.url?.absoluteString }
            
            // Record the search behavior
            let searchDetails: [String: String] = [
                "query": query,
                "resultCount": "\(results.count)",
                "depth": "\(depth)",
                "topKeywords": results.flatMap { $0.keywords }.prefix(5).joined(separator: ",")
            ]
            
            // Process in AI learning system
            AILearningManager.shared.processWebSearchData(query: query, results: resultURLs)
            
            // Record as a user behavior
            AILearningManager.shared.recordUserBehavior(
                action: "deep_search",
                screen: "WebSearch",
                duration: 0,
                details: searchDetails
            )
        }
    }
}

// MARK: - Privacy Management

/// Manages privacy settings for search functionality
class SearchPrivacyManager {
    // Privacy setting keys
    private let searchEnabledKey = "privacy_search_enabled"
    private let deepSearchEnabledKey = "privacy_deep_search_enabled"
    private let crawlingEnabledKey = "privacy_crawling_enabled"
    private let searchCachingEnabledKey = "privacy_search_caching_enabled"
    private let trackedDomainsKey = "privacy_tracked_domains"
    
    /// Check if general search is enabled
    var isSearchEnabled: Bool {
        return UserDefaults.standard.bool(forKey: searchEnabledKey)
    }
    
    /// Check if deep search is enabled
    var isDeepSearchEnabled: Bool {
        return UserDefaults.standard.bool(forKey: deepSearchEnabledKey)
    }
    
    /// Check if page crawling is enabled
    var isCrawlingEnabled: Bool {
        return UserDefaults.standard.bool(forKey: crawlingEnabledKey)
    }
    
    /// Check if search caching is enabled
    var isSearchCachingEnabled: Bool {
        return UserDefaults.standard.bool(forKey: searchCachingEnabledKey)
    }
    
    init() {
        // Set default values if not already set
        if UserDefaults.standard.object(forKey: searchEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: searchEnabledKey)
        }
        
        if UserDefaults.standard.object(forKey: deepSearchEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: deepSearchEnabledKey)
        }
        
        if UserDefaults.standard.object(forKey: crawlingEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: crawlingEnabledKey)
        }
        
        if UserDefaults.standard.object(forKey: searchCachingEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: searchCachingEnabledKey)
        }
    }
    
    /// Update search privacy settings
    func updateSettings(
        searchEnabled: Bool? = nil,
        deepSearchEnabled: Bool? = nil,
        crawlingEnabled: Bool? = nil,
        cachingEnabled: Bool? = nil
    ) {
        if let searchEnabled = searchEnabled {
            UserDefaults.standard.set(searchEnabled, forKey: searchEnabledKey)
        }
        
        if let deepSearchEnabled = deepSearchEnabled {
            UserDefaults.standard.set(deepSearchEnabled, forKey: deepSearchEnabledKey)
        }
        
        if let crawlingEnabled = crawlingEnabled {
            UserDefaults.standard.set(crawlingEnabled, forKey: crawlingEnabledKey)
        }
        
        if let cachingEnabled = cachingEnabled {
            UserDefaults.standard.set(cachingEnabled, forKey: searchCachingEnabledKey)
        }
    }
    
    /// Add a domain to privacy tracking exclusion list
    func excludeDomain(_ domain: String) {
        var domains = UserDefaults.standard.stringArray(forKey: trackedDomainsKey) ?? []
        if !domains.contains(domain) {
            domains.append(domain)
            UserDefaults.standard.set(domains, forKey: trackedDomainsKey)
        }
    }
    
    /// Remove a domain from privacy tracking exclusion list
    func includeDomain(_ domain: String) {
        var domains = UserDefaults.standard.stringArray(forKey: trackedDomainsKey) ?? []
        domains.removeAll { $0 == domain }
        UserDefaults.standard.set(domains, forKey: trackedDomainsKey)
    }
    
    /// Check if a domain should be tracked
    func shouldTrackDomain(_ domain: String) -> Bool {
        let excludedDomains = UserDefaults.standard.stringArray(forKey: trackedDomainsKey) ?? []
        return !excludedDomains.contains(domain)
    }
}

// MARK: - Helper Extensions

extension DateFormatter {
    @discardableResult
    func apply(_ configuration: (DateFormatter) -> Void) -> DateFormatter {
        configuration(self)
        return self
    }
}
