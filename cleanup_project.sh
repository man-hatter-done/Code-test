#!/bin/bash

# Script to clean up duplicates in project.pbxproj
PROJ_FILE="backdoor.xcodeproj/project.pbxproj"
BACKUP_FILE="backdoor.xcodeproj/project.pbxproj.before_cleanup"

# Make a backup
cp "$PROJ_FILE" "$BACKUP_FILE"

# Find the problematic section and fix it
awk '
BEGIN { in_exception_set = 0; member_count = 0; }
/PBXFileSystemSynchronizedBuildFileExceptionSet.*=/ { in_exception_set = 1; print; next; }
/SettingsHeaderTableViewCell.swift,/ && in_exception_set { 
    if (member_count == 0) { print; member_count++; } 
    next; 
}
/AILearningSettingsViewController.swift,/ && in_exception_set { 
    if (member_count == 1) { print; member_count++; } 
    next; 
}
/ImprovedLearningSettingsCell.swift,/ && in_exception_set { 
    if (member_count == 2) { print; member_count++; } 
    next; 
}
/ImprovedLearningViewController.swift,/ && in_exception_set { 
    if (member_count == 3) { print; member_count++; } 
    next; 
}
/ModelServerIntegrationViewController.swift,/ && in_exception_set { 
    if (member_count == 4) { print; member_count++; } 
    next; 
}
/\);/ && in_exception_set { in_exception_set = 0; print; next; }
{ print; }
' "$BACKUP_FILE" > "$PROJ_FILE"

echo "Project file cleaned up. Backup saved as $BACKUP_FILE"
