// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

// MARK: - AIMessageCell

class AIMessageCell: UITableViewCell {
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
        bubbleView.backgroundColor = .systemGray5
        bubbleView.layer.cornerRadius = Constants.cornerRadius
        bubbleView.layer.maskedCorners = [
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner,
            .layerMinXMaxYCorner
        ]
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
    }

    private func configureMessageLabel() {
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .label
        messageLabel.font = .systemFont(ofSize: Constants.fontSize)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Bubble view constraints
            bubbleView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: Constants.bubblePadding
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
    
    // MARK: - Configuration
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.content
    }
}
