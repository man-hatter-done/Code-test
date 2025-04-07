// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit

/// View controller for managing web search settings
class SearchSettingsViewController: UITableViewController {
    
    // MARK: - Properties
    
    private let cellReuseIdentifier = "SearchSettingCell"
    private let switchCellReuseIdentifier = "SearchSettingSwitchCell"
    private let labelCellReuseIdentifier = "SearchSettingLabelCell"
    
    // Privacy manager reference
    private let privacyManager = SearchPrivacyManager()
    
    // Section types
    private enum Section: Int {
        case info = 0
        case features = 1
        case privacy = 2
        case searchTypes = 3
        case exclusions = 4
        case resetSection = 5
    }
    
    // Default search depth option
    private var selectedDefaultDepth: SearchDepth = .enhanced {
        didSet {
            UserDefaults.standard.set(selectedDefaultDepth.rawValue, forKey: "default_search_depth")
        }
    }
    
    // Excluded domains
    private var excludedDomains: [String] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        loadSettings()
    }
    
    private func setupView() {
        title = "Search Settings"
        
        // Register cell types
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: switchCellReuseIdentifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: labelCellReuseIdentifier)
        
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        
        // Add done button
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }
    
    private func loadSettings() {
        // Load default search depth
        if let rawDepth = UserDefaults.standard.object(forKey: "default_search_depth") as? Int,
           let depth = SearchDepth(rawValue: rawDepth) {
            selectedDefaultDepth = depth
        } else {
            selectedDefaultDepth = .enhanced
            UserDefaults.standard.set(selectedDefaultDepth.rawValue, forKey: "default_search_depth")
        }
        
        // Load excluded domains
        excludedDomains = UserDefaults.standard.stringArray(forKey: "privacy_tracked_domains") ?? []
    }
    
    @objc private func doneTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .info:
            return 1
        case .features:
            return 3
        case .privacy:
            return 3
        case .searchTypes:
            return 4
        case .exclusions:
            return excludedDomains.isEmpty ? 1 : excludedDomains.count + 1
        case .resetSection:
            return 1
        case .none:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .info:
            return "About Web Search"
        case .features:
            return "Search Features"
        case .privacy:
            return "Privacy Settings"
        case .searchTypes:
            return "Specialized Search Types"
        case .exclusions:
            return "Domain Exclusions"
        case .resetSection:
            return nil
        case .none:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .info:
            return nil
        case .features:
            return "Default search depth affects how deeply the AI searches for information."
        case .privacy:
            return "Disable features to enhance privacy at the cost of search quality."
        case .searchTypes:
            return "Enable specialized search types for better academic, news, and technical results."
        case .exclusions:
            return "Domains added here will not be tracked or used for personalization."
        case .resetSection:
            return nil
        case .none:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            cell.textLabel?.text = "The AI search feature allows the assistant to find information on the web, with varying levels of depth and analysis."
            cell.textLabel?.numberOfLines = 0
            cell.selectionStyle = .none
            return cell
            
        case .features:
            if indexPath.row == 0 {
                // Default search depth
                let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
                cell.textLabel?.text = "Default Search Depth"
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = searchDepthString(for: selectedDefaultDepth)
                return cell
            } else if indexPath.row == 1 {
                // Personalized search
                let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! SwitchTableViewCell
                cell.textLabel?.text = "Personalized Search"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: "personalized_search_enabled")
                cell.switchValueChanged = { isOn in
                    UserDefaults.standard.set(isOn, forKey: "personalized_search_enabled")
                }
                return cell
            } else {
                // Deep search enabled
                let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! SwitchTableViewCell
                cell.textLabel?.text = "Enable Deep Search"
                cell.switchControl.isOn = privacyManager.isDeepSearchEnabled
                cell.switchValueChanged = { isOn in
                    self.privacyManager.updateSettings(deepSearchEnabled: isOn)
                }
                return cell
            }
            
        case .privacy:
            if indexPath.row == 0 {
                // Search enabled
                let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! SwitchTableViewCell
                cell.textLabel?.text = "Enable Web Search"
                cell.switchControl.isOn = privacyManager.isSearchEnabled
                cell.switchValueChanged = { isOn in
                    self.privacyManager.updateSettings(searchEnabled: isOn)
                    self.tableView.reloadSections(IndexSet(integer: Section.features.rawValue), with: .automatic)
                }
                return cell
            } else if indexPath.row == 1 {
                // Page crawling enabled
                let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! SwitchTableViewCell
                cell.textLabel?.text = "Allow Page Crawling"
                cell.switchControl.isOn = privacyManager.isCrawlingEnabled
                cell.switchControl.isEnabled = privacyManager.isSearchEnabled
                cell.textLabel?.isEnabled = privacyManager.isSearchEnabled
                cell.switchValueChanged = { isOn in
                    self.privacyManager.updateSettings(crawlingEnabled: isOn)
                }
                return cell
            } else {
                // Search caching
                let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! SwitchTableViewCell
                cell.textLabel?.text = "Cache Search Results"
                cell.switchControl.isOn = privacyManager.isSearchCachingEnabled
                cell.switchControl.isEnabled = privacyManager.isSearchEnabled
                cell.textLabel?.isEnabled = privacyManager.isSearchEnabled
                cell.switchValueChanged = { isOn in
                    self.privacyManager.updateSettings(cachingEnabled: isOn)
                }
                return cell
            }
            
        case .searchTypes:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellReuseIdentifier, for: indexPath) as! SwitchTableViewCell
            
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Academic Search"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: "academic_search_enabled")
                cell.switchValueChanged = { isOn in
                    UserDefaults.standard.set(isOn, forKey: "academic_search_enabled")
                }
            case 1:
                cell.textLabel?.text = "News Search"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: "news_search_enabled")
                cell.switchValueChanged = { isOn in
                    UserDefaults.standard.set(isOn, forKey: "news_search_enabled")
                }
            case 2:
                cell.textLabel?.text = "Technical Search"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: "technical_search_enabled")
                cell.switchValueChanged = { isOn in
                    UserDefaults.standard.set(isOn, forKey: "technical_search_enabled")
                }
            case 3:
                cell.textLabel?.text = "Reference Search"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: "reference_search_enabled")
                cell.switchValueChanged = { isOn in
                    UserDefaults.standard.set(isOn, forKey: "reference_search_enabled")
                }
            default:
                break
            }
            
            // Disable specialized searches if deep search is disabled
            cell.switchControl.isEnabled = privacyManager.isDeepSearchEnabled
            cell.textLabel?.isEnabled = privacyManager.isDeepSearchEnabled
            
            return cell
            
        case .exclusions:
            if indexPath.row == 0 {
                // Add domain button
                let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
                cell.textLabel?.text = "Add Domain to Exclusion List"
                cell.textLabel?.textColor = .systemBlue
                cell.accessoryType = .disclosureIndicator
                return cell
            } else {
                // Domain entry
                let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
                let domainIndex = indexPath.row - 1
                if domainIndex < excludedDomains.count {
                    cell.textLabel?.text = excludedDomains[domainIndex]
                    cell.textLabel?.textColor = .red
                }
                return cell
            }
            
        case .resetSection:
            let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
            cell.textLabel?.text = "Reset Search Settings"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = .systemRed
            return cell
            
        case .none:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section) {
        case .features:
            if indexPath.row == 0 {
                // Default search depth selection
                showSearchDepthPicker()
            }
            
        case .exclusions:
            if indexPath.row == 0 {
                // Add domain to exclusion list
                showAddDomainAlert()
            } else {
                // Remove domain from exclusion list
                let domainIndex = indexPath.row - 1
                if domainIndex < excludedDomains.count {
                    showRemoveDomainAlert(at: domainIndex)
                }
            }
            
        case .resetSection:
            showResetConfirmation()
            
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func searchDepthString(for depth: SearchDepth) -> String {
        switch depth {
        case .standard:
            return "Standard"
        case .enhanced:
            return "Enhanced"
        case .deep:
            return "Deep"
        case .specialized:
            return "Specialized"
        }
    }
    
    private func showSearchDepthPicker() {
        let alert = UIAlertController(title: "Default Search Depth", message: "Select the default depth for searches", preferredStyle: .actionSheet)
        
        let depths: [SearchDepth] = [.standard, .enhanced, .deep, .specialized]
        
        for depth in depths {
            let action = UIAlertAction(title: searchDepthString(for: depth), style: .default) { [weak self] _ in
                self?.selectedDefaultDepth = depth
                self?.tableView.reloadData()
            }
            
            // Mark current selection
            if depth == selectedDefaultDepth {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showAddDomainAlert() {
        let alert = UIAlertController(title: "Add Domain to Exclusion List", message: "Enter a domain name (e.g., example.com)", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Domain name"
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.keyboardType = .URL
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            if let domain = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !domain.isEmpty,
               let self = self {
                
                // Add domain to exclusion list
                if !self.excludedDomains.contains(domain) {
                    self.excludedDomains.append(domain)
                    UserDefaults.standard.set(self.excludedDomains, forKey: "privacy_tracked_domains")
                    self.tableView.reloadSections(IndexSet(integer: Section.exclusions.rawValue), with: .automatic)
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showRemoveDomainAlert(at index: Int) {
        guard index < excludedDomains.count else { return }
        
        let domain = excludedDomains[index]
        let alert = UIAlertController(title: "Remove Domain", message: "Remove '\(domain)' from the exclusion list?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            // Remove domain from exclusion list
            self.excludedDomains.remove(at: index)
            UserDefaults.standard.set(self.excludedDomains, forKey: "privacy_tracked_domains")
            self.tableView.reloadSections(IndexSet(integer: Section.exclusions.rawValue), with: .automatic)
        })
        
        present(alert, animated: true)
    }
    
    private func showResetConfirmation() {
        let alert = UIAlertController(title: "Reset Search Settings", message: "This will restore all search settings to their default values. This cannot be undone.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.resetSearchSettings()
        })
        
        present(alert, animated: true)
    }
    
    private func resetSearchSettings() {
        // Reset default search depth
        selectedDefaultDepth = .enhanced
        UserDefaults.standard.set(selectedDefaultDepth.rawValue, forKey: "default_search_depth")
        
        // Reset privacy settings
        privacyManager.updateSettings(
            searchEnabled: true,
            deepSearchEnabled: true,
            crawlingEnabled: true,
            cachingEnabled: true
        )
        
        // Reset specialized search types
        UserDefaults.standard.set(true, forKey: "academic_search_enabled")
        UserDefaults.standard.set(true, forKey: "news_search_enabled")
        UserDefaults.standard.set(true, forKey: "technical_search_enabled")
        UserDefaults.standard.set(true, forKey: "reference_search_enabled")
        
        // Reset personalized search
        UserDefaults.standard.set(true, forKey: "personalized_search_enabled")
        
        // Clear domain exclusions
        excludedDomains = []
        UserDefaults.standard.set(excludedDomains, forKey: "privacy_tracked_domains")
        
        // Reload table
        tableView.reloadData()
    }
}

// Implementation moved to shared SwitchTableViewCell.swift
