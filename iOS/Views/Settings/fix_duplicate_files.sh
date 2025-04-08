#!/bin/bash

# Script to fix duplicate Swift files causing build conflicts
# This addresses build errors related to duplicate .stringsdata outputs

# Create a backup directory
BACKUP_DIR="iOS/Views/Settings/AI Learning/backup"
mkdir -p "$BACKUP_DIR"

# List of files that are duplicated
DUPLICATE_FILES=(
    "AILearningSettingsViewController.swift"
    "ImprovedLearningSettingsCell.swift"
    "ImprovedLearningViewController.swift"
    "ModelServerIntegrationViewController.swift"
)

# Move files from AI Learning to backup
echo "Moving duplicate files to backup..."
for file in "${DUPLICATE_FILES[@]}"; do
    if [ -f "iOS/Views/Settings/AI Learning/$file" ]; then
        echo "Backing up: $file"
        mv "iOS/Views/Settings/AI Learning/$file" "$BACKUP_DIR/$file"
    fi
done

# Check if there's still a Safe Async file in the AI Learning directory
# that we might need to preserve functionality
if [ -f "iOS/Views/Settings/AI Learning/ModelServerIntegrationViewController+SafeAsync.swift" ]; then
    # Check if the parent directory already has the file
    if [ ! -f "iOS/Views/Settings/ModelServerIntegrationViewController+SafeAsync.swift" ]; then
        # Copy it to the parent directory to maintain functionality
        echo "Copying ModelServerIntegrationViewController+SafeAsync.swift to parent directory"
        cp "iOS/Views/Settings/AI Learning/ModelServerIntegrationViewController+SafeAsync.swift" "iOS/Views/Settings/"
    fi
fi

echo "Done. Files have been moved to $BACKUP_DIR"
echo "The Xcode project should now build without duplicate outputs."
echo ""
echo "After running this script, do the following:"
echo "1. Clean the build folder in Xcode (Shift+Command+K)"
echo "2. Clean the derived data (in Xcode menu: Product > Clean Build Folder)"
echo "3. Rebuild the project"
