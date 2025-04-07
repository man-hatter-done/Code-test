// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly 
// permitted under the terms of the Proprietary Software License.

import Foundation
import Nuke
import UIKit

/// Constants used by the SectionIcons class
private enum SectionIconConstants {
    /// Default sizes
    enum Sizes {
        /// Default icon size
        static let defaultIconSize = CGSize(width: 52, height: 52)
        /// Default symbol point size
        static let symbolPointSize: CGFloat = 16
        /// Default corner radius
        static let cornerRadius: CGFloat = 12
        /// Default inset amount for symbols
        static let symbolInset: CGFloat = 7
    }
    
    /// Visual properties
    enum Appearance {
        /// Default border width
        static let borderWidth: CGFloat = 1
        /// Border color
        static let borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
    }
}

/// Utility class for creating and managing section icons in table views
class SectionIcons {
    /// Adds a SF Symbol icon with background color to a table view cell
    /// 
    /// - Parameters:
    ///   - cell: The table cell to add the icon to
    ///   - symbolName: The SF Symbol name to use
    ///   - backgroundColor: The background color for the icon
    @available(iOS 13.0, *)
    public static func sectionIcon(
        to cell: UITableViewCell,
        with symbolName: String,
        backgroundColor: UIColor
    ) {
        // Create the symbol configuration with appropriate size
        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: SectionIconConstants.Sizes.symbolPointSize,
            weight: .medium
        )
        
        // Configure the symbol image with white tint
        guard let symbolImage = UIImage(
            systemName: symbolName,
            withConfiguration: symbolConfig
        )?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
            return
        }
        
        let imageSize = SectionIconConstants.Sizes.defaultIconSize
        let insetAmount = SectionIconConstants.Sizes.symbolInset
        
        // Calculate the proper size for the symbol to fit within the background
        let scaledSymbolSize = symbolImage.size.aspectFit(in: imageSize, insetBy: insetAmount)

        // Create a colored background with rounded corners
        let coloredBackgroundImage = UIGraphicsImageRenderer(size: imageSize).image { _ in
            backgroundColor.setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: imageSize),
                cornerRadius: 7
            ).fill()
        }

        // Create the final image by combining background and symbol
        let mergedImage = UIGraphicsImageRenderer(size: imageSize).image { _ in
            // Draw the background
            coloredBackgroundImage.draw(in: CGRect(origin: .zero, size: imageSize))
            
            // Center and draw the symbol
            symbolImage.draw(in: CGRect(
                x: (imageSize.width - scaledSymbolSize.width) / 2,
                y: (imageSize.height - scaledSymbolSize.height) / 2,
                width: scaledSymbolSize.width,
                height: scaledSymbolSize.height
            ))
        }

        // Apply the image and styling to the cell's image view
        cell.imageView?.image = mergedImage
        cell.imageView?.layer.cornerRadius = SectionIconConstants.Sizes.cornerRadius
        cell.imageView?.clipsToBounds = true
        cell.imageView?.layer.borderWidth = SectionIconConstants.Appearance.borderWidth
        cell.imageView?.layer.borderColor = SectionIconConstants.Appearance.borderColor
        cell.imageView?.layer.cornerCurve = .continuous
    }

    /// Adds an image icon to a table view cell, with optional resizing and styling
    ///
    /// - Parameters:
    ///   - cell: The table cell to add the icon to
    ///   - originalImage: The source image to use
    ///   - size: The desired size for the image (default: 52x52)
    ///   - radius: The corner radius to apply (default: 12)
    public static func sectionImage(
        to cell: UITableViewCell,
        with originalImage: UIImage,
        size: CGSize = SectionIconConstants.Sizes.defaultIconSize,
        radius: Int = Int(SectionIconConstants.Sizes.cornerRadius)
    ) {
        // Use modern image renderer API to create the resized image
        let resizedImage = UIGraphicsImageRenderer(size: size).image { _ in
            // Draw the original image scaled to the new size
            originalImage.draw(in: CGRect(origin: .zero, size: size))
        }
        
        // Apply the image to the cell
        cell.imageView?.image = resizedImage

        // Apply styling to the image view
        cell.imageView?.layer.cornerCurve = .continuous
        cell.imageView?.layer.cornerRadius = CGFloat(radius)
        cell.imageView?.layer.borderWidth = SectionIconConstants.Appearance.borderWidth
        cell.imageView?.layer.borderColor = SectionIconConstants.Appearance.borderColor
        cell.imageView?.clipsToBounds = true
    }

    /// Loads an image from a URL and applies it to a table view cell
    ///
    /// - Parameters:
    ///   - url: The URL to load the image from
    ///   - cell: The table cell to apply the image to
    ///   - indexPath: The index path of the cell (unused but kept for API compatibility)
    ///   - tableView: The table view containing the cell (unused but kept for API compatibility)
    public static func loadSectionImageFromURL(
        from url: URL,
        for cell: UITableViewCell,
        at indexPath: IndexPath,
        in tableView: UITableView
    ) {
        // Create the image request
        let request = ImageRequest(url: url)
        
        // Start with a placeholder image
        let placeholderImage = UIImage(named: "unknown") ?? UIImage()
        SectionIcons.sectionImage(to: cell, with: placeholderImage)

        // Check if the image is already cached
        if let cachedImage = ImagePipeline.shared.cache.cachedImage(for: request)?.image {
            // Use the cached image
            SectionIcons.sectionImage(to: cell, with: cachedImage)
        } else {
            // Load the image asynchronously
            ImagePipeline.shared.loadImage(
                with: request,
                queue: .global(),
                progress: nil,
                completion: { [weak cell] result in
                    switch result {
                    case let .success(imageResponse):
                        // Apply the loaded image on the main thread
                        DispatchQueue.main.async {
                            // Ensure the cell still exists
                            guard let cell = cell else { return }
                            SectionIcons.sectionImage(to: cell, with: imageResponse.image)
                        }
                    case let .failure(error):
                        // Log the error but keep the placeholder image
                        Debug.shared.log(
                            message: "Failed to load image from URL: \(url.absoluteString), " +
                                "error: \(error.localizedDescription)",
                            type: .debug
                        )
                    }
                }
            )
        }
    }

    /// Loads an image from a URL and returns it via completion handler
    ///
    /// - Parameters:
    ///   - url: The URL to load the image from
    ///   - completion: A closure that will be called with the loaded image or nil if failed
    public static func loadImageFromURL(
        from url: URL,
        completion: @escaping (UIImage?) -> Void
    ) {
        // Create the image request
        let request = ImageRequest(url: url)

        // Check if the image is already cached
        if let cachedImage = ImagePipeline.shared.cache.cachedImage(for: request)?.image {
            // Return the cached image immediately
            completion(cachedImage)
            return
        }
        
        // Load the image asynchronously
        ImagePipeline.shared.loadImage(
            with: request,
            queue: .global(),
            progress: nil,
            completion: { result in
                switch result {
                case let .success(imageResponse):
                    // Return the loaded image on the main thread
                    DispatchQueue.main.async {
                        completion(imageResponse.image)
                    }
                case let .failure(error):
                    // Log the error and return nil
                    Debug.shared.log(
                        message: "Failed to load image from URL: \(url.absoluteString), " +
                            "error: \(error.localizedDescription)",
                        type: .debug
                    )
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        )
    }
}
