// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit

protocol ConsentViewControllerDelegate: AnyObject {
    func userDidAcceptConsent()
    func userDidDeclineConsent()
}

class ConsentViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: ConsentViewControllerDelegate?
    
    private let scrollView = UIScrollView()
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let iconImageView = UIImageView()
    private let consentTextView = UITextView()
    private let acceptButton = UIButton(type: .system)
    private let declineButton = UIButton(type: .system)
    private let privacyCheckbox = UIButton(type: .system)
    private var isPrivacyAccepted = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        
        // Configure icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(named: "backdoor_glyph")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = Preferences.appTintColor.uiColor
        containerView.addSubview(iconImageView)
        
        // Configure title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Backdoor Data Collection Consent"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // Configure consent text
        consentTextView.translatesAutoresizingMaskIntoConstraints = false
        consentTextView.isEditable = false
        consentTextView.isScrollEnabled = true
        consentTextView.font = UIFont.systemFont(ofSize: 16)
        consentTextView.layer.borderWidth = 1
        consentTextView.layer.borderColor = UIColor.systemGray4.cgColor
        consentTextView.layer.cornerRadius = 8
        consentTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        consentTextView.text = self.getConsentText()
        containerView.addSubview(consentTextView)
        
        // Configure privacy checkbox
        privacyCheckbox.translatesAutoresizingMaskIntoConstraints = false
        privacyCheckbox.setImage(UIImage(systemName: "square"), for: .normal)
        privacyCheckbox.setTitle(" I have read and agree to the data collection policy", for: .normal)
        privacyCheckbox.contentHorizontalAlignment = .left
        privacyCheckbox.addTarget(self, action: #selector(togglePrivacyConsent), for: .touchUpInside)
        containerView.addSubview(privacyCheckbox)
        
        // Configure buttons
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.setTitle("Accept & Continue", for: .normal)
        acceptButton.backgroundColor = Preferences.appTintColor.uiColor
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.layer.cornerRadius = 12
        acceptButton.isEnabled = false
        acceptButton.alpha = 0.5
        acceptButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        acceptButton.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        containerView.addSubview(acceptButton)
        
        declineButton.translatesAutoresizingMaskIntoConstraints = false
        declineButton.setTitle("Decline", for: .normal)
        declineButton.setTitleColor(.systemRed, for: .normal)
        declineButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        declineButton.addTarget(self, action: #selector(declineButtonTapped), for: .touchUpInside)
        containerView.addSubview(declineButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            consentTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            consentTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            consentTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            consentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            
            privacyCheckbox.topAnchor.constraint(equalTo: consentTextView.bottomAnchor, constant: 20),
            privacyCheckbox.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            privacyCheckbox.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            acceptButton.topAnchor.constraint(equalTo: privacyCheckbox.bottomAnchor, constant: 30),
            acceptButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            acceptButton.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            acceptButton.heightAnchor.constraint(equalToConstant: 50),
            
            declineButton.topAnchor.constraint(equalTo: acceptButton.bottomAnchor, constant: 16),
            declineButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            declineButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func togglePrivacyConsent() {
        isPrivacyAccepted.toggle()
        
        if isPrivacyAccepted {
            privacyCheckbox.setImage(UIImage(systemName: "checkmark.square.fill"), for: .normal)
            acceptButton.isEnabled = true
            acceptButton.alpha = 1.0
        } else {
            privacyCheckbox.setImage(UIImage(systemName: "square"), for: .normal)
            acceptButton.isEnabled = false
            acceptButton.alpha = 0.5
        }
    }
    
    @objc private func acceptButtonTapped() {
        // Save consent to UserDefaults
        UserDefaults.standard.set(true, forKey: "UserHasAcceptedDataCollection")
        UserDefaults.standard.set(Date(), forKey: "UserConsentDate")
        
        // Notify delegate
        delegate?.userDidAcceptConsent()
        
        // Dismiss
        dismiss(animated: true)
    }
    
    @objc private func declineButtonTapped() {
        // Save declined consent
        UserDefaults.standard.set(false, forKey: "UserHasAcceptedDataCollection")
        
        // Notify delegate
        delegate?.userDidDeclineConsent()
        
        // Dismiss
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func getConsentText() -> String {
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
        
        By accepting this policy, you consent to all the data collection and processing described above. You can withdraw consent at any time through the Settings menu, though this may limit certain app functionalities.
        
        If you have any questions about our data practices, please contact us at support@backdoor-app.com.
        """
    }
}
