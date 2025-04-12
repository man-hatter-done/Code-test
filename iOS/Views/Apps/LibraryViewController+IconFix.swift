// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit
import CoreData

/// Extension to fix icon display issues in LibraryViewController
extension LibraryViewController {
    
    // MARK: - Icon Loading with LED Effects
    
    /// Enhanced icon loading for app cells with LED effects
    /// - Parameters:
    ///   - cell: The cell to configure
    ///   - app: The app object containing icon information
    ///   - filePath: The path to the app's files
    func loadEnhancedIcon(for cell: AppsTableViewCell, with app: NSManagedObject, filePath: URL) {
        // Start with a loading placeholder
        if let defaultImage = UIImage(named: "unknown") {
            SectionIcons.sectionImage(to: cell, with: defaultImage)
            
            // Add subtle pulsing effect to indicate loading
            cell.imageView?.layer.removeAllAnimations()
            let pulseAnimation = CABasicAnimation(keyPath: "opacity")
            pulseAnimation.fromValue = 0.6
            pulseAnimation.toValue = 1.0
            pulseAnimation.duration = 0.8
            pulseAnimation.autoreverses = true
            pulseAnimation.repeatCount = .infinity
            cell.imageView?.layer.add(pulseAnimation, forKey: "pulseLoading")
        }
        
        // Get icon URL if available
        if let iconURL = app.value(forKey: "iconURL") as? String {
            let imagePath = filePath.appendingPathComponent(iconURL)
            
            // Try loading from CoreData cache with fallback
            tryLoadingIconWithFallbacks(cell: cell, 
                                      imagePath: imagePath, 
                                      app: app, 
                                      filePath: filePath)
        } else {
            // Look for icon.png in the app bundle as fallback
            let alternativeIconPath = filePath.appendingPathComponent("icon.png")
            if FileManager.default.fileExists(atPath: alternativeIconPath.path),
               let image = UIImage(contentsOfFile: alternativeIconPath.path) {
                setImageWithLEDEffect(cell: cell, image: image)
                
                // Save this path for future use
                if let app = app as? DownloadedApps {
                    app.setValue("icon.png", forKey: "iconURL")
                    try? CoreDataManager.shared.saveContext()
                }
            } else {
                // Use a default image with glowing effect for visibility
                if let defaultImage = UIImage(named: "unknown") {
                    setImageWithLEDEffect(cell: cell, image: defaultImage, defaultEffect: true)
                }
            }
        }
    }
    
    /// Try multiple methods to load the app icon
    /// - Parameters:
    ///   - cell: The cell to configure
    ///   - imagePath: Path to the icon
    ///   - app: The app object
    ///   - filePath: Path to the app's files
    private func tryLoadingIconWithFallbacks(cell: AppsTableViewCell, 
                                           imagePath: URL, 
                                           app: NSManagedObject, 
                                           filePath: URL) {
        // Try loading from CoreData's image cache
        if let image = CoreDataManager.shared.loadImage(from: imagePath) {
            setImageWithLEDEffect(cell: cell, image: image)
            return
        }
        
        // Try loading directly from file path
        if FileManager.default.fileExists(atPath: imagePath.path),
           let image = UIImage(contentsOfFile: imagePath.path) {
            setImageWithLEDEffect(cell: cell, image: image)
            
            // Save to CoreData cache for future use
            CoreDataManager.shared.saveImage(image, at: imagePath)
            return
        }
        
        // Check the app bundle for icons in standard locations
        let possibleIconPaths = [
            "AppIcon60x60@2x.png",
            "AppIcon60x60@3x.png", 
            "AppIcon.png",
            "Icon.png",
            "icon.png"
        ]
        
        for iconName in possibleIconPaths {
            let potentialPath = filePath.appendingPathComponent(iconName)
            if FileManager.default.fileExists(atPath: potentialPath.path),
               let image = UIImage(contentsOfFile: potentialPath.path) {
                setImageWithLEDEffect(cell: cell, image: image)
                
                // Update the iconURL in CoreData
                if let app = app as? DownloadedApps {
                    app.setValue(iconName, forKey: "iconURL")
                    try? CoreDataManager.shared.saveContext()
                }
                return
            }
        }
        
        // Finally, try to extract icon from Info.plist
        extractIconFromInfoPlist(cell: cell, app: app, appPath: filePath)
    }
    
    /// Extract icon information from the app's Info.plist
    /// - Parameters:
    ///   - cell: The cell to configure
    ///   - app: The app object
    ///   - appPath: Path to the app bundle
    private func extractIconFromInfoPlist(cell: AppsTableViewCell, app: NSManagedObject, appPath: URL) {
        // Find the app's Info.plist
        let infoPlistPath = appPath.appendingPathComponent("Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistPath.path),
              let infoPlist = NSDictionary(contentsOf: infoPlistPath) else {
            // Use default image if Info.plist can't be found/read
            if let defaultImage = UIImage(named: "unknown") {
                setImageWithLEDEffect(cell: cell, image: defaultImage, defaultEffect: true)
            }
            return
        }
        
        // Try to get the icon filename from Info.plist
        var iconFilename: String?
        
        // First try CFBundleIcons -> CFBundlePrimaryIcon -> CFBundleIconFiles
        if let icons = infoPlist["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let filename = iconFiles.last {
            iconFilename = filename
        }
        // Then try CFBundleIconFiles directly
        else if let iconFiles = infoPlist["CFBundleIconFiles"] as? [String],
                let filename = iconFiles.last {
            iconFilename = filename
        }
        // Finally try CFBundleIconFile
        else if let filename = infoPlist["CFBundleIconFile"] as? String {
            iconFilename = filename
        }
        
        // If we found an icon filename, try to load it
        if let filename = iconFilename {
            // Try with multiple extensions
            let possibleExtensions = ["", ".png", "@2x.png", "@3x.png"]
            
            for ext in possibleExtensions {
                let fullPath = appPath.appendingPathComponent(filename + ext)
                if FileManager.default.fileExists(atPath: fullPath.path),
                   let image = UIImage(contentsOfFile: fullPath.path) {
                    setImageWithLEDEffect(cell: cell, image: image)
                    
                    // Update the iconURL in CoreData
                    if let app = app as? DownloadedApps {
                        app.setValue(filename + ext, forKey: "iconURL")
                        try? CoreDataManager.shared.saveContext()
                    }
                    return
                }
            }
        }
        
        // Final fallback to default image
        if let defaultImage = UIImage(named: "unknown") {
            setImageWithLEDEffect(cell: cell, image: defaultImage, defaultEffect: true)
        }
    }
    
    /// Set the image with an LED effect for better visibility
    /// - Parameters:
    ///   - cell: The cell to configure
    ///   - image: The image to display
    ///   - defaultEffect: Whether to apply special effect for default images
    private func setImageWithLEDEffect(cell: AppsTableViewCell, image: UIImage, defaultEffect: Bool = false) {
        // Remove any existing animations
        cell.imageView?.layer.removeAllAnimations()
        
        // Set the image
        SectionIcons.sectionImage(to: cell, with: image)
        
        // Apply appropriate LED effect
        DispatchQueue.main.async {
            if defaultEffect {
                // For default image, use a blinking effect to indicate missing icon
                let blinkAnimation = CABasicAnimation(keyPath: "borderColor")
                blinkAnimation.fromValue = UIColor.systemOrange.withAlphaComponent(0.2).cgColor
                blinkAnimation.toValue = UIColor.systemOrange.withAlphaComponent(0.8).cgColor
                blinkAnimation.duration = 1.5
                blinkAnimation.autoreverses = true
                blinkAnimation.repeatCount = .infinity
                
                cell.imageView?.layer.borderWidth = 2.0
                cell.imageView?.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.5).cgColor
                cell.imageView?.layer.cornerRadius = 10
                cell.imageView?.layer.add(blinkAnimation, forKey: "blinkingBorder")
            } else {
                // For valid images, add subtle glow
                cell.imageView?.layer.borderWidth = 0
                
                let shadowLayer = CALayer()
                shadowLayer.frame = cell.imageView?.bounds ?? CGRect.zero
                shadowLayer.shadowColor = UIColor.systemBlue.cgColor
                shadowLayer.shadowOffset = CGSize.zero
                shadowLayer.shadowOpacity = 0.5
                shadowLayer.shadowRadius = 5
                shadowLayer.cornerRadius = 10
                
                cell.imageView?.layer.insertSublayer(shadowLayer, at: 0)
            }
        }
    }
    
    // MARK: - Import Label Enhancement
    
    /// Add an import label indicator to show app source
    /// - Parameters:
    ///   - cell: The cell to configure
    ///   - sourceLocation: The source location string
    func addImportSourceLabel(to cell: AppsTableViewCell, sourceLocation: String?) {
        // Remove any existing label first
        if let existingLabel = cell.contentView.viewWithTag(9876) {
            existingLabel.removeFromSuperview()
        }
        
        // Check if we have source information
        guard let sourceLocation = sourceLocation,
              !sourceLocation.isEmpty else {
            return
        }
        
        // Create source label with icon
        let containerView = UIView()
        containerView.tag = 9876
        containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        containerView.layer.cornerRadius = 8
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create small icon (download arrow)
        let iconImage = UIImageView(image: UIImage(systemName: "arrow.down.circle.fill"))
        iconImage.tintColor = .systemBlue
        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        
        // Create label for source
        let sourceLabel = UILabel()
        sourceLabel.text = sourceLocation.contains("http") ? "Web Import" : 
                         sourceLocation.contains("Imported") ? "Local Import" : 
                         "Source: \(sourceLocation)"
        sourceLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        sourceLabel.textColor = .systemBlue
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to container
        containerView.addSubview(iconImage)
        containerView.addSubview(sourceLabel)
        
        // Add container to cell
        cell.contentView.addSubview(containerView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),
            containerView.heightAnchor.constraint(equalToConstant: 20),
            
            iconImage.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            iconImage.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 12),
            iconImage.heightAnchor.constraint(equalToConstant: 12),
            
            sourceLabel.leadingAnchor.constraint(equalTo: iconImage.trailingAnchor, constant: 3),
            sourceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -5),
            sourceLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // Add subtle LED glow effect
        containerView.addLEDEffect(
            color: .systemBlue,
            intensity: 0.3,
            spread: 5,
            animated: true,
            animationDuration: 2.0
        )
    }
}
