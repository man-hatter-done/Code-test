// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly
// permitted under the terms of the Proprietary Software License.

import UIKit

extension UIView {
    
    /// Apply modern card styling to a view
    /// - Parameters:
    ///   - backgroundColor: The background color of the card
    ///   - cornerRadius: The corner radius (default: 12)
    ///   - shadowEnabled: Whether to add a shadow (default: true)
    ///   - shadowIntensity: How strong the shadow should be (default: 0.2)
    func applyCardStyle(
        backgroundColor: UIColor? = nil,
        cornerRadius: CGFloat = 12,
        shadowEnabled: Bool = true,
        shadowIntensity: CGFloat = 0.2
    ) {
        // Apply background color if provided
        if let bgColor = backgroundColor {
            self.backgroundColor = bgColor
        }
        
        // Apply corner radius
        layer.cornerRadius = cornerRadius
        
        // Apply shadow if enabled
        if shadowEnabled {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowRadius = 6
            layer.shadowOpacity = Float(shadowIntensity)
            layer.masksToBounds = false
            
            // Create a shadow path for better performance
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        } else {
            clipsToBounds = true
        }
    }
    
    /// Add a subtle bounce animation to a view
    /// - Parameter duration: The duration of the animation
    func addBounceAnimation(duration: TimeInterval = 0.3) {
        UIView.animate(withDuration: duration / 2, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: duration / 2) {
                self.transform = CGAffineTransform.identity
            }
        })
    }
    
    /// Add a soft pulsing animation to draw attention to a view
    /// - Parameters:
    ///   - duration: Duration of each pulse
    ///   - minScale: Minimum scale factor during pulse
    ///   - maxScale: Maximum scale factor during pulse
    func addPulseAnimation(duration: TimeInterval = 1.5, minScale: CGFloat = 0.97, maxScale: CGFloat = 1.03) {
        UIView.animate(withDuration: duration / 2, delay: 0, options: [.autoreverse, .repeat], animations: {
            self.transform = CGAffineTransform(scaleX: maxScale, y: maxScale)
        })
    }
    
    /// Stops any current animations on the view
    func stopAnimations() {
        layer.removeAllAnimations()
        transform = .identity
    }
    
    /// Add a gradient overlay to the view
    /// - Parameters:
    ///   - colors: Array of colors to use in the gradient
    ///   - direction: Direction of the gradient
    ///   - locations: Optional array of locations for the gradient stops
    func addGradientBackground(
        colors: [UIColor],
        direction: GradientDirection = .topToBottom,
        locations: [NSNumber]? = nil
    ) {
        // Remove any existing gradients
        layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        
        if let locations = locations {
            gradientLayer.locations = locations
        }
        
        // Set gradient direction
        switch direction {
        case .leftToRight:
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        case .rightToLeft:
            gradientLayer.startPoint = CGPoint(x: 1.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.5)
        case .topToBottom:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        case .bottomToTop:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        case .topLeftToBottomRight:
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        case .bottomRightToTopLeft:
            gradientLayer.startPoint = CGPoint(x: 1.0, y: 1.0)
            gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
        }
        
        // Add as the bottom-most layer
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// Direction options for gradients
    enum GradientDirection {
        case leftToRight
        case rightToLeft
        case topToBottom
        case bottomToTop
        case topLeftToBottomRight
        case bottomRightToTopLeft
    }
    
    /// Add a glass-like blur effect to the view
    /// - Parameters:
    ///   - style: The blur style to use
    ///   - cornerRadius: Corner radius for the blur view
    ///   - alpha: Opacity of the blur effect
    func addGlassEffect(style: UIBlurEffect.Style = .systemUltraThinMaterial, cornerRadius: CGFloat = 0, alpha: CGFloat = 1.0) {
        // Remove any existing blur effect
        subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        
        backgroundColor = .clear
        
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = alpha
        blurEffectView.layer.cornerRadius = cornerRadius
        blurEffectView.layer.masksToBounds = true
        
        // Insert at index 0 to be below all content
        insertSubview(blurEffectView, at: 0)
    }
    
    /// Round specific corners of the view
    /// - Parameters:
    ///   - corners: Which corners to round
    ///   - radius: The corner radius
    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        layer.mask = maskLayer
    }
    
    /// Add a subtle border to the view
    /// - Parameters:
    ///   - color: The border color
    ///   - width: The border width
    func addBorder(color: UIColor, width: CGFloat = 1.0) {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
    }
    
    /// Add parallax effect to the view (subtle movement in response to device tilting)
    func addParallaxEffect(amount: CGFloat = 10) {
        // Remove any existing motion effects
        motionEffects.forEach { removeMotionEffect($0) }
        
        let horizontalEffect = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )
        horizontalEffect.minimumRelativeValue = -amount
        horizontalEffect.maximumRelativeValue = amount
        
        let verticalEffect = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )
        verticalEffect.minimumRelativeValue = -amount/2
        verticalEffect.maximumRelativeValue = amount/2
        
        let effectGroup = UIMotionEffectGroup()
        effectGroup.motionEffects = [horizontalEffect, verticalEffect]
        
        addMotionEffect(effectGroup)
    }
    
    /// Convert this view into a modern badge style
    /// - Parameters:
    ///   - backgroundColor: The badge background color
    ///   - textColor: The text color (if containing a label)
    func applyBadgeStyle(backgroundColor: UIColor, textColor: UIColor? = nil) {
        self.backgroundColor = backgroundColor
        layer.cornerRadius = bounds.height / 2
        clipsToBounds = true
        
        // Apply minimum size
        if bounds.width < bounds.height {
            frame.size.width = bounds.height
        }
        
        // If the view contains a label, update its text color
        if let textColor = textColor {
            subviews.compactMap { $0 as? UILabel }.forEach { $0.textColor = textColor }
        }
        
        // Add subtle shadow
        layer.shadowColor = backgroundColor.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.3
        layer.masksToBounds = false
    }
}
