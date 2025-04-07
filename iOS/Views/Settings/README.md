# Settings Directory Symbolic Links

## Important Note for Developers
These symbolic links are crucial for successful compilation and are already included in the GitHub repository. **No additional configuration is required** when cloning the repo - the links themselves should fix the compilation issues.

## Problem
The Xcode project uses File System Synchronized Groups to automatically include files in the build process. However, the compiler looks for certain files directly in the `iOS/Views/Settings/` directory, while the actual files are stored in subdirectories like `iOS/Views/Settings/About/` and `iOS/Views/Settings/AI Learning/`.

## Solution
Symbolic links have been created in the `iOS/Views/Settings/` directory pointing to the actual files in their subdirectories. This allows the files to remain in their original locations while still being properly found by the compiler.

### Files with Symbolic Links:
- `SettingsHeaderTableViewCell.swift` → `About/SettingsHeaderTableViewCell.swift`
- `AILearningSettingsViewController.swift` → `AI Learning/AILearningSettingsViewController.swift`
- `ImprovedLearningSettingsCell.swift` → `AI Learning/ImprovedLearningSettingsCell.swift`
- `ImprovedLearningViewController.swift` → `AI Learning/ImprovedLearningViewController.swift`
- `ModelServerIntegrationViewController.swift` → `AI Learning/ModelServerIntegrationViewController.swift`

## Why This Approach?
This approach was chosen to minimize changes to the project structure and configuration while still fixing the compilation errors. It allows the original file organization to be maintained while ensuring the compiler can find all necessary files.

## If Symbolic Links Are Lost
If you ever lose these symbolic links (e.g., during a complex merge), you can recreate them manually using these commands:

```bash
cd iOS/Views/Settings/
ln -sf About/SettingsHeaderTableViewCell.swift SettingsHeaderTableViewCell.swift
ln -sf "AI Learning/AILearningSettingsViewController.swift" AILearningSettingsViewController.swift
ln -sf "AI Learning/ImprovedLearningSettingsCell.swift" ImprovedLearningSettingsCell.swift
ln -sf "AI Learning/ImprovedLearningViewController.swift" ImprovedLearningViewController.swift
ln -sf "AI Learning/ModelServerIntegrationViewController.swift" ModelServerIntegrationViewController.swift
```

Or run the provided script:
```bash
./scripts/build-phases/create_symbolic_links.sh
```
