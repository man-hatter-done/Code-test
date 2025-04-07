//
//  TerminalTextView.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

class TerminalTextView: UITextView {
    // Terminal color theme
    struct TerminalTheme {
        let background: UIColor
        let text: UIColor
        let userInput: UIColor
        let systemOutput: UIColor
        let errorOutput: UIColor
    }
    
    // Default dark theme
    private var darkTheme = TerminalTheme(
        background: UIColor.black,
        text: UIColor.green,
        userInput: UIColor.cyan,
        systemOutput: UIColor.green,
        errorOutput: UIColor.red
    )
    
    // Light theme
    private var lightTheme = TerminalTheme(
        background: UIColor(white: 0.1, alpha: 1.0),
        text: UIColor.green,
        userInput: UIColor.systemBlue,
        systemOutput: UIColor.green,
        errorOutput: UIColor.systemRed
    )
    
    // Current theme based on user interface style
    private var currentTheme: TerminalTheme {
        return traitCollection.userInterfaceStyle == .dark ? darkTheme : lightTheme
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        // Apply theme
        updateTheme()
        
        // Configure text view properties
        font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        isEditable = false
        isSelectable = true
        autocorrectionType = .no
        autocapitalizationType = .none
        showsVerticalScrollIndicator = true
        
        // Add padding
        textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Enable text selection with custom menu
        setupCustomMenu()
        
        // Improve scrolling performance
        isScrollEnabled = true
        showsHorizontalScrollIndicator = false
        alwaysBounceVertical = true
        scrollsToTop = false
        
        // Accessibility
        accessibilityLabel = "Terminal Output"
        accessibilityHint = "Displays terminal command output"
        adjustsFontForContentSizeCategory = true
        
        // Notification for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userInterfaceStyleDidChange),
            name: .didChangeUserInterfaceStyle,
            object: nil
        )
    }
    
    private func setupCustomMenu() {
        let menuController = UIMenuController.shared
        menuController.menuItems = [
            UIMenuItem(title: "Copy", action: #selector(copy(_:))),
            UIMenuItem(title: "Select All", action: #selector(selectAll(_:)))
        ]
    }
    
    private func updateTheme() {
        backgroundColor = currentTheme.background
        textColor = currentTheme.text
    }
    
    @objc private func userInterfaceStyleDidChange() {
        updateTheme()
    }
    
    // Custom handling for text selection
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) || action == #selector(selectAll(_:)) {
            return true
        }
        return false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Create notification for interface style changes
extension NSNotification.Name {
    static let didChangeUserInterfaceStyle = NSNotification.Name("didChangeUserInterfaceStyle")
}
