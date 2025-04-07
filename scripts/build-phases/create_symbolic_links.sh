#!/bin/bash

# Create symbolic links for Swift files that need to be accessible directly from Settings directory
SETTINGS_DIR="$PROJECT_DIR/iOS/Views/Settings"

# Create link for SettingsHeaderTableViewCell.swift
ln -sf About/SettingsHeaderTableViewCell.swift "$SETTINGS_DIR/SettingsHeaderTableViewCell.swift"

# Create links for AI Learning files
ln -sf "AI Learning/AILearningSettingsViewController.swift" "$SETTINGS_DIR/AILearningSettingsViewController.swift"
ln -sf "AI Learning/ImprovedLearningSettingsCell.swift" "$SETTINGS_DIR/ImprovedLearningSettingsCell.swift"
ln -sf "AI Learning/ImprovedLearningViewController.swift" "$SETTINGS_DIR/ImprovedLearningViewController.swift"
ln -sf "AI Learning/ModelServerIntegrationViewController.swift" "$SETTINGS_DIR/ModelServerIntegrationViewController.swift"

echo "Created symbolic links for Swift files in Settings directory"
