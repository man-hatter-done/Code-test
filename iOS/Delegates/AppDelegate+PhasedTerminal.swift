//
//  AppDelegate+PhasedTerminal.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

extension AppDelegate {
    /// Phase 5: Initialize terminal components
    func initializePhase5_Terminal() {
        Debug.shared.log(message: "Initializing phase 5: Terminal components", type: .info)
        
        // Setup terminal
        setupTerminal()
        
        // Proceed to final setup
        initializePhase6_FinalSetup()
    }
    
    /// Phase 6: Final setup and cleanup
    func initializePhase6_FinalSetup() {
        Debug.shared.log(message: "Initializing phase 6: Final setup", type: .info)
        
        // Show startup components with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.initializeTerminalAfterLaunch()
        }
        
        // Notify app is ready
        NotificationCenter.default.post(name: .appInitializationCompleted, object: nil)
        
        Debug.shared.log(message: "App initialization complete", type: .success)
    }
}

// Create notification for app initialization completion
extension Notification.Name {
    static let appInitializationCompleted = Notification.Name("appInitializationCompleted")
}
