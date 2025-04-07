// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

/// Extension for CustomAIService to add deep search capabilities
extension CustomAIService {
    
    /// Determine the appropriate search depth for a query
    func determineSearchDepth(for query: String) -> SearchDepth {
        let lowercasedQuery = query.lowercased()
        
        // Check for deep search indicators
        if lowercasedQuery.contains("deep search") || 
           lowercasedQuery.contains("comprehensive") || 
           lowercasedQuery.contains("detailed") ||
           lowercasedQuery.contains("in-depth") ||
           lowercasedQuery.contains("thorough") {
            return .deep
        }
        
        // Check for academic search indicators
        if lowercasedQuery.contains("academic") || 
           lowercasedQuery.contains("scientific") || 
           lowercasedQuery.contains("research") ||
           lowercasedQuery.contains("scholarly") ||
           lowercasedQuery.contains("journal") ||
           lowercasedQuery.contains("paper") ||
           lowercasedQuery.contains("study") {
            return .specialized
        }
        
        // Check for news search indicators
        if lowercasedQuery.contains("news") || 
           lowercasedQuery.contains("recent") || 
           lowercasedQuery.contains("latest") ||
           lowercasedQuery.contains("current events") ||
           lowercasedQuery.contains("today") ||
           lowercasedQuery.contains("breaking") {
            return .specialized
        }
        
        // Check for enhanced search indicators
        if lowercasedQuery.contains("more about") || 
           lowercasedQuery.contains("learn more") ||
           lowercasedQuery.contains("better") ||
           lowercasedQuery.contains("improved") ||
           lowercasedQuery.contains("enhanced") ||
           query.count > 60 { // Longer queries often need more detailed results
            return .enhanced
        }
        
        // Default to standard
        return .standard
    }
    
    /// Determine the search query type
    func getSearchType(from query: String) -> SearchQueryType {
        let lowercasedQuery = query.lowercased()
        
        // Academic content
        if lowercasedQuery.contains("academic") || 
           lowercasedQuery.contains("research") || 
           lowercasedQuery.contains("scientific") ||
           lowercasedQuery.contains("journal") ||
           lowercasedQuery.contains("paper") ||
           lowercasedQuery.contains("study") ||
           lowercasedQuery.contains("thesis") {
            return .academic
        }
        
        // News content
        if lowercasedQuery.contains("news") || 
           lowercasedQuery.contains("latest") || 
           lowercasedQuery.contains("current") ||
           lowercasedQuery.contains("recent") ||
           lowercasedQuery.contains("today") ||
           lowercasedQuery.contains("breaking") {
            return .news
        }
        
        // Technical content
        if lowercasedQuery.contains("technical") || 
           lowercasedQuery.contains("developer") || 
           lowercasedQuery.contains("programming") ||
           lowercasedQuery.contains("code") ||
           lowercasedQuery.contains("framework") ||
           lowercasedQuery.contains("api") ||
           lowercasedQuery.contains("software") {
            return .technical
        }
        
        // Reference content
        if lowercasedQuery.contains("definition") || 
           lowercasedQuery.contains("meaning") || 
           lowercasedQuery.contains("what is") ||
           lowercasedQuery.contains("who is") ||
           lowercasedQuery.contains("explain") ||
           lowercasedQuery.contains("describe") {
            return .reference
        }
        
        // Default
        return .general
    }
    
    /// Perform a web search with the given query and return formatted results
    func performWebSearch(query: String, completion: @escaping (String) -> Void) {
        Debug.shared.log(message: "Performing web search for: \(query)", type: .info)
        
        WebSearchManager.shared.performSearch(query: query) { result in
            switch result {
            case .success(let searchResults):
                // Format the results for user-friendly display
                let formattedResults = WebSearchManager.shared.formatSearchResults(searchResults)
                
                completion("Here are the search results for \"\(query)\":\n\n\(formattedResults)")
                
            case .failure(let error):
                // Handle search errors
                let errorMessage: String
                switch error {
                case SearchError.invalidQuery:
                    errorMessage = "Sorry, the search query appears to be invalid. Please try a different search term."
                case SearchError.emptyResults:
                    errorMessage = "I couldn't find any results for \"\(query)\". Would you like to try a different search?"
                case SearchError.rateLimitExceeded:
                    errorMessage = "The search service is currently busy. Please try again in a moment."
                case SearchError.accessDenied:
                    errorMessage = "Search functionality is currently disabled in privacy settings."
                default:
                    errorMessage = "I encountered an issue while searching. Please try again or use a different search term."
                }
                
                completion(errorMessage)
            }
        }
    }
    
    /// Perform a deep search with enhanced capabilities
    func performDeepSearch(query: String, depth: SearchDepth = .enhanced, queryType: SearchQueryType = .general, completion: @escaping (String) -> Void) {
        Debug.shared.log(message: "Performing deep search for: \(query) with depth: \(depth)", type: .info)
        
        // Convert query type to source types
        var sourceTypes: [SourceType] = [.web]
        
        switch queryType {
        case .academic:
            sourceTypes = [.academic, .web]
        case .news:
            sourceTypes = [.news, .web]
        case .technical:
            sourceTypes = [.web, .database]
        case .reference:
            sourceTypes = [.web, .academic, .database]
        case .general:
            if depth == .specialized {
                sourceTypes = [.web, .news, .academic]
            }
        }
        
        // Perform the deep search
        WebSearchManager.shared.performDeepSearch(query: query, depth: depth, sourceTypes: sourceTypes) { result in
            switch result {
            case .success(let deepResults):
                // Format the results for user-friendly display
                let formattedResults = WebSearchManager.shared.formatDeepSearchResults(deepResults)
                
                // Add an introduction based on depth and query type
                var introduction = "Here are the search results for \"\(query)\":"
                
                switch depth {
                case .standard:
                    introduction = "Here are some results for \"\(query)\":"
                case .enhanced:
                    introduction = "Here are enhanced search results for \"\(query)\" with more detailed information:"
                case .deep:
                    introduction = "Here are comprehensive results from my deep search for \"\(query)\":"
                case .specialized:
                    switch queryType {
                    case .academic:
                        introduction = "Here are scholarly results from academic sources for \"\(query)\":"
                    case .news:
                        introduction = "Here are the latest news results for \"\(query)\":"
                    case .technical:
                        introduction = "Here are technical resources related to \"\(query)\":"
                    case .reference:
                        introduction = "Here's the reference information I found for \"\(query)\":"
                    case .general:
                        introduction = "Here are specialized search results for \"\(query)\":"
                    }
                }
                
                completion("\(introduction)\n\n\(formattedResults)")
                
                // Track this deep search in the learning system
                DispatchQueue.global(qos: .background).async {
                    AILearningManager.shared.recordUserBehavior(
                        action: "deep_search",
                        screen: "AI Chat",
                        duration: 0,
                        details: [
                            "query": query,
                            "depth": "\(depth)",
                            "queryType": "\(queryType)",
                            "resultCount": "\(deepResults.count)"
                        ]
                    )
                }
                
            case .failure(let error):
                // Handle search errors with context-appropriate messages
                let errorMessage: String
                switch error {
                case SearchError.invalidQuery:
                    errorMessage = "Sorry, the search query appears to be invalid. Please try a different search term."
                case SearchError.emptyResults:
                    errorMessage = "I couldn't find any results for \"\(query)\". Would you like to try a different search?"
                case SearchError.rateLimitExceeded:
                    errorMessage = "The deep search service is currently at capacity. Please try again in a moment."
                case SearchError.accessDenied:
                    errorMessage = "Deep search functionality is currently disabled in privacy settings."
                case SearchError.crawlFailed:
                    errorMessage = "I started searching for detailed information but encountered issues with some sources. Here are the partial results I could find."
                default:
                    errorMessage = "I encountered an issue while performing a deep search. Please try again or use a different search term."
                }
                
                completion(errorMessage)
            }
        }
    }
    
    /// Handle specialized academic searches
    func performAcademicSearch(query: String, completion: @escaping (String) -> Void) {
        Debug.shared.log(message: "Performing academic search for: \(query)", type: .info)
        
        // Use the deep search with academic focus
        performDeepSearch(query: query, depth: .specialized, queryType: .academic, completion: completion)
    }
    
    /// Handle specialized news searches
    func performNewsSearch(query: String, completion: @escaping (String) -> Void) {
        Debug.shared.log(message: "Performing news search for: \(query)", type: .info)
        
        // Use the deep search with news focus
        performDeepSearch(query: query, depth: .specialized, queryType: .news, completion: completion)
    }
}
