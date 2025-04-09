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
    
    /// Theme toggle button (light/dark mode)
    private let themeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "sun.max.fill", withConfiguration: imageConfig), for: .normal)
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
    
    /// BDG Hub branded logo view
    private let logoView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Create label for title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "BDG HUB"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = UIColor(hex: "#FF6482") // Pink accent color
        
        // Create sparkle icon
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        imageView.image = UIImage(systemName: "sparkles", withConfiguration: config)
        imageView.tintColor = UIColor(hex: "#FF6482")
        imageView.contentMode = .scaleAspectFit
        
        // Add to container
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 24),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }()
    
    /// Visual enhancement - pulse effect view that appears when page loads
    private let pulseEffectView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(hex: "#FF6482").withAlphaComponent(0.15)
        view.layer.cornerRadius = 40
        view.alpha = 0
        return view
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
        
        // Set up button actions
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        reloadButton.addTarget(self, action: #selector(reloadPage), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(sharePage), for: .touchUpInside)
        themeButton.addTarget(self, action: #selector(toggleTheme), for: .touchUpInside)
        
        // Add haptic feedback to buttons
        [backButton, forwardButton, reloadButton, shareButton, themeButton].forEach { button in
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        }
        
        // Update button states initially
        updateButtonStates()
        
        // Update theme button icon based on current mode
        updateThemeButtonIcon()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update UI for dark/light mode changes
            floatingButtonsContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
            updateThemeButtonIcon()
        }
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
    
    // This duplicate method has been merged with the previous implementation
    
    // MARK: - Setup Methods
    
    private func setupWebView() {
        webView.scrollView.addSubview(refreshControl)
        webView.scrollView.bounces = true
    }
    
    private func setupNavigationBar() {
        // Use branded logo view instead of search bar
        navigationItem.titleView = logoView
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Make the logo pulse slightly to draw attention
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.animateLogo()
        }
        
        // Add a themed button to the navigation bar for home
        let homeButton = UIBarButtonItem(
            image: UIImage(systemName: "house.fill"),
            style: .plain,
            target: self,
            action: #selector(goHome)
        )
        homeButton.tintColor = UIColor(hex: "#FF6482")
        navigationItem.rightBarButtonItem = homeButton
    }
    
    private func animateLogo() {
        UIView.animate(withDuration: 0.7, delay: 0, options: [.autoreverse, .repeat, .curveEaseInOut], animations: {
            self.logoView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }, completion: nil)
    }
    
    private func showSuccessAnimation() {
        // Reset the pulse view
        pulseEffectView.alpha = 0.8
        pulseEffectView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Animate it growing and fading out
        UIView.animate(withDuration: 0.8, delay: 0, options: .curveEaseOut, animations: {
            self.pulseEffectView.alpha = 0
            self.pulseEffectView.transform = CGAffineTransform(scaleX: 2.5, y: 2.5)
        }, completion: { _ in
            self.pulseEffectView.transform = .identity
        })
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add webView, progressView, and pulse effect view
        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(pulseEffectView)
        
        // Add floating controls container with blur effect
        view.addSubview(floatingButtonsContainer)
        floatingButtonsContainer.addSubview(blurEffectView)
        floatingButtonsContainer.addSubview(buttonStackView)
        
        // Add buttons to stack view - using theme toggle instead of browser button
        buttonStackView.addArrangedSubview(backButton)
        buttonStackView.addArrangedSubview(forwardButton)
        buttonStackView.addArrangedSubview(reloadButton)
        buttonStackView.addArrangedSubview(shareButton)
        buttonStackView.addArrangedSubview(themeButton)
        
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
        
        // Set constraints for pulse effect view
        NSLayoutConstraint.activate([
            pulseEffectView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pulseEffectView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            pulseEffectView.widthAnchor.constraint(equalToConstant: 80),
            pulseEffectView.heightAnchor.constraint(equalToConstant: 80)
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
        
        // Update theme button icon based on current mode
        updateThemeButtonIcon()
    }
    
    private func updateThemeButtonIcon() {
        let currentStyle = traitCollection.userInterfaceStyle
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        
        // Set the appropriate icon based on current mode
        let iconName = currentStyle == .dark ? "sun.max.fill" : "moon.fill"
        themeButton.setImage(UIImage(systemName: iconName, withConfiguration: imageConfig), for: .normal)
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
                // Don't change navigation title - we're using our custom logo view
                // But we can use the title for other purposes if needed
            }
        }
    }
    
    // MARK: - Web Loading Methods
    
    private func loadWebsite() {
        // Always load the home URL - don't save last visited URL
        // This ensures the user always returns to the main page
        let request = URLRequest(url: homeURL)
        webView.load(request)
    }
    
    @objc private func refreshWebView() {
        // Always reload the home URL
        let request = URLRequest(url: homeURL)
        webView.load(request)
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
        
        // Show pulse animation on reload
        showSuccessAnimation()
    }
    
    @objc private func goHome() {
        // Always go to homeURL even if already there (forced refresh)
        let request = URLRequest(url: homeURL)
        webView.load(request)
        
        // Show pulse animation on home navigation
        showSuccessAnimation()
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
    
    @objc private func toggleTheme() {
        // Toggle between light and dark mode
        let currentStyle = view.window?.overrideUserInterfaceStyle ?? .unspecified
        
        switch currentStyle {
            case .unspecified, .light:
                view.window?.overrideUserInterfaceStyle = .dark
            case .dark:
                view.window?.overrideUserInterfaceStyle = .light
            @unknown default:
                view.window?.overrideUserInterfaceStyle = .unspecified
        }
        
        // Update theme button icon
        updateThemeButtonIcon()
        
        // Provide haptic feedback for theme change
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred(intensity: 1.0)
        
        // Animate button
        animateButton(themeButton)
    }
    
    // MARK: - UI Update Methods
    
    private func updateButtonStates() {
        // Update button enabled states
        backButton.isEnabled = webView.canGoBack
        backButton.alpha = webView.canGoBack ? 1.0 : 0.4
        
        forwardButton.isEnabled = webView.canGoForward
        forwardButton.alpha = webView.canGoForward ? 1.0 : 0.4
        
        // Update share button for current URL
        shareButton.isEnabled = webView.url != nil
        shareButton.alpha = webView.url != nil ? 1.0 : 0.4
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
        
        // Apply custom stylesheet for enhanced appearance
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
        // IMPORTANT: Restrict navigation to prevent users from leaving the BDG Hub domain
        if let url = navigationAction.request.url {
            // Allow main domain navigation
            if url.host?.contains("backdoor-bdg.store") == true {
                decisionHandler(.allow)
                return
            }
            
            // Allow navigation within the app (back/forward, etc.)
            if navigationAction.navigationType == .backForward || 
               navigationAction.navigationType == .reload ||
               url.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            
            // Block navigation to external sites, but allow the page to function normally
            if navigationAction.targetFrame?.isMainFrame == true {
                // Show a pulse animation to indicate the action was received
                showSuccessAnimation()
                
                // Optionally show a toast message indicating external links aren't allowed
                
                decisionHandler(.cancel)
                return
            }
        }
        
        // Default to allowing in-page interactions
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
            box-shadow: 0 2px 4px rgba(0,0,0,0.1) !important;
        }
        
        button:active, .button:active, input[type='button']:active, input[type='submit']:active {
            transform: scale(0.95) !important;
            box-shadow: 0 1px 2px rgba(0,0,0,0.1) !important;
        }
        
        /* Enhanced input field styling */
        input[type='text'], input[type='password'], input[type='email'], input[type='search'], textarea {
            border-radius: 8px !important;
            padding: 10px !important;
            box-shadow: inset 0 1px 3px rgba(0,0,0,0.1) !important;
            transition: all 0.2s ease !important;
        }
        
        input:focus, textarea:focus {
            box-shadow: inset 0 1px 3px rgba(0,0,0,0.1), 0 0 0 3px rgba(255,100,130,0.2) !important;
            outline: none !important;
        }
        
        /* Add tap highlight effect */
        a, button, .button, input[type='button'], input[type='submit'] {
            -webkit-tap-highlight-color: rgba(255,100,130,0.2) !important;
        }
        
        /* Improve scrolling */
        * {
            -webkit-overflow-scrolling: touch !important;
        }
        
        /* Add subtle animations */
        a, button, .button, input[type='button'], input[type='submit'] {
            transition: transform 0.2s ease, opacity 0.2s ease, box-shadow 0.2s ease !important;
        }
        
        /* Make cards and containers nicer */
        .card, .container, .panel, section, article {
            border-radius: 12px !important;
            overflow: hidden !important;
            transition: transform 0.2s ease, box-shadow 0.3s ease !important;
        }
        
        /* Make images nicer */
        img {
            border-radius: 8px !important;
            transition: transform 0.3s ease !important;
        }
        
        img:hover {
            transform: scale(1.02) !important;
        }
        
        /* Add accent color to interactive elements */
        a:focus, button:focus, input:focus {
            outline: none !important;
            box-shadow: 0 0 0 3px rgba(255,100,130,0.3) !important;
        }
        
        /* Smooth transitions for dark mode if implemented on the site */
        * {
            transition: background-color 0.3s ease, color 0.3s ease, border-color 0.3s ease !important;
        }
        """
        
        let script = """
        var style = document.createElement('style');
        style.textContent = `\(css)`;
        document.head.appendChild(style);
        
        // Handle any site-specific enhancements
        document.addEventListener('DOMContentLoaded', function() {
            // Add touch-friendly interactive elements
            document.querySelectorAll('a, button, .button').forEach(function(el) {
                el.addEventListener('touchstart', function() {
                    this.style.transform = 'scale(0.98)';
                });
                el.addEventListener('touchend', function() {
                    this.style.transform = 'scale(1)';
                });
            });
        });
        """
        
        webView.evaluateJavaScript(script, completionHandler: nil)
        
        // Apply additional enhanced styles
        enhanceCustomStylesheet()
    }
}

// MARK: - Enhanced CSS Styling

extension WebViewController {
    /// Applies enhanced styles to web content for better integration with the app
    private func enhanceCustomStylesheet() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        // Add additional custom CSS for specific BDG Hub content
        let additionalCSS = """
        /* Enhanced card styling */
        .card, .panel, .content-box {
            box-shadow: 0 4px 12px rgba(0,0,0,0.1) !important;
            transition: transform 0.3s ease, box-shadow 0.3s ease !important;
            overflow: hidden;
        }
        
        .card:hover, .panel:hover, .content-box:hover {
            transform: translateY(-2px) !important;
            box-shadow: 0 8px 16px rgba(0,0,0,0.15) !important;
        }
        
        /* Enhanced buttons with accent color */
        .primary-button, .main-button, .action-button {
            background-color: \(isDarkMode ? "#FF6482" : "#FF6482") !important;
            color: white !important;
            border: none !important;
            transition: all 0.2s ease !important;
        }
        
        /* Section dividers with subtle gradient */
        hr, .divider {
            height: 2px !important;
            border: none !important;
            background: linear-gradient(to right, transparent, \(isDarkMode ? "rgba(255,100,130,0.5)" : "rgba(255,100,130,0.5)"), transparent) !important;
            margin: 20px 0 !important;
        }
        
        /* Improve text readability */
        p, .text, article {
            line-height: 1.6 !important;
            font-size: 16px !important;
        }
        
        /* Enhance focus states */
        *:focus {
            outline: none !important;
            box-shadow: 0 0 0 3px rgba(255,100,130,0.4) !important;
        }
        """
        
        let script = """
        var enhancedStyle = document.createElement('style');
        enhancedStyle.textContent = `\(additionalCSS)`;
        document.head.appendChild(enhancedStyle);
        """
        
        webView.evaluateJavaScript(script, completionHandler: nil)
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
