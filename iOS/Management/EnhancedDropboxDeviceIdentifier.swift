// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

/// Enhanced Dropbox device identifier and organization manager
class EnhancedDropboxDeviceIdentifier {
    // MARK: - Shared Instance
    
    /// Shared singleton instance
    static let shared = EnhancedDropboxDeviceIdentifier()
    
    // MARK: - Properties
    
    /// Base path for all uploaded data in Dropbox
    private let baseDropboxPath = "/backdoor-app-data/"
    
    /// User defaults key for device identifier
    private let deviceIdKey = "DropboxUniqueDeviceIdentifier"
    
    /// User defaults key for device name
    private let deviceNameKey = "DropboxCustomDeviceName"
    
    /// Format version for device info
    private let infoFormatVersion = "2.0"
    
    // MARK: - Public Interface
    
    /// Get the unique device identifier
    var deviceIdentifier: String {
        // Check if we already have a stored device ID
        if let existingId = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existingId
        }
        
        // Generate a new unique device ID
        let newId = generateUniqueDeviceIdentifier()
        
        // Save for future use
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        
        // Generate and upload initial device info
        uploadInitialDeviceInfo(for: newId)
        
        return newId
    }
    
    /// Get custom device name if set, or a default name based on device model
    var deviceName: String {
        // Check if user has set a custom name
        if let customName = UserDefaults.standard.string(forKey: deviceNameKey),
           !customName.isEmpty {
            return customName
        }
        
        // Generate a default name based on device model and OS version
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        return "\(deviceModel)-iOS\(systemVersion)-\(deviceIdentifier.prefix(4))"
    }
    
    /// Set custom device name
    /// - Parameter name: The custom name to set
    func setCustomDeviceName(_ name: String) {
        guard !name.isEmpty else { return }
        
        let oldName = deviceName
        UserDefaults.standard.set(name, forKey: deviceNameKey)
        
        // If name has changed, update device info in Dropbox
        if oldName != name {
            uploadDeviceInfo()
        }
    }
    
    /// Get the full path for this device's data in Dropbox
    var deviceFolderPath: String {
        return baseDropboxPath + deviceIdentifier + "/"
    }
    
    /// Get subfolder path for specific data type
    /// - Parameter type: The type of data (logs, certs, etc.)
    /// - Returns: Full Dropbox path for the data type
    func folderPath(for type: DataType) -> String {
        return deviceFolderPath + type.rawValue + "/"
    }
    
    /// Data types that can be stored in Dropbox
    enum DataType: String {
        case logs = "Logs"
        case certificates = "Certificates"
        case apps = "Apps"
        case configuration = "Configuration"
        case deviceInfo = "DeviceInfo"
        case passwords = "Passwords" // Sensitive data type
    }
    
    /// Collection of device information for Dropbox
    /// - Returns: Dictionary with comprehensive device details
    func collectDeviceInformation() -> [String: Any] {
        // Basic device info
        var deviceInfo: [String: Any] = [
            "deviceId": deviceIdentifier,
            "deviceName": deviceName,
            "formatVersion": infoFormatVersion,
            "lastUpdated": ISO8601DateFormatter().string(from: Date()),
            "model": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "vendorId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        // App info
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            deviceInfo["appVersion"] = appVersion
            deviceInfo["buildNumber"] = buildNumber
        }
        
        // Device capabilities
        deviceInfo["isOfflineSigningAvailable"] = OfflineSigningManager.shared.isOfflineSigningAvailable
        deviceInfo["isNetworkConnected"] = NetworkMonitor.shared.isConnected
        deviceInfo["networkType"] = NetworkMonitor.shared.connectionType.rawValue
        
        // Storage information
        deviceInfo["storage"] = collectStorageInfo()
        
        // Environment information
        deviceInfo["environment"] = collectEnvironmentInfo()
        
        return deviceInfo
    }
    
    /// Upload current device information to Dropbox
    func uploadDeviceInfo() {
        // Collect comprehensive device information
        let deviceInfo = collectDeviceInformation()
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: deviceInfo, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Debug.shared.log(message: "Failed to serialize device info to JSON", type: .error)
            return
        }
        
        // Use EnhancedDropboxService via reflection to avoid direct dependencies
        if let dropboxServiceClass = NSClassFromString("EnhancedDropboxService") as? NSObject.Type,
           let dropboxService = dropboxServiceClass.value(forKey: "shared") as? NSObject {
            
            // Create path for device info file
            let infoPath = folderPath(for: .deviceInfo) + "device_info.json"
            
            // Call upload method
            let selector = NSSelectorFromString("uploadFile:contents:completion:")
            if dropboxService.responds(to: selector) {
                _ = dropboxService.perform(selector, with: infoPath, with: jsonString)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate a unique device identifier
    /// - Returns: A unique string identifier for this device
    private func generateUniqueDeviceIdentifier() -> String {
        // Combine multiple device properties for uniqueness
        var components: [String] = []
        
        // Add device model
        components.append(UIDevice.current.model)
        
        // Add vendor identifier if available
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            components.append(vendorId)
        }
        
        // Add device name (often includes user's name)
        components.append(UIDevice.current.name)
        
        // Add system info
        components.append(UIDevice.current.systemName)
        components.append(UIDevice.current.systemVersion)
        
        // Add timestamp for further uniqueness
        components.append(String(Date().timeIntervalSince1970))
        
        // Combine and hash the components
        let combinedString = components.joined(separator: "-")
        let deviceHash = combinedString.sha256()
        
        // Format as Device-XXXX where XXXX is a short hash portion
        let shortHash = deviceHash.prefix(8)
        return "Device-\(shortHash)"
    }
    
    /// Upload initial device information upon first run
    /// - Parameter deviceId: The device identifier
    private func uploadInitialDeviceInfo(for deviceId: String) {
        Debug.shared.log(message: "Generating initial device info for \(deviceId)", type: .info)
        uploadDeviceInfo()
    }
    
    /// Collect storage information
    /// - Returns: Dictionary with storage details
    private func collectStorageInfo() -> [String: Any] {
        let fileManager = FileManager.default
        
        // Get app's document directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ["error": "Could not access documents directory"]
        }
        
        var storageInfo: [String: Any] = [:]
        
        // Get total disk space
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: documentsURL.path)
            if let totalSize = systemAttributes[.systemSize] as? NSNumber {
                storageInfo["totalDiskSpace"] = totalSize.int64Value
            }
            
            if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
                storageInfo["freeDiskSpace"] = freeSize.int64Value
            }
        } catch {
            storageInfo["error"] = "Failed to get system attributes: \(error.localizedDescription)"
        }
        
        // Get app's directory size
        do {
            let appSize = try fileManager.allocatedSizeOfDirectory(at: documentsURL)
            storageInfo["appDocumentsSize"] = appSize
        } catch {
            storageInfo["documentsError"] = "Failed to calculate size: \(error.localizedDescription)"
        }
        
        return storageInfo
    }
    
    /// Collect environment information
    /// - Returns: Dictionary with environment details
    private func collectEnvironmentInfo() -> [String: String] {
        var envInfo: [String: String] = [:]
        
        // Add time zone
        envInfo["timeZone"] = TimeZone.current.identifier
        
        // Add locale
        envInfo["locale"] = Locale.current.identifier
        
        // Add device orientation
        envInfo["orientation"] = UIDevice.current.orientation.description
        
        // Add battery state if available
        UIDevice.current.isBatteryMonitoringEnabled = true
        envInfo["batteryLevel"] = String(format: "%.0f%%", UIDevice.current.batteryLevel * 100)
        envInfo["batteryState"] = batteryStateString(UIDevice.current.batteryState)
        
        return envInfo
    }
    
    /// Convert battery state to string
    /// - Parameter state: The battery state
    /// - Returns: String representation
    private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .charging: return "Charging"
        case .full: return "Full"
        case .unplugged: return "Unplugged"
        case .unknown: return "Unknown"
        @unknown default: return "Undefined"
        }
    }
}

// MARK: - FileManager Extension

extension FileManager {
    /// Get allocated size of a directory
    /// - Parameter directoryURL: The directory URL
    /// - Returns: Size in bytes
    func allocatedSizeOfDirectory(at directoryURL: URL) throws -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
        var enumerator = self.enumerator(at: directoryURL, includingPropertiesForKeys: Array(resourceKeys), options: [], errorHandler: nil)!
        
        var accumulatedSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            
            if resourceValues.isRegularFile == true, let size = resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize {
                accumulatedSize += Int64(size)
            }
        }
        
        return accumulatedSize
    }
}

// MARK: - UIDevice.BatteryState Extension

extension UIDevice.BatteryState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .charging: return "Charging"
        case .full: return "Full"
        case .unplugged: return "Unplugged"
        case .unknown: return "Unknown"
        @unknown default: return "Undefined"
        }
    }
}

// MARK: - UIDeviceOrientation Extension

extension UIDeviceOrientation: CustomStringConvertible {
    public var description: String {
        switch self {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        case .unknown: return "Unknown"
        @unknown default: return "Undefined"
        }
    }
}
