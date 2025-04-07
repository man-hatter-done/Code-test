// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

// MARK: - UserMessageCell

class UserMessageCell: UITableViewCell {
    // MARK: - Properties
    
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    
    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static let fontSize: CGFloat = 16
        
        static let bubblePadding: CGFloat = 12
        static let bubbleTopBottomPadding: CGFloat = 6
        static let bubbleMaxWidth: CGFloat = 280
        
        static let messagePadding: CGFloat = 12
        static let messageTopBottomPadding: CGFloat = 8
        
        static let shadowOpacity: Float = 0.5
        static let shadowRadius: CGFloat = 4
        static let shadowOffset = CGSize(width: 0, height: 2)
        static let shadowAlpha: CGFloat = 0.2
    }
    
    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Configuration

    private func configureViews() {
        configureCellAppearance()
        configureBubbleView()
        configureMessageLabel()
        setupConstraints()
    }
    
    private func configureCellAppearance() {
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    private func configureBubbleView() {
        // Configure bubble shape
        bubbleView.layer.cornerRadius = Constants.cornerRadius
        bubbleView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMinYCorner
        ]
        
        // Add gradient background
        addGradientToBubble()
        
        // Add shadow for visual depth
        configureBubbleShadow()
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
    }
    
    private func configureBubbleShadow() {
        bubbleView.layer.shadowColor = UIColor.black.withAlphaComponent(Constants.shadowAlpha).cgColor
        bubbleView.layer.shadowOffset = Constants.shadowOffset
        bubbleView.layer.shadowRadius = Constants.shadowRadius
        bubbleView.layer.shadowOpacity = Constants.shadowOpacity
        bubbleView.layer.masksToBounds = false
    }
    
    private func configureMessageLabel() {
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: Constants.fontSize)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Bubble view constraints
            bubbleView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -Constants.bubblePadding
            ),
            bubbleView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: Constants.bubbleTopBottomPadding
            ),
            bubbleView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Constants.bubbleTopBottomPadding
            ),
            bubbleView.widthAnchor.constraint(
                lessThanOrEqualToConstant: Constants.bubbleMaxWidth
            ),
            
            // Message label constraints
            messageLabel.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: Constants.messagePadding
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -Constants.messagePadding
            ),
            messageLabel.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: Constants.messageTopBottomPadding
            ),
            messageLabel.bottomAnchor.constraint(
                equalTo: bubbleView.bottomAnchor,
                constant: -Constants.messageTopBottomPadding
            )
        ])
    }
    
    // MARK: - Gradient Configuration

    private func addGradientToBubble() {
        let gradientLayer = CAGradientLayer()
        
        // Configure gradient colors and direction
        gradientLayer.colors = [
            UIColor.systemBlue.cgColor,
            UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = Constants.cornerRadius
        
        // Set initial frame
        gradientLayer.frame = bubbleView.bounds
        
        // Add gradient to bubble view
        bubbleView.layer.insertSublayer(gradientLayer, at: 0)
        bubbleView.layer.layoutIfNeeded()
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update gradient frame when layout changes
        if let gradientLayer = bubbleView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = bubbleView.bounds
        }
    }
    
    // MARK: - Configuration

    func configure(with message: ChatMessage) {
        messageLabel.text = message.content
    }
}
