// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import CoreData
import UIKit

// MARK: - BundleOptions

struct BundleOptions {
    var name: String?
    var bundleId: String?
    var version: String?
    var sourceURL: URL?
}

// MARK: - SigningsViewController

class SigningsViewController: UIViewController {
    // MARK: - Constants
    
    private enum Constants {
        static let tableBottomInset: CGFloat = 70
        static let headerHeight: CGFloat = 40
        static let buttonHeight: CGFloat = 50
        static let buttonSideMargin: CGFloat = 16
        static let buttonBottomMargin: CGFloat = 17
        static let blurViewZPosition: CGFloat = 3
        static let buttonZPosition: CGFloat = 4
        static let iphoneBlurHeight: CGFloat = 80.0
        static let ipadBlurHeight: CGFloat = 65.0
    }
    
    // MARK: - Table Data
    
    var tableData = [
        [
            "AppIcon",
            String.localized("APPS_INFORMATION_TITLE_NAME"),
            String.localized("APPS_INFORMATION_TITLE_IDENTIFIER"),
            String.localized("APPS_INFORMATION_TITLE_VERSION"),
        ],
        [
            "Signing",
        ],
        [
            String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_ADD_TWEAKS"),
            String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_MODIFY_DYLIBS"),
        ],
        [String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_PROPERTIES")],
    ]

    var sectionTitles = [
        String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_TITLE_CUSTOMIZATION"),
        String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_TITLE_SIGNING"),
        String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_TITLE_ADVANCED"),
        "",
    ]

    // MARK: - Properties
    
    public var application: NSManagedObject?
    private var appsViewController: LibraryViewController?

    var signingDataWrapper: SigningDataWrapper
    var mainOptions = SigningMainDataWrapper(mainOptions: MainSigningOptions())

    var bundle: BundleOptions?

    var tableView: UITableView!
    private var variableBlurView: UIVariableBlurView?
    private var largeButton = ActivityIndicatorButton()
    private var iconCell = IconImageViewCell()
    var signingCompletionHandler: ((Bool) -> Void)?

    // MARK: - Initialization
    
    init(
        signingDataWrapper: SigningDataWrapper,
        application: NSManagedObject,
        appsViewController: LibraryViewController
    ) {
        self.signingDataWrapper = signingDataWrapper
        self.application = application
        self.appsViewController = appsViewController
        super.init(nibName: nil, bundle: nil)

        setupBundleOptions(from: application)
        configureCertificateAndUUID(from: application)
        handleProtectionSettings()
        applyCustomConfigurations()
        
        if signingDataWrapper.signingOptions.dynamicProtection {
            Task {
                await checkDynamicProtection()
            }
        }
    }
    
    private func setupBundleOptions(from application: NSManagedObject) {
        guard let name = application.value(forKey: "name") as? String,
              let bundleId = application.value(forKey: "bundleidentifier") as? String,
              let version = application.value(forKey: "version") as? String else {
            return
        }
        
        let sourceLocation = application.value(forKey: "oSU") as? String
        let sourceURL = sourceLocation.flatMap { URL(string: $0) }
        
        bundle = BundleOptions(
            name: name,
            bundleId: bundleId,
            version: version,
            sourceURL: sourceURL
        )
    }
    
    private func configureCertificateAndUUID(from application: NSManagedObject) {
        if let certificate = CoreDataManager.shared.getCurrentCertificate() {
            mainOptions.mainOptions.certificate = certificate
        }
        
        if let uuid = application.value(forKey: "uuid") as? String {
            mainOptions.mainOptions.uuid = uuid
        }
    }
    
    private func handleProtectionSettings() {
        guard signingDataWrapper.signingOptions.ppqCheckProtection,
              mainOptions.mainOptions.certificate?.certData?.pPQCheck == true,
              let bundleId = bundle?.bundleId else {
            return
        }
        
        if !signingDataWrapper.signingOptions.dynamicProtection {
            mainOptions.mainOptions.bundleId = bundleId + "." + Preferences.pPQCheckString
        }
    }
    
    private func applyCustomConfigurations() {
        // Apply custom bundle ID if configured
        if let currentBundleId = bundle?.bundleId,
           let newBundleId = signingDataWrapper.signingOptions.bundleIdConfig[currentBundleId] {
            mainOptions.mainOptions.bundleId = newBundleId
        }

        // Apply custom display name if configured
        if let currentName = bundle?.name,
           let newName = signingDataWrapper.signingOptions.displayNameConfig[currentName] {
            mainOptions.mainOptions.name = newName
        }
    }

    private func checkDynamicProtection() async {
        guard signingDataWrapper.signingOptions.ppqCheckProtection,
              mainOptions.mainOptions.certificate?.certData?.pPQCheck == true,
              let bundleId = bundle?.bundleId else {
            return
        }

        let shouldModify = await BundleIdChecker.shouldModifyBundleId(originalBundleId: bundleId)
        if shouldModify {
            mainOptions.mainOptions.bundleId = bundleId + "." + Preferences.pPQCheckString
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupViews()
        setupToolbar()
        setupGestures()
        
        #if !targetEnvironment(simulator)
            certAlert()
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fetch),
            name: Notification.Name("reloadSigningController"),
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("reloadSigningController"),
            object: nil
        )
    }
    
    // MARK: - UI Setup
    
    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        
        tableView.addGestureRecognizer(swipeLeft)
        tableView.addGestureRecognizer(swipeRight)
    }

    private func setupNavigation() {
        let logoImageView = UIImageView(image: UIImage(named: "backdoor_glyph"))
        logoImageView.contentMode = .scaleAspectFit
        navigationItem.titleView = logoImageView
        navigationController?.navigationBar.prefersLargeTitles = false

        isModalInPresentation = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: String.localized("DISMISS"),
            style: .done,
            target: self,
            action: #selector(closeSheet)
        )
    }

    private func setupViews() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.showsHorizontalScrollIndicator = false
        tableView.showsVerticalScrollIndicator = false
        tableView.contentInset.bottom = Constants.tableBottomInset

        view.addSubview(tableView)
        tableView.constraintCompletely(to: view)
    }

    private func setupToolbar() {
        // Configure button
        largeButton.translatesAutoresizingMaskIntoConstraints = false
        largeButton.addTarget(self, action: #selector(startSign), for: .touchUpInside)

        // Configure blur view
        let gradientMask = VariableBlurViewConstants.defaultGradientMask
        variableBlurView = UIVariableBlurView(frame: .zero)
        variableBlurView?.gradientMask = gradientMask
        variableBlurView?.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        variableBlurView?.translatesAutoresizingMaskIntoConstraints = false

        // Add views
        if let blurView = variableBlurView {
            view.addSubview(blurView)
        }
        view.addSubview(largeButton)

        // Calculate height based on device type
        let height = UIDevice.current.userInterfaceIdiom == .pad ? 
                     Constants.ipadBlurHeight : 
                     Constants.iphoneBlurHeight

        // Set constraints
        NSLayoutConstraint.activate([
            variableBlurView!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            variableBlurView!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            variableBlurView!.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            variableBlurView!.heightAnchor.constraint(equalToConstant: height),

            largeButton.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: Constants.buttonSideMargin
            ),
            largeButton.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -Constants.buttonSideMargin
            ),
            largeButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -Constants.buttonBottomMargin
            ),
            largeButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight),
        ])

        // Set z-position for proper layering
        variableBlurView?.layer.zPosition = Constants.blurViewZPosition
        largeButton.layer.zPosition = Constants.buttonZPosition
    }

    private func certAlert() {
        guard mainOptions.mainOptions.certificate == nil else { return }
        
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: String.localized("APP_SIGNING_VIEW_CONTROLLER_NO_CERTS_ALERT_TITLE"),
                message: String.localized("APP_SIGNING_VIEW_CONTROLLER_NO_CERTS_ALERT_DESCRIPTION"),
                preferredStyle: .alert
            )
            
            let dismissAction = UIAlertAction(
                title: String.localized("LAME"),
                style: .default
            ) { [weak self] _ in
                self?.dismiss(animated: true)
            }
            
            alert.addAction(dismissAction)
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - Actions

    @objc func closeSheet() {
        dismiss(animated: true)
    }

    @objc func fetch() {
        tableView.reloadData()
    }
    
    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let location = gesture.location(in: tableView)
        
        // Check if swipe occurred on certificate cell
        guard let indexPath = tableView.indexPathForRow(at: location),
              indexPath.section == 1 && indexPath.row == 0 else {
            return
        }
        
        let certificates = CoreDataManager.shared.getDatedCertificate()
        guard certificates.count > 1 else { return }

        // Find current certificate index
        let currentIndex = certificates.firstIndex { $0 == mainOptions.mainOptions.certificate } ?? 0
        var newIndex = currentIndex

        // Determine new index based on swipe direction
        switch gesture.direction {
        case .left:
            newIndex = (currentIndex + 1) % certificates.count
        case .right:
            newIndex = (currentIndex - 1 + certificates.count) % certificates.count
        default:
            break
        }

        // Provide haptic feedback
        let feedbackGenerator = UISelectionFeedbackGenerator()
        feedbackGenerator.prepare()
        feedbackGenerator.selectionChanged()

        // Update certificate selection
        Preferences.selectedCert = newIndex
        mainOptions.mainOptions.certificate = certificates[newIndex]
        
        // Animate cell update
        let animationDirection = gesture.direction == .left ? UITableView.RowAnimation.left : .right
        tableView.reloadRows(at: [indexPath], with: animationDirection)
    }

    @objc func startSign() {
        guard let bundle = bundle,
              let app = application as? DownloadedApps else { return }
        
        // Disable back button and show loading
        navigationItem.leftBarButtonItem = nil
        largeButton.showLoadingIndicator()
        
        // Start signing process
        let appPath = getFilesForDownloadedApps(app: app, getuuidonly: false)
        
        signInitialApp(
            bundle: bundle,
            mainOptions: mainOptions,
            signingOptions: signingDataWrapper,
            appPath: appPath
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let (signedPath, signedApp)):
                self.handleSuccessfulSigning(signedPath: signedPath, signedApp: signedApp)
                
            case .failure(let error):
                Debug.shared.log(
                    message: "Signing failed: \(error.localizedDescription)",
                    type: .error
                )
                self.signingCompletionHandler?(false)
            }

            self.dismiss(animated: true)
        }
    }
    
    private func handleSuccessfulSigning(signedPath: URL, signedApp: URL) {
        // Refresh app list
        appsViewController?.fetchSources()
        appsViewController?.tableView.reloadData()
        
        // Log file path
        Debug.shared.log(message: signedPath.path)
        
        // Install if needed
        if signingDataWrapper.signingOptions.installAfterSigned {
            appsViewController?.startInstallProcess(
                meow: signedApp,
                filePath: signedPath.path
            )
            signingCompletionHandler?(true)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension SigningsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        return sectionTitles.count
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].count
    }
    
    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionTitles[section].isEmpty ? 0 : Constants.headerHeight
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = sectionTitles[section]
        return InsetGroupedSectionHeader(title: title)
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellText = tableData[indexPath.section][indexPath.row]
        return configureCellForType(cellText, at: indexPath)
    }
    
    private func configureCellForType(_ cellText: String, at indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "Cell"
        let cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .none
        cell.selectionStyle = .gray
        cell.textLabel?.text = cellText
        
        switch cellText {
        case "AppIcon":
            return configureAppIconCell()
            
        case String.localized("APPS_INFORMATION_TITLE_NAME"):
            cell.detailTextLabel?.text = mainOptions.mainOptions.name ?? bundle?.name
            cell.accessoryType = .disclosureIndicator
            
        case String.localized("APPS_INFORMATION_TITLE_IDENTIFIER"):
            cell.detailTextLabel?.text = mainOptions.mainOptions.bundleId ?? bundle?.bundleId
            cell.accessoryType = .disclosureIndicator
            
        case String.localized("APPS_INFORMATION_TITLE_VERSION"):
            cell.detailTextLabel?.text = mainOptions.mainOptions.version ?? bundle?.version
            cell.accessoryType = .disclosureIndicator
            
        case "Signing":
            return configureCertificateCell(baseCell: cell)
            
        case "Change Certificate", 
             String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_ADD_TWEAKS"),
             String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_MODIFY_DYLIBS"),
             String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_PROPERTIES"):
            cell.accessoryType = .disclosureIndicator
        
        default:
            break
        }

        return cell
    }
    
    private func configureAppIconCell() -> UITableViewCell {
        if mainOptions.mainOptions.iconURL != nil {
            iconCell.configure(with: mainOptions.mainOptions.iconURL)
        } else if let app = application as? DownloadedApps, 
                  let iconURL = getIconURL(for: app) {
            iconCell.configure(with: CoreDataManager.shared.loadImage(from: iconURL))
        }
        
        iconCell.accessoryType = .disclosureIndicator
        return iconCell
    }
    
    private func configureCertificateCell(baseCell: UITableViewCell) -> UITableViewCell {
        if let certificate = mainOptions.mainOptions.certificate {
            let certCell = CertificateViewTableViewCell()
            certCell.configure(with: certificate, isSelected: false)
            certCell.selectionStyle = .none
            return certCell
        } else {
            let noSelectionText = String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CURRENT_CERTIFICATE_NOSELECTED")
            baseCell.textLabel?.text = noSelectionText
            baseCell.textLabel?.textColor = .secondaryLabel
            baseCell.selectionStyle = .none
            return baseCell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let itemTapped = tableData[indexPath.section][indexPath.row]
        handleTappedItem(itemTapped, at: indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func handleTappedItem(_ item: String, at indexPath: IndexPath) {
        switch item {
        case "AppIcon":
            importAppIconFile()
            
        case String.localized("APPS_INFORMATION_TITLE_NAME"):
            navigateToInputViewController(for: .name, at: indexPath)
            
        case String.localized("APPS_INFORMATION_TITLE_IDENTIFIER"):
            navigateToInputViewController(for: .bundleId, at: indexPath)
            
        case String.localized("APPS_INFORMATION_TITLE_VERSION"):
            navigateToInputViewController(for: .version, at: indexPath)
            
        case String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_ADD_TWEAKS"):
            navigateToTweaksViewController()
            
        case String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_MODIFY_DYLIBS"):
            navigateToDylibViewController()
            
        case String.localized("APP_SIGNING_VIEW_CONTROLLER_CELL_PROPERTIES"):
            navigateToAdvancedViewController()
            
        default:
            break
        }
    }
    
    private enum InputType {
        case name, bundleId, version
    }
    
    private func navigateToInputViewController(for type: InputType, at indexPath: IndexPath) {
        var initialValue: String
        
        switch type {
        case .name:
            initialValue = mainOptions.mainOptions.name ?? bundle?.name ?? ""
        case .bundleId:
            initialValue = mainOptions.mainOptions.bundleId ?? bundle?.bundleId ?? ""
        case .version:
            initialValue = mainOptions.mainOptions.version ?? bundle?.version ?? ""
        }
        
        guard !initialValue.isEmpty else { return }
        
        let viewController = SigningsInputViewController(
            parentView: self,
            initialValue: initialValue,
            valueToSaveTo: indexPath.row
        )
        
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func navigateToTweaksViewController() {
        let viewController = SigningsTweakViewController(
            signingDataWrapper: signingDataWrapper
        )
        
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func navigateToDylibViewController() {
        guard let app = application as? DownloadedApps else { return }
        
        let appPath = getFilesForDownloadedApps(app: app, getuuidonly: false)
        let viewController = SigningsDylibViewController(
            mainOptions: mainOptions,
            app: appPath
        )
        
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func navigateToAdvancedViewController() {
        let viewController = SigningsAdvancedViewController(
            signingDataWrapper: signingDataWrapper,
            mainOptions: mainOptions
        )
        
        navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - File Management

extension SigningsViewController {
    public func getFilesForDownloadedApps(app: DownloadedApps, getuuidonly: Bool) -> URL {
        do {
            return try CoreDataManager.shared.getFilesForDownloadedApps(for: app, getuuidonly: getuuidonly)
        } catch {
            Debug.shared.log(message: "Error in getFilesForDownloadedApps: \(error)", type: .error)
            // Return a fallback URL that doesn't crash when used
            return URL(fileURLWithPath: "")
        }
    }

    private func getIconURL(for app: DownloadedApps) -> URL? {
        guard let iconURLString = app.value(forKey: "iconURL") as? String,
              let iconURL = URL(string: iconURLString) else {
            return nil
        }

        let filesURL = getFilesForDownloadedApps(app: app, getuuidonly: false)
        return filesURL.appendingPathComponent(iconURL.lastPathComponent)
    }
}
