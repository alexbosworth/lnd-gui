//
//  Tokens.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/23/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Tokens represent a currency value using the base unit.
 */
typealias Tokens = UInt64

// MARK: - Formatting
extension Tokens {
  /** Formatting defines currency formatting definitions.
   */
  private enum Formatting {
    static let minimumFractionDigits = 8
    static let minimumIntegerDigits = 1
    static let valueDenominator: Double = 100_000_000
  }
  
  /** formatted returns the string formatted version of the value.
   */
  var formatted: String {
    let formatter = NumberFormatter()
    let largeUnitValue: Double = Double(self) / Formatting.valueDenominator
    
    formatter.minimumFractionDigits = Formatting.minimumFractionDigits
    formatter.minimumIntegerDigits = Formatting.minimumIntegerDigits
    
    return (formatter.string(from: NSNumber(value: largeUnitValue)) ?? String()) as String
  }
}

// MARK: - NSNumber
extension NSNumber {
  /** Get tokens from a NSNumber
   */
  var tokensValue: Tokens { return uint64Value }
}
