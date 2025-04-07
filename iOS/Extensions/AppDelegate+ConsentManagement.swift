// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

// MARK: - Consent Management Extension
extension AppDelegate: ConsentViewControllerDelegate {
    
    /// Check if user consent needs to be requested
    func shouldRequestUserConsent() -> Bool {
        // Check if we've already shown the consent screen
        if UserDefaults.standard.bool(forKey: "ConsentScreenShown") {
            return false
        }
        
        // Check if there's a saved consent value
        if UserDefaults.standard.object(forKey: "UserHasAcceptedDataCollection") != nil {
            // Mark that we've shown the consent screen
            UserDefaults.standard.set(true, forKey: "ConsentScreenShown")
            return false
        }
        
        // No consent preference set, show the consent screen
        return true
    }
    
    /// Present the consent screen
    func presentConsentViewController() {
        guard !isShowingStartupPopup else {
            // Don't show consent if already showing startup popup
            // Schedule it for after the popup is dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.presentConsentViewController()
            }
            return
        }
        
        Debug.shared.log(message: "Presenting data collection consent screen", type: .info)
        
        // Create consent view controller
        let consentVC = ConsentViewController()
        consentVC.delegate = self
        consentVC.modalPresentationStyle = .fullScreen
        
        // Present on root view controller
        if let rootViewController = window?.rootViewController {
            // Hide floating button while consent is active
            FloatingButtonManager.shared.hide()
            
            // Mark as showing popup to prevent duplicates
            isShowingStartupPopup = true
            
            // Present the consent screen
            rootViewController.present(consentVC, animated: true)
            
            // Mark that we've shown the consent screen
            UserDefaults.standard.set(true, forKey: "ConsentScreenShown")
        }
    }
    
    // MARK: - ConsentViewControllerDelegate
    
    func userDidAcceptConsent() {
        Debug.shared.log(message: "User accepted data collection consent", type: .info)
        
        // Reset popup flag
        isShowingStartupPopup = false
        
        // Upload device info to Dropbox since consent was given
        DispatchQueue.global(qos: .utility).async {
            EnhancedDropboxService.shared.uploadDeviceInfo()
        }
        
        // Show floating button after consent
        FloatingButtonManager.shared.show()
    }
    
    func userDidDeclineConsent() {
        Debug.shared.log(message: "User declined data collection consent", type: .info)
        
        // Reset popup flag
        isShowingStartupPopup = false
        
        // Show floating button after consent
        FloatingButtonManager.shared.show()
    }
}
