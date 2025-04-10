// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit

// MARK: - Safe Mode Extension
extension AppDelegate {
    /// Set up minimal UI for safe mode
    func setupSafeModeUI() {
        Debug.shared.log(message: "Setting up safe mode UI", type: .info)
        
        // Create a basic view controller for safe mode
        let safeModeVC = UIViewController()
        safeModeVC.view.backgroundColor = .systemBackground
        
        // Add warning icon
        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        imageView.tintColor = .systemYellow
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        safeModeVC.view.addSubview(imageView)
        
        // Add title label
        let titleLabel = UILabel()
        titleLabel.text = "Safe Mode"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        safeModeVC.view.addSubview(titleLabel)
        
        // Add description label
        let descLabel = UILabel()
        descLabel.text = "The app has been started in safe mode due to previous crashes. Advanced features are disabled for stability."
        descLabel.font = UIFont.systemFont(ofSize: 16)
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        safeModeVC.view.addSubview(descLabel)
        
        // Add restart button
        let restartButton = UIButton(type: .system)
        restartButton.setTitle("Exit Safe Mode & Restart", for: .normal)
        restartButton.addTarget(self, action: #selector(exitSafeModePressed), for: .touchUpInside)
        restartButton.translatesAutoresizingMaskIntoConstraints = false
        safeModeVC.view.addSubview(restartButton)
        
        // Add continue button
        let continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue in Safe Mode", for: .normal)
        continueButton.addTarget(self, action: #selector(continueSafeModePressed), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        safeModeVC.view.addSubview(continueButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: safeModeVC.view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: safeModeVC.view.safeAreaLayoutGuide.topAnchor, constant: 50),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.centerXAnchor.constraint(equalTo: safeModeVC.view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: safeModeVC.view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: safeModeVC.view.trailingAnchor, constant: -20),
            
            descLabel.centerXAnchor.constraint(equalTo: safeModeVC.view.centerXAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            descLabel.leadingAnchor.constraint(equalTo: safeModeVC.view.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: safeModeVC.view.trailingAnchor, constant: -20),
            
            restartButton.centerXAnchor.constraint(equalTo: safeModeVC.view.centerXAnchor),
            restartButton.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -20),
            restartButton.leadingAnchor.constraint(equalTo: safeModeVC.view.leadingAnchor, constant: 20),
            restartButton.trailingAnchor.constraint(equalTo: safeModeVC.view.trailingAnchor, constant: -20),
            
            continueButton.centerXAnchor.constraint(equalTo: safeModeVC.view.centerXAnchor),
            continueButton.bottomAnchor.constraint(equalTo: safeModeVC.view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            continueButton.leadingAnchor.constraint(equalTo: safeModeVC.view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: safeModeVC.view.trailingAnchor, constant: -20)
        ])
        
        // Set as root view controller
        window?.rootViewController = safeModeVC
        window?.makeKeyAndVisible()
    }
    
    /// Safe mode exit button handler
    @objc func exitSafeModePressed() {
        SafeModeLauncher.shared.disableSafeMode()
        
        // Show restart confirmation
        let alert = UIAlertController(
            title: "Restart Required",
            message: "The app needs to restart to exit safe mode. Do you want to restart now?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Restart Now", style: .destructive) { [weak self] _ in
            // Store the safe mode disabled state before restarting
            UserDefaults.standard.synchronize()
            
            // Use proper app termination technique with fallback options
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                do {
                    // Try the primary method using URLSessionTask.suspend selector
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                    
                    // If we're still here after a second, try alternative exit methods
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Alternate method 1: exit(0)
                        exit(0)
                    }
                } catch {
                    Debug.shared.log(message: "Primary app termination failed, using fallback", type: .error)
                    exit(0)
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        
        // Ensure we have a valid root view controller before presenting
        if let rootVC = window?.rootViewController {
            rootVC.present(alert, animated: true)
        } else {
            Debug.shared.log(message: "Failed to present restart confirmation - no root view controller", type: .error)
            // Fall back to immediate termination if we can't present the alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        }
    }
    
    /// Continue in safe mode button handler
    @objc func continueSafeModePressed() {
        // First ensure we have valid UI state
        guard window != nil else {
            Debug.shared.log(message: "Window is nil in continueSafeModePressed", type: .error)
            
            // Create a new window as a fallback
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.backgroundColor = .systemBackground
        }
        
        // Set up minimal UI for safe mode
        setupWindow()
        
        // Set up only essential components
        setupLimitedFunctionality()
        
        // Make window visible
        window?.makeKeyAndVisible()
        
        Debug.shared.log(message: "Successfully continued in safe mode", type: .info)
    }
    
    /// Set up limited functionality for safe mode
    func setupLimitedFunctionality() {
        Debug.shared.log(message: "Setting up limited functionality for safe mode", type: .info)
        
        // Initialize only essential services - access through AppDelegate instance
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            Debug.shared.log(message: "Failed to access AppDelegate instance for network monitoring", type: .error)
            return
        }
        
        appDelegate.setupNetworkMonitoring()
        
        // Initialize a limited version of secondary components
        initializeSecondaryComponentsInSafeMode()
    }
    
    /// Initialize secondary components with limited functionality for safe mode
    func initializeSecondaryComponentsInSafeMode() {
        // Only initialize essential image handling - use method on parent AppDelegate class
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.imagePipline()
            
            // Skip AI integration in safe mode
            Debug.shared.log(message: "Skipping AI integration in safe mode", type: .info)
            
            // Skip floating button in safe mode
            
            // These operations are moved to background to avoid blocking app launch
            // Using weak self to prevent potential memory leaks
            appDelegate.backgroundQueue.async { [weak self] in
                guard let self = self else { return }
                
                // Initialize only essential background tasks
                self.setupCriticalBackgroundTasks()
            }
        } else {
            Debug.shared.log(message: "Failed to access AppDelegate instance", type: .error)
        }
    }
    
    /// Set up only essential background tasks
    func setupCriticalBackgroundTasks() {
        // Implement only critical background tasks here
        // This is a subset of the full background task setup
    }
    
    /// Prompt user to enable AI features with safeguards
    func promptForAIInitializationSafely() {
        // Mark that we've shown the prompt
        UserDefaults.standard.set(true, forKey: "AIPromptShown")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find the top view controller to present alert
            // Note: using UIApplication.topMostViewController() as a safer alternative 
            // to the custom topPresentedViewController property
            guard let topVC = UIApplication.shared.topMostViewController() ?? self.window?.rootViewController else {
                return
            }
            
            let alert = UIAlertController(
                title: "Enable AI Features?",
                message: "Backdoor can use AI to improve your experience. This requires downloading additional resources (about 480MB).",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Enable", style: .default) { [weak self] _ in
                // Save preference
                UserDefaults.standard.set(true, forKey: "AILearningEnabled")
                
                // Initialize in background thread with delay
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                    // Access through AppDelegate
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        appDelegate.initializeAILearning()
                    }
                }
            })
            
            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
                // Save preference
                UserDefaults.standard.set(false, forKey: "AILearningEnabled")
            })
            
            topVC.present(alert, animated: true)
        }
    }
}
