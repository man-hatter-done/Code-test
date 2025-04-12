// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted 
// under the terms of the Proprietary Software License.

import UIKit

/// Enhanced SafeMode manager
extension AppDelegate {
    
    /// Check if the app should launch in safe mode based on crash history
    func shouldLaunchInSafeMode() -> Bool {
        return SafeModeLauncher.shared.inSafeMode
    }
    
    /// Setup enhanced safe mode UI with LED effects
    func setupEnhancedSafeModeUI() {
        Debug.shared.log(message: "Setting up enhanced safe mode UI", type: .info)
        
        // Create a basic view controller for safe mode
        let safeModeVC = UIViewController()
        safeModeVC.view.backgroundColor = .systemBackground
        
        // Create container view for LED effects
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        containerView.layer.cornerRadius = 20
        safeModeVC.view.addSubview(containerView)
        
        // Add warning icon
        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        imageView.tintColor = .systemYellow
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        // Add title label
        let titleLabel = UILabel()
        titleLabel.text = "Safe Mode"
        titleLabel.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Add description label with improved explanation
        let descLabel = UILabel()
        descLabel.text = "The app has been started in safe mode due to repeated crashes. Advanced features are disabled for stability.\n\nYou can still use basic app functions while we prevent crashes from recurring."
        descLabel.font = UIFont.systemFont(ofSize: 16)
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descLabel)
        
        // Add restart button with LED effect
        let restartButton = UIButton(type: .system)
        restartButton.setTitle("Exit Safe Mode & Restart", for: .normal)
        restartButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        restartButton.backgroundColor = .systemBlue
        restartButton.setTitleColor(.white, for: .normal)
        restartButton.layer.cornerRadius = 10
        restartButton.addTarget(self, action: #selector(exitSafeModePressed), for: .touchUpInside)
        restartButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(restartButton)
        
        // Add continue button
        let continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue in Safe Mode", for: .normal)
        continueButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        continueButton.backgroundColor = .tertiarySystemBackground
        continueButton.setTitleColor(.systemBlue, for: .normal)
        continueButton.layer.cornerRadius = 10
        continueButton.addTarget(self, action: #selector(continueSafeModePressed), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(continueButton)
        
        // Add crash info section
        let crashInfoLabel = UILabel()
        crashInfoLabel.text = getCrashInfoText()
        crashInfoLabel.font = UIFont.systemFont(ofSize: 13)
        crashInfoLabel.textColor = .secondaryLabel
        crashInfoLabel.textAlignment = .center
        crashInfoLabel.numberOfLines = 0
        crashInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(crashInfoLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: safeModeVC.view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: safeModeVC.view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: safeModeVC.view.widthAnchor, multiplier: 0.9),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: safeModeVC.view.heightAnchor, multiplier: 0.8),
            
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            descLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            descLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            descLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            
            restartButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            restartButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 40),
            restartButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            restartButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            restartButton.heightAnchor.constraint(equalToConstant: 50),
            
            continueButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            continueButton.topAnchor.constraint(equalTo: restartButton.bottomAnchor, constant: 15),
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            continueButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            
            crashInfoLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            crashInfoLabel.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 25),
            crashInfoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            crashInfoLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            crashInfoLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // Apply LED effects
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Add pulsing glow to container
            containerView.layer.shadowColor = UIColor.systemYellow.cgColor
            containerView.layer.shadowOffset = CGSize(width: 0, height: 0)
            containerView.layer.shadowRadius = 15
            containerView.layer.shadowOpacity = 0.3
            
            // Add animation to the shadow
            let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            shadowAnimation.fromValue = 0.3
            shadowAnimation.toValue = 0.6
            shadowAnimation.duration = 2.0
            shadowAnimation.autoreverses = true
            shadowAnimation.repeatCount = .infinity
            containerView.layer.add(shadowAnimation, forKey: "shadowPulse")
            
            // Add LED effect to warning icon
            imageView.addLEDEffect(
                color: .systemYellow,
                intensity: 0.6,
                spread: 15,
                animated: true,
                animationDuration: 2.5
            )
            
            // Add LED effects to buttons
            restartButton.addButtonLEDEffect(color: .systemBlue)
            continueButton.addLEDEffect(
                color: .systemBlue,
                intensity: 0.3,
                spread: 8,
                animated: true,
                animationDuration: 2.0
            )
        }
        
        // Set as root view controller
        window?.rootViewController = safeModeVC
        window?.makeKeyAndVisible()
    }
    
    /// Get formatted information about crash history
    private func getCrashInfoText() -> String {
        let crashCount = UserDefaults.standard.integer(forKey: "crashCount") 
        let lastCrashTime = UserDefaults.standard.object(forKey: "lastCrashTime") as? Date
        
        var infoText = "Crash Information: "
        
        if crashCount > 0 {
            infoText += "\(crashCount) crash"
            infoText += crashCount > 1 ? "es" : ""
            
            if let lastTime = lastCrashTime {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let relativeTime = formatter.localizedString(for: lastTime, relativeTo: Date())
                infoText += " detected, last occurred \(relativeTime)"
            }
        } else {
            infoText += "No recent crashes detected"
        }
        
        return infoText
    }
    
    /// Update safe mode banner in normal mode
    func updateSafeModeBanner(on viewController: UIViewController, isEnabled: Bool) {
        // Remove existing banner if any
        if let existingBanner = viewController.view.viewWithTag(8888) {
            existingBanner.removeFromSuperview()
        }
        
        guard isEnabled else { return }
        
        // Create safe mode banner
        let banner = UIView()
        banner.tag = 8888
        banner.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.85)
        banner.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(banner)
        
        // Create label
        let label = UILabel()
        label.text = "SAFE MODE ACTIVE"
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(label)
        
        // Add constraints
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: viewController.view.safeAreaLayoutGuide.topAnchor),
            banner.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            banner.heightAnchor.constraint(equalToConstant: 24),
            
            label.centerXAnchor.constraint(equalTo: banner.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: banner.centerYAnchor)
        ])
        
        // Add LED glow effect
        banner.addFlowingLEDEffect(
            color: .systemYellow,
            intensity: 0.7,
            width: 1,
            speed: 3.0
        )
    }
}

// MARK: - SafeModeLauncher Enhancements

extension SafeModeLauncher {
    /// Enhanced method to determine crash count
    var crashCountThreshold: Int {
        // Return different thresholds based on device performance
        // Lower-end devices may need a higher threshold due to occasional resource constraints
        if deviceIsLowEnd() {
            return 3 // More forgiving for low-end devices
        } else {
            return 2 // Standard threshold
        }
    }
    
    /// Determine if the device is a lower-end model
    private func deviceIsLowEnd() -> Bool {
        // Check total RAM as a proxy for device capability
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let gigabyte = 1024 * 1024 * 1024
        
        // Consider devices with less than 3GB RAM as low-end
        return physicalMemory < 3 * UInt64(gigabyte)
    }
    
    /// Check if a specific feature should be enabled in safe mode
    func isFeatureEnabledInSafeMode(_ feature: SafeModeFeature) -> Bool {
        switch feature {
            case .fileManagement:
                return true // Essential feature, always enabled
            case .settings:
                return true // Basic settings should be available
            case .appSigningBasic:
                return true // Basic signing without advanced features
            case .appSigningAdvanced:
                return false // Disable advanced signing features
            case .aiAssistant:
                return false // Disable AI features
            case .sources:
                return true // Allow viewing sources but limit downloads
        }
    }
}

/// Features that can be selectively enabled/disabled in safe mode
enum SafeModeFeature {
    case fileManagement
    case settings
    case appSigningBasic
    case appSigningAdvanced
    case aiAssistant
    case sources
}
