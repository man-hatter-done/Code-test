// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit
import ObjectiveC

/// Extension for adding LED lighting effects to UIView elements
extension UIView {
    
    // MARK: - Properties
    
    /// The LED gradient layer - stored as associated object
    private var ledGradientLayer: CAGradientLayer? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.ledGradientLayer) as? CAGradientLayer
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.ledGradientLayer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Animation group for the LED effect
    private var ledAnimationGroup: CAAnimationGroup? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.ledAnimationGroup) as? CAAnimationGroup
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.ledAnimationGroup, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Public Methods
    
    /// Add a soft LED glow effect to the view
    /// - Parameters:
    ///   - color: The main color of the LED effect
    ///   - intensity: Glow intensity (0.0-1.0, default: 0.6)
    ///   - spread: How far the glow spreads (points, default: 10)
    ///   - animated: Whether the glow should pulsate (default: true)
    ///   - animationDuration: Duration of pulse animation if animated (default: 2.0)
    func addLEDEffect(
        color: UIColor,
        intensity: CGFloat = 0.6,
        spread: CGFloat = 10,
        animated: Bool = true,
        animationDuration: TimeInterval = 2.0
    ) {
        // Remove any existing LED effect
        removeLEDEffect()
        
        // Create the gradient layer for the LED effect
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds.insetBy(dx: -spread, dy: -spread)
        
        // Set up gradient colors with transparency for subtle glow
        let innerColor = color.withAlphaComponent(intensity)
        let outerColor = color.withAlphaComponent(0)
        
        gradientLayer.colors = [outerColor.cgColor, innerColor.cgColor, innerColor.cgColor, outerColor.cgColor]
        gradientLayer.locations = [0.0, 0.3, 0.7, 1.0]
        
        // Use a radial gradient for omnidirectional glow
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        
        // Make sure the layer is positioned below content
        if let index = layer.sublayers?.firstIndex(where: { $0 is CAGradientLayer }) {
            layer.insertSublayer(gradientLayer, at: UInt32(index))
        } else {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        
        ledGradientLayer = gradientLayer
        
        // Position and update the layer
        updateLEDLayerPosition()
        
        // Add animation if needed
        if animated {
            addLEDAnimation(duration: animationDuration, intensity: intensity)
        }
    }
    
    /// Add a flowing LED effect that follows the outline of the view
    /// - Parameters:
    ///   - color: The main color of the LED effect
    ///   - intensity: Glow intensity (0.0-1.0, default: 0.8)
    ///   - width: Width of the flowing LED effect (default: 5)
    ///   - speed: Animation speed - lower is faster (default: 2.0)
    func addFlowingLEDEffect(
        color: UIColor,
        intensity: CGFloat = 0.8,
        width: CGFloat = 5,
        speed: TimeInterval = 2.0
    ) {
        // Remove any existing LED effect
        removeLEDEffect()
        
        // Create the gradient layer
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = CGRect(
            x: -width, 
            y: -width, 
            width: bounds.width + width * 2,
            height: bounds.height + width * 2
        )
        
        // Create gradient of the LED effect going around the view
        gradientLayer.colors = [
            color.withAlphaComponent(0).cgColor,
            color.withAlphaComponent(intensity).cgColor,
            color.withAlphaComponent(intensity).cgColor,
            color.withAlphaComponent(0).cgColor
        ]
        
        // Set initial position for animation
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        
        // Create a mask to only show the border
        let maskLayer = CAShapeLayer()
        let maskPath = UIBezierPath(
            roundedRect: CGRect(
                x: width/2, 
                y: width/2, 
                width: bounds.width + width, 
                height: bounds.height + width
            ),
            cornerRadius: layer.cornerRadius + width/2
        )
        
        // Cut out the inside to create a border-only effect
        let innerPath = UIBezierPath(
            roundedRect: CGRect(
                x: width * 1.5, 
                y: width * 1.5, 
                width: bounds.width, 
                height: bounds.height
            ),
            cornerRadius: layer.cornerRadius
        )
        maskPath.append(innerPath.reversing())
        
        maskLayer.path = maskPath.cgPath
        maskLayer.fillRule = .evenOdd
        
        gradientLayer.mask = maskLayer
        
        // Add the gradient layer
        layer.insertSublayer(gradientLayer, at: 0)
        ledGradientLayer = gradientLayer
        
        // Animate the LED flow
        animateFlowingLED(speed: speed)
    }
    
    /// Remove any LED lighting effects from the view
    func removeLEDEffect() {
        ledGradientLayer?.removeFromSuperlayer()
        ledGradientLayer = nil
        ledAnimationGroup?.removeAllAnimations()
        ledAnimationGroup = nil
    }
    
    // MARK: - Private Helper Methods
    
    /// Update LED layer position when frame changes
    private func updateLEDLayerPosition() {
        guard let ledLayer = ledGradientLayer else { return }
        
        if ledLayer.type == .radial {
            // For radial gradient, center it on the view
            ledLayer.position = CGPoint(
                x: bounds.midX - ledLayer.bounds.midX,
                y: bounds.midY - ledLayer.bounds.midY
            )
        } else {
            // For flowing LED, update the mask
            if let maskLayer = ledLayer.mask as? CAShapeLayer {
                let borderWidth = 5.0 // Same as default width
                
                let maskPath = UIBezierPath(
                    roundedRect: CGRect(
                        x: borderWidth/2, 
                        y: borderWidth/2, 
                        width: bounds.width + borderWidth, 
                        height: bounds.height + borderWidth
                    ),
                    cornerRadius: layer.cornerRadius + borderWidth/2
                )
                
                let innerPath = UIBezierPath(
                    roundedRect: CGRect(
                        x: borderWidth * 1.5, 
                        y: borderWidth * 1.5, 
                        width: bounds.width, 
                        height: bounds.height
                    ),
                    cornerRadius: layer.cornerRadius
                )
                maskPath.append(innerPath.reversing())
                
                maskLayer.path = maskPath.cgPath
            }
        }
    }
    
    /// Add pulsating animation to the LED effect
    private func addLEDAnimation(duration: TimeInterval, intensity: CGFloat) {
        guard let ledLayer = ledGradientLayer else { return }
        
        // Create scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.95
        scaleAnimation.toValue = 1.05
        scaleAnimation.autoreverses = true
        
        // Create opacity animation for pulsing effect
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = intensity - 0.2
        opacityAnimation.toValue = intensity + 0.1
        opacityAnimation.autoreverses = true
        
        // Group animations
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.duration = duration
        animationGroup.repeatCount = .infinity
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Save reference and add animation
        ledAnimationGroup = animationGroup
        ledLayer.add(animationGroup, forKey: "ledPulse")
    }
    
    /// Animate the flowing LED effect
    private func animateFlowingLED(speed: TimeInterval) {
        guard let ledLayer = ledGradientLayer else { return }
        
        // Create animation for flowing effect around the border
        let flowAnimation = CAKeyframeAnimation(keyPath: "position")
        
        // Create a path that follows the border
        let path = UIBezierPath()
        
        let width = ledLayer.frame.width
        let height = ledLayer.frame.height
        
        // Start at top-left and move clockwise
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0)) // Top edge
        path.addLine(to: CGPoint(x: width, y: height)) // Right edge
        path.addLine(to: CGPoint(x: 0, y: height)) // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: 0)) // Left edge
        
        flowAnimation.path = path.cgPath
        flowAnimation.duration = speed
        flowAnimation.repeatCount = .infinity
        flowAnimation.calculationMode = .paced
        
        // Also rotate the gradient colors
        let startPointAnimation = CAKeyframeAnimation(keyPath: "startPoint")
        startPointAnimation.values = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1),
            CGPoint(x: 0, y: 0)
        ]
        startPointAnimation.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        startPointAnimation.duration = speed
        startPointAnimation.repeatCount = .infinity
        
        let endPointAnimation = CAKeyframeAnimation(keyPath: "endPoint")
        endPointAnimation.values = [
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1),
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0)
        ]
        endPointAnimation.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        endPointAnimation.duration = speed
        endPointAnimation.repeatCount = .infinity
        
        // Group the animations
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [startPointAnimation, endPointAnimation]
        animationGroup.duration = speed
        animationGroup.repeatCount = .infinity
        
        // Save reference and add animation
        ledAnimationGroup = animationGroup
        ledLayer.add(animationGroup, forKey: "flowingLED")
    }
    
    // MARK: - Associated Objects Keys
    
    private struct AssociatedKeys {
        static var ledGradientLayer = "ledGradientLayer"
        static var ledAnimationGroup = "ledAnimationGroup"
    }
}

// Convenience method for applying LED effects to UIButton
extension UIButton {
    /// Add LED effect to button with appropriate settings
    /// - Parameter color: The color of the LED effect (default: tint color)
    func addButtonLEDEffect(color: UIColor? = nil) {
        let effectColor = color ?? tintColor ?? .systemBlue
        addLEDEffect(
            color: effectColor,
            intensity: 0.5,
            spread: 12,
            animated: true,
            animationDuration: 2.0
        )
    }
    
    /// Add flowing LED border to button
    /// - Parameter color: The color of the LED effect (default: tint color)
    func addButtonFlowingLEDEffect(color: UIColor? = nil) {
        let effectColor = color ?? tintColor ?? .systemBlue
        addFlowingLEDEffect(
            color: effectColor,
            intensity: 0.7,
            width: 3,
            speed: 3.0
        )
    }
}

// Convenience methods for applying LED effects to UITabBar
extension UITabBar {
    /// Add a flowing LED effect around the tab bar
    /// - Parameter color: The color of the effect (default: tint color)
    func addTabBarLEDEffect(color: UIColor? = nil) {
        let effectColor = color ?? tintColor ?? .systemBlue
        addFlowingLEDEffect(
            color: effectColor,
            intensity: 0.6,
            width: 2,
            speed: 4.0
        )
    }
}

// Convenience methods for table view cells
extension UITableViewCell {
    /// Add subtle LED effect to highlight important cells
    /// - Parameter color: The color of the LED effect
    func addCellLEDEffect(color: UIColor) {
        contentView.addLEDEffect(
            color: color,
            intensity: 0.3,
            spread: 15,
            animated: true,
            animationDuration: 3.0
        )
    }
}
