// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly
// permitted under the terms of the Proprietary Software License.

import UIKit

/// Constants used by section header components
private enum SectionHeaderConstants {
    /// Font sizes
    enum FontSizes {
        /// Title font size
        static let titleSize: CGFloat = 19
        /// Subtitle font size
        static let subtitleSize: CGFloat = 15
        /// Button font size
        static let buttonSize: CGFloat = 14
    }
    /// Spacing and margin constants
    enum Spacing {
        /// Default top margin
        static let defaultTopMargin: CGFloat = 7
        /// Content inset
        static let contentInset: CGFloat = 10
        /// Leading padding
        static let leadingPadding: CGFloat = 19
        /// Trailing padding
        static let trailingPadding: CGFloat = 17
        /// Small spacing
        static let smallSpacing: CGFloat = 2
        /// Medium spacing
        static let mediumSpacing: CGFloat = 5
        /// Large spacing
        static let largeSpacing: CGFloat = 8
    }
    /// View dimensions
    enum Dimensions {
        /// Button corner radius
        static let buttonCornerRadius: CGFloat = 13
        /// Image view corner radius
        static let imageCornerRadius: CGFloat = 5
        /// Icon dimension
        static let iconSize: CGFloat = 24
    }
    /// Appearance settings
    enum Appearance {
        /// Border color for image views
        static let borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        /// Border width
        static let borderWidth: CGFloat = 1
    }
}

/// A section header view with inset grouped appearance
class InsetGroupedSectionHeader: UIView {
    /// The label displaying the section title
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: SectionHeaderConstants.FontSizes.titleSize, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// The spacing between the top of the view and the title
    private let topAnchorConstant: CGFloat

    /// Creates a new section header with the specified title and top spacing
    /// - Parameters:
    ///   - title: The title text to display
    ///   - topAnchorConstant: The spacing between the top of the view and the title
    init(title: String, topAnchorConstant: CGFloat = SectionHeaderConstants.Spacing.defaultTopMargin) {
        self.topAnchorConstant = topAnchorConstant
        super.init(frame: .zero)
        setupUI()
        self.title = title
    }

    /// Required initializer that is not supported
    /// - Parameter coder: The NSCoder instance
    required init?(coder: NSCoder) {
        // Support storyboard initialization
        self.topAnchorConstant = SectionHeaderConstants.Spacing.defaultTopMargin
        super.init(coder: coder)
        setupUI()
    }

    /// The title text displayed in the header
    var title: String {
        get { return titleLabel.text ?? "" }
        set { titleLabel.text = newValue }
    }
    
    /// Sets up the UI components and constraints
    private func setupUI() {
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor, 
                constant: SectionHeaderConstants.Spacing.smallSpacing
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor, 
                constant: -SectionHeaderConstants.Spacing.mediumSpacing
            ),
            titleLabel.topAnchor.constraint(
                equalTo: topAnchor,
                constant: topAnchorConstant
            ),
            // Ensure the label is properly constrained to the bottom for proper sizing
            titleLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -SectionHeaderConstants.Spacing.smallSpacing
            )
        ])
    }
    
    /// Returns the intrinsic content size for this view
    override var intrinsicContentSize: CGSize {
        let titleHeight = titleLabel.intrinsicContentSize.height
        let totalHeight = titleHeight + topAnchorConstant + SectionHeaderConstants.Spacing.smallSpacing
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
}

/// A section header view for search results with an icon and title
class SearchAppSectionHeader: UIView {
    /// The label displaying the section title
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: SectionHeaderConstants.FontSizes.titleSize, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// The image view displaying the section icon
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = SectionHeaderConstants.Dimensions.imageCornerRadius
        imageView.layer.borderWidth = SectionHeaderConstants.Appearance.borderWidth
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderColor = SectionHeaderConstants.Appearance.borderColor
        imageView.clipsToBounds = true
        return imageView
    }()

    /// The spacing between the top of the view and the title
    private let topAnchorConstant: CGFloat

    /// Creates a new search app section header with the specified title, icon, and top spacing
    /// - Parameters:
    ///   - title: The title text to display
    ///   - icon: The optional icon image to display
    ///   - topAnchorConstant: The spacing between the top of the view and the title
    init(title: String, icon: UIImage?, topAnchorConstant: CGFloat = SectionHeaderConstants.Spacing.defaultTopMargin) {
        self.topAnchorConstant = topAnchorConstant
        super.init(frame: .zero)
        setupUI()
        self.title = title
        self.iconImageView.image = icon
    }

    /// Required initializer for interface builder/storyboard support
    /// - Parameter coder: The NSCoder instance
    required init?(coder: NSCoder) {
        self.topAnchorConstant = SectionHeaderConstants.Spacing.defaultTopMargin
        super.init(coder: coder)
        setupUI()
    }

    /// The title text displayed in the header
    var title: String {
        get { return titleLabel.text ?? "" }
        set { titleLabel.text = newValue }
    }

    /// Sets the icon image for the header
    /// - Parameter image: The image to use as the icon
    func setIcon(with image: UIImage?) {
        iconImageView.image = image
    }

    /// Sets up the UI components and constraints
    private func setupUI() {
        addSubview(iconImageView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            // Icon constraints
            iconImageView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: SectionHeaderConstants.Spacing.largeSpacing
            ),
            iconImageView.centerYAnchor.constraint(
                equalTo: centerYAnchor
            ),
            iconImageView.widthAnchor.constraint(
                equalToConstant: SectionHeaderConstants.Dimensions.iconSize
            ),
            iconImageView.heightAnchor.constraint(
                equalToConstant: SectionHeaderConstants.Dimensions.iconSize
            ),

            // Title constraints
            titleLabel.leadingAnchor.constraint(
                equalTo: iconImageView.trailingAnchor,
                constant: SectionHeaderConstants.Spacing.largeSpacing
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -SectionHeaderConstants.Spacing.mediumSpacing
            ),
            titleLabel.topAnchor.constraint(
                equalTo: topAnchor,
                constant: topAnchorConstant
            ),
            titleLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -topAnchorConstant
            )
        ])
    }
    
    /// Returns the intrinsic content size for this view
    override var intrinsicContentSize: CGSize {
        let titleHeight = titleLabel.intrinsicContentSize.height
        let totalHeight = max(titleHeight, SectionHeaderConstants.Dimensions.iconSize) + (topAnchorConstant * 2)
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
}

/// A section header view with a title, optional subtitle, and optional action button
class GroupedSectionHeader: UIView {
    /// The label displaying the section title
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: SectionHeaderConstants.FontSizes.titleSize, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// The label displaying the section subtitle
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: SectionHeaderConstants.FontSizes.subtitleSize, weight: .regular)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// The button for the section header action
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .boldSystemFont(ofSize: SectionHeaderConstants.FontSizes.buttonSize)
        button.setTitleColor(.tintColor, for: .normal)
        button.backgroundColor = .quaternarySystemFill
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = SectionHeaderConstants.Dimensions.buttonCornerRadius

        // Set content insets to add padding around the title
        if #available(iOS 15.0, *) {
            var config = button.configuration ?? UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(
                top: SectionHeaderConstants.Spacing.mediumSpacing,
                leading: SectionHeaderConstants.Spacing.contentInset,
                bottom: SectionHeaderConstants.Spacing.mediumSpacing,
                trailing: SectionHeaderConstants.Spacing.contentInset
            )
            button.configuration = config
        } else {
            button.contentEdgeInsets = UIEdgeInsets(
                top: SectionHeaderConstants.Spacing.mediumSpacing,
                left: SectionHeaderConstants.Spacing.contentInset,
                bottom: SectionHeaderConstants.Spacing.mediumSpacing,
                right: SectionHeaderConstants.Spacing.contentInset
            )
        }

        return button
    }()

    /// The spacing between the top of the view and the title
    private let topAnchorConstant: CGFloat
    /// The title for the action button
    private let buttonTitle: String?
    /// The action to perform when the button is tapped
    private let buttonAction: (() -> Void)?

    /// Creates a new section header with the specified title, subtitle, and button
    /// - Parameters:
    ///   - title: The title text to display
    ///   - subtitle: Optional subtitle text to display
    ///   - topAnchorConstant: The spacing between the top of the view and the title
    ///   - buttonTitle: Optional title for the action button
    ///   - buttonAction: Optional closure to execute when the button is tapped
    init(
        title: String,
        subtitle: String? = nil,
        topAnchorConstant: CGFloat = SectionHeaderConstants.Spacing.contentInset,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) {
        self.topAnchorConstant = topAnchorConstant
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction

        super.init(frame: .zero)
        setupUI()
        self.title = title
        
        if let title = buttonTitle {
            setupButton(title: title)
        }

        if let subtitle = subtitle {
            self.subtitle = subtitle
        }
    }

    /// Required initializer for interface builder/storyboard support
    /// - Parameter coder: The NSCoder instance
    required init?(coder: NSCoder) {
        self.topAnchorConstant = SectionHeaderConstants.Spacing.contentInset
        self.buttonTitle = nil
        self.buttonAction = nil
        super.init(coder: coder)
        setupUI()
    }

    /// The title text displayed in the header
    var title: String {
        get { return titleLabel.text ?? "" }
        set { titleLabel.text = newValue }
    }

    /// The subtitle text displayed in the header
    var subtitle: String {
        get { return subtitleLabel.text ?? "" }
        set { subtitleLabel.text = newValue }
    }

    /// Sets up the UI components and constraints
    private func setupUI() {
        addSubview(titleLabel)
        if buttonTitle != nil { addSubview(actionButton) }
        if subtitleLabel.text != "" { addSubview(subtitleLabel) }

        // Setup constraints
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: SectionHeaderConstants.Spacing.leadingPadding
            ),
            titleLabel.topAnchor.constraint(
                equalTo: topAnchor,
                constant: topAnchorConstant
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -SectionHeaderConstants.Spacing.trailingPadding
            )
        ])

        if subtitleLabel.text != "" {
            NSLayoutConstraint.activate([
                subtitleLabel.leadingAnchor.constraint(
                    equalTo: leadingAnchor,
                    constant: SectionHeaderConstants.Spacing.leadingPadding
                ),
                subtitleLabel.topAnchor.constraint(
                    equalTo: titleLabel.bottomAnchor,
                    constant: SectionHeaderConstants.Spacing.smallSpacing
                ),
                subtitleLabel.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -SectionHeaderConstants.Spacing.trailingPadding
                ),
                subtitleLabel.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -topAnchorConstant
                )
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.bottomAnchor.constraint(
                    equalTo: bottomAnchor,
                    constant: -topAnchorConstant
                )
            ])
        }

        if buttonTitle != nil {
            NSLayoutConstraint.activate([
                actionButton.trailingAnchor.constraint(
                    equalTo: trailingAnchor,
                    constant: -SectionHeaderConstants.Spacing.leadingPadding
                ),
                actionButton.centerYAnchor.constraint(
                    equalTo: titleLabel.centerYAnchor
                )
            ])
        }
    }

    /// Sets up the action button with the specified title
    /// - Parameter title: The button title
    private func setupButton(title: String) {
        actionButton.setTitle(title, for: .normal)
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    /// Called when the action button is tapped
    @objc private func buttonTapped() {
        buttonAction?()
    }

    /// Returns the intrinsic content size for this view
    override var intrinsicContentSize: CGSize {
        let height: CGFloat
        if subtitleLabel.text != "" {
            height = titleLabel.intrinsicContentSize.height
                    + subtitleLabel.intrinsicContentSize.height
                    + topAnchorConstant * 2
                    + SectionHeaderConstants.Spacing.smallSpacing
        } else {
            height = titleLabel.intrinsicContentSize.height + topAnchorConstant * 2
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }
}

/// A custom inline button with a gear icon for settings
class InlineButton: UIButton {
    /// Creates a new inline button with the default gear icon
    /// - Parameter frame: The frame rectangle for the view
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Configure the symbol with multi-color palette
        let symbolConfig = UIImage.SymbolConfiguration(paletteColors: [.tintColor, .secondarySystemBackground])
            .applying(UIImage.SymbolConfiguration(pointSize: 23, weight: .unspecified))
        
        // Create the image with the configuration
        let image = UIImage(systemName: "gearshape.circle.fill")?
            .withRenderingMode(.alwaysTemplate)
            .applyingSymbolConfiguration(symbolConfig)
        
        // Set the image as the button's content
        setImage(image, for: .normal)
        
        // Configure the insets based on iOS version
        if #available(iOS 15.0, *) {
            var buttonConfig = configuration ?? UIButton.Configuration.plain()
            buttonConfig.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 0,
                bottom: -SectionHeaderConstants.Spacing.mediumSpacing,
                trailing: 0
            )
            configuration = buttonConfig
        } else {
            contentEdgeInsets = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: -SectionHeaderConstants.Spacing.mediumSpacing,
                right: 0
            )
        }
    }

    /// Required initializer for interface builder/storyboard support
    /// - Parameter coder: The NSCoder instance
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        // Configure the symbol with multi-color palette
        let symbolConfig = UIImage.SymbolConfiguration(paletteColors: [.tintColor, .secondarySystemBackground])
            .applying(UIImage.SymbolConfiguration(pointSize: 23, weight: .unspecified))
        
        // Create the image with the configuration
        let image = UIImage(systemName: "gearshape.circle.fill")?
            .withRenderingMode(.alwaysTemplate)
            .applyingSymbolConfiguration(symbolConfig)
        
        // Set the image as the button's content
        setImage(image, for: .normal)
        
        // Configure the insets based on iOS version
        if #available(iOS 15.0, *) {
            var buttonConfig = configuration ?? UIButton.Configuration.plain()
            buttonConfig.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 0,
                bottom: -SectionHeaderConstants.Spacing.mediumSpacing,
                trailing: 0
            )
            configuration = buttonConfig
        } else {
            contentEdgeInsets = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: -SectionHeaderConstants.Spacing.mediumSpacing,
                right: 0
            )
        }
    }
}
