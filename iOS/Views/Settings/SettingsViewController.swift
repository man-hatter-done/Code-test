// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import Nuke
import SwiftUI
import UIKit

class SettingsViewController: FRSTableViewController {
    let aboutSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SUBMIT_FEEDBACK"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_GITHUB"),
    ]

    let displaySection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"),
    ]

    let certificateSection = [
        "Current Certificate",
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"),
    ]
    
    let aiSection = [
        "AI Learning Settings",
        "AI Search Settings",
    ]
    
    let terminalSection = [
        "Terminal",
        "Terminal Settings",
        "Terminal Button"
    ]

    let logsSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"),
    ]

    let foldersSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"),
    ]

    let resetSection = [
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"),
        String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"),
    ]

    // Flag to prevent double initialization
    private var isInitialized = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Defensive programming - ensure we're on the main thread for UI setup
        if !Thread.isMainThread {
            backdoor.Debug.shared.log(message: "SettingsViewController.viewDidLoad called off main thread, dispatching to main", type: .error)
            DispatchQueue.main.async { [weak self] in
                self?.viewDidLoad()
            }
            return
        }

        // Set the title immediately for better user experience
        self.title = String.localized("TAB_SETTINGS")

        do {
            // Set up UI with proper error handling
            try safeInitialize()
            backdoor.Debug.shared.log(message: "SettingsViewController initialized successfully", type: .info)
            
            // Add LED effects to important sections after a delay to ensure layout is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.addLEDEffectsToImportantCells()
            }
        } catch {
            backdoor.Debug.shared.log(message: "SettingsViewController initialization failed: \(error)", type: .error)
            
            // Show an error dialog if initialization fails
            let alert = UIAlertController(
                title: "Settings Error",
                message: "There was a problem loading settings. Please try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true, completion: nil)
        }
    }
    
    /// Add LED effects to highlight important settings cells
    private func addLEDEffectsToImportantCells() {
        // Only apply effects if the view is visible
        guard isViewLoaded && view.window != nil else { return }
        
        // Get visible cells to apply effects only to what the user can see
        let visibleCells = tableView.visibleCells
        
        for cell in visibleCells {
            // Apply LED effects based on cell content
            if let textLabel = cell.textLabel, let text = textLabel.text {
                switch text {
                case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                    // About section gets brand color glow
                    cell.contentView.addLEDEffect(
                        color: UIColor(hex: "#FF6482") ?? .systemPink,
                        intensity: 0.3,
                        spread: 10,
                        animated: true,
                        animationDuration: 3.0
                    )
                    
                case "Current Certificate":
                    // Certificate section gets flowing LED to draw attention
                    if let cert = CoreDataManager.shared.getCurrentCertificate() {
                        let isExpiring = isCertificateExpiringSoon(cert)
                        let color: UIColor = isExpiring ? .systemOrange : .systemGreen
                        
                        cell.contentView.addFlowingLEDEffect(
                            color: color,
                            intensity: isExpiring ? 0.6 : 0.4,
                            width: 2,
                            speed: isExpiring ? 3.0 : 5.0
                        )
                    }
                
                case "Terminal":
                    // Terminal gets a tech-like glow
                    cell.contentView.addLEDEffect(
                        color: .systemGreen,
                        intensity: 0.4,
                        spread: 8,
                        animated: true,
                        animationDuration: 4.0
                    )
                    
                case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"),
                     String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
                    // Reset buttons get subtle warning glow
                    cell.contentView.addLEDEffect(
                        color: .systemRed,
                        intensity: 0.3,
                        spread: 5,
                        animated: true,
                        animationDuration: 2.0
                    )
                    
                default:
                    break
                }
            }
        }
    }
    
    /// Check if certificate is expiring within 7 days
    private func isCertificateExpiringSoon(_ certificate: Certificate) -> Bool {
        guard let expirationDate = certificate.certData?.expirationDate else {
            return false
        }
        
        let currentDate = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: currentDate, to: expirationDate)
        let daysLeft = components.day ?? 0
        
        return daysLeft < 7 && daysLeft >= 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Refresh LED effects when view appears
        addLEDEffectsToImportantCells()
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Apply LED effects to newly visible cells
        if let text = cell.textLabel?.text {
            switch text {
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                cell.contentView.addLEDEffect(
                    color: UIColor(hex: "#FF6482") ?? .systemPink,
                    intensity: 0.3,
                    spread: 10,
                    animated: true,
                    animationDuration: 3.0
                )
                
            case "Current Certificate":
                if let cert = CoreDataManager.shared.getCurrentCertificate() {
                    let isExpiring = isCertificateExpiringSoon(cert)
                    cell.contentView.addFlowingLEDEffect(
                        color: isExpiring ? .systemOrange : .systemGreen,
                        intensity: isExpiring ? 0.6 : 0.4,
                        width: 2,
                        speed: isExpiring ? 3.0 : 5.0
                    )
                }
                
            // Other cases as needed...
                
            default:
                break
            }
        }
    }
    
    private func safeInitialize() throws {
        // Initialize settings with error handling
        do {
            initializeTableData()
            setupNavigation()
            
            // Mark as initialized only if everything succeeds
            isInitialized = true
        } catch {
            isInitialized = false
            throw error
        }
    }

    // Separate method for initialization to make error handling clearer
    private func initializeTableData() {
        tableData = [
            aboutSection,
            displaySection,
            certificateSection,
            aiSection,
            terminalSection,
            logsSection,
            foldersSection,
            resetSection,
        ]

        sectionTitles = ["", "", "", "", "", "", "", ""]
        ensureTableDataHasSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Only reload if already initialized to prevent crashes
        if isInitialized {
            self.tableView.reloadData()
        } else {
            // If not initialized yet, trigger viewDidLoad again
            viewDidLoad()
        }
    }

    fileprivate func setupNavigation() {
        self.title = String.localized("TAB_SETTINGS")

        // Ensure the navigation bar is properly configured
        if let navController = navigationController {
            navController.navigationBar.prefersLargeTitles = true
            navController.navigationBar.tintColor = Preferences.appTintColor.uiColor
        }
    }

    // MARK: - ViewControllerRefreshable

    override func refreshContent() {
        // Only refresh if view is loaded and initialized
        if isViewLoaded && isInitialized {
            tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource & UITableViewDelegate overrides

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Safety check to prevent crashes
        guard isInitialized, section < tableData.count, tableData[section] != nil else {
            return 0
        }
        return tableData[section].count
    }

    override func numberOfSections(in _: UITableView) -> Int {
        // Safety check to prevent crashes
        guard isInitialized, tableData != nil else {
            return 0
        }
        return tableData.count
    }
    
    // Note: tableView:cellForRowAt: implementation moved to the extension below
}

extension SettingsViewController {
    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if Preferences.beta, section == 0 {
            return String.localized("SETTINGS_VIEW_CONTROLLER_SECTION_FOOTER_ISSUES")
        } else if !Preferences.beta, section == 1 {
            return String.localized("SETTINGS_VIEW_CONTROLLER_SECTION_FOOTER_ISSUES")
        }

        switch section {
            case sectionTitles.count - 1: 
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
                return "Backdoor \(appVersion) (\(buildNumber)) • iOS \(UIDevice.current.systemVersion)"
            default:
                return nil
        }
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = "Cell"
        let cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.accessoryType = .none
        cell.selectionStyle = .none

        let cellText = tableData[indexPath.section][indexPath.row]
        cell.textLabel?.text = cellText

        switch cellText {
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                cell.setAccessoryIcon(with: "info.circle")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SUBMIT_FEEDBACK"), String.localized("SETTINGS_VIEW_CONTROLLER_CELL_GITHUB"):
                cell.textLabel?.textColor = .tintColor
                cell.setAccessoryIcon(with: "safari")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"):
                cell.setAccessoryIcon(with: "paintbrush")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"):
                cell.setAccessoryIcon(with: "app.dashed")
                cell.selectionStyle = .default

            case "Current Certificate":
                if let hasGotCert = CoreDataManager.shared.getCurrentCertificate() {
                    let cell = CertificateViewTableViewCell()
                    cell.configure(with: hasGotCert, isSelected: false)
                    cell.selectionStyle = .none
                    return cell
                } else {
                    cell.textLabel?.text = String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CURRENT_CERTIFICATE_NOSELECTED")
                    cell.textLabel?.textColor = .secondaryLabel
                    cell.selectionStyle = .none
                }

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"):
                cell.setAccessoryIcon(with: "plus")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"):
                cell.setAccessoryIcon(with: "signature")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"):
                cell.setAccessoryIcon(with: "server.rack")
                cell.selectionStyle = .default
                
            case "Terminal":
                cell.setAccessoryIcon(with: "terminal")
                cell.selectionStyle = .default
                
            case "Terminal Settings":
                cell.setAccessoryIcon(with: "gear")
                cell.selectionStyle = .default
                
            case "Terminal Button":
                let isEnabled = UserDefaults.standard.bool(forKey: "show_terminal_button")
                let toggleSwitch = UISwitch()
                toggleSwitch.isOn = isEnabled
                toggleSwitch.onTintColor = .tintColor
                toggleSwitch.addTarget(self, action: #selector(terminalButtonToggled(_:)), for: .valueChanged)
                cell.accessoryView = toggleSwitch
                cell.selectionStyle = .none

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"):
                cell.setAccessoryIcon(with: "newspaper")
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"),
                 String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"):
                cell.accessoryType = .disclosureIndicator
                cell.textLabel?.textColor = .tintColor
                cell.selectionStyle = .default

            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"),
                 String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
                cell.textLabel?.textColor = .tintColor
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default

            default:
                break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let itemTapped = tableData[indexPath.section][indexPath.row]
        switch itemTapped {
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ABOUT", arguments: "Backdoor"):
                let l = AboutViewController()
                navigationController?.pushViewController(l, animated: true)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_GITHUB"):
                guard let url = URL(string: "https://github.com/khcrysalis/Backdoor") else {
                    backdoor.Debug.shared.log(message: "Invalid URL")
                    return
                }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SUBMIT_FEEDBACK"):
                guard let url = URL(string: "https://github.com/khcrysalis/Backdoor/issues") else {
                    backdoor.Debug.shared.log(message: "Invalid URL")
                    return
                }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_DISPLAY"):
                let l = DisplayViewController()
                navigationController?.pushViewController(l, animated: true)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APP_ICON"):
                let l = IconsListViewController()
                navigationController?.pushViewController(l, animated: true)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_ADD_CERTIFICATES"):
                let l = CertificatesViewController()
                navigationController?.pushViewController(l, animated: true)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SIGN_OPTIONS"):
                let signingDataWrapper = SigningDataWrapper(signingOptions: UserDefaults.standard.signingOptions)
                let l = SigningsOptionViewController(signingDataWrapper: signingDataWrapper)
                navigationController?.pushViewController(l, animated: true)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_SERVER_OPTIONS"):
                let l = ServerOptionsViewController()
                navigationController?.pushViewController(l, animated: true)
            case "AI Learning Settings":
                let l = AILearningSettingsViewController(style: .grouped)
                navigationController?.pushViewController(l, animated: true)
            case "AI Search Settings":
                let l = SearchSettingsViewController(style: .grouped)
                navigationController?.pushViewController(l, animated: true)
            case "Terminal":
                let l = TerminalViewController()
                let nav = UINavigationController(rootViewController: l)
                present(nav, animated: true)
            case "Terminal Settings":
                let l = TerminalSettingsViewController(style: .grouped)
                navigationController?.pushViewController(l, animated: true)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_VIEW_LOGS"):
                let l = LogsViewController()
                navigationController?.pushViewController(l, animated: true)
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_APPS_FOLDER"):
                openDirectory(named: "Apps")
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_CERTS_FOLDER"):
                openDirectory(named: "Certificates")
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET"):
                self.resetOptionsAction()
            case String.localized("SETTINGS_VIEW_CONTROLLER_CELL_RESET_ALL"):
                self.resetAllAction()
            default:
                break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension UITableViewCell {
    func setAccessoryIcon(with symbolName: String, tintColor: UIColor = .tertiaryLabel, renderingMode: UIImage.RenderingMode = .alwaysOriginal) {
        if let image = UIImage(systemName: symbolName)?.withTintColor(tintColor, renderingMode: renderingMode) {
            let imageView = UIImageView(image: image)
            self.accessoryView = imageView
        } else {
            self.accessoryView = nil
        }
    }
}

private extension SettingsViewController {
    func openDirectory(named directoryName: String) {
        let directoryURL = getDocumentsDirectory().appendingPathComponent(directoryName)
        let path = directoryURL.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")

        UIApplication.shared.open(URL(string: path)!, options: [:]) { success in
            if success {
                backdoor.Debug.shared.log(message: "File opened successfully.")
            } else {
                backdoor.Debug.shared.log(message: "Failed to open file.")
            }
        }
    }
    
    // Terminal button toggle handler moved to SettingsViewController+Terminal.swift
}
