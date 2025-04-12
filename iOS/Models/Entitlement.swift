// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation

/// Represents a single iOS app entitlement
struct Entitlement: Codable, Identifiable, Equatable {
    /// Unique identifier for this entitlement
    var id = UUID()
    
    /// The key for the entitlement (e.g., "com.apple.developer.networking.wifi-info")
    var key: String
    
    /// The value type for this entitlement
    var valueType: EntitlementValueType
    
    /// Raw string representation of the value
    var stringValue: String
    
    /// Description of what this entitlement does
    var description: String?
    
    /// Whether this entitlement is valid (has proper format)
    var isValid: Bool {
        return validateEntitlement()
    }
    
    /// Initialize with key and string value, automatically determining type
    init(key: String, stringValue: String, description: String? = nil) {
        self.key = key
        self.stringValue = stringValue
        self.description = description
        
        // Determine value type based on the string value
        if stringValue.lowercased() == "true" || stringValue.lowercased() == "false" {
            self.valueType = .boolean
        } else if let _ = Int(stringValue) {
            self.valueType = .integer
        } else if stringValue.hasPrefix("[") && stringValue.hasSuffix("]") {
            self.valueType = .array
        } else if stringValue.hasPrefix("{") && stringValue.hasSuffix("}") {
            self.valueType = .dictionary
        } else {
            self.valueType = .string
        }
    }
    
    /// Initialize with key, specified value type, and string value
    init(key: String, valueType: EntitlementValueType, stringValue: String, description: String? = nil) {
        self.key = key
        self.valueType = valueType
        self.stringValue = stringValue
        self.description = description
    }
    
    /// Validate the entitlement format based on its type
    private func validateEntitlement() -> Bool {
        // Basic key validation - must be in reverse domain format and non-empty
        guard !key.isEmpty, key.contains(".") else {
            return false
        }
        
        // Validate value format based on type
        switch valueType {
            case .boolean:
                return stringValue.lowercased() == "true" || stringValue.lowercased() == "false"
                
            case .integer:
                return Int(stringValue) != nil
                
            case .string:
                return !stringValue.isEmpty
                
            case .array:
                // Basic validation for array format
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
                
            case .dictionary:
                // Basic validation for dictionary format
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
        }
    }
    
    /// Convert to property list compatible value
    func toPlistValue() -> Any {
        switch valueType {
            case .boolean:
                return stringValue.lowercased() == "true"
                
            case .integer:
                return Int(stringValue) ?? 0
                
            case .string:
                return stringValue
                
            case .array:
                // Basic array parsing - in a real implementation, this would be more robust
                let content = stringValue.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                let items = content.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                return items
                
            case .dictionary:
                // For simplicity, returning a string representation
                // In a real implementation, this would parse the dictionary properly
                return ["value": stringValue]
        }
    }
}

/// Represents the type of value an entitlement can have
enum EntitlementValueType: String, Codable, CaseIterable {
    case boolean = "Boolean"
    case integer = "Integer"
    case string = "String"
    case array = "Array"
    case dictionary = "Dictionary"
}

/// Collection of common iOS entitlements for quick reference
struct CommonEntitlements {
    static let appGroups = Entitlement(
        key: "com.apple.security.application-groups",
        valueType: .array,
        stringValue: "[group.example.identifier]",
        description: "Share data between apps using App Groups"
    )
    
    static let healthKit = Entitlement(
        key: "com.apple.developer.healthkit",
        valueType: .boolean,
        stringValue: "true",
        description: "Access HealthKit data"
    )
    
    static let homeKit = Entitlement(
        key: "com.apple.developer.homekit",
        valueType: .boolean,
        stringValue: "true",
        description: "Access HomeKit data"
    )
    
    static let inAppPurchase = Entitlement(
        key: "com.apple.developer.in-app-payments",
        valueType: .array,
        stringValue: "[merchant.com.example]",
        description: "Process in-app payments"
    )
    
    static let pushNotifications = Entitlement(
        key: "aps-environment",
        valueType: .string,
        stringValue: "development",
        description: "Enable push notifications (development or production)"
    )
    
    static let associatedDomains = Entitlement(
        key: "com.apple.developer.associated-domains",
        valueType: .array,
        stringValue: "[applinks:example.com]",
        description: "Associate app with domains for Universal Links"
    )
    
    static let multipath = Entitlement(
        key: "com.apple.developer.networking.multipath",
        valueType: .boolean,
        stringValue: "true",
        description: "Use multiple network paths simultaneously"
    )
    
    static let hotspotConfiguration = Entitlement(
        key: "com.apple.developer.networking.HotspotConfiguration",
        valueType: .boolean,
        stringValue: "true",
        description: "Configure Wi-Fi networks via the app"
    )
    
    static let nfcTagReader = Entitlement(
        key: "com.apple.developer.nfc.readersession.formats",
        valueType: .array,
        stringValue: "[NDEF, TAG]",
        description: "Read NFC tags"
    )
    
    static let siriKit = Entitlement(
        key: "com.apple.developer.siri",
        valueType: .boolean,
        stringValue: "true",
        description: "Integrate with Siri"
    )
    
    static let accessWiFiInformation = Entitlement(
        key: "com.apple.developer.networking.wifi-info",
        valueType: .boolean,
        stringValue: "true",
        description: "Access current Wi-Fi network information"
    )
    
    /// Get a list of all common entitlements
    static var all: [Entitlement] {
        return [
            appGroups,
            healthKit,
            homeKit,
            inAppPurchase,
            pushNotifications,
            associatedDomains,
            multipath,
            hotspotConfiguration,
            nfcTagReader,
            siriKit,
            accessWiFiInformation
        ]
    }
}
