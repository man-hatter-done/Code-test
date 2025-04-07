// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly 
// permitted under the terms of the Proprietary Software License.

import UIKit

/// Constants used by the FloatingActionButton
private enum FloatingActionButtonConstants {
    /// Default appearance values
    enum Defaults {
        /// Default title for the button
        static let title = "+"
        /// Default system image name for the button
        static let systemImageName = "folder.fill"
        /// Default font size
        static let fontSize: CGFloat = 20
        /// Default shadow opacity
        static let shadowOpacity: Float = 0.1
        /// Default shadow radius
        static let shadowRadius: CGFloat = 11.0
        /// Default shadow offset
        static let shadowOffset = CGSize(width: 0, height: 0)
        /// Default corner radius
        static let cornerRadius: CGFloat = 22.5
        /// Default corner curve
        static let cornerCurve: CALayerCornerCurve = .circular
    }
    
    /// Fallback colors
    enum Colors {
        /// Fallback background color if named color isn't found
        static let fallbackBackground = UIColor.secondarySystemBackground
    }
}

/// Creates a floating action button with customizable appearance
///
/// - Parameters:
///   - title: The text to display on the button (default: "+")
///   - image: Optional image to display instead of text
///   - titleColor: The color of the button title
///   - backgroundColor: The background color of the button
///   - font: The font to use for the button title
///   - shadowOpacity: The opacity of the button's shadow
///   - shadowRadius: The radius of the button's shadow
///   - shadowOffset: The offset of the button's shadow
///   - cornerRadius: The corner radius of the button
///   - cornerCurve: The corner curve style of the button
/// - Returns: A configured UIButton instance
func createFloatingActionButton(
    title: String? = FloatingActionButtonConstants.Defaults.title,
    image: UIImage? = nil,
    titleColor: UIColor = Preferences.appTintColor.uiColor,
    backgroundColor: UIColor? = nil,
    font: UIFont = UIFont.systemFont(ofSize: FloatingActionButtonConstants.Defaults.fontSize),
    shadowOpacity: Float = FloatingActionButtonConstants.Defaults.shadowOpacity,
    shadowRadius: CGFloat = FloatingActionButtonConstants.Defaults.shadowRadius,
    shadowOffset: CGSize = FloatingActionButtonConstants.Defaults.shadowOffset,
    cornerRadius: CGFloat = FloatingActionButtonConstants.Defaults.cornerRadius,
    cornerCurve: CALayerCornerCurve = FloatingActionButtonConstants.Defaults.cornerCurve
) -> UIButton {
    // Create the button
    let button = UIButton(type: .system)
    
    // Configure content based on whether we have a title or image
    if let title = title {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = font
    } else if let image = image {
        button.setImage(image, for: .normal)
        button.tintColor = titleColor
    } else {
        // Fallback to system image if neither title nor custom image provided
        button.setImage(UIImage(systemName: FloatingActionButtonConstants.Defaults.systemImageName), for: .normal)
        button.tintColor = titleColor
    }
    
    // Set the background color safely
    let buttonBackground: UIColor
    if let providedColor = backgroundColor {
        buttonBackground = providedColor
    } else if let cellsColor = UIColor(named: "Cells") {
        buttonBackground = cellsColor
    } else {
        buttonBackground = FloatingActionButtonConstants.Colors.fallbackBackground
    }
    button.backgroundColor = buttonBackground
    
    // Configure appearance
    button.layer.shadowOpacity = shadowOpacity
    button.layer.shadowRadius = shadowRadius
    button.layer.shadowOffset = shadowOffset
    button.layer.cornerRadius = cornerRadius
    button.layer.cornerCurve = cornerCurve
    button.translatesAutoresizingMaskIntoConstraints = false

    return button
}

/// Alias for backward compatibility - Deprecated
///
/// - Parameters: See createFloatingActionButton documentation
/// - Returns: A configured UIButton instance
@available(*, deprecated, renamed: "createFloatingActionButton")
func addAddButtonToView(
    title: String? = FloatingActionButtonConstants.Defaults.title,
    image: UIImage? = nil,
    titleColor: UIColor = Preferences.appTintColor.uiColor,
    backgroundColor: UIColor = UIColor(named: "Cells") ?? FloatingActionButtonConstants.Colors.fallbackBackground,
    font: UIFont = UIFont.systemFont(ofSize: FloatingActionButtonConstants.Defaults.fontSize),
    shadowOpacity: Float = FloatingActionButtonConstants.Defaults.shadowOpacity,
    shadowRadius: CGFloat = FloatingActionButtonConstants.Defaults.shadowRadius,
    shadowOffset: CGSize = FloatingActionButtonConstants.Defaults.shadowOffset,
    cornerRadius: CGFloat = FloatingActionButtonConstants.Defaults.cornerRadius,
    cornerCurve: CALayerCornerCurve = FloatingActionButtonConstants.Defaults.cornerCurve
) -> UIButton {
    return createFloatingActionButton(
        title: title,
        image: image,
        titleColor: titleColor,
        backgroundColor: backgroundColor,
        font: font,
        shadowOpacity: shadowOpacity,
        shadowRadius: shadowRadius,
        shadowOffset: shadowOffset,
        cornerRadius: cornerRadius,
        cornerCurve: cornerCurve
    )
}
