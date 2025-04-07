// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import Foundation
import UIKit

// MARK: - SearchResultsTableViewController

class SearchResultsTableViewController: UIViewController,
                                        UISearchResultsUpdating,
                                        UITableViewDataSource,
                                        UITableViewDelegate {
    // MARK: - Properties
    
    var tableView: UITableView!
    var sources: [Source] = []
    var fetchedSources: [URL: SourcesData] = [:]
    var filteredSources: [SourcesData: [StoreAppsData]] = [:]
    var sourceURLMapping: [SourcesData: URL] = [:]
    private var dataFetched = false
    private var activityIndicator: UIActivityIndicatorView!

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupActivityIndicator()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchAppsForSources()
    }
    
    // MARK: - UI Setup
    
    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .background
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.center = CGPoint(x: view.center.x, y: view.center.y)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
    }

    // MARK: - UITableViewDataSource
    
    func numberOfSections(in _: UITableView) -> Int { 
        return filteredSources.keys.count 
    }
    
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let source = Array(filteredSources.keys)[section]
        return filteredSources[source]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        configureCell(cell, at: indexPath, in: tableView)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat { 
        return 40 
    }
    
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let source = Array(filteredSources.keys)[section]
        let header = SearchAppSectionHeader(title: source.name ?? "Unknown", icon: UIImage(named: "unknown"))
        let iconURL = source.iconURL ?? source.apps.first?.iconURL
        loadAndSetImage(from: iconURL, for: header)
        return header
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presentAppDetail(for: indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Cell Configuration
    
    private func configureCell(_ cell: UITableViewCell, at indexPath: IndexPath, in tableView: UITableView) {
        let source = Array(filteredSources.keys)[indexPath.section]
        let app = filteredSources[source]?[indexPath.row]

        // Configure app name
        var appname = app?.name ?? String.localized("UNKNOWN")
        if app?.bundleIdentifier.hasSuffix("Beta") == true {
            appname += " (Beta)"
        }
        cell.textLabel?.text = appname

        // Configure subtitle
        let appVersion = (app?.versions?.first?.version ?? app?.version) ?? "1.0"
        let appSubtitle = app?.subtitle ?? 
                         (app?.localizedDescription ?? String.localized("SOURCES_CELLS_DEFAULT_SUBTITLE"))
        let displayText = appVersion + " • " + appSubtitle

        cell.detailTextLabel?.text = displayText
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.accessoryType = .disclosureIndicator

        // Configure image
        configureImageView(for: cell, with: app, at: indexPath, in: tableView)
    }
    
    private func configureImageView(
        for cell: UITableViewCell,
        with app: StoreAppsData?,
        at indexPath: IndexPath,
        in tableView: UITableView
    ) {
        let placeholderImage = UIImage(named: "unknown")
        let imageSize = CGSize(width: 30, height: 30)

        func setImage(_ image: UIImage?) {
            let resizedImage = UIGraphicsImageRenderer(size: imageSize).image { _ in
                image?.draw(in: CGRect(origin: .zero, size: imageSize))
            }
            cell.imageView?.image = resizedImage
            cell.imageView?.layer.cornerRadius = 7
            cell.imageView?.layer.cornerCurve = .continuous
            cell.imageView?.layer.borderWidth = 1
            cell.imageView?.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
            cell.imageView?.clipsToBounds = true
        }

        setImage(placeholderImage)

        if let iconURL = app?.iconURL {
            SectionIcons.loadImageFromURL(from: iconURL) { image in
                DispatchQueue.main.async {
                    if tableView.indexPath(for: cell) == indexPath {
                        setImage(image)
                    }
                }
            }
        }
    }
    
    // MARK: - App Detail Presentation
    
    private func presentAppDetail(for indexPath: IndexPath) {
        let source = Array(filteredSources.keys)[indexPath.section]
        let app = filteredSources[source]?[indexPath.row]

        guard let url = sourceURLMapping[source] else { return }
        
        let savc = SourceAppViewController()
        savc.name = source.name
        savc.uri = [url]

        savc.highlightAppName = app?.name
        savc.highlightBundleID = app?.bundleIdentifier
        savc.highlightVersion = app?.version ?? app?.versions?[0].version
        savc.highlightDeveloperName = app?.developerName
        savc.highlightDescription = app?.localizedDescription

        let navigationController = UINavigationController(rootViewController: savc)

        if let presentationController = navigationController.presentationController as? UISheetPresentationController {
            presentationController.detents = [.medium(), .large()]
        }

        present(navigationController, animated: true)
    }

    // MARK: - Header Setup
    
    private func loadAndSetImage(from url: URL?, for header: SearchAppSectionHeader) {
        guard let url = url else {
            header.setIcon(with: UIImage(named: "unknown"))
            return
        }
        SectionIcons.loadImageFromURL(from: url) { image in
            header.setIcon(with: image ?? UIImage(named: "unknown"))
        }
    }

    // MARK: - UISearchResultsUpdating
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !dataFetched { 
            fetchAppsForSources() 
        }

        filteredSources.removeAll()

        if searchText.isEmpty {
            for (_, source) in fetchedSources {
                filteredSources[source] = source.apps
            }
        } else {
            for (_, source) in fetchedSources {
                let matchingApps = source.apps.filter { app in
                    app.name.localizedCaseInsensitiveContains(searchText)
                }
                if !matchingApps.isEmpty {
                    filteredSources[source] = matchingApps
                }
            }
        }
        tableView.reloadData()
    }

    // MARK: - Data Fetching
    
    private func fetchAppsForSources() {
        let dispatchGroup = DispatchGroup()
        var allSources: [URL: SourcesData] = [:]
        sourceURLMapping.removeAll()

        for source in sources {
            guard let url = source.sourceURL else { continue }

            dispatchGroup.enter()
            DispatchQueue.global(qos: .background).async {
                SourceGET().downloadURL(from: url) { result in
                    switch result {
                    case let .success((data, _)):
                        switch SourceGET().parse(data: data) {
                        case let .success(sourceData):
                            allSources[url] = sourceData
                            self.sourceURLMapping[sourceData] = url
                        case let .failure(error):
                            Debug.shared.log(message: "Error parsing data: \(error)")
                        }
                    case let .failure(error):
                        Debug.shared.log(message: "Error downloading data: \(error)")
                    }
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.fetchedSources = allSources
            self.dataFetched = true
            
            UIView.transition(
                with: self.tableView,
                duration: 0.3,
                options: .transitionCrossDissolve,
                animations: {
                    self.tableView.reloadData()
                    self.activityIndicator.stopAnimating()
                }
            )
        }
    }
}
