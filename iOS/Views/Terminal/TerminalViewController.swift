//
//  TerminalViewController.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

class TerminalViewController: UIViewController {
    // MARK: - UI Components
    private let terminalOutputTextView = TerminalTextView()
    private let commandInputView = CommandInputView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let toolbar = UIToolbar()
    private let connectionStatusView = UIView()
    
    // MARK: - Properties
    private let history = CommandHistory()
    private var isExecuting = false
    private let logger = Debug.shared
    private var isWebSocketConnected = false
    private var userPreferenceWebSockets = true
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupKeyboardNotifications()
        setupActions()
        
        // Load user preferences
        loadUserPreferences()
        
        // Load command history
        history.loadHistory()
        
        // Check WebSocket connection status
        updateConnectionStatus()
        
        // Update title to reflect current connection mode
        updateTitle()
        
        // Set up periodic connection status check
        setupConnectionStatusTimer()
        
        // Welcome message with connection info
        let connectionInfo = isWebSocketConnected ? "WebSocket Connected" : "HTTP Mode"
        appendToTerminal("Terminal Ready [\(connectionInfo)]\n$ ", isInput: false)
        
        logger.log(message: "Terminal view controller loaded", type: .info)
    }
    
    private func loadUserPreferences() {
        // Load WebSocket preference from UserDefaults
        if UserDefaults.standard.object(forKey: "terminal_websocket_enabled") != nil {
            userPreferenceWebSockets = UserDefaults.standard.bool(forKey: "terminal_websocket_enabled")
        } else {
            // Default to true if not set previously
            userPreferenceWebSockets = true
            UserDefaults.standard.set(true, forKey: "terminal_websocket_enabled")
        }
        
        logger.log(message: "Loaded WebSocket preference: \(userPreferenceWebSockets)", type: .debug)
    }
    
    private func saveUserPreferences() {
        // Save WebSocket preference to UserDefaults
        UserDefaults.standard.set(userPreferenceWebSockets, forKey: "terminal_websocket_enabled")
    }
    
    private func setupConnectionStatusTimer() {
        // Update connection status every 3 seconds
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let wasConnected = self.isWebSocketConnected
            self.updateConnectionStatus()
            
            // If connection status changed, inform the user
            if wasConnected != self.isWebSocketConnected {
                DispatchQueue.main.async {
                    if self.isWebSocketConnected {
                        self.appendToTerminal("\nWebSocket connection established\n$ ", isInput: false)
                    } else if self.userPreferenceWebSockets {
                        self.appendToTerminal("\nWebSocket disconnected, using HTTP fallback\n$ ", isInput: false)
                    }
                    
                    // Update title to reflect current status
                    self.updateTitle()
                }
            }
        }
    }
    
    private func updateTitle() {
        // Update navigation title to include connection mode
        if isWebSocketConnected {
            self.title = "Terminal [WebSocket]"
        } else if !userPreferenceWebSockets {
            self.title = "Terminal [HTTP]"
        } else {
            self.title = "Terminal [HTTP - Reconnecting]"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        commandInputView.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Save command history when leaving view
        history.saveHistory()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Notify the terminal text view about the interface style change
            NotificationCenter.default.post(name: .didChangeUserInterfaceStyle, object: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        logger.log(message: "Terminal view controller deallocated", type: .info)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor(named: "Background") ?? UIColor.systemBackground
        
        // Set navigation bar title and style
        title = "Terminal"
        navigationItem.largeTitleDisplayMode = .never
        
        // Add a close button if presented modally
        if presentingViewController != nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissTerminal)
            )
        }
        
        // Terminal output setup
        terminalOutputTextView.isEditable = false
        
        // Apply font size from settings
        let fontSize = UserDefaults.standard.integer(forKey: "terminal_font_size")
        terminalOutputTextView.font = UIFont.monospacedSystemFont(
            ofSize: fontSize > 0 ? CGFloat(fontSize) : 14,
            weight: .regular
        )
        
        // Command input setup
        commandInputView.placeholder = "Enter command..."
        commandInputView.returnKeyType = .send
        commandInputView.autocorrectionType = .no
        commandInputView.autocapitalizationType = .none
        commandInputView.delegate = self
        
        // Activity indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .systemBlue
        
        // Connection status indicator setup
        connectionStatusView.layer.cornerRadius = 5
        connectionStatusView.layer.masksToBounds = true
        updateConnectionStatus()
        
        // Toolbar setup
        setupToolbar()
        
        // Add subviews
        view.addSubview(terminalOutputTextView)
        view.addSubview(commandInputView)
        view.addSubview(activityIndicator)
        view.addSubview(connectionStatusView)
    }
    
    private func updateConnectionStatus() {
        // Check if WebSocket is connected, respecting user preference
        isWebSocketConnected = userPreferenceWebSockets && TerminalService.shared.isWebSocketActive
        
        // Update connection status indicator
        if isWebSocketConnected {
            connectionStatusView.backgroundColor = .systemGreen
        } else if !userPreferenceWebSockets {
            // Red when user has disabled WebSockets
            connectionStatusView.backgroundColor = .systemRed
        } else {
            // Gray when WebSockets are enabled but not connected
            connectionStatusView.backgroundColor = .systemGray
        }
        
        // Update toolbar buttons to reflect current status
        updateToolbarButtons()
    }
    
    @objc private func toggleWebSocketMode() {
        // Toggle user preference for WebSockets
        userPreferenceWebSockets = !userPreferenceWebSockets
        
        // Save the preference
        saveUserPreferences()
        
        // Update connection status
        updateConnectionStatus()
        
        // Update title to reflect new mode
        updateTitle()
        
        // Inform the user about the change
        let message = userPreferenceWebSockets 
            ? "WebSocket mode enabled" 
            : "WebSocket mode disabled, using HTTP fallback"
        
        logger.log(message: message, type: .info)
        appendToTerminal("\n\(message)\n$ ", isInput: false)
    }
    
    private func setupToolbar() {
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let clearButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(clearTerminal)
        )
        clearButton.accessibilityLabel = "Clear Terminal"
        
        let historyUpButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up"),
            style: .plain,
            target: self,
            action: #selector(historyUp)
        )
        historyUpButton.accessibilityLabel = "Previous Command"
        
        let historyDownButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.down"),
            style: .plain,
            target: self,
            action: #selector(historyDown)
        )
        historyDownButton.accessibilityLabel = "Next Command"
        
        let tabButton = UIBarButtonItem(
            title: "Tab",
            style: .plain,
            target: self,
            action: #selector(insertTab)
        )
        
        let ctrlCButton = UIBarButtonItem(
            title: "Ctrl+C",
            style: .plain,
            target: self,
            action: #selector(sendCtrlC)
        )
        ctrlCButton.accessibilityLabel = "Interrupt Command"
        
        // WebSocket toggle button
        let wsImage = UIImage(systemName: isWebSocketConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
        let wsButton = UIBarButtonItem(
            image: wsImage,
            style: .plain,
            target: self,
            action: #selector(toggleWebSocketMode)
        )
        wsButton.accessibilityLabel = isWebSocketConnected ? "Disable WebSocket" : "Enable WebSocket"
        
        toolbar.items = [clearButton, flexSpace, historyUpButton, historyDownButton, flexSpace, tabButton, flexSpace, ctrlCButton, flexSpace, wsButton]
        toolbar.sizeToFit()
        commandInputView.inputAccessoryView = toolbar
    }
    
    private func updateToolbarButtons() {
        guard let items = toolbar.items else { return }
        
        // Update WebSocket toggle button (last item)
        if let wsButton = items.last {
            wsButton.image = UIImage(systemName: isWebSocketConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
            wsButton.accessibilityLabel = isWebSocketConnected ? "Disable WebSocket" : "Enable WebSocket"
        }
    }
    
    private func setupConstraints() {
        terminalOutputTextView.translatesAutoresizingMaskIntoConstraints = false
        commandInputView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        connectionStatusView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Terminal output
            terminalOutputTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            terminalOutputTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminalOutputTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Command input
            commandInputView.topAnchor.constraint(equalTo: terminalOutputTextView.bottomAnchor),
            commandInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commandInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commandInputView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            commandInputView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Connection status indicator
            connectionStatusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            connectionStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            connectionStatusView.widthAnchor.constraint(equalToConstant: 10),
            connectionStatusView.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func setupActions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        terminalOutputTextView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Terminal Functions
    private func executeCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appendToTerminal("\n$ ", isInput: false)
            return
        }
        
        history.addCommand(command)
        appendToTerminal("\n", isInput: false)
        isExecuting = true
        activityIndicator.startAnimating()
        
        // Use streaming if WebSocket is connected
        if isWebSocketConnected {
            // Create a stream handler to receive real-time updates
            let streamHandler: (String) -> Void = { [weak self] outputChunk in
                DispatchQueue.main.async {
                    guard let self = self, self.isExecuting else { return }
                    self.appendToTerminalStreaming(outputChunk)
                }
            }
            
            logger.log(message: "Executing command with WebSocket streaming: \(command)", type: .info)
            
            // Execute with streaming support
            TerminalService.shared.executeCommand(command, streamHandler: streamHandler) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.activityIndicator.stopAnimating()
                    self.isExecuting = false
                    
                    switch result {
                    case .success:
                        // Terminal output already updated incrementally via streamHandler
                        break
                    case .failure(let error):
                        self.appendToTerminal("\nError: \(error.localizedDescription)", isInput: false)
                    }
                    
                    self.appendToTerminal("\n$ ", isInput: false)
                    self.scrollToBottom()
                }
            }
        } else {
            // Legacy HTTP-based execution without streaming
            logger.log(message: "Executing command via HTTP: \(command)", type: .info)
            
            TerminalService.shared.executeCommand(command) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.activityIndicator.stopAnimating()
                    self.isExecuting = false
                    
                    switch result {
                    case .success(let output):
                        self.appendToTerminal(output, isInput: false)
                    case .failure(let error):
                        self.appendToTerminal("Error: \(error.localizedDescription)", isInput: false)
                    }
                    
                    self.appendToTerminal("\n$ ", isInput: false)
                    self.scrollToBottom()
                }
            }
        }
    }
    
    // Append streaming output to terminal
    private func appendToTerminalStreaming(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Get the appropriate color based on text type and theme
        let colorTheme = UserDefaults.standard.integer(forKey: "terminal_color_theme")
        
        let outputColor: UIColor
        switch colorTheme {
        case 1: // Light theme
            outputColor = .systemGreen
        case 2: // Dark theme
            outputColor = .green
        case 3: // Solarized
            outputColor = UIColor(red: 0.52, green: 0.6, blue: 0.0, alpha: 1.0)
        default: // Default theme
            outputColor = traitCollection.userInterfaceStyle == .dark ? .green : .systemGreen
        }
        
        // Create attributed string for the new chunk
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.foregroundColor, 
                                     value: outputColor, 
                                     range: NSRange(location: 0, length: text.count))
        
        // Append to existing text
        let newAttributedText = NSMutableAttributedString(attributedString: terminalOutputTextView.attributedText ?? NSAttributedString())
        newAttributedText.append(attributedString)
        terminalOutputTextView.attributedText = newAttributedText
        
        // Scroll to bottom with each update for real-time feedback
        scrollToBottom()
    }
    
    private func appendToTerminal(_ text: String, isInput: Bool) {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Get the appropriate color based on text type and theme
        let colorTheme = UserDefaults.standard.integer(forKey: "terminal_color_theme")
        
        if isInput {
            let userInputColor: UIColor
            switch colorTheme {
            case 1: // Light theme
                userInputColor = .systemBlue
            case 2: // Dark theme
                userInputColor = .cyan
            case 3: // Solarized
                userInputColor = UIColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)
            default: // Default theme
                userInputColor = traitCollection.userInterfaceStyle == .dark ? .cyan : .systemBlue
            }
            
            attributedString.addAttribute(.foregroundColor, 
                                         value: userInputColor, 
                                         range: NSRange(location: 0, length: text.count))
        } else {
            let outputColor: UIColor
            switch colorTheme {
            case 1: // Light theme
                outputColor = .systemGreen
            case 2: // Dark theme
                outputColor = .green
            case 3: // Solarized
                outputColor = UIColor(red: 0.52, green: 0.6, blue: 0.0, alpha: 1.0)
            default: // Default theme
                outputColor = traitCollection.userInterfaceStyle == .dark ? .green : .systemGreen
            }
            
            attributedString.addAttribute(.foregroundColor, 
                                         value: outputColor, 
                                         range: NSRange(location: 0, length: text.count))
        }
        
        let newAttributedText = NSMutableAttributedString(attributedString: terminalOutputTextView.attributedText ?? NSAttributedString())
        newAttributedText.append(attributedString)
        terminalOutputTextView.attributedText = newAttributedText
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        if terminalOutputTextView.text.count > 0 {
            let location = terminalOutputTextView.text.count - 1
            let bottom = NSRange(location: location, length: 1)
            terminalOutputTextView.scrollRangeToVisible(bottom)
        }
    }
    
    // MARK: - Actions
    @objc private func clearTerminal() {
        terminalOutputTextView.text = ""
        appendToTerminal("$ ", isInput: false)
    }
    
    @objc private func historyUp() {
        if let previousCommand = history.getPreviousCommand() {
            commandInputView.text = previousCommand
        }
    }
    
    @objc private func historyDown() {
        if let nextCommand = history.getNextCommand() {
            commandInputView.text = nextCommand
        } else {
            commandInputView.text = ""
        }
    }
    
    @objc private func insertTab() {
        commandInputView.insertText("\t")
    }
    
    @objc private func sendCtrlC() {
        if isExecuting {
            // Send interrupt signal
            appendToTerminal("^C", isInput: false)
            executeCommand("\u{0003}") // Ctrl+C character
        }
    }
    
    @objc private func handleTap() {
        commandInputView.becomeFirstResponder()
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        scrollToBottom()
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        // Handle keyboard hiding if needed
    }
    
    @objc private func dismissTerminal() {
        // Post notification to restore floating terminal button before dismissing
        NotificationCenter.default.post(name: .showTerminalButton, object: nil)
        
        // Also post to a more general notification that can be observed by other components
        NotificationCenter.default.post(name: Notification.Name("TerminalDismissed"), object: nil)
        
        // Explicitly tell the FloatingButtonManager to show if available
        DispatchQueue.main.async {
            FloatingButtonManager.shared.show()
        }
        
        // Log dismissal
        logger.log(message: "Terminal dismissed, floating button restored", type: .info)
        
        // Dismiss the terminal view controller
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension TerminalViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let command = textField.text, !isExecuting {
            appendToTerminal(command, isInput: true)
            executeCommand(command)
            textField.text = ""
        }
        return false
    }
}
