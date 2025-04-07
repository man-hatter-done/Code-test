// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation

class SourceGET {
    // Private session with configuration
    private let session: URLSession
    
    init(timeoutInterval: TimeInterval = 30.0, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = cachePolicy
        self.session = URLSession(configuration: config)
    }
    
    deinit {
        // Properly clean up URLSession resources when this instance is deallocated
        session.invalidateAndCancel()
    }
    
    func downloadURL(from url: URL, completion: @escaping (Result<(Data, HTTPURLResponse?), Error>) -> Void) {
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                Debug.shared.log(message: "Network error: \(error.localizedDescription)", type: .error)
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "InvalidResponse", code: -1, 
                                    userInfo: [NSLocalizedDescriptionKey: "Response was not an HTTP response"])
                Debug.shared.log(message: "Invalid response: Not an HTTP response", type: .error)
                completion(.failure(error))
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let errorDescription = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                let error = NSError(domain: "HTTPError", code: httpResponse.statusCode, 
                                    userInfo: [NSLocalizedDescriptionKey: errorDescription])
                
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    Debug.shared.log(message: "HTTP Error Response (\(httpResponse.statusCode)): \(responseBody)", type: .error)
                } else {
                    Debug.shared.log(message: "HTTP Error: \(httpResponse.statusCode) - \(errorDescription)", type: .error)
                }
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(domain: "DataError", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No data received from server"])
                Debug.shared.log(message: "No data received from server", type: .error)
                completion(.failure(error))
                return
            }

            completion(.success((data, httpResponse)))
        }
        task.resume()
    }

    /// Generic parsing method for any Decodable type
    func parseJSON<T: Decodable>(data: Data) -> Result<T, Error> {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(T.self, from: data)
            return .success(result)
        } catch {
            Debug.shared.log(message: "Failed to parse JSON: \(error)", type: .error)
            return .failure(error)
        }
    }
    
    func parse(data: Data) -> Result<SourcesData, Error> {
        return parseJSON(data: data)
    }

    func parseCert(data: Data) -> Result<ServerPack, Error> {
        return parseJSON(data: data)
    }

    func parsec(data: Data) -> Result<[CreditsPerson], Error> {
        return parseJSON(data: data)
    }
}
