// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

class ActivityIndicatorViewCell: UITableViewCell {
    let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(activityIndicator)
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentView.addSubview(activityIndicator)
        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
        ])
    }
}

class ActivityIndicatorButton: UIButton {
    // MARK: - UI Components
    
    private let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()
    
    private let gradientLayer = CAGradientLayer()
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Properties
    
    private var normalBackgroundColor: UIColor {
        return UIColor(hex: "#FF6482") ?? Preferences.appTintColor.uiColor
    }
    
    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
        addPressAnimation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
        addPressAnimation()
    }

    // MARK: - Setup Methods
    
    private func setupButton() {
        // Text styling
        setTitle(String.localized("APP_SIGNING_VIEW_CONTROLLER_START_SIGNING"), for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        setTitleColor(.white, for: .normal)
        frame.size = CGSize(width: 100, height: 54)
        
        // Shape styling
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        
        // Add subtle gradient
        setupGradient()
        
        // Shadow effects
        layer.masksToBounds = false
        layer.shadowColor = normalBackgroundColor.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
        
        // Prepare feedback generator
        feedbackGenerator.prepare()
        
        // Enable button
        isEnabled = true
    }
    
    private func setupGradient() {
        // Create gradient colors from our accent color
        let topColor = normalBackgroundColor.lighter(by: 5).cgColor
        let bottomColor = normalBackgroundColor.darker(by: 10).cgColor
        
        gradientLayer.colors = [topColor, bottomColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.cornerRadius = layer.cornerRadius
        gradientLayer.frame = bounds
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func addPressAnimation() {
        // Add touch animations for better feedback
        addTarget(self, action: #selector(buttonPressed), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(buttonReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }
    
    // MARK: - Action Methods
    
    @objc private func buttonPressed() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.layer.shadowOpacity = 0.2
        })
    }
    
    @objc private func buttonReleased() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform.identity
            self.layer.shadowOpacity = 0.4
        })
        
        // Provide haptic feedback
        feedbackGenerator.impactOccurred()
    }
    
    // MARK: - Public Methods
    
    func showLoadingIndicator() {
        // Add activity indicator
        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Provide feedback before disabling
        feedbackGenerator.impactOccurred()

        // Animate transition to loading state
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
            // Fade out text
            self.titleLabel?.alpha = 0
            
            // Scale button slightly to indicate state change
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            
            // Adjust gradient colors to appear disabled
            if let colors = self.gradientLayer.colors as? [CGColor] {
                let dimmedColors = colors.map { cgColor -> CGColor in
                    let color = UIColor(cgColor: cgColor).withAlphaComponent(0.7)
                    return color.cgColor
                }
                self.gradientLayer.colors = dimmedColors
            }
            
            // Reduce shadow
            self.layer.shadowOpacity = 0.2
        }, completion: { _ in
            // Start activity indicator
            self.activityIndicator.startAnimating()
            
            // Update button state
            self.isEnabled = false
            self.setTitle("", for: .normal)
        })
    }
    
    // MARK: - Lifecycle Methods
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update shadow color for appearance changes
            layer.shadowColor = normalBackgroundColor.cgColor
        }
    }
}

// Helper extension for color adjustments
extension UIColor {
    func lighter(by percentage: CGFloat) -> UIColor {
        return self.adjust(by: abs(percentage))
    }
    
    func darker(by percentage: CGFloat) -> UIColor {
        return self.adjust(by: -abs(percentage))
    }
    
    private func adjust(by percentage: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let adjustAmount = percentage / 100
        
        return UIColor(
            red: max(min(red + adjustAmount, 1.0), 0.0),
            green: max(min(green + adjustAmount, 1.0), 0.0),
            blue: max(min(blue + adjustAmount, 1.0), 0.0),
            alpha: alpha
        )
    }
}
