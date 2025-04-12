// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

// MARK: - Enhanced PopupViewController

extension PopupViewController {
    
    /// Apply fixes to the popup presentation and layout
    func applyMenuFixes() {
        // Fix button layout and sizing
        adjustButtonLayout()
        
        // Add LED effects to buttons
        applyLEDEffectsToButtons()
        
        // Ensure popup doesn't crash when app is backgrounded
        setupBackgroundHandling()
        
        // Fix vertical scrolling issues
        disableVerticalScrollingIfFewButtons()
    }
    
    /// Adjust button layout to fix oversized menu issues
    private func adjustButtonLayout() {
        guard let stackView = stackView else { return }
        
        // Set consistent button height
        let buttonHeight: CGFloat = 56
        
        // Adjust stack view constraints
        NSLayoutConstraint.activate([
            stackView.heightAnchor.constraint(lessThanOrEqualToConstant: 300),
            stackView.widthAnchor.constraint(equalToConstant: 320)
        ])
        
        // Ensure proper button sizing
        for subview in stackView.arrangedSubviews {
            if let button = subview as? PopupViewControllerButton {
                // Remove any existing height constraint
                button.constraints.filter { $0.firstAttribute == .height }.forEach { $0.isActive = false }
                
                // Add fixed height constraint
                button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
                
                // Fix button corner radius
                button.layer.cornerRadius = 12
                
                // Ensure proper text alignment and padding
                button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
                button.titleLabel?.textAlignment = .center
                button.titleLabel?.adjustsFontSizeToFitWidth = true
                button.titleLabel?.minimumScaleFactor = 0.8
            }
        }
        
        // Add spacing between buttons
        stackView.spacing = 10
        
        // Update stack view layout
        stackView.layoutIfNeeded()
    }
    
    /// Apply LED effects to buttons for better visual appearance
    private func applyLEDEffectsToButtons() {
        guard let stackView = stackView else { return }
        
        for (index, subview) in stackView.arrangedSubviews.enumerated() {
            if let button = subview as? PopupViewControllerButton {
                // Apply different effects based on button position
                if index == 0 {
                    // Primary button (first button) gets stronger effect
                    button.addButtonLEDEffect(color: button.backgroundColor ?? .systemBlue)
                } else {
                    // Secondary buttons get subtler effects
                    button.addLEDEffect(
                        color: button.backgroundColor?.withAlphaComponent(0.8) ?? .systemGray,
                        intensity: 0.3,
                        spread: 8,
                        animated: true,
                        animationDuration: 2.0
                    )
                }
                
                // Add haptic feedback to all buttons
                addHapticFeedback(to: button)
            }
        }
    }
    
    /// Add haptic feedback to buttons
    private func addHapticFeedback(to button: UIButton) {
        // Store original action
        let originalAction = button.actions(forTarget: nil, forControlEvents: .touchUpInside)?.first
        
        // Remove original action
        if let originalSelector = originalAction {
            button.removeTarget(nil, action: NSSelectorFromString(originalSelector), for: .touchUpInside)
        }
        
        // Add new action with haptic feedback
        button.addAction(UIAction { [weak self, weak button] _ in
            // Generate haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            
            // Call original action if available
            if let originalSelector = originalAction,
               let target = button?.target(forAction: NSSelectorFromString(originalSelector), withSender: button) {
                target.perform(NSSelectorFromString(originalSelector), with: button)
            }
            
            // Call onTap handler
            if let popupButton = button as? PopupViewControllerButton {
                popupButton.onTap?()
            }
            
            // Dismiss popup
            self?.dismiss(animated: true)
        }, for: .touchUpInside)
    }
    
    /// Setup handler for app backgrounding to prevent crashes
    private func setupBackgroundHandling() {
        // Add notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    /// Disable vertical scrolling if we have few buttons
    private func disableVerticalScrollingIfFewButtons() {
        guard let stackView = stackView else { return }
        
        // If we have 3 or fewer buttons, disable scrolling
        if stackView.arrangedSubviews.count <= 3 {
            if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                scrollView.isScrollEnabled = false
            }
        }
    }
    
    // MARK: - Application State Handling
    
    @objc private func applicationWillResignActive() {
        // Save state before backgrounding
        UserDefaults.standard.set(true, forKey: "popupWasShowing")
    }
    
    @objc private func applicationDidBecomeActive() {
        // Check if we need to restore or dismiss
        if UserDefaults.standard.bool(forKey: "popupWasShowing") {
            // Clear the flag
            UserDefaults.standard.set(false, forKey: "popupWasShowing")
            
            // We're already visible, no need to take action
        }
    }
}
