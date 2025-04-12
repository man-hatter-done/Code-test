// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit
import CoreData

// MARK: - Enhanced PopupViewController with Sign Button Fix

extension PopupViewController {
    
    /// Apply essential fixes to prevent crashes and improve functionality
    func applyMenuFixes() {
        // Fix button layout and sizing
        adjustButtonLayout()
        
        // Add LED effects to buttons
        applyLEDEffectsToButtons()
        
        // Prevent popup from disappearing during app state changes
        setupBackgroundHandling()
        
        // Fix sheet presentation sizing issues
        fixSheetPresentation()
    }
    
    /// Fix sizing and presentation issues with the popup sheet
    private func fixSheetPresentation() {
        if let sheet = self.sheetPresentationController {
            // Calculate proper height based on content
            let buttonCount = stackView.arrangedSubviews.count
            let buttonHeight: CGFloat = 50.0
            let buttonSpacing: CGFloat = 10.0
            let verticalPadding: CGFloat = 40.0
            
            let estimatedHeight = (CGFloat(buttonCount) * buttonHeight) + 
                                 (CGFloat(max(0, buttonCount - 1)) * buttonSpacing) + 
                                 verticalPadding
            
            // Apply custom detent if available, otherwise use built-in sizes
            if #available(iOS 16.0, *) {
                let customDetent = UISheetPresentationController.Detent.custom { _ in
                    return estimatedHeight
                }
                sheet.detents = [customDetent]
            } else if #available(iOS 15.0, *) {
                // Use medium for 1-2 buttons, large for more
                sheet.detents = buttonCount <= 2 ? [.medium()] : [.large()]
            }
            
            // Always show grabber for better UX
            sheet.prefersGrabberVisible = true
            
            // Prevent issues with scrolling and expanding
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            
            // Set proper corner radius
            sheet.preferredCornerRadius = 16.0
        }
    }
    
    /// Adjust button layout to fix oversized menu issues
    private func adjustButtonLayout() {
        // Set consistent button height
        let buttonHeight: CGFloat = 50
        
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
                if #available(iOS 15.0, *) {
                    var config = button.configuration ?? UIButton.Configuration.plain()
                    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
                    button.configuration = config
                } else {
                    button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
                }
                
                button.titleLabel?.textAlignment = .center
                button.titleLabel?.adjustsFontSizeToFitWidth = true
                button.titleLabel?.minimumScaleFactor = 0.8
            }
        }
        
        // Add spacing between buttons
        stackView.spacing = 10
        
        // Update stack view layout and ensure it's properly constrained
        if stackView.constraints.isEmpty {
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
            ])
            
            // Add bottom constraint but make it a priority lower than required
            // to allow the sheet to size properly
            let bottomConstraint = stackView.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            )
            bottomConstraint.priority = .defaultHigh
            bottomConstraint.isActive = true
        }
        
        // Force layout update
        view.layoutIfNeeded()
    }
    
    /// Apply LED effects to buttons for better visual appearance
    private func applyLEDEffectsToButtons() {
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
            }
        }
    }
    
    /// Setup handler for app backgrounding to prevent crashes
    private func setupBackgroundHandling() {
        // Add notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppStateChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    // MARK: - Application State Handling
    
    @objc private func handleAppStateChange(_ notification: Notification) {
        if notification.name == UIApplication.willResignActiveNotification {
            // Save state before backgrounding
            UserDefaults.standard.set(true, forKey: "popupWasShowing")
        } else if notification.name == UIApplication.didBecomeActiveNotification {
            // We're coming back to foreground
            if UserDefaults.standard.bool(forKey: "popupWasShowing") {
                // Clear the flag
                UserDefaults.standard.set(false, forKey: "popupWasShowing")
                
                // Refresh sheet presentation if needed
                if let presentationController = presentationController as? UISheetPresentationController {
                    // Force update the presentation controller's layout
                    presentationController.invalidateDetents()
                }
                
                // Ensure buttons are still correctly displayed
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Sign Button Fix
    
    /// Fixed implementation for handling app signing that prevents crash
    /// - Parameters:
    ///   - app: The app to sign
    ///   - viewController: The parent view controller
    func safeHandleAppSigning(app: NSManagedObject, viewController: UIViewController) {
        // Properly dismiss the popup first
        dismiss(animated: true) {
            // Only attempt to present signing controller after popup is fully dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let libraryVC = viewController as? LibraryViewController {
                    // Use the fixed startSigning method from LibraryViewController+PopupFix extension
                    libraryVC.startSigning(app: app)
                } else {
                    // Fallback in case we have a different view controller type
                    self.fallbackSigningPresentation(for: app, from: viewController)
                }
            }
        }
    }
    
    /// Fallback method if we're not using LibraryViewController
    /// - Parameters:
    ///   - app: The app to sign
    ///   - viewController: The view controller to present from
    private func fallbackSigningPresentation(for app: NSManagedObject, from viewController: UIViewController) {
        // Log fallback
        Debug.shared.log(message: "Using fallback signing presentation", type: .warning)
        
        // Create signing options with current user defaults
        let signingDataWrapper = SigningDataWrapper(signingOptions: UserDefaults.standard.signingOptions)
        
        // If we can cast to DownloadedApps, proceed with signing
        if let downloadedApp = app as? DownloadedApps,
           let libraryVC = viewController.navigationController?.viewControllers.first(where: { $0 is LibraryViewController }) as? LibraryViewController {
            
            // Create and configure signing view controller
            let signingVC = SigningsViewController(
                signingDataWrapper: signingDataWrapper,
                application: downloadedApp,
                appsViewController: libraryVC
            )
            
            // Present with navigation controller
            let navigationController = UINavigationController(rootViewController: signingVC)
            navigationController.shouldPresentFullScreen()
            
            // Present from the parent view controller
            viewController.present(navigationController, animated: true)
        } else {
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Cannot sign app: invalid app data or context.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
        }
    }
}
