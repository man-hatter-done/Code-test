// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Foundation
import UIKit

class PopupViewController: UIViewController {
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupStackView()
    }

    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
        ])
    }

    func configureButtons(_ buttons: [UIButton]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for button in buttons {
            stackView.addArrangedSubview(button)
        }
    }
}

class PopupViewControllerButton: UIButton {
    // MARK: - Properties
    
    var onTap: (() -> Void)?
    private var originalBackgroundColor: UIColor?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let gradientLayer = CAGradientLayer()
    
    // MARK: - Initialization
    
    init(title: String, color: UIColor, titleColor: UIColor? = .white) {
        super.init(frame: .zero)
        setupButton(title: title, color: color, titlecolor: titleColor!)
        addButtonTargets()
        
        // Prepare haptic feedback
        feedbackGenerator.prepare()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton(title: String.localized("DEFAULT"), color: .systemBlue, titlecolor: .white)
        addButtonTargets()
        
        // Prepare haptic feedback
        feedbackGenerator.prepare()
    }
    
    // MARK: - Setup Methods
    
    private func addButtonTargets() {
        addTarget(self, action: #selector(handleButtonPressEvent), for: .touchDown)
        addTarget(self, action: #selector(handleButtonReleaseEvent), for: .touchUpInside)
        addTarget(self, action: #selector(handleButtonReleaseEvent), for: .touchUpOutside)
        addTarget(self, action: #selector(buttonCancelled), for: .touchCancel)
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    private func setupButton(title: String, color: UIColor, titlecolor: UIColor) {
        // Store original color
        originalBackgroundColor = color
        
        // Basic appearance
        setTitle(title, for: .normal)
        setTitleColor(titlecolor, for: .normal)
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        
        // Modern shape with continuous corners
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        
        // Add subtle shadow
        layer.shadowColor = color.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.2
        
        // Special styling for accent actions (pink colored buttons)
        if color == UIColor(hex: "#FF6482") || 
           colorIsCloseToAccent(color) ||
           color == .tintColor {
            // For primary actions, use custom gradient
            setupGradient(withBaseColor: UIColor(hex: "#FF6482") ?? color)
            layer.borderWidth = 0
        } else if color.isLight() {
            // For light colored buttons (secondary actions)
            backgroundColor = color
            layer.borderWidth = 0.5
            layer.borderColor = color.darker(by: 15).cgColor
        } else {
            // For other buttons
            backgroundColor = color
        }
        
        // Button content insets
        if #available(iOS 15.0, *) {
            var config = configuration ?? UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            configuration = config
        } else {
            contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        }
        
        // Add appropriate LED effects based on button type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if color == UIColor(hex: "#FF6482") || 
               self.colorIsCloseToAccent(color) ||
               color == .tintColor {
                // Primary action buttons get a flowing LED border effect
                self.addFlowingLEDEffect(
                    color: color,
                    intensity: 0.6,
                    width: 2.5,
                    speed: 4.0
                )
            } else if color.isLight() {
                // Light secondary buttons get a subtle glow
                self.addLEDEffect(
                    color: color.darker(by: 5),
                    intensity: 0.4,
                    spread: 8,
                    animated: true,
                    animationDuration: 3.0
                )
            } else {
                // Dark buttons get a subtle pulsing glow
                self.addLEDEffect(
                    color: color.lighter(by: 30),
                    intensity: 0.3,
                    spread: 10,
                    animated: true,
                    animationDuration: 2.5
                )
            }
        }
    }
    
    private func setupGradient(withBaseColor color: UIColor) {
        // Create a subtle gradient variation of the base color
        let topColor = color.lighter(by: 10).cgColor
        let bottomColor = color.darker(by: 10).cgColor
        
        gradientLayer.colors = [topColor, bottomColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.frame = bounds
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func colorIsCloseToAccent(_ color: UIColor) -> Bool {
        // Check if the color is similar to our accent color
        let accentColor = UIColor(hex: "#FF6482") ?? .systemPink
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        accentColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        // Calculate color distance (simple Euclidean distance)
        let distance = sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2))
        return distance < 0.3 // Threshold for considering colors "close"
    }
    
    // MARK: - Action Methods
    
    @objc public func handleButtonPressEvent() {
        // Visual feedback
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.layer.shadowOpacity = 0.1
            
            if self.gradientLayer.superlayer != nil {
                // For gradient buttons, adjust colors
                let adjustedColors = self.gradientLayer.colors?.map { color in
                    if let cgColor = color as? CGColor {
                        return UIColor(cgColor: cgColor).withAlphaComponent(0.8).cgColor
                    }
                    return color
                }
                self.gradientLayer.colors = adjustedColors
            } else {
                // For solid color buttons
                self.alpha = 0.8
            }
        })
    }

    @objc public func handleButtonReleaseEvent() {
        // Visual feedback
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.transform = .identity
            self.layer.shadowOpacity = 0.2
            
            if self.gradientLayer.superlayer != nil {
                // Restore original gradient colors
                let adjustedColors = [
                    (self.originalBackgroundColor?.lighter(by: 10) ?? .white).cgColor,
                    (self.originalBackgroundColor?.darker(by: 10) ?? .gray).cgColor
                ]
                self.gradientLayer.colors = adjustedColors
            } else {
                // Restore solid color
                self.alpha = 1.0
            }
        })
    }

    @objc private func buttonCancelled() {
        // Reset button state without animation
        transform = .identity
        layer.shadowOpacity = 0.2
        alpha = 1.0
        
        if gradientLayer.superlayer != nil {
            let adjustedColors = [
                (originalBackgroundColor?.lighter(by: 10) ?? .white).cgColor,
                (originalBackgroundColor?.darker(by: 10) ?? .gray).cgColor
            ]
            gradientLayer.colors = adjustedColors
        }
    }

    @objc private func buttonTapped() {
        // Provide haptic feedback
        feedbackGenerator.impactOccurred()
        
        // Call the callback
        onTap?()
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

// Helper color extensions
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
    
    func isLight() -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate relative luminance
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.5
    }
}
