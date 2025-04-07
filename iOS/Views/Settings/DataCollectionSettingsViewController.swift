// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit

/// View controller for managing data collection settings
class DataCollectionSettingsViewController: UITableViewController {
    
    // MARK: - Properties
    
    private let cellReuseIdentifier = "DataCollectionCell"
    private let switchCellReuseIdentifier = "DataCollectionSwitchCell"
    
    // Section indices
    private enum Section: Int {
        case about = 0
        case settings = 1
        case datasets = 2
        case actions = 3
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Data Collection"
        
        // Configure table view
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: switchCellReuseIdentifier)
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .about:
            return 1
        case .settings:
            return 1
        case .datasets:
            return 1
        case .actions:
            return 1
        case .none:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .about:
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            cell.textLabel?.text = "Backdoor collects data to improve app functionality and user experience. This includes app usage, device information, error logs, and AI training data."
            cell.textLabel?.numberOfLines = 0
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
            
        case .settings:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = "Enable Data Collection"
            cell.switchControl.isOn = UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection")
            cell.switchValueChanged = { isOn in
                UserDefaults.standard.set(isOn, forKey: "UserHasAcceptedDataCollection")
                if isOn {
                    // If user enables collection, update device info
                    DispatchQueue.global(qos: .utility).async {
                        // Try to access BackdoorDataCollector first
                        if let collectorClass = NSClassFromString("BackdoorDataCollector") as? NSObject.Type,
                           let collector = collectorClass.value(forKey: "shared") as? NSObject,
                           collector.responds(to: Selector(("uploadDeviceInfo"))) {
                            collector.perform(Selector(("uploadDeviceInfo")))
                        } 
                        // Fall back to EnhancedDropboxService if BackdoorDataCollector isn't available
                        else if let dropboxServiceClass = NSClassFromString("EnhancedDropboxService") as? NSObject.Type,
                                let dropboxService = dropboxServiceClass.value(forKey: "shared") as? NSObject,
                                dropboxService.responds(to: Selector(("uploadDeviceInfo"))) {
                            dropboxService.perform(Selector(("uploadDeviceInfo")))
                        }
                    }
                }
                self.tableView.reloadSections(IndexSet(integer: Section.datasets.rawValue), with: .automatic)
            }
            return cell
            
        case .datasets:
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            cell.textLabel?.text = "AI Dataset Management"
            cell.accessoryType = .disclosureIndicator
            cell.isUserInteractionEnabled = UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection")
            cell.textLabel?.isEnabled = UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection")
            return cell
            
        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            cell.textLabel?.text = "View Data Collection Policy"
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case .none:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .about:
            return "About Data Collection"
        case .settings:
            return "Settings"
        case .datasets:
            return "AI Learning"
        case .actions:
            return "Actions"
        case .none:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section) {
        case .datasets:
            if UserDefaults.standard.bool(forKey: "UserHasAcceptedDataCollection") {
                // Use indirect instantiation to avoid compilation dependency
                showDatasetManager()
            }
        case .actions:
            showDataCollectionPolicy()
        default:
            break
        }
    }
    
    // MARK: - Actions
    
    private func showDatasetManager() {
        // Check for protected dataset access
        let alert = UIAlertController(
            title: "Dataset Management",
            message: "Enter admin password to access dataset management",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            guard let password = alert.textFields?.first?.text else { return }
            
            // Try to validate password using BackdoorDataCollector
            var isPasswordValid = false
            
            if let collectorClass = NSClassFromString("BackdoorDataCollector") as? NSObject.Type,
               let collector = collectorClass.value(forKey: "shared") as? NSObject,
               collector.responds(to: Selector(("validateDatasetPassword:"))) {
                let result = collector.perform(Selector(("validateDatasetPassword:")), with: password)
                if let validationResult = result?.takeUnretainedValue() as? Bool {
                    isPasswordValid = validationResult
                }
            } else {
                // Fallback to direct check
                isPasswordValid = (password == "2B4D5G")
            }
            
            if isPasswordValid {
                // We have the correct password, show dataset UI
                self?.showSimpleDatasetUI()
            } else {
                // Wrong password
                let errorAlert = UIAlertController(
                    title: "Access Denied",
                    message: "Invalid password",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(errorAlert, animated: true)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showSimpleDatasetUI() {
        let datasetVC = UIViewController()
        datasetVC.title = "Dataset Management"
        
        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Try to get dataset info from BackdoorDataCollector
        var datasetsInfo = "Datasets are automatically managed in the background.\n\nActive data collection is enabled.\n\nData is securely transmitted to the specified Dropbox account."
        
        if let collectorClass = NSClassFromString("BackdoorDataCollector") as? NSObject.Type,
           let collector = collectorClass.value(forKey: "shared") as? NSObject,
           collector.responds(to: Selector(("getAvailableDatasets"))) {
            
            if let result = collector.perform(Selector(("getAvailableDatasets")))?.takeUnretainedValue() as? [String: Any],
               let datasets = result["datasets"] as? [[String: Any]] {
                
                datasetsInfo += "\n\n--- Available Datasets ---\n"
                
                for (index, dataset) in datasets.enumerated() {
                    if let name = dataset["name"] as? String,
                       let description = dataset["description"] as? String {
                        datasetsInfo += "\n\(index + 1). \(name): \(description)"
                    }
                }
            }
        }
        
        infoLabel.text = datasetsInfo
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .left
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        datasetVC.view.addSubview(scrollView)
        scrollView.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: datasetVC.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: datasetVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: datasetVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: datasetVC.view.safeAreaLayoutGuide.bottomAnchor),
            
            infoLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            infoLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            infoLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        navigationController?.pushViewController(datasetVC, animated: true)
    }
    
    private func showFeatureNotAvailableAlert() {
        let alert = UIAlertController(
            title: "Feature Not Available",
            message: "AI Dataset Management is not available in this build",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showDataCollectionPolicy() {
        let policyVC = UIViewController()
        policyVC.title = "Data Collection Policy"
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.text = getDataCollectionPolicyText()
        policyVC.view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: policyVC.view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: policyVC.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: policyVC.view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: policyVC.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        navigationController?.pushViewController(policyVC, animated: true)
    }
    
    private func getDataCollectionPolicyText() -> String {
        return """
        DATA COLLECTION POLICY
        
        Backdoor App collects and processes the following information to provide and improve our services:
        
        1. USAGE DATA
        We collect information about how you use the app, including:
        - Features and screens you visit
        - Actions you take within the app
        - Time spent on different activities
        - AI interactions and conversations
        
        2. DEVICE INFORMATION
        We collect information about your device, including:
        - Device model and iOS version
        - Device name and identifiers
        - Network information
        
        3. LOG FILES
        We collect logs that help us identify and fix issues, including:
        - App crashes and errors
        - Performance metrics
        - Debug information
        
        4. AI LEARNING DATA
        To improve our AI capabilities, we collect:
        - Your messages to the AI assistant
        - AI responses and performance data
        - Feedback you provide about AI interactions
        
        5. CERTIFICATE DATA
        When you upload certificates for app signing:
        - Your certificate files are processed for signing operations
        - Certificate metadata may be stored for your convenience
        
        6. STORAGE AND RETENTION
        - All collected data is securely stored in our cloud storage (Dropbox)
        - Data is organized in folders specific to your device
        - We retain this information to provide ongoing service improvements
        
        7. DATA DOWNLOADS
        The app may periodically download datasets to improve AI functionality:
        - These downloads happen automatically when needed
        - Only relevant datasets will be downloaded based on your usage
        
        You can withdraw consent at any time through the Settings menu, though this may limit certain app functionalities.
        
        If you have any questions about our data practices, please contact us at support@backdoor-app.com.
        """
    }
}
