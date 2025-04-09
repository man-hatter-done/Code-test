// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit

class CertificateViewTableViewCell: UITableViewCell {
    var certs: Certificate?

    private let teamNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let expirationDateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let pillsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.distribution = .fillProportionally
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let roundedBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemGroupedBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "checkmark"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    private let certImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "certificate"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.addSubview(roundedBackgroundView)
        roundedBackgroundView.addSubview(teamNameLabel)
        roundedBackgroundView.addSubview(expirationDateLabel)
        roundedBackgroundView.addSubview(pillsStackView)
        contentView.addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            roundedBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            roundedBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            roundedBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            roundedBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            teamNameLabel.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor, constant: 15),
            teamNameLabel.topAnchor.constraint(equalTo: roundedBackgroundView.topAnchor, constant: 10),
            teamNameLabel.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor, constant: -45),

            expirationDateLabel.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor, constant: 15),
            expirationDateLabel.topAnchor.constraint(equalTo: teamNameLabel.bottomAnchor, constant: 5),
            expirationDateLabel.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor, constant: -15),

            pillsStackView.leadingAnchor.constraint(equalTo: roundedBackgroundView.leadingAnchor, constant: 15),
            pillsStackView.topAnchor.constraint(equalTo: expirationDateLabel.bottomAnchor, constant: 10),
            pillsStackView.trailingAnchor.constraint(equalTo: roundedBackgroundView.trailingAnchor, constant: -15),
            pillsStackView.bottomAnchor.constraint(equalTo: roundedBackgroundView.bottomAnchor, constant: -10),

            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            checkmarkImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with certificate: Certificate, isSelected: Bool) {
        if !Preferences.certificateTitleAppIDtoTeamID {
            teamNameLabel.text = certificate.certData?.name
        } else {
            teamNameLabel.text = certificate.certData?.teamName
        }

        expirationDateLabel.text = certificate.certData?.appIDName
        certs = certificate

        pillsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let expirationDate = certificate.certData?.expirationDate {
            let currentDate = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: currentDate, to: expirationDate)

            let daysLeft = components.day ?? 0
            let expirationText = daysLeft < 0 ? String.localized("CERTIFICATES_VIEW_CONTROLLER_CELL_EXPIRED") : String.localized("CERTIFICATES_VIEW_CONTROLLER_CELL_DAYS_LEFT", arguments: "\(daysLeft)")

            let p1 = PillView(text: expirationText, backgroundColor: daysLeft < 0 ? .systemRed : .systemGray, iconName: daysLeft < 0 ? "xmark" : "timer")
            pillsStackView.addArrangedSubview(p1)
        }

        if certificate.certData?.pPQCheck == true {
            let p2 = PillView(text: "PPQCheck", backgroundColor: .systemRed, iconName: "checkmark")
            pillsStackView.addArrangedSubview(p2)
        }

        checkmarkImageView.isHidden = !isSelected
    }
}

class CertificateViewAddTableViewCell: UITableViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 19)
        label.textColor = .tintColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .gray
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let roundedBackgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 10
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        view.backgroundColor = UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.7)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let borderLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemGray.withAlphaComponent(0.4).cgColor
        layer.lineWidth = 1
        layer.fillColor = UIColor.clear.cgColor
        layer.lineDashPattern = [7, 7]
        return layer
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        contentView.addSubview(roundedBackgroundView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(iconImageView)

        roundedBackgroundView.layer.addSublayer(borderLayer)

        let padding: CGFloat = 16

        NSLayoutConstraint.activate([
            roundedBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            roundedBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            roundedBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            roundedBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconImageView.centerXAnchor.constraint(equalTo: roundedBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: roundedBackgroundView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.centerXAnchor.constraint(equalTo: roundedBackgroundView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: roundedBackgroundView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: roundedBackgroundView.leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: roundedBackgroundView.trailingAnchor, constant: -padding),

            descriptionLabel.centerXAnchor.constraint(equalTo: roundedBackgroundView.centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.bottomAnchor.constraint(equalTo: roundedBackgroundView.bottomAnchor, constant: -30),
            descriptionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: roundedBackgroundView.leadingAnchor, constant: padding),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: roundedBackgroundView.trailingAnchor, constant: -padding),
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        borderLayer.strokeColor = UIColor.systemGray.withAlphaComponent(0.2).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        borderLayer.frame = roundedBackgroundView.bounds
        let borderPath = UIBezierPath(roundedRect: roundedBackgroundView.bounds.insetBy(dx: borderLayer.lineWidth / 2, dy: borderLayer.lineWidth / 2), cornerRadius: roundedBackgroundView.layer.cornerRadius)
        borderLayer.path = borderPath.cgPath
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with title: String?, description: String?) {
        titleLabel.text = title
        descriptionLabel.text = description
    }

    func configure(with symbolName: String?) {
        iconImageView.image = UIImage(systemName: symbolName ?? "plus")
    }
}

class PillView: UIView {
    // MARK: - UI Components
    
    private let pillStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Properties
    
    private let padding: UIEdgeInsets
    private let gradientLayer = CAGradientLayer()
    private let accentColor: UIColor // Store the color for theme changes
    
    // MARK: - Initialization

    init(text: String, backgroundColor: UIColor, iconName: String? = nil, padding: UIEdgeInsets = .init(top: 6, left: 10, bottom: 6, right: 10)) {
        self.padding = padding
        self.accentColor = backgroundColor
        super.init(frame: .zero)
        
        // Set up visual appearance
        layer.cornerRadius = 13
        layer.cornerCurve = .continuous
        clipsToBounds = true
        
        // Add subtle border
        layer.borderWidth = 0.5
        layer.borderColor = backgroundColor.withAlphaComponent(0.3).cgColor
        
        // Set up gradient background
        setupGradientBackground(with: backgroundColor)
        
        // Add stack view for better layout
        addSubview(pillStackView)
        
        // Configure icon if provided
        if let iconName = iconName {
            configureIcon(iconName: iconName, tintColor: backgroundColor)
            pillStackView.addArrangedSubview(iconImageView)
        }
        
        // Configure label
        configureLabel(text: text, textColor: backgroundColor)
        pillStackView.addArrangedSubview(label)
        
        // Set up constraints
        setupConstraints()
        
        // Add subtle animation on appearance
        addAppearanceAnimation()
    }
    
    private func setupGradientBackground(with color: UIColor) {
        gradientLayer.colors = [
            color.withAlphaComponent(0.15).cgColor,
            color.withAlphaComponent(0.08).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func configureIcon(iconName: String, tintColor: UIColor) {
        // Use symbol configuration for better rendering
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        iconImageView.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        iconImageView.tintColor = tintColor
        
        // Set size constraints
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 14),
            iconImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    private func configureLabel(text: String, textColor: UIColor) {
        label.text = text
        label.textColor = textColor
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            pillStackView.topAnchor.constraint(equalTo: topAnchor, constant: padding.top),
            pillStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding.bottom),
            pillStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding.left),
            pillStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding.right)
        ])
    }
    
    private func addAppearanceAnimation() {
        // Start slightly scaled down and transparent
        transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        alpha = 0.8
        
        // Animate to full size with slight bounce
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: [], animations: {
            self.transform = .identity
            self.alpha = 1.0
        })
    }
    
    // MARK: - Lifecycle
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update border and gradient for new appearance
            layer.borderColor = accentColor.withAlphaComponent(0.3).cgColor
            setupGradientBackground(with: accentColor)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
