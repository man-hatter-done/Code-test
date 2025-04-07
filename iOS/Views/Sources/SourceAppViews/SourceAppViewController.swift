// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import AlertKit
import CoreData
import Nuke
import SwiftUI
import UIKit

// MARK: - SortOption

enum SortOption: String, Codable {
    case `default`
    case name
    case date
}

// MARK: - SourceAppViewController

class SourceAppViewController: UITableViewController {
    // MARK: - Properties
    
    var newsData: [NewsData] = []
    var apps: [StoreAppsData] = []
    var oApps: [StoreAppsData] = []
    var filteredApps: [StoreAppsData] = []

    var name: String? { didSet { self.title = name } }
    var uri: [URL]!

    var highlightAppName: String?
    var highlightBundleID: String?
    var highlightVersion: String?
    var highlightDeveloperName: String?
    var highlightDescription: String?

    var sortActionsGroup: UIMenu?

    private let sourceGET = SourceGET()

    public var searchController: UISearchController!

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Initialization
    
    init() { super.init(style: .plain) }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupSearchController()
        setupViews()
        loadAppsData()
    }

    // MARK: - Setup Methods
    
    fileprivate func setupViews() {
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.tableHeaderView = UIView()
        self.tableView.register(AppTableViewCell.self, forCellReuseIdentifier: "AppTableViewCell")
        self.navigationItem.titleView = activityIndicator
        self.activityIndicator.startAnimating()
    }

    private func setupHeader() {
        guard uri.count == 1, !newsData.isEmpty else { return }
        
        let headerView = UIHostingController(rootView: NewsCardsScrollView(newsData: newsData))
        headerView.view.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 170)
        tableView.tableHeaderView = headerView.view

        addChild(headerView)
        headerView.didMove(toParent: self)
    }
    
    fileprivate func setupNavigation() {
        self.navigationItem.largeTitleDisplayMode = .never
    }

    // MARK: - Filter Menu
    
    private func updateFilterMenu() {
        let filterMenu = UIMenu(
            title: String.localized("SOURCES_CELLS_ACTIONS_FILTER_TITLE"),
            children: createSubSortMenu()
        )
        let filterButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease"),
            menu: filterMenu
        )

        self.navigationItem.rightBarButtonItem = filterButton
    }

    private func createSubSortMenu() -> [UIMenuElement] {
        let sortByDAction = createSortAction(
            title: String.localized("SOURCES_CELLS_ACTIONS_FILTER_BY_DEFAULT"),
            sortOption: .default
        )
        let sortByNameAction = createSortAction(
            title: String.localized("SOURCES_CELLS_ACTIONS_FILTER_BY_NAME"),
            sortOption: .name
        )
        let sortBySizeAction = createSortAction(
            title: String.localized("SOURCES_CELLS_ACTIONS_FILTER_BY_DATE"),
            sortOption: .date
        )

        let sortMenu = UIMenu(
            title: "",
            image: nil,
            identifier: nil,
            options: .displayInline,
            children: [sortByDAction, sortByNameAction, sortBySizeAction]
        )

        return [sortMenu]
    }

    private func createSortAction(title: String, sortOption: SortOption) -> UIAction {
        return UIAction(
            title: title,
            image: arrowImage(for: sortOption),
            identifier: UIAction.Identifier("sort\(title)"),
            state: Preferences.currentSortOption == sortOption ? .on : .off,
            handler: { [weak self] _ in
                self?.handleSortOptionSelected(sortOption)
            }
        )
    }
    
    private func handleSortOptionSelected(_ sortOption: SortOption) {
        if Preferences.currentSortOption == sortOption {
            Preferences.currentSortOptionAscending.toggle()
        } else {
            Preferences.currentSortOption = sortOption
            updateSortOrderImage(for: sortOption)
        }
        applyFilter()
    }

    /// Arrow images for Sort options
    func arrowImage(for sortOption: SortOption) -> UIImage? {
        let isAscending = Preferences.currentSortOptionAscending
        let imageName = isAscending ? "chevron.up" : "chevron.down"
        return sortOption == Preferences.currentSortOption ? UIImage(systemName: imageName) : nil
    }

    func updateSortOrderImage(for sortOption: SortOption) {
        guard let sortActionsGroup = sortActionsGroup else {
            print("sortActionsGroup is nil")
            return
        }

        for case let action as UIAction in sortActionsGroup.children {
            if action.identifier == UIAction.Identifier("sort\(sortOption)") {
                action.image = arrowImage(for: sortOption)
            }
        }
    }

    // MARK: - Filtering & Sorting
    
    func applyFilter() {
        let sortOption = Preferences.currentSortOption
        let ascending = Preferences.currentSortOptionAscending

        switch sortOption {
        case .default:
            apps = ascending ? oApps : oApps.reversed()
        case .name:
            apps = apps.sorted { ascending ? $0.name < $1.name : $0.name > $1.name }
        case .date:
            apps = sortAppsByDate(ascending: ascending)
        }

        reloadTableWithAnimation()
        updateFilterMenu()
    }
    
    private func sortAppsByDate(ascending: Bool) -> [StoreAppsData] {
        return apps.sorted { app1, app2 in
            let date1 = app1.versions?.first?.date ?? app1.versionDate
            let date2 = app2.versions?.first?.date ?? app2.versionDate

            if date1 == nil && date2 == nil { return ascending }

            guard let date1 = date1, let date2 = date2 else {
                return date1 != nil
            }

            return ascending ? date1 > date2 : date1 < date2
        }
    }
    
    private func reloadTableWithAnimation() {
        UIView.transition(
            with: tableView,
            duration: 0.3, 
            options: .transitionCrossDissolve,
            animations: { self.tableView.reloadData() }
        )
    }

    // MARK: - App Filtering
    
    private func shouldFilter() -> StoreAppsData? {
        guard let name = highlightAppName,
              let id = highlightBundleID,
              let version = highlightVersion,
              let desc = highlightDescription else {
            return nil
        }

        return filterApps(
            from: apps,
            name: name,
            id: id,
            version: version,
            desc: desc,
            devname: highlightDeveloperName
        ).first
    }

    private func filterApps(
        from apps: [StoreAppsData],
        name: String,
        id: String,
        version: String,
        desc: String,
        devname: String?
    ) -> [StoreAppsData] {
        return apps.filter { app in
            app.name == name &&
            app.bundleIdentifier == id &&
            app.version == version &&
            app.localizedDescription == desc &&
            (devname == nil || app.developerName == devname)
        }
    }

    // MARK: - Data Loading
    
    private func loadAppsData() {
        guard let urls = uri else { return }
        
        let dispatchGroup = DispatchGroup()
        var allApps: [StoreAppsData] = []
        var newsData: [NewsData] = []
        var website = ""
        var tintColor = ""

        // Fetch data from each URL
        for uri in urls {
            dispatchGroup.enter()
            fetchDataFromURL(uri, into: &allApps, newsData: &newsData, website: &website, tintColor: &tintColor) {
                dispatchGroup.leave()
            }
        }

        // Process data when all fetches complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.processLoadedAppData(
                allApps: allApps,
                newsData: newsData,
                website: website,
                tintColor: tintColor
            )
        }
    }
    
    private func fetchDataFromURL(
        _ uri: URL,
        into allApps: inout [StoreAppsData],
        newsData: inout [NewsData],
        website: inout String,
        tintColor: inout String,
        completion: @escaping () -> Void
    ) {
        sourceGET.downloadURL(from: uri) { [weak self] result in
            switch result {
            case let .success((data, _)):
                if let parseResult = self?.sourceGET.parse(data: data),
                   case let .success(sourceData) = parseResult {
                    allApps.append(contentsOf: sourceData.apps)
                    newsData.append(contentsOf: sourceData.news ?? [])
                    tintColor = sourceData.tintColor ?? ""
                    website = sourceData.website ?? ""
                }
            case let .failure(error):
                Debug.shared.log(message: "Error fetching data from \(uri): \(error.localizedDescription)")
            }
            
            completion()
        }
    }
    
    private func processLoadedAppData(
        allApps: [StoreAppsData],
        newsData: [NewsData],
        website: String,
        tintColor: String
    ) {
        // Store the loaded data
        self.apps = allApps
        self.oApps = allApps
        self.newsData = newsData

        // Setup the UI with loaded data
        setupHeader()
        applyTintColor(tintColor)
        filterAppsIfNeeded()
        setupWebsiteTitleMenu(website: website)
        finishLoading()
    }
    
    private func applyTintColor(_ tintColor: String) {
        if !tintColor.isEmpty {
            self.view.tintColor = UIColor(hex: tintColor)
        }
    }
    
    private func filterAppsIfNeeded() {
        if let filteredApp = shouldFilter() {
            self.apps = [filteredApp]
        } else {
            applyFilter()
        }
    }
    
    private func setupWebsiteTitleMenu(website: String) {
        guard uri.count == 1, !website.isEmpty else { return }
        
        let children = [
            UIAction(title: "Visit Website", image: UIImage(systemName: "globe")) { _ in
                if let url = URL(string: website) {
                    UIApplication.shared.open(url)
                }
            }
        ]

        let menu = UIMenu(children: children)

        if #available(iOS 16.0, *) {
            self.navigationItem.titleMenuProvider = { _ in menu }
        }
    }
    
    private func finishLoading() {
        UIView.transition(
            with: self.tableView,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: {
                self.activityIndicator.stopAnimating()
                self.navigationItem.titleView = nil
                
                if self.highlightAppName == nil {
                    self.updateFilterMenu()
                }
                
                self.tableView.reloadData()
            }
        )
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension SourceAppViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return isFiltering ? filteredApps.count : apps.count
    }

    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let app = isFiltering ? filteredApps[indexPath.row] : apps[indexPath.row]
        
        if let screenshotURLs = app.screenshotURLs,
           !screenshotURLs.isEmpty,
           Preferences.appDescriptionAppearence != 2 {
            return 322
        } else if Preferences.appDescriptionAppearence == 2 {
            return UITableView.automaticDimension
        } else {
            return 72
        }
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = AppTableViewCell(style: .subtitle, reuseIdentifier: "RoundedBackgroundCell")
        let app = isFiltering ? filteredApps[indexPath.row] : apps[indexPath.row]
        
        // Configure cell
        configureCell(cell, with: app, at: indexPath)
        
        return cell
    }
    
    private func configureCell(_ cell: AppTableViewCell, with app: StoreAppsData, at indexPath: IndexPath) {
        cell.configure(with: app)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        
        // Configure button
        cell.getButton.tag = indexPath.row
        cell.getButton.addTarget(self, action: #selector(getButtonTapped(_:)), for: .touchUpInside)
        
        // Add long press gesture
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(getButtonHold(_:)))
        cell.getButton.addGestureRecognizer(longPressGesture)
        cell.getButton.longPressGestureRecognizer = longPressGesture
    }

    override func tableView(
        _: UITableView, 
        contextMenuConfigurationForRowAt indexPath: IndexPath, 
        point _: CGPoint
    ) -> UIContextMenuConfiguration? {
        let app = isFiltering ? filteredApps[indexPath.row] : apps[indexPath.row]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            return self.createContextMenu(for: app)
        }
    }
    
    private func createContextMenu(for app: StoreAppsData) -> UIMenu {
        // Create version actions
        let versionActions = app.versions?.map { version in
            UIAction(
                title: "\(version.version)",
                image: UIImage(systemName: "doc.on.clipboard")
            ) { _ in
                UIPasteboard.general.string = version.downloadURL.absoluteString
            }
        } ?? []

        // Create versions menu
        let versionsMenu = UIMenu(
            title: "Other Download Links",
            image: UIImage(systemName: "list.bullet"),
            children: versionActions
        )

        // Create latest action
        let latestAction = UIAction(
            title: "Copy Latest Download Link",
            image: UIImage(systemName: "doc.on.clipboard")
        ) { _ in
            let downloadURL = app.downloadURL?.absoluteString ?? app.versions?[0].downloadURL.absoluteString
            UIPasteboard.general.string = downloadURL
        }

        return UIMenu(title: "", children: [latestAction, versionsMenu])
    }

    override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        if isFiltering || apps.isEmpty || (highlightAppName != nil) {
            return nil
        }
        
        return String.localized(
            apps.count > 1 ? "SOURCES_APP_VIEW_CONTROLLER_NUMBER_OF_APPS_PLURAL" : "SOURCES_APP_VIEW_CONTROLLER_NUMBER_OF_APPS",
            arguments: "\(apps.count)"
        )
    }
}

// MARK: - Search Controller

extension SourceAppViewController: UISearchControllerDelegate, UISearchBarDelegate {
    func setupSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.searchBar.placeholder = String.localized("SOURCES_APP_VIEW_CONTROLLER_SEARCH_APPS")
        
        if highlightAppName == nil {
            navigationItem.searchController = searchController
            definesPresentationContext = true
            navigationItem.hidesSearchBarWhenScrolling = true
        }
    }

    var isFiltering: Bool {
        return searchController.isActive && !searchBarIsEmpty
    }

    var searchBarIsEmpty: Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
}

// MARK: - UISearchResultsUpdating

extension SourceAppViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterContentForSearchText(searchText)
        tableView.reloadData()
    }

    private func filterContentForSearchText(_ searchText: String) {
        let lowercasedSearchText = searchText.lowercased()

        filteredApps = apps.filter { app in
            return doesApp(app, matchSearchText: lowercasedSearchText)
        }
    }
    
    private func doesApp(_ app: StoreAppsData, matchSearchText searchText: String) -> Bool {
        let nameMatch = app.name.lowercased().contains(searchText)
        let bundleIdMatch = app.bundleIdentifier.lowercased().contains(searchText)
        let developerMatch = app.developerName?.lowercased().contains(searchText) ?? false
        let subtitleMatch = app.subtitle?.lowercased().contains(searchText) ?? false
        let descriptionMatch = app.localizedDescription?.lowercased().contains(searchText) ?? false
        
        return nameMatch || bundleIdMatch || developerMatch || subtitleMatch || descriptionMatch
    }
}
