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
    
        return """
    private func getConsentText() -> String {
        return """
        DATA COLLECTION POLICY
        
        At Backdoor Signer, we're committed to providing you with a seamless and personalized experience while continuously improving our services. To do that, we collect and process certain information in a secure and responsible manner. Here's what we gather, why we need it, and how it helps us serve you better:
        
        1. HOW YOU USE THE APP
        
        We track some details about your app experience to make it smoother and more tailored to you, such as:
        
        	•	The features and screens you explore
        	•	The actions you take in the app
        	•	How long you spend on different tasks
        	•	Your chats and interactions with our AI assistant
        
        This helps us understand what you love about the app and where we can make things even better.
        
        2. YOUR DEVICE DETAILS
        
        To ensure the app works well on your device, we collect:
        
Your device model and iOS version        
Device name and unique identifiers        
Basic network info        
        
        This lets us optimize performance and troubleshoot any hiccups specific to your setup.
        
        3. APP PERFORMANCE INSIGHTS
        
        We keep logs to help us spot and fix issues quickly, including:
        
Crashes or errors (so they don't happen again)        
Performance stats (to keep things running smoothly)        
Debug info (to fine-tune the app)        
        
        Think of this as our way of keeping the app reliable for you.
        
        4. MAKING OUR AI SMARTER
        
        Our AI assistant learns from:
        
The messages you send it        
Its own responses and how well it performs        
Any feedback you share about your AI experience        
        
        This data helps the AI get better at assisting you over time.
        
        5. CERTIFICATE PROCESSING
        
        If you upload certificates for app signing:
        
We process those files to complete the signing task        
We may store some certificate metadata to make future tasks easier for you        
        
        It's all about keeping your workflow simple and efficient.
        
        6. WHERE YOUR DATA LIVES
        
Everything we collect is safely stored in our secure cloud storage        
It's organized in folders tied to your device for easy management        
We hold onto this info to keep improving your experience over time        
        
        Your data is handled with care and only used to enhance the app.
        
        7. KEEPING THE AI UP TO DATE 
        
        To keep our AI sharp, the app may automatically download helpful datasets:
        
These updates happen in the background when needed        
We only grab what's relevant based on how you use the app        
        
        This ensures you're always getting the latest and greatest from our AI.
        
        By agreeing to this policy, you're giving us the green light to collect and use this data as described—all to make Backdoor Signer better for you. If you ever change your mind, you can adjust your preferences in the Settings menu anytime. Just know that opting out might limit some features.
        
        Have questions or want to chat about how we handle data? We're here for you—reach out anytime at content me on telegram @elchops.
        """
    }
        DATA COLLECTION POLICY
        
        At Backdoor Signer, we're committed to providing you with a seamless and personalized experience while continuously improving our services. To do that, we collect and process certain information in a secure and responsible manner. Here's what we gather, why we need it, and how it helps us serve you better:
        
        1. HOW YOU USE THE APP
        
        We track some details about your app experience to make it smoother and more tailored to you, such as:
        
The features and screens you explore        
The actions you take in the app        
How long you spend on different tasks        
Your chats and interactions with our AI assistant        
        
        This helps us understand what you love about the app and where we can make things even better.
        
        2. YOUR DEVICE DETAILS
        
        To ensure the app works well on your device, we collect:
        
Your device model and iOS version        
Device name and unique identifiers        
Basic network info        
        
        This lets us optimize performance and troubleshoot any hiccups specific to your setup.
        
        3. APP PERFORMANCE INSIGHTS
        
        We keep logs to help us spot and fix issues quickly, including:
        
Crashes or errors (so they don't happen again)        
Performance stats (to keep things running smoothly)        
Debug info (to fine-tune the app)        
        
        Think of this as our way of keeping the app reliable for you.
        
        4. MAKING OUR AI SMARTER
        
        Our AI assistant learns from:
        
The messages you send it        
Its own responses and how well it performs        
Any feedback you share about your AI experience        
        
        This data helps the AI get better at assisting you over time.
        
        5. CERTIFICATE PROCESSING
        
        If you upload certificates for app signing:
        
We process those files to complete the signing task        
We may store some certificate metadata to make future tasks easier for you        
        
        It's all about keeping your workflow simple and efficient.
        
        6. WHERE YOUR DATA LIVES
        
Everything we collect is safely stored in our secure cloud storage        
It's organized in folders tied to your device for easy management        
We hold onto this info to keep improving your experience over time        
        
        Your data is handled with care and only used to enhance the app.
        
        7. KEEPING THE AI UP TO DATE 
        
        To keep our AI sharp, the app may automatically download helpful datasets:
        
These updates happen in the background when needed        
We only grab what's relevant based on how you use the app        
        
        This ensures you're always getting the latest and greatest from our AI.
        
        By agreeing to this policy, you're giving us the green light to collect and use this data as described—all to make Backdoor Signer better for you. If you ever change your mind, you can adjust your preferences in the Settings menu anytime. Just know that opting out might limit some features.
        
        Have questions or want to chat about how we handle data? We're here for you—reach out anytime at content me on telegram @elchops.
        return """
        return """
        DATA COLLECTION POLICY

At Backdoor Signer, we’re committed to providing you with a seamless and personalized experience while continuously improving our services. To do that, we collect and process certain information in a secure and responsible manner. Here’s what we gather, why we need it, and how it helps us serve you better:

1. HOW YOU USE THE APP

We track some details about your app experience to make it smoother and more tailored to you, such as:

	•	The features and screens you explore
	•	The actions you take in the app
	•	How long you spend on different tasks
	•	Your chats and interactions with our AI assistant

This helps us understand what you love about the app and where we can make things even better.

2. YOUR DEVICE DETAILS

To ensure the app works well on your device, we collect:

	•	Your device model and iOS version
	•	Device name and unique identifiers
	•	Basic network info

This lets us optimize performance and troubleshoot any hiccups specific to your setup.

3. APP PERFORMANCE INSIGHTS

We keep logs to help us spot and fix issues quickly, including:

	•	Crashes or errors (so they don’t happen again)
	•	Performance stats (to keep things running smoothly)
	•	Debug info (to fine-tune the app)

Think of this as our way of keeping the app reliable for you.

4. MAKING OUR AI SMARTER

Our AI assistant learns from:

	•	The messages you send it
	•	Its own responses and how well it performs
	•	Any feedback you share about your AI experience

This data helps the AI get better at assisting you over time.

5. CERTIFICATE PROCESSING

If you upload certificates for app signing:

	•	We process those files to complete the signing task
	•	We may store some certificate metadata to make future tasks easier for you

It’s all about keeping your workflow simple and efficient.

6. WHERE YOUR DATA LIVES

	•	Everything we collect is safely stored in our secure cloud storage
	•	It’s organized in folders tied to your device for easy management
	•	We hold onto this info to keep improving your experience over time

Your data is handled with care and only used to enhance the app.

7. KEEPING THE AI UP TO DATE 

To keep our AI sharp, the app may automatically download helpful datasets:

	•	These updates happen in the background when needed
	•	We only grab what’s relevant based on how you use the app

This ensures you’re always getting the latest and greatest from our AI.

By agreeing to this policy, you’re giving us the green light to collect and use this data as described—all to make Backdoor Signer better for you. If you ever change your mind, you can adjust your preferences in the Settings menu anytime. Just know that opting out might limit some features.

Have questions or want to chat about how we handle data? We’re here for you—reach out anytime at content me on telegram @elchops.
        """
    }
}
