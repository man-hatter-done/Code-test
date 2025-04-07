//
//  SettingsViewController+Terminal.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

// MARK: - Terminal Button Toggle
extension SettingsViewController {
    /// Toggle handler for the terminal button setting
    @objc func terminalButtonToggled(_ sender: UISwitch) {
        // Save setting
        UserDefaults.standard.set(sender.isOn, forKey: "show_terminal_button")
        
        // Update button visibility
        if sender.isOn {
            TerminalButtonManager.shared.show()
            Debug.shared.log(message: "Terminal button enabled", type: .info)
        } else {
            TerminalButtonManager.shared.hide()
            Debug.shared.log(message: "Terminal button disabled", type: .info)
        }
    }
}

// Extension to handle any terminal reset options
extension SettingsViewController {
    
    /// Resets the terminal settings to defaults
    @objc func resetTerminalSettings() {
        let alert = UIAlertController(
            title: "Reset Terminal Settings",
            message: "Are you sure you want to reset all terminal settings? This will not affect your command history.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            // Reset terminal settings (server settings are now hardcoded)
            UserDefaults.standard.removeObject(forKey: "terminal_font_size")
            UserDefaults.standard.removeObject(forKey: "terminal_color_theme")
            
            // Post notification for settings change
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
            
            // Show confirmation
            let confirmAlert = UIAlertController(
                title: "Settings Reset",
                message: "Terminal settings have been reset to defaults.",
                preferredStyle: .alert
            )
            confirmAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirmAlert, animated: true)
            
            Debug.shared.log(message: "Terminal settings reset to defaults", type: .info)
        })
        
        present(alert, animated: true)
    }
    
    /// Add terminal settings reset to the full reset option
    func resetTerminalAll() {
        // Reset settings
        resetTerminalSettings()
        
        // Also clear command history
        let history = CommandHistory()
        history.clearHistory()
        history.saveHistory()
        
        // End any active sessions
        TerminalService.shared.endSession { _ in
            Debug.shared.log(message: "Terminal session ended during reset all", type: .info)
        }
        
        Debug.shared.log(message: "Terminal fully reset (settings, history, and session)", type: .info)
    }
}

// Terminal-specific reset methods that will be called from the main reset methods in ResetAlertOptions.swift
extension SettingsViewController {
    // Terminal reset functionality to be integrated with the main reset options
    func integrateTerminalReset() {
        // Reset terminal settings
        resetTerminalSettings()
        
        // Also clear command history
        let history = CommandHistory()
        history.clearHistory()
        history.saveHistory()
        
        // End any active sessions
        TerminalService.shared.endSession { _ in
            Debug.shared.log(message: "Terminal session ended during reset all", type: .info)
        }
        
        Debug.shared.log(message: "Terminal fully reset (settings, history, and session)", type: .info)
    }
}
