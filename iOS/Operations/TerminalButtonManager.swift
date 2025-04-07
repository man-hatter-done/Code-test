//
//  TerminalButtonManager.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

/// Manages the floating terminal button across the app
final class TerminalButtonManager {
    // Singleton instance
    static let shared = TerminalButtonManager()
    
    // UI components
    private let floatingButton = FloatingTerminalButton()
    
    // Thread-safe state tracking
    private let stateQueue = DispatchQueue(label: "com.backdoor.terminalButtonState", qos: .userInteractive)
    private var _isPresentingTerminal = false
    private var isPresentingTerminal: Bool {
        get { stateQueue.sync { _isPresentingTerminal } }
        set { stateQueue.sync { _isPresentingTerminal = newValue } }
    }
    
    // Setup state
    private var _isSetUp = false
    private var isSetUp: Bool {
        get { stateQueue.sync { _isSetUp } }
        set { stateQueue.sync { _isSetUp = newValue } }
    }
    
    // Parent view references
    private weak var parentViewController: UIViewController?
    private weak var parentView: UIView?
    
    // Recovery counter
    private var _recoveryAttempts = 0
    private var recoveryAttempts: Int {
        get { stateQueue.sync { _recoveryAttempts } }
        set { stateQueue.sync { _recoveryAttempts = newValue } }
    }
    
    private let maxRecoveryAttempts = 3
    
    // Monitor app state
    private var isAppActive = true
    
    // Logger
    private let logger = Debug.shared
    
    private init() {
        logger.log(message: "TerminalButtonManager initialized", type: .info)
        
        // Configure button
        configureFloatingButton()
        
        // Set up observers
        setupObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        logger.log(message: "TerminalButtonManager deinit", type: .debug)
    }
    
    private func configureFloatingButton() {
        // Ensure it's above other views but below AI button
        floatingButton.layer.zPosition = 998
        floatingButton.isUserInteractionEnabled = true
    }
    
    private func setupObservers() {
        // Observe orientation changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // Observe interface style changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateButtonAppearance),
            name: NSNotification.Name("UIInterfaceStyleChanged"),
            object: nil
        )
        
        // Listen for button taps
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminalRequest),
            name: .showTerminal,
            object: nil
        )
        
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // Listen for tab changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTabChange),
            name: .tabDidChange,
            object: nil
        )
    }
    
    @objc private func handleTabChange(_ notification: Notification) {
        // Skip if app is inactive
        guard isAppActive else {
            logger.log(message: "Tab change ignored - app inactive", type: .debug)
            return
        }
        
        // Wait for tab change to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if !self.isPresentingTerminal {
                self.recoveryAttempts = 0
                self.attachToRootView()
            }
        }
    }
    
    private func attachToRootView() {
        // Skip if presenting terminal
        guard !isPresentingTerminal else {
            logger.log(message: "Skipping button attach - terminal is presenting", type: .debug)
            return
        }
        
        // Find top view controller
        guard let rootVC = UIApplication.shared.topMostViewController() else {
            logger.log(message: "No root view controller found", type: .error)
            return
        }
        
        // Check view controller state
        guard !rootVC.isBeingDismissed, !rootVC.isBeingPresented,
              rootVC.view.window != nil, rootVC.isViewLoaded
        else {
            logger.log(message: "View controller in invalid state for button attachment", type: .warning)
            
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.attachToRootView()
            }
            return
        }
        
        // Clean up existing button
        floatingButton.removeFromSuperview()
        
        // Store parent references
        parentViewController = rootVC
        parentView = rootVC.view
        
        // Set frame size
        floatingButton.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Add to view
        rootVC.view.addSubview(floatingButton)
        
        // Ensure correct position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak rootVC] in
            guard let self = self, let rootVC = rootVC else { return }
            
            // Adjust for safe area
            let safeArea = rootVC.view.safeAreaInsets
            let minX = 20 + safeArea.left
            let maxX = rootVC.view.bounds.width - 20 - safeArea.right
            let minY = 60 + safeArea.top
            let maxY = rootVC.view.bounds.height - 60 - safeArea.bottom
            
            // Adjust position if needed
            let currentCenter = self.floatingButton.center
            let xPos = min(max(currentCenter.x, minX), maxX)
            let yPos = min(max(currentCenter.y, minY), maxY)
            
            if xPos != currentCenter.x || yPos != currentCenter.y {
                UIView.animate(withDuration: 0.3) {
                    self.floatingButton.center = CGPoint(x: xPos, y: yPos)
                }
            }
            
            self.logger.log(message: "Terminal button positioned at \(self.floatingButton.center)", type: .debug)
        }
        
        // Mark setup complete
        isSetUp = true
        recoveryAttempts = 0
        
        logger.log(message: "Terminal button attached to root view", type: .info)
    }
    
    @objc private func handleOrientationChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonPosition()
        }
    }
    
    private func updateButtonPosition() {
        // Skip if button is hidden or app inactive
        guard !floatingButton.isHidden, isAppActive else { return }
        
        // Verify parent is valid
        guard let parentVC = parentViewController, parentVC.view.window != nil,
              !parentVC.isBeingDismissed, !parentVC.isBeingPresented
        else {
            // Try to recover
            if recoveryAttempts < maxRecoveryAttempts {
                recoveryAttempts += 1
                logger.log(message: "Trying to recover terminal button (attempt \(recoveryAttempts))", type: .warning)
                attachToRootView()
            }
            return
        }
        
        // Reset recovery counter
        recoveryAttempts = 0
        
        // Update position for current orientation
        let safeArea = parentVC.view.safeAreaInsets
        let maxX = parentVC.view.bounds.width - 80 - safeArea.right
        let maxY = parentVC.view.bounds.height - 160 - safeArea.bottom
        
        UIView.animate(withDuration: 0.3) {
            self.floatingButton.center = CGPoint(x: maxX, y: maxY)
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        isAppActive = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            if !self.isPresentingTerminal {
                self.show()
            }
        }
    }
    
    @objc private func handleAppWillResignActive() {
        isAppActive = false
        hide()
    }
    
    @objc private func updateButtonAppearance() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingButton.updateAppearance()
        }
    }
    
    /// Show the terminal button
    func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Don't show if presenting terminal
            if self.isPresentingTerminal {
                return
            }
            
            // Make button visible
            self.floatingButton.isHidden = false
            
            // Attach if needed
            if !self.isSetUp || self.parentView?.window == nil {
                self.attachToRootView()
            } else {
                self.updateButtonPosition()
            }
        }
    }
    
    /// Hide the terminal button
    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.floatingButton.isHidden = true
        }
    }
    
    @objc private func handleTerminalRequest() {
        // Ensure we're on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleTerminalRequest()
            }
            return
        }
        
        // Prevent multiple presentations
        if isPresentingTerminal {
            logger.log(message: "Already presenting terminal, ignoring request", type: .warning)
            return
        }
        
        // Set flag to prevent multiple presentations
        isPresentingTerminal = true
        
        // Haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        // Hide button
        hide()
        
        // Find top view controller
        guard let topVC = UIApplication.shared.topMostViewController() else {
            logger.log(message: "Could not find top view controller to present terminal", type: .error)
            isPresentingTerminal = false
            show() // Show button again
            return
        }
        
        // Check if view controller is in valid state
        if topVC.isBeingDismissed || topVC.isBeingPresented {
            logger.log(message: "View controller is in transition, delaying terminal presentation", type: .warning)
            
            // Delay and retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isPresentingTerminal = false
                self?.handleTerminalRequest()
            }
            return
        }
        
        // Present terminal
        let terminalVC = TerminalViewController()
        let navController = UINavigationController(rootViewController: terminalVC)
        
        // Add dismiss handler
        let dismissButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissTerminal))
        terminalVC.navigationItem.leftBarButtonItem = dismissButton
        
        // Present terminal
        topVC.present(navController, animated: true, completion: nil)
    }
    
    @objc private func dismissTerminal() {
        guard let presentingVC = UIApplication.shared.topMostViewController()?.presentingViewController else {
            isPresentingTerminal = false
            show()
            return
        }
        
        presentingVC.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.isPresentingTerminal = false
            self.show()
        }
    }
}
