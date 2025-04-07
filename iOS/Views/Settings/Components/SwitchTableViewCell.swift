// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import UIKit

/// A reusable table view cell with a switch control
class SwitchTableViewCell: UITableViewCell {
    
    let switchControl = UISwitch()
    var switchValueChanged: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        
        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        accessoryView = switchControl
        selectionStyle = .none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func switchChanged() {
        switchValueChanged?(switchControl.isOn)
    }
}
