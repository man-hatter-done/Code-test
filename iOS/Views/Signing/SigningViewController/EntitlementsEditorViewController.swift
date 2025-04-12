// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import UIKit

/// View controller for editing custom entitlements during app signing
class EntitlementsEditorViewController: FRSITableViewController {
    
    // MARK: - Properties
    
    /// User's custom entitlements
    private var entitlements: [Entitlement] = [] {
        didSet {
            saveEntitlementsToSigningOptions()
        }
    }
    
    /// Toolbar items
    private var addButton: UIBarButtonItem!
    private var quickAddButton: UIBarButtonItem!
    
    /// Search controller for filtering entitlements
    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = "Search Entitlements"
        return controller
    }()
    
    /// Filtered entitlements for search
    private var filteredEntitlements: [Entitlement] = []
    
    /// Flag to indicate if search is active
    private var isSearching: Bool {
        return searchController.isActive && !(searchController.searchBar.text?.isEmpty ?? true)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load entitlements from signing options
        loadEntitlementsFromSigningOptions()
        
        // Configure UI
        configureNavigationBar()
        configureTableView()
        
        // Apply LED effects to search bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.applyLEDEffectsToSearchBar()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure navigation bar is visible and properly styled
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Apply LED effects
        applyLEDEffectsToTableView()
    }
    
    // MARK: - UI Configuration
    
    private func configureNavigationBar() {
        title = "Custom Entitlements"
        
        // Add buttons
        addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(addEntitlementTapped)
        )
        
        quickAddButton = UIBarButtonItem(
            image: UIImage(systemName: "bolt.fill"),
            style: .plain,
            target: self,
            action: #selector(quickAddTapped)
        )
        
        navigationItem.rightBarButtonItems = [addButton, quickAddButton]
        
        // Add search controller
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    private func configureTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "EntitlementCell")
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = .systemBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        
        // Empty state message
        updateEmptyStateIfNeeded()
    }
    
    private func applyLEDEffectsToTableView() {
        // Add subtle LED glow to section headers
        for section in 0..<tableView.numberOfSections {
            if let headerView = tableView.headerView(forSection: section) {
                headerView.applyEntitlementHeaderStyle()
            }
        }
        
        // Apply effects to visible cells
        for cell in tableView.visibleCells {
            applyCellLEDEffect(cell, animated: true)
        }
    }
    
    private func applyLEDEffectsToSearchBar() {
        // Find the search bar's text field
        if let textField = searchController.searchBar.value(forKey: "searchField") as? UITextField {
            textField.applyEntitlementFieldStyle()
            
            // Reduce animation intensity for better readability
            if let animations = textField.layer.animations {
                if let borderAnimation = animations["borderColor"] as? CABasicAnimation {
                    borderAnimation.fromValue = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
                    borderAnimation.toValue = UIColor.systemBlue.withAlphaComponent(0.4).cgColor
                }
            }
        }
    }
    
    private func applyCellLEDEffect(_ cell: UITableViewCell, animated: Bool) {
        // Add a subtle LED effect to the cell
        cell.contentView.addLEDEffect(
            color: UIColor.systemBlue,
            intensity: 0.2,
            spread: 8,
            animated: animated,
            animationDuration: 3.0
        )
    }
    
    private func updateEmptyStateIfNeeded() {
        let displayedEntitlements = isSearching ? filteredEntitlements : entitlements
        
        // Get or create empty state label
        let emptyStateTag = 1001
        let emptyLabel: UILabel
        
        if let existing = tableView.viewWithTag(emptyStateTag) as? UILabel {
            emptyLabel = existing
        } else {
            emptyLabel = UILabel()
            emptyLabel.tag = emptyStateTag
            emptyLabel.textAlignment = .center
            emptyLabel.numberOfLines = 0
            emptyLabel.font = .systemFont(ofSize: 16)
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            tableView.addSubview(emptyLabel)
            
            NSLayoutConstraint.activate([
                emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -40),
                emptyLabel.leadingAnchor.constraint(equalTo: tableView.leadingAnchor, constant: 40),
                emptyLabel.trailingAnchor.constraint(equalTo: tableView.trailingAnchor, constant: -40)
            ])
        }
        
        // Show/hide and configure the label
        if displayedEntitlements.isEmpty {
            if isSearching {
                emptyLabel.text = "No matching entitlements found"
            } else {
                emptyLabel.text = "No custom entitlements configured\n\nTap + to add an entitlement or use Quick Add for common options"
            }
            emptyLabel.isHidden = false
            
            // Add LED glow to empty state message
            emptyLabel.addLEDEffect(
                color: UIColor.systemBlue,
                intensity: 0.3,
                spread: 12,
                animated: true,
                animationDuration: 2.5
            )
        } else {
            emptyLabel.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func addEntitlementTapped() {
        showEntitlementEditor()
    }
    
    @objc private func quickAddTapped() {
        // Create action sheet with common entitlements
        let alertController = UIAlertController(
            title: "Add Common Entitlement",
            message: "Select an entitlement to add",
            preferredStyle: .actionSheet
        )
        
        // Add actions for common entitlements
        for entitlement in CommonEntitlements.all {
            let action = UIAlertAction(title: entitlement.key, style: .default) { [weak self] _ in
                self?.showEntitlementEditor(preset: entitlement)
            }
            alertController.addAction(action)
        }
        
        // Add cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alertController.popoverPresentationController {
            popover.barButtonItem = quickAddButton
        }
        
        present(alertController, animated: true)
    }
    
    private func showEntitlementEditor(preset: Entitlement? = nil, editingIndex: Int? = nil) {
        let alertController = UIAlertController(
            title: editingIndex != nil ? "Edit Entitlement" : "Add Entitlement",
            message: nil,
            preferredStyle: .alert
        )
        
        // Add text fields
        alertController.addTextField { textField in
            textField.placeholder = "Key (e.g. com.apple.developer.networking.wifi-info)"
            if let preset = preset {
                textField.text = preset.key
            } else if let index = editingIndex {
                let entitlement = self.isSearching ? self.filteredEntitlements[index] : self.entitlements[index]
                textField.text = entitlement.key
            }
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Value (e.g. true, string, [array])"
            if let preset = preset {
                textField.text = preset.stringValue
            } else if let index = editingIndex {
                let entitlement = self.isSearching ? self.filteredEntitlements[index] : self.entitlements[index]
                textField.text = entitlement.stringValue
            }
        }
        
        // Add actions
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self, weak alertController] _ in
            guard let self = self,
                  let keyField = alertController?.textFields?[0],
                  let valueField = alertController?.textFields?[1],
                  let key = keyField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let value = valueField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !key.isEmpty, !value.isEmpty else {
                return
            }
            
            let newEntitlement = Entitlement(key: key, stringValue: value)
            
            if let editingIndex = editingIndex {
                if self.isSearching {
                    // Find the actual index in the entitlements array
                    if let filteredEntitlement = self.filteredEntitlements[safe: editingIndex],
                       let actualIndex = self.entitlements.firstIndex(where: { $0.id == filteredEntitlement.id }) {
                        self.entitlements[actualIndex] = newEntitlement
                    }
                } else {
                    self.entitlements[editingIndex] = newEntitlement
                }
            } else {
                // Add new entitlement
                self.entitlements.append(newEntitlement)
            }
            
            // Reload table
            self.tableView.reloadData()
            self.updateEmptyStateIfNeeded()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    // MARK: - Data Methods
    
    private func loadEntitlementsFromSigningOptions() {
        // Get entitlements dictionary from signing options
        if let entitlementsDict = signingDataWrapper.signingOptions.customEntitlements {
            // Convert dictionary to array of Entitlement objects
            entitlements = entitlementsDict.map { key, value in
                Entitlement(key: key, stringValue: String(describing: value))
            }
        } else {
            entitlements = []
        }
    }
    
    private func saveEntitlementsToSigningOptions() {
        // Convert array of Entitlement objects to dictionary
        var entitlementsDict: [String: Any] = [:]
        for entitlement in entitlements {
            entitlementsDict[entitlement.key] = entitlement.toPlistValue()
        }
        
        // Save to signing options
        signingDataWrapper.signingOptions.customEntitlements = entitlementsDict.isEmpty ? nil : entitlementsDict
    }
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = isSearching ? filteredEntitlements.count : entitlements.count
        updateEmptyStateIfNeeded()
        return count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EntitlementCell", for: indexPath)
        let displayedEntitlements = isSearching ? filteredEntitlements : entitlements
        
        if let entitlement = displayedEntitlements[safe: indexPath.row] {
            // Configure cell
            var content = cell.defaultContentConfiguration()
            content.text = entitlement.key
            content.secondaryText = entitlement.stringValue
            content.secondaryTextProperties.color = entitlement.isValid ? .secondaryLabel : .systemRed
            cell.contentConfiguration = content
            
            // Add LED effect
            applyCellLEDEffect(cell, animated: false)
            
            // Add validation visual indicator
            if !entitlement.isValid {
                cell.contentView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            } else {
                cell.contentView.backgroundColor = .clear
            }
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showEntitlementEditor(editingIndex: indexPath.row)
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Create delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }
            
            if self.isSearching {
                // Find the actual index in the entitlements array
                if let filteredEntitlement = self.filteredEntitlements[safe: indexPath.row],
                   let actualIndex = self.entitlements.firstIndex(where: { $0.id == filteredEntitlement.id }) {
                    self.entitlements.remove(at: actualIndex)
                    self.filterEntitlements(with: self.searchController.searchBar.text ?? "")
                }
            } else {
                self.entitlements.remove(at: indexPath.row)
            }
            
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.updateEmptyStateIfNeeded()
            completion(true)
        }
        
        // Configure delete action
        deleteAction.image = UIImage(systemName: "trash.fill")
        deleteAction.backgroundColor = .systemRed
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let label = UILabel()
        label.text = "Custom Entitlements"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])
        
        // Add pulsing LED effect to header
        headerView.addLEDEffect(
            color: UIColor.systemBlue,
            intensity: 0.3,
            spread: 10,
            animated: true,
            animationDuration: 2.0
        )
        
        return headerView
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
}

// MARK: - UISearchResultsUpdating

extension EntitlementsEditorViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterEntitlements(with: searchController.searchBar.text ?? "")
    }
    
    private func filterEntitlements(with searchText: String) {
        if searchText.isEmpty {
            filteredEntitlements = entitlements
        } else {
            filteredEntitlements = entitlements.filter { entitlement in
                return entitlement.key.localizedCaseInsensitiveContains(searchText) ||
                       entitlement.stringValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        tableView.reloadData()
        updateEmptyStateIfNeeded()
    }
}

// MARK: - Safe Array Access Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - SigningDataWrapper Extension

extension SigningDataWrapper.SigningOptions {
    /// Custom entitlements dictionary
    var customEntitlements: [String: Any]? {
        get {
            return additionalData["customEntitlements"] as? [String: Any]
        }
        set {
            if additionalData == nil {
                additionalData = [:]
            }
            additionalData?["customEntitlements"] = newValue
        }
    }
}
