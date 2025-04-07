# Settings Directory Symbolic Links

## Problem
The Xcode project uses File System Synchronized Groups to automatically include files in the build process. However, the compiler is looking for certain files directly in the `iOS/Views/Settings/` directory, while the actual files are stored in subdirectories like `iOS/Views/Settings/About/` and `iOS/Views/Settings/AI Learning/`.

## Solution
Symbolic links have been created in the `iOS/Views/Settings/` directory pointing to the actual files in their subdirectories. This allows the files to remain in their original locations while still being properly found by the compiler.

### Files with Symbolic Links:
- `SettingsHeaderTableViewCell.swift` -> `About/SettingsHeaderTableViewCell.swift`
- `AILearningSettingsViewController.swift` -> `AI Learning/AILearningSettingsViewController.swift`
- `ImprovedLearningSettingsCell.swift` -> `AI Learning/ImprovedLearningSettingsCell.swift`
- `ImprovedLearningViewController.swift` -> `AI Learning/ImprovedLearningViewController.swift`
- `ModelServerIntegrationViewController.swift` -> `AI Learning/ModelServerIntegrationViewController.swift`

## Automated Script
A build phase script has been created in `scripts/build-phases/create_symbolic_links.sh` that automatically creates these symbolic links during the build process. This ensures the links are always up to date, even if the repository is freshly cloned or the links are accidentally removed.

To add this script as a build phase in your Xcode project:
1. Open the Xcode project
2. Select the target
3. Go to "Build Phases"
4. Click "+" -> "New Run Script Phase"
5. Set the script to: `$PROJECT_DIR/scripts/build-phases/create_symbolic_links.sh`

## Why This Approach?
This approach was chosen to minimize changes to the project structure and configuration while still fixing the compilation errors. It allows the original file organization to be maintained while ensuring the compiler can find all necessary files.
