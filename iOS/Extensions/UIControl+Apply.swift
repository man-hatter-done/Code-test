//
//  UIControl+Apply.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

extension UIControl {
    /// Apply a configuration to a UIControl and return it (builder pattern)
    /// - Parameter configuration: Configuration closure to apply to this control
    /// - Returns: Self for chaining
    @discardableResult
    func apply(_ configuration: (Self) -> Void) -> Self {
        // Apply the configuration to self
        configuration(self)
        // Return self for chaining
        return self
    }
}
