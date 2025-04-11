# Backdoor App Signer

![Backdoor App Logo](https://via.placeholder.com/150x150.png?text=Backdoor)

## Introduction

Backdoor App Signer is a powerful iOS application that lets you sign, install, and manage iOS applications directly on your device. This tool enables developers, testers, and power users to work with app packages using their own certificates and provisioning profiles without requiring a computer.

## Features

### App Management
- **App Signing**: Sign iOS apps with your certificates and provisioning profiles using [Zsign](https://github.com/zhlynn/zsign) technology
- **App Installation**: Install signed apps directly to your device via a built-in HTTPS server
- **App Library**: Maintain a catalog of your signed and downloaded apps
- **Bundle ID Protection**: Automatic modification of bundle IDs to avoid conflicts with App Store versions

### Certificate Management
- **Certificate Import**: Import and manage signing certificates (.p12, .cer)
- **Provisioning Profile Support**: Handle iOS provisioning profiles (.mobileprovision)
- **Certificate Validation**: Verify certificate validity and expiration dates
- **Secure Storage**: Proprietary .backdoor format for secure certificate storage

### Built-in Terminal
- **Command Line Interface**: Execute terminal commands within the app
- **File Operations**: Perform file management operations (ls, cp, mv, etc.)
- **App Utilities**: Access system information and app-specific commands
- **Script Support**: Run automation scripts for complex operations

### AI Assistant
- **Context-Aware Help**: Get assistance with app-related tasks
- **Command Suggestions**: Receive recommendations based on usage patterns
- **Learning Capability**: AI assistant improves over time with user interaction
- **On-device Learning**: CoreML integration for local model training
- **Offline Support**: Core functionality works without internet connectivity

### Advanced Features
- **Custom App Icons**: Change app icons after signing
- **Tweak Integration**: Add enhancement libraries to apps
- **Self-hosted HTTPS Server**: Uses localhost.direct certificate for local app installation
- **URL Scheme Handling**: Support for `backdoor://` URL schemes
- **Safe Mode**: Troubleshoot issues with reduced functionality for stability

## System Requirements

- iOS 15.0 or later
- iPhone, iPad, or iPod Touch
- Minimum 300MB free storage space
- Internet connection for cloud features and updates

## Technical Implementation

Backdoor App Signer uses the following technologies:

- **Signing Engine**: Custom implementation of [Zsign](https://github.com/zhlynn/zsign) for iOS
- **HTTPS Server**: [Vapor](https://github.com/vapor/vapor) with [localhost.direct](https://github.com/Upinel/localhost.direct) certificate
- **AI Processing**: CoreML for on-device learning and pattern recognition
- **File Processing**: Native Swift implementation for handling app packages
- **Security**: Advanced encryption for storing sensitive certificate data

## Installation

1. Download the latest IPA file from the [GitHub Releases](https://github.com/app-an-server-official/releases) page
2. Sign and install the app using a method of your choice (AltStore, Sideloadly, etc.)
3. On first launch, follow the on-screen setup instructions
4. Import your certificates and provisioning profiles

## Usage Guide

### Getting Started
1. Navigate to the Settings tab and import your certificates
2. From the Sources tab, download apps or import your own IPA files
3. Sign the apps with your certificates
4. Install and use the signed apps

### Signing an App
1. Select an app from your library or import a new IPA file
2. Tap "Sign" to begin the signing process
3. Select the certificate to use for signing
4. Configure any signing options (custom app name, version, etc.)
5. Tap "Start Signing" to process the app
6. Once complete, you can install the signed app directly

### Using the Terminal
1. Access the Terminal from the Settings tab
2. Enter commands to manage files, view system information, or run scripts
3. Use built-in commands for app-specific operations
4. Save frequently used commands for quick access

### AI Assistant
1. Access the AI assistant from any screen using the floating button
2. Ask questions about app signing, certificates, or other app functions
3. The assistant will provide contextual help based on your current activity
4. Provide feedback to help improve the assistant's responses

## Frequently Asked Questions

### How does Backdoor work?
Backdoor allows you to import a `.p12` certificate and a `.mobileprovision` profile to sign applications. It uses Zsign for the signing process and feeds it the certificates you've selected in the certificates tab.

### Why does Backdoor append a random string to the bundle ID?
This is a safety measure. New Apple Developer Program memberships created after June 2021 require development and ad-hoc signed apps to check with a Provisioning Profile Query Check service. This check looks for similar bundle identifiers on the App Store, and if a match is found with a non-App Store certificate, your Apple ID could be flagged. The random string helps prevent this issue, but it can be disabled in settings if needed.

### What about free developer accounts?
Backdoor is designed for use with paid developer accounts. For free developer accounts, we recommend alternatives such as [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io).

## Troubleshooting

### Safe Mode
If the app crashes repeatedly, it will launch in Safe Mode with limited functionality:
1. Confirm the Safe Mode prompt when it appears
2. Navigate to Settings → Reset → Clear Cache
3. Restart the app normally

### Common Issues

#### Certificate Import Failures
- Ensure your certificate is in the correct format (.p12, .cer, or .backdoor)
- Check that your certificate password is correct
- Verify that your certificate is not expired

#### App Signing Errors
- Check that your provisioning profile matches your certificate
- Ensure the app is compatible with your iOS version
- Verify that you have sufficient storage space

#### Installation Failures
- Check that your device is compatible with the app
- Ensure that you trust the developer certificate in iOS Settings
- Verify that the app is properly signed

## License

Backdoor App Signer is protected under the Proprietary Software License Version 1.0.
Copyright (C) 2025 BDG

You may not use, modify, or distribute this software except as expressly permitted under the terms of the Proprietary Software License.

## Support

For assistance with Backdoor App Signer:
- File issues in the [GitHub repository](https://github.com/app-an-server-official/issues)
- Join our community forum
- Contact support via the in-app support form
- Consult the AI assistant for immediate help

---

*Disclaimer: Backdoor App Signer is meant for legitimate development and testing purposes only. Users are responsible for complying with Apple's terms and conditions and any applicable laws regarding app signing and distribution.*
