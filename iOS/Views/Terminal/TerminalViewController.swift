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
    
    // MARK: - Properties
    private let history = CommandHistory()
    private var isExecuting = false
    private let logger = Debug.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupKeyboardNotifications()
        setupActions()
        
        // Load command history
        history.loadHistory()
        
        // Welcome message
        appendToTerminal("Terminal Ready\n$ ", isInput: false)
        
        logger.log(message: "Terminal view controller loaded", type: .info)
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
        
        // Toolbar setup
        setupToolbar()
        
        // Add subviews
        view.addSubview(terminalOutputTextView)
        view.addSubview(commandInputView)
        view.addSubview(activityIndicator)
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
        
        toolbar.items = [clearButton, flexSpace, historyUpButton, historyDownButton, flexSpace, tabButton, flexSpace, ctrlCButton]
        toolbar.sizeToFit()
        commandInputView.inputAccessoryView = toolbar
    }
    
    private func setupConstraints() {
        terminalOutputTextView.translatesAutoresizingMaskIntoConstraints = false
        commandInputView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
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
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
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
