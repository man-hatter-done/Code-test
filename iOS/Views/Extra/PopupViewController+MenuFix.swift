// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

/// Extension to fix popup menu sizing and presentation issues
extension PopupViewController {
    
    /// Configure a popup for proper sizing and presentation
    /// - Parameter hasUpdate: Whether this popup contains update options (affects sizing)
    func configurePopupDetents(hasUpdate: Bool = false) {
        // Get sheet presentation controller if available
        if let sheet = self.sheetPresentationController {
            let buttonCount = stackView.arrangedSubviews.count
            let requiredHeight = calculateRequiredHeight(buttonCount: buttonCount, hasUpdate: hasUpdate)
            
            if #available(iOS 16.0, *) {
                // Use custom detent in iOS 16+ for precise height control
                let customDetent = UISheetPresentationController.Detent.custom { _ in
                    return requiredHeight
                }
                sheet.detents = [customDetent]
            } else if #available(iOS 15.0, *) {
                // Use medium or large detent based on button count for iOS 15
                sheet.detents = buttonCount > 3 ? [.large()] : [.medium()]
            } else {
                // For older iOS versions, do nothing as the sheet will use defaults
            }
            
            // Always show grabber for better user experience
            sheet.prefersGrabberVisible = true
            
            // Adjust corner radius for consistent appearance
            sheet.preferredCornerRadius = 20.0
            
            // Don't allow user to change detent (prevents sizing issues)
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            
            // Prevent user from dismissing by dragging (forces use of buttons)
            if hasUpdate {
                sheet.prefersModalPresentation = true
            }
        }
    }
    
    /// Calculate the appropriate height for the popup based on its content
    /// - Parameters:
    ///   - buttonCount: Number of buttons in the popup
    ///   - hasUpdate: Whether this is an update popup (affects sizing)
    /// - Returns: The calculated height
    private func calculateRequiredHeight(buttonCount: Int, hasUpdate: Bool) -> CGFloat {
        // Base padding (top and bottom margins)
        let basePadding: CGFloat = hasUpdate ? 60.0 : 40.0
        
        // Button heights and spacing
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 10.0
        let totalButtonsHeight = CGFloat(buttonCount) * buttonHeight
        let totalSpacingHeight = CGFloat(max(0, buttonCount - 1)) * buttonSpacing
        
        // Calculate total height
        return basePadding + totalButtonsHeight + totalSpacingHeight
    }
    
    /// Configure buttons with proper constraints for popup sizing
    /// - Parameter buttons: Array of buttons to display
    func configureButtons(_ buttons: [PopupViewControllerButton]) {
        // Remove any existing buttons
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add each button to the stack view
        for button in buttons {
            // Set height constraint for consistent button sizing
            button.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
            
            // Add to stack view
            stackView.addArrangedSubview(button)
        }
        
        // Add bottom constraint to ensure proper sizing
        if let lastButton = stackView.arrangedSubviews.last {
            NSLayoutConstraint.activate([
                lastButton.bottomAnchor.constraint(
                    lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                    constant: -20
                )
            ])
        }
        
        // Force layout update
        view.layoutIfNeeded()
    }
    
    /// Ensure popup doesn't get dismissed inappropriately during app state changes
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Register for app state notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Remove observers when view disappears
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        // Fix presentation issues that might occur when app returns to foreground
        if let presentationController = presentationController as? UISheetPresentationController {
            // Force update the presentation controller's layout
            presentationController.invalidateDetents()
            
            // Ensure buttons are still correctly displayed
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
    }
}
