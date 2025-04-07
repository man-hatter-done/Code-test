// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except
// as expressly permitted under the terms of the Proprietary Software License.

import AlertKit
import CoreData
import Foundation
import UIKit

// MARK: - External function declarations from C/C++ code

@_silgen_name("zsign")
func zsign(_ appPath: String,
           _ provisionPath: String,
           _ p12Path: String,
           _ password: String,
           _ bundleId: String,
           _ name: String,
           _ version: String,
           _ removeProvisioningFile: Bool) -> Int32

// MARK: - External C++ functions

@_silgen_name("InjectDyLib")
private func _InjectDyLib(_ filePath: String, _ dylibPath: String, _ weakInject: Bool, _ bCreate: Bool) -> Bool

@_silgen_name("ChangeDylibPath")
private func _ChangeDylibPath(_ filePath: String, _ oldPath: String, _ newPath: String) -> Bool

@_silgen_name("ListDylibs")
private func _ListDylibs(_ filePath: String, _ dylibPaths: NSMutableArray) -> Bool

@_silgen_name("UninstallDylibs")
private func _UninstallDylibs(_ filePath: String, _ dylibPaths: [String]) -> Bool

// MARK: - Swift wrapper functions

func injectDyLib(_ filePath: String, _ dylibPath: String, _ weakInject: Bool, _ bCreate: Bool) -> Bool {
    return _InjectDyLib(filePath, dylibPath, weakInject, bCreate)
}

func changeDylibPath(_ filePath: String, _ oldPath: String, _ newPath: String) -> Bool {
    return _ChangeDylibPath(filePath, oldPath, newPath)
}

func getDylibsList(_ filePath: String, _ dylibPaths: NSMutableArray) -> Bool {
    return _ListDylibs(filePath, dylibPaths)
}

func removeDylibs(_ filePath: String, _ dylibPaths: [String]) -> Bool {
    return _UninstallDylibs(filePath, dylibPaths)
}

// MARK: - App Signing Functions

func signInitialApp(
    bundle: BundleOptions,
    mainOptions: SigningMainDataWrapper,
    signingOptions: SigningDataWrapper,
    appPath: URL,
    completion: @escaping (Result<(URL, NSManagedObject), Error>) -> Void
) {
    UIApplication.shared.isIdleTimerDisabled = true
    
    DispatchQueue(label: "Signing").async {
        let fileManager = FileManager.default
        let tmpDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tmpDirApp = tmpDir.appendingPathComponent(appPath.lastPathComponent)
        var iconURL = ""

        do {
            // Log signing options
            Debug.shared.log(message: "============================================")
            Debug.shared.log(message: "\(mainOptions.mainOptions)")
            Debug.shared.log(message: "============================================")
            Debug.shared.log(message: "\(signingOptions.signingOptions)")
            Debug.shared.log(message: "============================================")
            
            // Create working directories and copy app
            try fileManager.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            try fileManager.copyItem(at: appPath, to: tmpDirApp)

            // Update app info and retrieve icon info
            if let infoPlistURL = tmpDirApp.appendingPathComponent("Info.plist"),
               let infoPlistDict = NSDictionary(contentsOf: infoPlistURL),
               let info = infoPlistDict.mutableCopy() as? NSMutableDictionary {
                
                try updateInfoPlist(
                    infoDict: info,
                    main: mainOptions,
                    options: signingOptions,
                    icon: mainOptions.mainOptions.iconURL,
                    app: tmpDirApp
                )

                if let iconsDict = info["CFBundleIcons"] as? [String: Any],
                   let primaryIconsDict = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
                   let iconFiles = primaryIconsDict["CFBundleIconFiles"] as? [String],
                   let iconFileName = iconFiles.first {
                    iconURL = iconFileName
                }
            }

            // Handle tweaks
            let handler = TweakHandler(urls: signingOptions.signingOptions.toInject, app: tmpDirApp)
            try handler.getInputFiles()

            // Remove injected paths if requested
            if !mainOptions.mainOptions.removeInjectPaths.isEmpty {
                if let appExe = try? TweakHandler.findExecutable(at: tmpDirApp) {
                    _ = uninstallDylibs(
                        filePath: appExe.path,
                        dylibPaths: mainOptions.mainOptions.removeInjectPaths
                    )
                }
            }

            // Update app components
            try updatePlugIns(options: signingOptions, app: tmpDirApp)
            try removeWatchPlaceholderExtension(options: signingOptions, app: tmpDirApp)
            try updateMobileProvision(app: tmpDirApp)

            // Prepare certificate paths
            let certPath = try CoreDataManager.shared.getCertifcatePath(
                source: mainOptions.mainOptions.certificate
            )
            let provisionPath = certPath.appendingPathComponent(
                mainOptions.mainOptions.certificate?.provisionPath ?? ""
            ).path
            let p12Path = certPath.appendingPathComponent(
                mainOptions.mainOptions.certificate?.p12Path ?? ""
            ).path

            // Sign the app
            Debug.shared.log(message: "🦋 Start Signing 🦋")
            try signAppWithZSign(
                tmpDirApp: tmpDirApp,
                certPaths: (provisionPath, p12Path),
                password: mainOptions.mainOptions.certificate?.password ?? "",
                main: mainOptions,
                options: signingOptions
            )
            Debug.shared.log(message: "🦋 End Signing 🦋")

            // Move to final location
            let signedUUID = UUID().uuidString
            let signedAppsDir = getDocumentsDirectory().appendingPathComponent("Apps/Signed")
            try fileManager.createDirectory(at: signedAppsDir, withIntermediateDirectories: true)
            let signedPath = signedAppsDir.appendingPathComponent(signedUUID)
            try fileManager.moveItem(at: tmpDir, to: signedPath)

            // Update database and UI on main thread
            DispatchQueue.main.async {
                var signedAppObject: NSManagedObject?
                
                // Create core data entry
                CoreDataManager.shared.addToSignedApps(
                    version: (mainOptions.mainOptions.version ?? bundle.version) ?? "",
                    name: (mainOptions.mainOptions.name ?? bundle.name) ?? "",
                    bundleidentifier: (mainOptions.mainOptions.bundleId ?? bundle.bundleId) ?? "",
                    iconURL: iconURL,
                    uuid: signedUUID,
                    appPath: appPath.lastPathComponent,
                    timeToLive: mainOptions.mainOptions.certificate?.certData?.expirationDate ?? Date(),
                    teamName: mainOptions.mainOptions.certificate?.certData?.name ?? "",
                    originalSourceURL: bundle.sourceURL
                ) { result in
                    switch result {
                    case let .success(signedApp):
                        signedAppObject = signedApp
                    case let .failure(error):
                        Debug.shared.log(message: "signApp: \(error)", type: .error)
                        completion(.failure(error))
                    }
                }

                let appName = (mainOptions.mainOptions.name ?? bundle.name) ?? String.localized("UNKNOWN")
                Debug.shared.log(
                    message: String.localized("SUCCESS_SIGNED", arguments: appName),
                    type: .success
                )
                Debug.shared.log(message: "============================================")

                UIApplication.shared.isIdleTimerDisabled = false
                
                if let signedApp = signedAppObject {
                    completion(.success((signedPath, signedApp)))
                } else {
                    let error = NSError(
                        domain: "AppSigningErrorDomain",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create signed app object"]
                    )
                    completion(.failure(error))
                }
            }
        } catch {
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
                Debug.shared.log(message: "signApp: \(error)", type: .critical)
                completion(.failure(error))
            }
        }
    }
}

func resignApp(certificate: Certificate, appPath: URL, completion: @escaping (Bool) -> Void) {
    UIApplication.shared.isIdleTimerDisabled = true
    
    DispatchQueue(label: "Resigning").async {
        do {
            // Prepare certificate paths
            let certPath = try CoreDataManager.shared.getCertifcatePath(source: certificate)
            let provisionPath = certPath.appendingPathComponent(certificate.provisionPath ?? "").path
            let p12Path = certPath.appendingPathComponent(certificate.p12Path ?? "").path

            Debug.shared.log(message: "============================================")
            Debug.shared.log(message: "🦋 Start Resigning 🦋")

            // Sign the app
            try signAppWithZSign(
                tmpDirApp: appPath,
                certPaths: (provisionPath, p12Path),
                password: certificate.password ?? ""
            )

            Debug.shared.log(message: "🦋 End Resigning 🦋")
            
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
                Debug.shared.log(message: String.localized("SUCCESS_RESIGN"), type: .success)
            }
            
            Debug.shared.log(message: "============================================")
            completion(true)
        } catch {
            Debug.shared.log(message: "\(error)", type: .warning)
            completion(false)
        }
    }
}

// MARK: - Helper Functions

private func signAppWithZSign(
    tmpDirApp: URL,
    certPaths: (provisionPath: String, p12Path: String),
    password: String,
    main: SigningMainDataWrapper? = nil,
    options: SigningDataWrapper? = nil
) throws {
    // Call zsign function
    let result = zsign(
        tmpDirApp.path,
        certPaths.provisionPath,
        certPaths.p12Path,
        password,
        main?.mainOptions.bundleId ?? "",
        main?.mainOptions.name ?? "",
        main?.mainOptions.version ?? "",
        options?.signingOptions.removeProvisioningFile ?? true
    )
    
    if result != 0 {
        throw NSError(
            domain: "AppSigningErrorDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: String.localized("ERROR_ZSIGN_FAILED")]
        )
    }
}

func injectDylib(filePath: String, dylibPath: String, weakInject: Bool) -> Bool {
    // Call injectDyLib function using the Swift wrapper
    let bCreate = false
    return injectDyLib(filePath, dylibPath, weakInject, bCreate)
}

func changeDylib(filePath: String, oldPath: String, newPath: String) -> Bool {
    // Call changeDylibPath function using the Swift wrapper
    return changeDylibPath(filePath, oldPath, newPath)
}

func updateMobileProvision(app: URL) throws {
    let provisioningFilePath = app.appendingPathComponent("embedded.mobileprovision")
    if FileManager.default.fileExists(atPath: provisioningFilePath.path) {
        do {
            try FileManager.default.removeItem(at: provisioningFilePath)
            Debug.shared.log(message: "Embedded.mobileprovision file removed successfully!")
        } catch {
            throw error
        }
    } else {
        Debug.shared.log(message: "Could not find any mobileprovision to remove.")
    }
}

func listDylibs(filePath: String) -> [String]? {
    // Call listDylibs function using the Swift wrapper
    let dylibPathsArray = NSMutableArray()
    
    let success = getDylibsList(filePath, dylibPathsArray)
    
    if success {
        if let dylibPaths = dylibPathsArray as? [String] {
            return dylibPaths
        }
    }
    
    Debug.shared.log(message: "Failed to list dylibs.")
    return nil
}

func uninstallDylibs(filePath: String, dylibPaths: [String]) -> Bool {
    // Call removeDylibs function using the Swift wrapper
    return removeDylibs(filePath, dylibPaths)
}

func updatePlugIns(options: SigningDataWrapper, app: URL) throws {
    if options.signingOptions.removePlugins {
        let fileManager = FileManager.default
        let pluginsPath = app.appendingPathComponent("PlugIns")
        
        if fileManager.fileExists(atPath: pluginsPath.path) {
            do {
                try fileManager.removeItem(at: pluginsPath)
                Debug.shared.log(message: "Removed PlugIns!")
            } catch {
                throw error
            }
        } else {
            Debug.shared.log(message: "Could not find any PlugIns to remove.")
        }
    }
}

func removeWatchPlaceholderExtension(options: SigningDataWrapper, app: URL) throws {
    if options.signingOptions.removeWatchPlaceHolder {
        let fileManager = FileManager.default
        let placeholderPath = app.appendingPathComponent("com.apple.WatchPlaceholder")
        
        if fileManager.fileExists(atPath: placeholderPath.path) {
            do {
                try fileManager.removeItem(at: placeholderPath)
                Debug.shared.log(message: "Removed placeholder watch app!")
            } catch {
                throw error
            }
        } else {
            Debug.shared.log(message: "Placeholder watch app not found.")
        }
    }
}

func updateInfoPlist(
    infoDict: NSMutableDictionary,
    main: SigningMainDataWrapper,
    options: SigningDataWrapper,
    icon _: UIImage?,
    app: URL
) throws {
    // Update app icon if provided
    if let iconURL = main.mainOptions.iconURL {
        let imageSizes = [
            (width: 120, height: 120, name: "FRIcon60x60@2x.png"),
            (width: 152, height: 152, name: "FRIcon76x76@2x~ipad.png")
        ]

        for imageSize in imageSizes {
            let resizedImage = iconURL.resize(imageSize.width, imageSize.height)
            if let imageData = resizedImage.pngData() {
                let fileURL = app.appendingPathComponent(imageSize.name)
                do {
                    try imageData.write(to: fileURL)
                    Debug.shared.log(message: "Saved image to: \(fileURL)")
                } catch {
                    Debug.shared.log(
                        message: "Failed to save image: \(imageSize.name), error: \(error)"
                    )
                    throw error
                }
            }
        }

        let cfBundleIcons: [String: Any] = [
            "CFBundlePrimaryIcon": [
                "CFBundleIconFiles": ["FRIcon60x60"],
                "CFBundleIconName": "FRIcon"
            ]
        ]

        let cfBundleIconsIpad: [String: Any] = [
            "CFBundlePrimaryIcon": [
                "CFBundleIconFiles": ["FRIcon60x60", "FRIcon76x76"],
                "CFBundleIconName": "FRIcon"
            ]
        ]

        infoDict["CFBundleIcons"] = cfBundleIcons
        infoDict["CFBundleIcons~ipad"] = cfBundleIconsIpad
    } else {
        Debug.shared.log(message: "updateInfoPlist.updateicon: Does not include an icon, skipping!")
    }

    // Handle localization
    if options.signingOptions.forceTryToLocalize, let newName = main.mainOptions.name {
        if let displayName = infoDict.value(forKey: "CFBundleDisplayName") as? String {
            if displayName != newName {
                updateLocalizedInfoPlist(in: app, newDisplayName: newName)
            }
        } else {
            Debug.shared.log(message: "updateInfoPlist.displayName: CFBundleDisplayName not found, skipping!")
        }
    }

    // Apply various Info.plist modifications based on options
    if options.signingOptions.forceFileSharing {
        infoDict.setObject(true, forKey: "UISupportsDocumentBrowser" as NSCopying)
    }
    
    if options.signingOptions.forceiTunesFileSharing {
        infoDict.setObject(true, forKey: "UIFileSharingEnabled" as NSCopying)
    }
    
    if options.signingOptions.removeSupportedDevices {
        infoDict.removeObject(forKey: "UISupportedDevices")
    }
    
    if options.signingOptions.removeURLScheme {
        infoDict.removeObject(forKey: "CFBundleURLTypes")
    }
    
    if options.signingOptions.forceProMotion {
        infoDict.setObject(true, forKey: "CADisableMinimumFrameDurationOnPhone" as NSCopying)
    }
    
    if options.signingOptions.forceGameMode {
        infoDict.setObject(true, forKey: "GCSupportsGameMode" as NSCopying)
    }
    
    if options.signingOptions.forceForceFullScreen {
        infoDict.setObject(true, forKey: "UIRequiresFullScreen" as NSCopying)
    }
    
    if options.signingOptions.forceMinimumVersion != "Automatic" {
        infoDict.setObject(options.signingOptions.forceMinimumVersion, forKey: "MinimumOSVersion" as NSCopying)
    }
    
    if options.signingOptions.forceLightDarkAppearence != "Automatic" {
        infoDict.setObject(
            options.signingOptions.forceLightDarkAppearence,
            forKey: "UIUserInterfaceStyle" as NSCopying
        )
    }
    
    // Write updated plist back to disk
    try infoDict.write(to: app.appendingPathComponent("Info.plist"))
}

func updateLocalizedInfoPlist(in appDirectory: URL, newDisplayName: String) {
    let fileManager = FileManager.default
    do {
        let contents = try fileManager.contentsOfDirectory(
            at: appDirectory,
            includingPropertiesForKeys: nil
        )
        let localizationBundles = contents.filter { $0.pathExtension == "lproj" }

        guard !localizationBundles.isEmpty else {
            Debug.shared.log(
                message: "No .lproj directories found in \(appDirectory.path), skipping!"
            )
            return
        }

        for localizationBundle in localizationBundles {
            let infoPlistStringsURL = localizationBundle.appendingPathComponent("InfoPlist.strings")

            if fileManager.fileExists(atPath: infoPlistStringsURL.path) {
                var localizedStrings = try String(contentsOf: infoPlistStringsURL, encoding: .utf8)
                
                if let localizedDict = NSDictionary(contentsOf: infoPlistStringsURL) as? [String: String],
                   let currentDisplayName = localizedDict["CFBundleDisplayName"],
                   currentDisplayName != newDisplayName {
                    
                    localizedStrings = localizedStrings.replacingOccurrences(
                        of: currentDisplayName,
                        with: newDisplayName
                    )
                    try localizedStrings.write(to: infoPlistStringsURL, atomically: true, encoding: .utf8)
                    Debug.shared.log(message: "Updated CFBundleDisplayName in \(infoPlistStringsURL.path)")
                }
            }
        }
    } catch {
        Debug.shared.log(message: "Unable to localize, skipping!", type: .debug)
    }
}
