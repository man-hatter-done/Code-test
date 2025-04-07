// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import CoreData
import UIKit

// MARK: - SystemMessageCell

class SystemMessageCell: UITableViewCell {
    // MARK: - Properties
    
    private let messageLabel = UILabel()
    private let containerView = UIView()
    private var animationImageView: UIImageView?
    
    private enum Constants {
        static let cellPadding: CGFloat = 3
        static let labelPadding: CGFloat = 12
        static let iconSize: CGFloat = 20
        static let iconSpacing: CGFloat = 4
        static let cornerRadius: CGFloat = 10
        static let fontSize: CGFloat = 14
        static let animationDuration: TimeInterval = 0.5
        static let animationScale: CGFloat = 1.2
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
        selectionStyle = .none
        backgroundColor = .clear
        
        configureContainerView()
        configureMessageLabel()
        setupConstraints()
    }
    
    private func configureContainerView() {
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
    }
    
    private func configureMessageLabel() {
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .systemGray
        messageLabel.font = .systemFont(ofSize: Constants.fontSize, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(messageLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view constraints
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.cellPadding),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Constants.cellPadding),
            
            // Message label constraints
            messageLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            messageLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: containerView.leadingAnchor,
                constant: Constants.labelPadding
            ),
            messageLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: containerView.trailingAnchor,
                constant: -Constants.labelPadding
            ),
            messageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Constants.cellPadding),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Constants.cellPadding)
        ])
    }
    
    // MARK: - Message Configuration
    
    func configure(with message: ChatMessage) {
        // Clear any existing animation
        clearAnimation()
        
        // Process the message content
        let content = message.content ?? ""
        
        // Handle different system message types with specialized styling
        if content.contains("error") || content.contains("failed") || content.contains("Error:") {
            configureErrorMessage(content)
        } else if content.contains("success") || content.contains("completed") {
            configureSuccessMessage(content)
        } else if content == "Assistant is thinking..." {
            configureThinkingMessage(content)
        } else {
            configureDefaultMessage(content)
        }
    }
    
    private func configureErrorMessage(_ content: String) {
        messageLabel.textColor = .systemRed
        messageLabel.text = content
        addIconAnimation(iconName: "exclamationmark.triangle.fill", tintColor: .systemRed)
    }
    
    private func configureSuccessMessage(_ content: String) {
        messageLabel.textColor = .systemGreen
        messageLabel.text = content
        addIconAnimation(iconName: "checkmark.circle.fill", tintColor: .systemGreen)
    }
    
    private func configureThinkingMessage(_ content: String) {
        messageLabel.textColor = .systemGray
        messageLabel.text = content
    }
    
    private func configureDefaultMessage(_ content: String) {
        messageLabel.textColor = .systemGray
        messageLabel.text = content
    }
    
    // MARK: - Animation
    
    private func addIconAnimation(iconName: String, tintColor: UIColor) {
        // Create an image view with SF Symbol
        let imageView = UIImageView()
        
        if let image = UIImage(systemName: iconName) {
            imageView.image = image
        } else {
            // Fallback if SF Symbol not available
            imageView.backgroundColor = tintColor
            imageView.layer.cornerRadius = Constants.cornerRadius
        }
        
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        animationImageView = imageView
        
        // Position icon next to the text
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(
                equalTo: messageLabel.trailingAnchor,
                constant: Constants.iconSpacing
            ),
            imageView.centerYAnchor.constraint(equalTo: messageLabel.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: Constants.iconSize),
            imageView.heightAnchor.constraint(equalToConstant: Constants.iconSize)
        ])
        
        // Add simple pulse animation
        UIView.animate(
            withDuration: Constants.animationDuration,
            delay: 0,
            options: [.autoreverse, .repeat],
            animations: {
                imageView.transform = CGAffineTransform(
                    scaleX: Constants.animationScale,
                    y: Constants.animationScale
                )
            }
        )
    }
    
    private func clearAnimation() {
        // Remove animation view if exists
        animationImageView?.layer.removeAllAnimations()
        animationImageView?.removeFromSuperview()
        animationImageView = nil
    }
    
    // MARK: - Cell Lifecycle
    
    override func prepareForReuse() {
        super.prepareForReuse()
        clearAnimation()
        messageLabel.textColor = .systemGray
    }
}
