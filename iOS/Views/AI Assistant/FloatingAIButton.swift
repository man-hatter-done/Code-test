// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

// MARK: - FloatingAIButton

/// Floating button with custom AI assistant functionality
final class FloatingAIButton: UIView {
    // MARK: - UI Components

    private let aiButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 30
        
        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: 24,
            weight: .medium
        )
        let image = UIImage(
            systemName: "bubble.left.and.bubble.right.fill",
            withConfiguration: symbolConfig
        )
        
        btn.setImage(image, for: .normal)
        btn.tintColor = .white
        btn.accessibilityLabel = "AI Assistant"

        return btn
    }()

    // MARK: - Properties

    private var initialPoint: CGPoint = .zero
    private var lastStoredPosition: CGPoint?
    private let positionStorageKey = "AIButtonPosition"
    private let buttonSize: CGFloat = 60
    private let buttonRadius: CGFloat = 30
    private let shadowRadius: CGFloat = 6
    private let defaultMargin: CGFloat = 20

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureGradientBackground()
        restoreSavedPosition()
        beginPulseEffect()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Configuration

    private func configureView() {
        // Add and configure the button
        addSubview(aiButton)
        aiButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            aiButton.topAnchor.constraint(equalTo: topAnchor),
            aiButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            aiButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            aiButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Set frame size
        frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)

        configureShadow()
        configureGestures()
    }
    
    private func configureShadow() {
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = shadowRadius
    }
    
    private func configureGestures() {
        // Add gestures
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)

        // Add tap target
        aiButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    private func configureGradientBackground() {
        // Create a gradient background that matches app theme
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)

        // Use app tint color for gradient
        let tintColor = Preferences.appTintColor.uiColor
        let lighterTint = tintColor.adjustBrightness(by: 0.2)

        gradient.colors = [tintColor.cgColor, lighterTint.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = buttonRadius
        aiButton.layer.insertSublayer(gradient, at: 0)
    }

    private func beginPulseEffect() {
        // Create a subtle pulse animation
        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.duration = 0.8
        pulse.fromValue = 1.0
        pulse.toValue = 1.08
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.initialVelocity = 0.5
        pulse.damping = 1.0
        layer.add(pulse, forKey: "pulse")
    }

    // MARK: - Position Management

    private func restoreSavedPosition() {
        guard let position = retrievePosition(),
              let superview = superview,
              position.x > 0,
              position.y > 0 else {
            return
        }
        
        center = position
        adjustPositionToSafeBounds(in: superview)
        
        Debug.shared.log(message: "Restored button position to: \(center)", type: .debug)
    }
    
    private func adjustPositionToSafeBounds(in view: UIView) {
        let safeArea = view.safeAreaInsets
        let minX = defaultMargin + safeArea.left + frame.width / 2
        let maxX = view.bounds.width - defaultMargin - safeArea.right - frame.width / 2
        let minY = defaultMargin + safeArea.top + frame.height / 2
        let maxY = view.bounds.height - defaultMargin - safeArea.bottom - frame.height / 2

        center.x = min(max(center.x, minX), maxX)
        center.y = min(max(center.y, minY), maxY)
    }

    private func persistPosition() {
        guard let positionData = try? JSONEncoder().encode(center) else { return }
        
        UserDefaults.standard.set(positionData, forKey: positionStorageKey)
        UserDefaults.standard.synchronize() // Ensure the position is saved immediately
        lastStoredPosition = center
        
        Debug.shared.log(message: "Saved button position: \(center)", type: .debug)
    }

    private func retrievePosition() -> CGPoint? {
        if let positionData = UserDefaults.standard.data(forKey: positionStorageKey),
           let position = try? JSONDecoder().decode(CGPoint.self, from: positionData) {
            return position
        }
        return lastStoredPosition
    }

    // Make this method public so FloatingButtonManager can access it
    func getSavedPosition() -> CGPoint? {
        return retrievePosition()
    }

    // Apply saved position whenever the button is added to a view
    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        if superview != nil {
            DispatchQueue.main.async { [weak self] in
                self?.restoreSavedPosition()
            }
        }
    }

    // MARK: - Gesture Handling

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            initialPoint = center
            // Stop pulse animation during drag
            layer.removeAnimation(forKey: "pulse")

        case .changed:
            center = CGPoint(
                x: initialPoint.x + translation.x,
                y: initialPoint.y + translation.y
            )
            keepWithinBounds(superview: superview)

        case .ended, .cancelled:
            snapToEdge(superview: superview)
            // Save position after snap
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.persistPosition()
            }
            // Restart pulse animation
            beginPulseEffect()

        default:
            break
        }
    }

    private func keepWithinBounds(superview: UIView) {
        let halfWidth = frame.width / 2
        let halfHeight = frame.height / 2
        let margin = defaultMargin
        
        // Calculate safe boundaries
        let minX = margin + halfWidth
        let maxX = superview.bounds.width - margin - halfWidth
        let minY = margin + halfHeight
        let maxY = superview.bounds.height - margin - halfHeight
        
        // Restrict position to safe boundaries
        center.x = max(minX, min(center.x, maxX))
        center.y = max(minY, min(center.y, maxY))
    }

    private func snapToEdge(superview: UIView) {
        let margin = defaultMargin
        let halfWidth = frame.width / 2
        let screenCenter = superview.bounds.width / 2
        
        // Determine which edge to snap to
        let newX = center.x < screenCenter ? 
                   margin + halfWidth : 
                   superview.bounds.width - margin - halfWidth

        // Animate to edge with spring effect
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5
        ) {
            self.center = CGPoint(x: newX, y: self.center.y)
            self.keepWithinBounds(superview: superview)
        }
    }

    // MARK: - Actions

    @objc private func buttonTapped() {
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Notify that the AI assistant button was tapped
        NotificationCenter.default.post(name: .showAIAssistant, object: nil)
    }

    // MARK: - Public Methods

    /// Update the visual appearance of the button when app theme changes
    func updateAppearance() {
        // Remove existing gradient
        aiButton.layer.sublayers?.first { $0 is CAGradientLayer }?.removeFromSuperlayer()

        // Re-apply gradient with new app theme color
        configureGradientBackground()
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// Adjust color brightness
    func adjustBrightness(by factor: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(
                hue: hue,
                saturation: saturation,
                brightness: min(brightness + factor, 1.0),
                alpha: alpha
            )
        }
        return self
    }
}

// Note: showAIAssistant notification name is declared elsewhere
// This section is intentionally empty to avoid duplicate declarations

// MARK: - CGPoint+Codable

extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}
