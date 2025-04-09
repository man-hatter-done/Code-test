// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

// Extension to fix popup presentation issues
extension PopupViewController {
    
    /// Configures the sheet presentation controller to display the popup properly
    /// - Parameter hasUpdate: Whether the popup is displaying an update option
    func configureSheetPresentation(hasUpdate: Bool = false) {
        if let sheet = self.sheetPresentationController {
            // Using detents with appropriate heights
            if #available(iOS 16.0, *) {
                let smallDetent = UISheetPresentationController.Detent.custom { _ in
                    // Calculate based on number of buttons plus padding
                    return hasUpdate ? 150.0 : self.calculateRequiredHeight()
                }
                sheet.detents = [smallDetent]
            } else {
                // Fallback for older iOS versions
                sheet.detents = [.medium()]
            }
            
            // Always show grabber for better UX
            sheet.prefersGrabberVisible = true
            
            // Set proper corner radius for consistent appearance
            sheet.preferredCornerRadius = 20.0
        }
    }
    
    /// Calculates the required height based on stack view content
    /// - Returns: Appropriate height for the popup sheet
    private func calculateRequiredHeight() -> CGFloat {
        // Base padding (top and bottom)
        let basePadding: CGFloat = 40.0
        
        // Number of buttons in stack view
        let buttonCount = stackView.arrangedSubviews.count
        
        // Height per button plus spacing
        let buttonHeight: CGFloat = 50.0 
        let spacingHeight: CGFloat = stackView.spacing * CGFloat(max(0, buttonCount - 1))
        
        // Calculate total required height
        return basePadding + (buttonHeight * CGFloat(buttonCount)) + spacingHeight
    }
    
    /// Enhanced button configuration with proper layout and spacing
    /// - Parameter buttons: Array of buttons to display in popup
    func configureButtonsWithLayout(_ buttons: [PopupViewControllerButton]) {
        // First clear existing buttons
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add buttons to stack with proper constraints
        for button in buttons {
            // Set fixed height for consistent button sizes
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
            
            // Add to stack view
            stackView.addArrangedSubview(button)
        }
        
        // Add bottom constraint to ensure proper sizing of the popup
        if let lastButton = stackView.arrangedSubviews.last {
            NSLayoutConstraint.activate([
                lastButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
            ])
        }
    }
}
