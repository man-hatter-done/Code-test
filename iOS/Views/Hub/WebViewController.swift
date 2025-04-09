// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly
// permitted under the terms of the Proprietary Software License.

import UIKit
import WebKit
import SafariServices

/// Enhanced WebViewController for BDG Hub with modern UI and features
class WebViewController: UIViewController, WKNavigationDelegate, UIScrollViewDelegate {
    // MARK: - UI Components
    
    /// Configured WebView with enhanced settings
    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.backgroundColor = .systemBackground
        return webView
    }()
    
    /// Progress indicator for page loading
    private let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = UIColor(hex: "#FF6482") // Pink accent color
        progressView.trackTintColor = UIColor.systemGray.withAlphaComponent(0.2)
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 1.5) // Slightly taller
        progressView.alpha = 0
        return progressView
    }()
    
    /// Pull-to-refresh control
    private let refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .systemGray
        return refreshControl
    }()
    
    /// Container for floating navigation buttons
    private let floatingButtonsContainer: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        container.layer.cornerRadius = 20
        container.layer.shadowColor = UIColor.black.withAlphaComponent(0.2).cgColor
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 6
        container.layer.shadowOpacity = 1
        return container
    }()
    
    /// Blur effect for the floating buttons
    private let blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 20
        blurView.layer.masksToBounds = true
        return blurView
    }()
    
    /// Back navigation button
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.left", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.layer.cornerRadius = 15
        return button
    }()
    
    /// Forward navigation button
    private let forwardButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.right", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.layer.cornerRadius = 15
        return button
    }()
    
    /// Reload page button
    private let reloadButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.layer.cornerRadius = 15
        return button
    }()
    
    /// Share button
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.layer.cornerRadius = 15
        return button
    }()
    
    /// Open in browser button
    private let browserButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "safari", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.layer.cornerRadius = 15
        return button
    }()
    
    /// Stack view for floating buttons
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 15
        return stackView
    }()
    
    /// Search bar for URL input and search
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search or enter URL"
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .go
        
        // Improve appearance
        searchBar.searchTextField.backgroundColor = UIColor.secondarySystemBackground
        searchBar.searchTextField.layer.cornerRadius = 10
        searchBar.searchTextField.font = UIFont.systemFont(ofSize: 15)
        
        return searchBar
    }()
    
    // MARK: - Properties
    
    private var progressObservation: NSKeyValueObservation?
    private var floatingButtonsBottomConstraint: NSLayoutConstraint?
    private var showingButtons = true
    private var lastContentOffset: CGFloat = 0
    private var homeURL = URL(string: "https://backdoor-bdg.store")!
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupUI()
        setupNavigationBar()
        setupObservers()
        loadWebsite()
        
        // Set up delegates
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        searchBar.delegate = self
        
        // Set up button actions
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        reloadButton.addTarget(self, action: #selector(reloadPage), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(sharePage), for: .touchUpInside)
        browserButton.addTarget(self, action: #selector(openInBrowser), for: .touchUpInside)
        
        // Add haptic feedback to buttons
        [backButton, forwardButton, reloadButton, shareButton, browserButton].forEach { button in
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        }
        
        // Update button states initially
        updateButtonStates()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Apply theme color to navigation bar
        navigationController?.navigationBar.tintColor = UIColor(hex: "#FF6482") // Pink accent color
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShowFloatingButtons()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update UI for dark/light mode changes
            floatingButtonsContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupWebView() {
        webView.scrollView.addSubview(refreshControl)
        webView.scrollView.bounces = true
    }
    
    private func setupNavigationBar() {
        navigationItem.titleView = searchBar
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Add "Home" button to navigation bar
        let homeButton = UIBarButtonItem(
            image: UIImage(systemName: "house.fill"),
            style: .plain,
            target: self,
            action: #selector(goHome)
        )
        navigationItem.rightBarButtonItem = homeButton
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add webView and progressView
        view.addSubview(webView)
        view.addSubview(progressView)
        
        // Add floating controls container with blur effect
        view.addSubview(floatingButtonsContainer)
        floatingButtonsContainer.addSubview(blurEffectView)
        floatingButtonsContainer.addSubview(buttonStackView)
        
        // Add buttons to stack view
        buttonStackView.addArrangedSubview(backButton)
        buttonStackView.addArrangedSubview(forwardButton)
        buttonStackView.addArrangedSubview(reloadButton)
        buttonStackView.addArrangedSubview(shareButton)
        buttonStackView.addArrangedSubview(browserButton)
        
        // Set constraints for webView
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set constraints for progress view
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
        
        // Set constraints for blur effect
        NSLayoutConstraint.activate([
            blurEffectView.topAnchor.constraint(equalTo: floatingButtonsContainer.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: floatingButtonsContainer.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: floatingButtonsContainer.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: floatingButtonsContainer.bottomAnchor)
        ])
        
        // Set constraints for button stack view
        NSLayoutConstraint.activate([
            buttonStackView.topAnchor.constraint(equalTo: floatingButtonsContainer.topAnchor, constant: 12),
            buttonStackView.leadingAnchor.constraint(equalTo: floatingButtonsContainer.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: floatingButtonsContainer.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: floatingButtonsContainer.bottomAnchor, constant: -12)
        ])
        
        // Set constraints for floating buttons container
        NSLayoutConstraint.activate([
            floatingButtonsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            floatingButtonsContainer.heightAnchor.constraint(equalToConstant: 50),
            floatingButtonsContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
        
        // Store the bottom constraint so we can animate it
        floatingButtonsBottomConstraint = floatingButtonsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 100)
        floatingButtonsBottomConstraint?.isActive = true
        
        // Apply initial button states
        updateButtonStates()
    }
    
    private func setupObservers() {
        // Observe webView progress
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let self = self, let newValue = change.newValue else { return }
            
            self.updateProgress(newValue)
        }
        
        // Observe webView title changes
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.title) {
            if let title = webView.title, !title.isEmpty {
                self.title = title
            } else {
                self.title = "BDG Hub"
            }
        } else if keyPath == #keyPath(WKWebView.url) {
            if let url = webView.url {
                searchBar.text = url.absoluteString
            }
        }
    }
    
    // MARK: - Web Loading Methods
    
    private func loadWebsite() {
        if let savedURL = UserDefaults.standard.url(forKey: "BDGLastVisitedURL") {
            let request = URLRequest(url: savedURL)
            webView.load(request)
        } else {
            let request = URLRequest(url: homeURL)
            webView.load(request)
        }
    }
    
    @objc private func refreshWebView() {
        webView.reload()
    }
    
    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
            animateButton(backButton)
        }
    }
    
    @objc private func goForward() {
        if webView.canGoForward {
            webView.goForward()
            animateButton(forwardButton)
        }
    }
    
    @objc private func reloadPage() {
        webView.reload()
        animateButton(reloadButton)
    }
    
    @objc private func goHome() {
        let request = URLRequest(url: homeURL)
        webView.load(request)
    }
    
    @objc private func sharePage() {
        guard let url = webView.url else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Present from the button for iPad compatibility
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = shareButton
            popoverController.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    @objc private func openInBrowser() {
        guard let url = webView.url else { return }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true)
    }
    
    // MARK: - UI Update Methods
    
    private func updateButtonStates() {
        // Update button enabled states
        backButton.isEnabled = webView.canGoBack
        backButton.alpha = webView.canGoBack ? 1.0 : 0.4
        
        forwardButton.isEnabled = webView.canGoForward
        forwardButton.alpha = webView.canGoForward ? 1.0 : 0.4
        
        // Update buttons for current URL
        shareButton.isEnabled = webView.url != nil
        shareButton.alpha = webView.url != nil ? 1.0 : 0.4
        
        browserButton.isEnabled = webView.url != nil
        browserButton.alpha = webView.url != nil ? 1.0 : 0.4
    }
    
    private func updateProgress(_ value: Double) {
        // Show progress view only when loading
        if value < 1.0 && progressView.alpha == 0 {
            UIView.animate(withDuration: 0.2) {
                self.progressView.alpha = 1.0
            }
        }
        
        // Update progress value
        progressView.progress = Float(value)
        
        // Hide progress view when loading complete
        if value >= 1.0 {
            UIView.animate(withDuration: 0.2, delay: 0.3, options: .curveEaseInOut, animations: {
                self.progressView.alpha = 0
            }, completion: nil)
        }
    }
    
    // MARK: - Button Animation Methods
    
    @objc private func buttonTapped(_ sender: UIButton) {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred(intensity: 0.7)
    }
    
    private func animateButton(_ button: UIButton) {
        UIView.animate(withDuration: 0.15, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) {
                button.transform = .identity
            }
        })
    }
    
    // MARK: - Floating Buttons Animation
    
    private func animateShowFloatingButtons() {
        self.floatingButtonsContainer.alpha = 0
        self.floatingButtonsBottomConstraint?.constant = 20
        
        UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.floatingButtonsContainer.alpha = 1
            self.view.layoutIfNeeded()
        }
    }
    
    private func toggleFloatingButtons(show: Bool, animated: Bool = true) {
        guard show != showingButtons else { return }
        
        showingButtons = show
        
        floatingButtonsBottomConstraint?.constant = show ? 20 : 100
        
        if animated {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
                self.floatingButtonsContainer.alpha = show ? 1.0 : 0.0
                self.view.layoutIfNeeded()
            }
        } else {
            floatingButtonsContainer.alpha = show ? 1.0 : 0.0
            view.layoutIfNeeded()
        }
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateButtonStates()
        refreshControl.endRefreshing()
        
        // Save the current URL
        if let url = webView.url {
            UserDefaults.standard.set(url, forKey: "BDGLastVisitedURL")
        }
        
        // Apply custom stylesheet
        applyCustomStyleToWebContent()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
        
        // Show error if needed
        if (error as NSError).code != NSURLErrorCancelled {
            let alert = UIAlertController(
                title: "Loading Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Handle link clicks, form submissions, etc.
        decisionHandler(.allow)
    }
    
    // MARK: - UIScrollViewDelegate Methods
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height
        
        // Calculate scroll direction and distance
        let scrollingDown = currentOffset > lastContentOffset
        let distanceFromBottom = contentHeight - currentOffset - frameHeight
        
        // Show/hide floating buttons based on scroll direction and position
        if scrollingDown && currentOffset > 100 {
            toggleFloatingButtons(show: false)
        } else if !scrollingDown || currentOffset < 50 || distanceFromBottom < 100 {
            toggleFloatingButtons(show: true)
        }
        
        lastContentOffset = currentOffset
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // When user stops dragging and scrolling will stop immediately
            toggleFloatingButtons(show: true)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // When scrolling stops completely
        toggleFloatingButtons(show: true)
    }
    
    // MARK: - Custom Styling
    
    private func applyCustomStyleToWebContent() {
        // Apply custom CSS to enhance website appearance within the app
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        let css = """
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            \(isDarkMode ? "color: #EFEFEF !important;" : "")
        }
        
        /* Improve button styling */
        button, .button, input[type='button'], input[type='submit'] {
            border-radius: 8px !important;
            transition: transform 0.2s ease, background-color 0.2s ease !important;
        }
        
        button:active, .button:active, input[type='button']:active, input[type='submit']:active {
            transform: scale(0.95) !important;
        }
        
        /* Improve input field styling */
        input[type='text'], input[type='password'], input[type='email'], input[type='search'], textarea {
            border-radius: 8px !important;
            padding: 10px !important;
        }
        
        /* Add tap highlight effect */
        a, button, .button, input[type='button'], input[type='submit'] {
            -webkit-tap-highlight-color: rgba(0,0,0,0.1) !important;
        }
        
        /* Improve scrolling */
        * {
            -webkit-overflow-scrolling: touch !important;
        }
        
        /* Add subtle animations */
        a, button, .button, input[type='button'], input[type='submit'] {
            transition: transform 0.2s ease, opacity 0.2s ease !important;
        }
        
        /* Make images nicer */
        img {
            border-radius: 4px !important;
        }
        """
        
        let script = """
        var style = document.createElement('style');
        style.textContent = `\(css)`;
        document.head.appendChild(style);
        """
        
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

// MARK: - UISearchBarDelegate Extension

extension WebViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, !searchText.isEmpty else { return }
        
        var urlString = searchText
        
        // Check if the input is a URL or a search term
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            // If it contains a dot and no spaces, assume it's a website
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            } else {
                // Otherwise, treat as a search term
                if let encodedSearch = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    urlString = "https://www.google.com/search?q=\(encodedSearch)"
                }
            }
        }
        
        // Load the URL
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        
        searchBar.resignFirstResponder()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.becomeFirstResponder()
    }
}

// MARK: - RefreshContent Implementation

extension WebViewController {
    override func refreshContent() {
        super.refreshContent()
        
        // When switching to this tab, ensure UI is updated
        if webView.isLoading {
            progressView.alpha = 1.0
            progressView.progress = Float(webView.estimatedProgress)
        }
        
        updateButtonStates()
        
        // If the web view was previously hidden, reload the page
        // but only if it's been more than 30 minutes since the last load
        if let lastNavigationDate = UserDefaults.standard.object(forKey: "BDGLastNavigationDate") as? Date,
           Date().timeIntervalSince(lastNavigationDate) > 1800 {
            webView.reload()
        }
        
        // Update last navigation date
        UserDefaults.standard.set(Date(), forKey: "BDGLastNavigationDate")
    }
}
