//
//  LaunchTerminalViewController.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

/// LaunchTerminalViewController - Button to launch the terminal
/// This view controller provides a simplified UI to launch the Terminal
class LaunchTerminalViewController: UIViewController {
    
    private let containerView = UIView()
    private let launchButton = UIButton(type: .system)
    private let iconImageView = UIImageView()
    private let descriptionLabel = UILabel()
    private let logger = Debug.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Terminal"
        view.backgroundColor = UIColor(named: "Background") ?? .systemBackground
        
        setupUI()
        setupConstraints()
        
        logger.log(message: "Terminal launch view controller loaded", type: .info)
    }
    
    private func setupUI() {
        // Container view
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Terminal icon
        iconImageView.image = UIImage(systemName: "terminal")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .tintColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)
        
        // Description label
        descriptionLabel.text = "The terminal provides command-line access to perform advanced operations with the backend server."
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)
        
        // Launch button
        launchButton.setTitle("Open Terminal", for: .normal)
        launchButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        launchButton.backgroundColor = .tintColor
        launchButton.setTitleColor(.white, for: .normal)
        launchButton.layer.cornerRadius = 12
        launchButton.addTarget(self, action: #selector(launchTerminal), for: .touchUpInside)
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(launchButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Button
            launchButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            launchButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            launchButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.7),
            launchButton.heightAnchor.constraint(equalToConstant: 50),
            launchButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    @objc private func launchTerminal() {
        logger.log(message: "Launching terminal from launch view", type: .info)
        
        let terminalVC = TerminalViewController()
        let navController = UINavigationController(rootViewController: terminalVC)
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true)
    }
}
