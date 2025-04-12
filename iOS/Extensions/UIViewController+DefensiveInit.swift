// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

/// Extension for adding defensive initialization and error recovery to view controllers
extension UIViewController {
    
    /// Execute a function with proper error handling and recovery
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - errorHandler: Handler for any errors that occur
    ///   - completion: Called when operation completes successfully
    func executeWithErrorHandling(
        operation: @escaping () throws -> Void,
        errorHandler: ((Error) -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        do {
            try operation()
            completion?()
        } catch {
            Debug.shared.log(message: "Error in \(type(of: self)): \(error.localizedDescription)", type: .error)
            
            // Call the provided error handler or use a default one
            if let errorHandler = errorHandler {
                errorHandler(error)
            } else {
                defaultErrorHandler(error)
            }
        }
    }
    
    /// Default error handler to show an alert
    /// - Parameter error: The error that occurred
    private func defaultErrorHandler(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.view.window != nil else { return }
            
            let alert = UIAlertController(
                title: "Error",
                message: "An error occurred: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            self.present(alert, animated: true)
        }
    }
    
    /// Alert with a recovery option to attempt fixing the issue
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - recoveryOperation: Operation to perform for recovery
    func showRecoveryAlert(title: String, message: String, recoveryOperation: @escaping () -> Void) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        // Add recovery action
        let recoverAction = UIAlertAction(title: "Recover", style: .default) { _ in
            recoveryOperation()
        }
        
        // Add ignore action
        let ignoreAction = UIAlertAction(title: "Ignore", style: .cancel)
        
        alert.addAction(recoverAction)
        alert.addAction(ignoreAction)
        
        // Add LED glow effect to highlight importance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let alertWindow = alert.view.window {
                alertWindow.layer.borderWidth = 2.0
                alertWindow.layer.borderColor = UIColor.systemYellow.cgColor
                alertWindow.layer.cornerRadius = 10.0
                
                // Add glow effect
                alertWindow.layer.shadowColor = UIColor.systemYellow.cgColor
                alertWindow.layer.shadowOffset = CGSize(width: 0, height: 0)
                alertWindow.layer.shadowRadius = 10.0
                alertWindow.layer.shadowOpacity = 0.8
                
                // Add animation
                let animation = CABasicAnimation(keyPath: "shadowOpacity")
                animation.fromValue = 0.8
                animation.toValue = 0.4
                animation.duration = 1.5
                animation.autoreverses = true
                animation.repeatCount = Float.infinity
                alertWindow.layer.add(animation, forKey: "glowAnimation")
            }
        }
        
        present(alert, animated: true)
    }
    
    /// Check if view controller is in an invalid state
    var isInvalidState: Bool {
        return isBeingDismissed || 
               isMovingFromParent || 
               isBeingPresented || 
               view.window == nil
    }
    
    /// Safe method to push a view controller
    /// - Parameters:
    ///   - viewController: The view controller to push
    ///   - animated: Whether to animate the transition
    ///   - completion: Completion handler
    func safePush(
        viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        // Check if we're in a valid state to push
        guard let navigationController = navigationController,
              !isInvalidState else {
            Debug.shared.log(message: "Cannot push - invalid state or no navigation controller", type: .warning)
            return
        }
        
        // Push the view controller
        navigationController.pushViewController(viewController, animated: animated)
        
        // Execute completion handler if animation is disabled or after animation completes
        if !animated {
            completion?()
        } else if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
        }
    }
    
    /// Safe method to present a view controller
    /// - Parameters:
    ///   - viewController: The view controller to present
    ///   - animated: Whether to animate the transition
    ///   - completion: Completion handler
    func safePresent(
        viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        // Check if we're in a valid state to present
        guard !isInvalidState,
              presentedViewController == nil else {
            Debug.shared.log(message: "Cannot present - invalid state or already presenting", type: .warning)
            return
        }
        
        // Present the view controller
        present(viewController, animated: animated, completion: completion)
    }
    
    /// Show an LED-styled indicator for the current state
    /// - Parameters:
    ///   - type: The type of indicator
    ///   - message: Optional message to display
    ///   - duration: How long to show the indicator
    func showLEDIndicator(type: LEDIndicatorType, message: String? = nil, duration: TimeInterval = 2.0) {
        // Remove any existing indicators
        if let existingIndicator = view.viewWithTag(7777) {
            existingIndicator.removeFromSuperview()
        }
        
        // Create indicator container
        let container = UIView()
        container.tag = 7777
        container.backgroundColor = type.backgroundColor
        container.alpha = 0
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        // Configure layout
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            container.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        // Add message label if provided
        if let message = message {
            let label = UILabel()
            label.text = message
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
            ])
        }
        
        // Add LED glow effect
        container.addLEDEffect(
            color: type.glowColor,
            intensity: 0.7,
            spread: 10,
            animated: true,
            animationDuration: 1.0
        )
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1.0
        }
        
        // Automatically hide after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.3, animations: {
                container.alpha = 0
            }, completion: { _ in
                container.removeFromSuperview()
            })
        }
    }
}

/// Types of LED indicators
enum LEDIndicatorType {
    case success
    case error
    case warning
    case info
    
    var backgroundColor: UIColor {
        switch self {
        case .success: return UIColor.systemGreen.withAlphaComponent(0.8)
        case .error: return UIColor.systemRed.withAlphaComponent(0.8)
        case .warning: return UIColor.systemOrange.withAlphaComponent(0.8)
        case .info: return UIColor.systemBlue.withAlphaComponent(0.8)
        }
    }
    
    var glowColor: UIColor {
        switch self {
        case .success: return .systemGreen
        case .error: return .systemRed
        case .warning: return .systemOrange
        case .info: return .systemBlue
        }
    }
}

// MARK: - ViewControllerRefreshable Enhanced

/// Protocol for view controllers that can refresh their content
protocol EnhancedViewControllerRefreshable: ViewControllerRefreshable {
    /// Refresh content with defensive error handling
    func refreshContentSafely()
    
    /// Check if this controller needs recovery after being in an invalid state
    var needsRecovery: Bool { get }
    
    /// Perform recovery operation to restore the controller to a valid state
    func performRecovery()
}

/// Default implementation of EnhancedViewControllerRefreshable
extension EnhancedViewControllerRefreshable where Self: UIViewController {
    /// Default implementation that wraps refreshContent in error handling
    func refreshContentSafely() {
        executeWithErrorHandling(
            operation: { 
                self.refreshContent() 
            },
            errorHandler: { error in
                Debug.shared.log(message: "Error refreshing content: \(error.localizedDescription)", type: .error)
                
                // Show recovery option if needed
                if self.needsRecovery {
                    self.showRecoveryAlert(
                        title: "Refresh Error",
                        message: "There was a problem refreshing content. Would you like to attempt recovery?",
                        recoveryOperation: {
                            self.performRecovery()
                        }
                    )
                }
            }
        )
    }
    
    /// Default implementation of needsRecovery
    var needsRecovery: Bool {
        return false
    }
    
    /// Default implementation of performRecovery
    func performRecovery() {
        // Default implementation does nothing
    }
}
