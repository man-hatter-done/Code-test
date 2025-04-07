//
//  CommandInputView.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

class CommandInputView: UITextField {
    private let padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
    }
    
    private func setupTextField() {
        backgroundColor = UIColor(named: "SettingsCell") ?? UIColor.darkGray
        textColor = UIColor.label
        tintColor = UIColor.systemBlue // Cursor color
        font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        layer.borderColor = UIColor.gray.cgColor
        layer.borderWidth = 1.0
        returnKeyType = .send
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartQuotesType = .no
        keyboardType = .asciiCapable
        keyboardAppearance = .default
        adjustsFontForContentSizeCategory = true
        
        // Add a clear button when editing
        clearButtonMode = .whileEditing
        
        // Add shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 1
        
        // Accessibility
        accessibilityLabel = "Command Input"
        accessibilityHint = "Enter terminal commands here"
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        let originalRect = super.clearButtonRect(forBounds: bounds)
        return originalRect.offsetBy(dx: -padding.right / 2, dy: 0)
    }
    
    // Handle dark/light mode changes
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            layer.borderColor = UIColor.gray.cgColor
        }
    }
}
