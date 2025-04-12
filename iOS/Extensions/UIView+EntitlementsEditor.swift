// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

/// Extension to add LED-style effects to entitlements editor UI components
extension UIView {
    
    /// Applies an LED effect to text fields in the entitlements editor
    func applyEntitlementFieldStyle() {
        // Apply corner radius
        layer.cornerRadius = 8
        clipsToBounds = true
        
        // Apply border with LED effect
        layer.borderWidth = 1.0
        
        // Create glowing border color animation
        let glowAnimation = CABasicAnimation(keyPath: "borderColor")
        glowAnimation.fromValue = UIColor.systemBlue.withAlphaComponent(0.4).cgColor
        glowAnimation.toValue = UIColor.systemBlue.withAlphaComponent(0.8).cgColor
        glowAnimation.duration = 1.5
        glowAnimation.autoreverses = true
        glowAnimation.repeatCount = .infinity
        layer.add(glowAnimation, forKey: "glowingBorder")
        
        // Set initial border color
        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        
        // Add subtle shadow for depth
        layer.shadowColor = UIColor.systemBlue.withAlphaComponent(0.4).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.4
        layer.masksToBounds = false
    }
    
    /// Applies an LED effect to buttons in the entitlements editor
    func applyEntitlementButtonStyle() {
        // Apply general styling
        layer.cornerRadius = 8
        clipsToBounds = true
        
        // Create background color animation for subtle pulsing effect
        let pulseAnimation = CABasicAnimation(keyPath: "backgroundColor")
        pulseAnimation.fromValue = UIColor.systemBlue.withAlphaComponent(0.7).cgColor
        pulseAnimation.toValue = UIColor.systemBlue.withAlphaComponent(0.9).cgColor
        pulseAnimation.duration = 1.2
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        layer.add(pulseAnimation, forKey: "backgroundPulse")
        
        // Set initial background color
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        
        // Add glow effect
        layer.shadowColor = UIColor.systemBlue.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.6
        layer.masksToBounds = false
    }
    
    /// Applies an LED header style for section headers in the entitlements editor
    func applyEntitlementHeaderStyle() {
        // Apply corner radius
        layer.cornerRadius = 6
        
        // Create subtle background glow
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.1).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 6
        
        // Remove any existing gradient layers
        layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        // Add the gradient layer
        layer.insertSublayer(gradientLayer, at: 0)
        
        // Add subtle border
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
    }
    
    /// Adds a validation effect to show whether an entitlement is valid
    func showValidationEffect(isValid: Bool) {
        // Remove any existing animations
        layer.removeAnimation(forKey: "validationEffect")
        
        // Set colors based on validity
        let color = isValid ? UIColor.systemGreen : UIColor.systemRed
        
        // Create pulsing animation
        let pulseAnimation = CABasicAnimation(keyPath: "borderColor")
        pulseAnimation.fromValue = color.withAlphaComponent(0.4).cgColor
        pulseAnimation.toValue = color.withAlphaComponent(0.8).cgColor
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = 3
        
        // Set border color and add animation
        layer.borderColor = color.withAlphaComponent(0.6).cgColor
        layer.add(pulseAnimation, forKey: "validationEffect")
        
        // Reset to default border after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self else { return }
            
            UIView.animate(withDuration: 0.3) {
                self.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
            }
        }
    }
}
