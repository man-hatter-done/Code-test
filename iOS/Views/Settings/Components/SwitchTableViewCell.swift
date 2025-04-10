// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit

/// A reusable table view cell with a modern, enhanced switch control
class SwitchTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    
    let switchControl = UISwitch()
    private let subtitleLabel = UILabel()
    
    // MARK: - Properties
    
    var switchValueChanged: ((Bool) -> Void)?
    var subtitle: String? {
        didSet {
            updateSubtitle()
        }
    }
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        
        setupSwitchControl()
        setupSubtitleLabel()
        configureAppearance()
        
        // Setup tap gesture for the entire cell
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    
    private func setupSwitchControl() {
        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        accessoryView = switchControl
        
        // Set the accent color to match app theme
        // Safely handle optional color from hex
        let defaultAccentColor = UIColor.systemPink
        let accentColor = UIColor(hex: "#FF6482") ?? defaultAccentColor
        switchControl.onTintColor = accentColor
    }
    
    private func setupSubtitleLabel() {
        subtitleLabel.font = UIFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: textLabel!.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: textLabel!.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -60),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
        
        // Hide initially
        subtitleLabel.isHidden = true
    }
    
    private func configureAppearance() {
        // Modern styling for the cell
        selectionStyle = .none
        
        // Enhance text label appearance
        textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        // Add subtle divider line with inset
        separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        
        // Prepare haptic feedback
        feedbackGenerator.prepare()
    }
    
    private func updateSubtitle() {
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil || subtitle!.isEmpty
        
        // Adjust cell height constraints if needed
        if !subtitleLabel.isHidden {
            // Make sure the cell can expand to fit the subtitle
            contentView.constraints.forEach { constraint in
                if constraint.firstAttribute == .height {
                    constraint.isActive = false
                }
            }
        }
    }
    
    // MARK: - Action Handlers
    
    @objc private func switchChanged() {
        // Provide haptic feedback
        feedbackGenerator.impactOccurred()
        
        // Call the callback
        switchValueChanged?(switchControl.isOn)
    }
    
    @objc private func cellTapped() {
        // Toggle switch when cell is tapped
        switchControl.setOn(!switchControl.isOn, animated: true)
        switchChanged()
        
        // Add visual feedback when tapped
        UIView.animate(withDuration: 0.1, animations: {
            self.contentView.alpha = 0.7
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.contentView.alpha = 1.0
            }
        }
    }
    
    // MARK: - Lifecycle Methods
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update appearance for theme changes
            switchControl.onTintColor = UIColor(hex: "#FF6482") ?? .systemPink
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        let alphaValue: CGFloat = highlighted ? 0.9 : 1.0
        
        if animated {
            UIView.animate(withDuration: 0.1) {
                self.contentView.alpha = alphaValue
            }
        } else {
            contentView.alpha = alphaValue
        }
    }
}
