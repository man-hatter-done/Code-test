// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import Nuke
import UIKit

// MARK: - AppTableViewCell

class AppTableViewCell: UITableViewCell {
    // MARK: - Properties
    
    public var appDownload: AppDownload?
    private var progressObserver: NSObjectProtocol?

    private let progressLayer = CAShapeLayer()
    private var getButtonWidthConstraint: NSLayoutConstraint?
    private var buttonImage: UIImage?

    // MARK: - UI Components
    
    private let iconImageView = AppCellFactory.createIconImageView()
    private let nameLabel = AppCellFactory.createNameLabel()
    private let versionLabel = AppCellFactory.createVersionLabel()
    private let descriptionLabel = AppCellFactory.createDescriptionLabel()
    private let screenshotsScrollView = AppCellFactory.createScreenshotsScrollView()
    private let screenshotsStackView = AppCellFactory.createScreenshotsStackView()
    
    let getButton: UIButton = {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 15
        button.layer.backgroundColor = UIColor.quaternarySystemFill.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        configureGetButtonArrow()
        configureProgressLayer()
        addObservers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - View Setup
    
    private func setupViews() {
        let labelsStackView = UIStackView(arrangedSubviews: [nameLabel, versionLabel])
        labelsStackView.axis = .vertical
        labelsStackView.spacing = 1
        
        // Add subviews
        contentView.addSubview(iconImageView)
        contentView.addSubview(labelsStackView)
        contentView.addSubview(screenshotsScrollView)
        screenshotsScrollView.addSubview(screenshotsStackView)
        contentView.addSubview(getButton)
        contentView.addSubview(descriptionLabel)

        // Configure translatesAutoresizingMaskIntoConstraints
        labelsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup constraints
        getButtonWidthConstraint = getButton.widthAnchor.constraint(equalToConstant: 70)
        setupConstraints(labelsStackView: labelsStackView)
    }
    
    private func setupConstraints(labelsStackView: UIStackView) {
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            iconImageView.widthAnchor.constraint(equalToConstant: 52),
            iconImageView.heightAnchor.constraint(equalToConstant: 52),

            labelsStackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 15),
            labelsStackView.trailingAnchor.constraint(equalTo: getButton.leadingAnchor, constant: -15),
            labelsStackView.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            labelsStackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 15),

            getButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            getButton.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            getButtonWidthConstraint!,
            getButton.heightAnchor.constraint(equalToConstant: 30),

            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),

            screenshotsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            screenshotsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            screenshotsStackView.leadingAnchor.constraint(equalTo: screenshotsScrollView.leadingAnchor),
            screenshotsStackView.topAnchor.constraint(equalTo: screenshotsScrollView.topAnchor),
            screenshotsStackView.bottomAnchor.constraint(equalTo: screenshotsScrollView.bottomAnchor),
            screenshotsStackView.trailingAnchor.constraint(equalTo: screenshotsScrollView.trailingAnchor),
            screenshotsStackView.heightAnchor.constraint(equalTo: screenshotsScrollView.heightAnchor)
        ])
    }

    // MARK: - Button Configuration
    
    private func configureGetButtonArrow() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        buttonImage = UIImage(systemName: "arrow.down", withConfiguration: symbolConfig)
        getButton.setImage(buttonImage, for: .normal)
        getButton.tintColor = .tintColor
    }

    private func configureGetButtonSquare() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        buttonImage = UIImage(systemName: "square.fill", withConfiguration: symbolConfig)
        getButton.setImage(buttonImage, for: .normal)
        getButton.tintColor = .tintColor
    }

    private func configureProgressLayer() {
        progressLayer.strokeColor = UIColor.tintColor.cgColor
        progressLayer.lineWidth = 3.0
        progressLayer.fillColor = nil
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0.0

        let circularPath = UIBezierPath(roundedRect: getButton.bounds, cornerRadius: 15)
        progressLayer.path = circularPath.cgPath
        getButton.layer.addSublayer(progressLayer)
    }

    private func addObservers() {
        progressObserver = NotificationCenter.default.addObserver(
            forName: .downloadProgressUpdated, 
            object: nil, 
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let uuid = userInfo["uuid"] as? String,
                  self.appDownload?.AppUUID == uuid else { return }
        }
    }

    // MARK: - Lifecycle Methods
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateProgressLayerPath()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        getButton.layer.backgroundColor = UIColor.quaternarySystemFill.cgColor
        updateProgressLayerPath()
    }

    // MARK: - Cell Configuration
    
    func configure(with app: StoreAppsData) {
        // Configure basic app info
        configureAppName(app)
        configureVersionText(app)
        configureAppIcon(app)
        
        // Remove any existing screenshots
        screenshotsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Setup screenshot layout or description based on preferences
        setupAppContentLayout(app)
        
        // Update download state
        updateDownloadState(uuid: app.bundleIdentifier)
    }
    
    private func configureAppName(_ app: StoreAppsData) {
        var appname = app.name
        if app.bundleIdentifier.hasSuffix("Beta") {
            appname += " (Beta)"
        }
        nameLabel.text = appname
    }
    
    private func configureVersionText(_ app: StoreAppsData) {
        let appVersion = (app.versions?.first?.version ?? app.version) ?? "1.0"
        var displayText = appVersion
        var descText = ""

        // Add date if available
        displayText = addDateToDisplayText(displayText, app: app)
        
        // Add subtitle/description based on preferences
        (displayText, descText) = addAppDescriptionInfo(displayText, app: app)
        
        descriptionLabel.text = descText
        versionLabel.text = displayText
    }
    
    private func addDateToDisplayText(_ displayText: String, app: StoreAppsData) -> String {
        var result = displayText
        let appDate = (app.versions?.first?.date ?? app.versionDate) ?? ""
        
        if !appDate.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

            if let date = dateFormatter.date(from: appDate) {
                let formattedDate = date.formatted(date: .numeric, time: .omitted)
                result += " • " + formattedDate
            } else {
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: appDate) {
                    let formattedDate = date.formatted(date: .numeric, time: .omitted)
                    result += " • " + formattedDate
                }
            }
        }
        
        return result
    }
    
    private func addAppDescriptionInfo(_ displayText: String, app: StoreAppsData) -> (String, String) {
        var resultDisplay = displayText
        var descText = ""
        
        switch Preferences.appDescriptionAppearence {
        case 0:
            let appSubtitle = app.subtitle ?? String.localized("SOURCES_CELLS_DEFAULT_SUBTITLE")
            resultDisplay += " • " + appSubtitle
            
        case 1:
            let appSubtitle = app.localizedDescription ?? String.localized("SOURCES_CELLS_DEFAULT_SUBTITLE")
            resultDisplay += " • " + appSubtitle
            
        case 2:
            let appSubtitle = app.subtitle ?? String.localized("SOURCES_CELLS_DEFAULT_SUBTITLE")
            resultDisplay += " • " + appSubtitle
            descText = app.localizedDescription ?? 
                      (app.versions?[0].localizedDescription ?? 
                       String.localized("SOURCES_CELLS_DEFAULT_DESCRIPTION"))
            
        default:
            break
        }
        
        return (resultDisplay, descText)
    }
    
    private func configureAppIcon(_ app: StoreAppsData) {
        iconImageView.image = UIImage(named: "unknown")

        if let iconURL = app.iconURL {
            loadImage(from: iconURL) { [weak self] image in
                DispatchQueue.main.async {
                    self?.iconImageView.image = image
                }
            }
        }
    }
    
    private func setupAppContentLayout(_ app: StoreAppsData) {
        if let screenshotUrls = app.screenshotURLs, 
           !screenshotUrls.isEmpty, 
           Preferences.appDescriptionAppearence != 2 {
            setupScreenshots(for: screenshotUrls)
        } else if Preferences.appDescriptionAppearence == 2 {
            setupDescription()
        } else {
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        }
    }

    // MARK: - Screenshots Setup
    
    private func setupScreenshots(for urls: [URL]) {
        let imageViews = createImageViewsForScreenshots(urls)
        
        screenshotsScrollView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 10).isActive = true
        screenshotsScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15).isActive = true
        iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15).isActive = true

        for imageView in imageViews {
            screenshotsStackView.addArrangedSubview(imageView)
            imageView.heightAnchor.constraint(equalTo: screenshotsScrollView.heightAnchor).isActive = true
        }

        loadImages(from: urls, into: imageViews)
    }
    
    private func createImageViewsForScreenshots(_ urls: [URL]) -> [UIImageView] {
        return urls.map { _ -> UIImageView in
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 15
            imageView.layer.cornerCurve = .continuous
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.layer.borderWidth = 1
            imageView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleScreenshotTap(_:)))
            imageView.addGestureRecognizer(tapGesture)
            imageView.isUserInteractionEnabled = true
            
            return imageView
        }
    }

    private func setupDescription() {
        iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15).isActive = true
        descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15).isActive = true
        descriptionLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 15).isActive = true
    }

    @objc private func handleScreenshotTap(_ sender: UITapGestureRecognizer) {
        guard let tappedImageView = sender.view as? UIImageView,
              let tappedImage = tappedImageView.image else {
            return
        }

        let fullscreenImageVC = SourceAppScreenshotViewController()
        fullscreenImageVC.image = tappedImage

        let navigationController = UINavigationController(rootViewController: fullscreenImageVC)
        navigationController.modalPresentationStyle = .fullScreen

        if let viewController = self.parentViewController {
            viewController.present(navigationController, animated: true)
        }
    }

    // MARK: - Image Loading
    
    private func loadImages(from urls: [URL], into imageViews: [UIImageView]) {
        let dispatchGroup = DispatchGroup()

        for (index, url) in urls.enumerated() {
            dispatchGroup.enter()
            loadImage(from: url) { [weak self] image in
                defer { dispatchGroup.leave() }
                
                guard let self = self,
                      let image = image, 
                      index < imageViews.count else {
                    return
                }

                let imageView = imageViews[index]
                DispatchQueue.main.async {
                    let aspectRatio = image.size.width / image.size.height
                    let width = self.screenshotsScrollView.bounds.height * aspectRatio
                    imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
                    Task { imageView.image = await image.byPreparingForDisplay() }
                }
            }
        }
    }

    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let request = ImageRequest(url: url)

        if let cachedImage = ImagePipeline.shared.cache.cachedImage(for: request)?.image {
            completion(cachedImage)
            return
        }
        
        ImagePipeline.shared.loadImage(
            with: request,
            queue: .global(),
            progress: nil
        ) { result in
            switch result {
            case let .success(imageResponse):
                completion(imageResponse.image)
            case .failure:
                completion(nil)
            }
        }
    }

    // MARK: - Download State
    
    private func updateDownloadState(uuid: String?) {
        guard let appUUID = uuid else { return }

        DownloadTaskManager.shared.restoreTaskState(for: appUUID, cell: self)

        if let task = DownloadTaskManager.shared.task(for: appUUID),
           case .inProgress = task.state {
            DispatchQueue.main.async {
                self.startDownload()
            }
        }
    }

    func updateProgress(to value: CGFloat) {
        DispatchQueue.main.async {
            self.progressLayer.strokeEnd = value
        }
    }

    func startDownload() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.getButtonWidthConstraint?.constant = 30
                self.layoutIfNeeded()
                self.configureGetButtonSquare()
                self.updateProgressLayerPath()
            }
        }
    }

    func stopDownload() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.getButtonWidthConstraint?.constant = 70
                self.progressLayer.strokeEnd = 0.0
                self.configureGetButtonArrow()
                self.layoutIfNeeded()
            }
        }
    }

    func cancelDownload() {
        DispatchQueue.main.async {
            self.stopDownload()
        }
    }

    private func updateProgressLayerPath() {
        let circularPath = UIBezierPath(roundedRect: getButton.bounds, cornerRadius: 15)
        progressLayer.path = circularPath.cgPath
    }
}

// MARK: - Factory for UI Elements

fileprivate enum AppCellFactory {
    static func createIconImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }
    
    static func createNameLabel() -> UILabel {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 16)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    static func createVersionLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .gray
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    static func createDescriptionLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .gray
        label.numberOfLines = 20
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    static func createScreenshotsScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }
    
    static func createScreenshotsStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }
}

// MARK: - SourceAppScreenshotViewController

class SourceAppScreenshotViewController: UIViewController {
    // MARK: - Properties
    
    var image: UIImage?

    // MARK: - UI Components
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 16
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        imageView.layer.borderWidth = 1
        imageView.clipsToBounds = true
        return imageView
    }()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateImageViewSize()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        view.backgroundColor = .systemBackground
        view.addSubview(imageView)
        setupConstraints()
        imageView.image = image
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String.localized("DONE"),
            style: .done,
            target: self,
            action: #selector(closeSheet)
        )
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.9),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.9)
        ])
    }

    private func updateImageViewSize() {
        guard let image = image else { return }
        
        let imageSize = image.size
        let maxWidth = view.safeAreaLayoutGuide.layoutFrame.width * 0.9
        let maxHeight = view.safeAreaLayoutGuide.layoutFrame.height * 0.9
        let aspectRatio = imageSize.width / imageSize.height
        
        let constrainedWidth = min(imageSize.width, maxWidth)
        let constrainedHeight = min(imageSize.height, maxHeight)
        
        let imageViewWidth = min(constrainedWidth, constrainedHeight * aspectRatio)
        let imageViewHeight = min(constrainedHeight, constrainedWidth / aspectRatio)
        
        imageView.frame.size = CGSize(width: imageViewWidth, height: imageViewHeight)
        imageView.center = view.center
    }

    // MARK: - Actions
    
    @objc func closeSheet() {
        dismiss(animated: true)
    }
}
