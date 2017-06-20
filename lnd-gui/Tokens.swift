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
  fileprivate enum Formatting {
    static let centsDenominator = 100
    static let minimumFractionDigits = 8
    static let minimumIntegerDigits = 1
    static let valueDenominator: Double = 100_000_000
  }
  
  /** Parse tokens from string
   */
  init(from amount: String) {
    guard !amount.isEmpty else { self = Tokens(); return }
    
    let number = (NSDecimalNumber(string: amount) as Decimal) * (NSDecimalNumber(value: 100_000_000) as Decimal)
    
    self = type(of: self).init((number as NSDecimalNumber).doubleValue)
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

  /** Formatted with a unit label
   */
  func formatted(with unit: CurrencyType) -> String {
    return "\(formatted) \(unit.symbol)"
  }
}

// MARK: - NSNumber
extension NSNumber {
  /** Get tokens from a NSNumber
   */
  var tokensValue: Tokens { return uint64Value }
}

extension Tokens {
  enum ConversionFailure: Error {
    case expectedFormatted
  }
  
  func converted(to currency: CurrencyType, with centsPerCoin: Int) throws -> String {
    let formatter = NumberFormatter()

    formatter.locale = Locale(identifier: Locale.current.identifier)
    formatter.maximumFractionDigits = 2
    formatter.numberStyle = .currency

    let value = Decimal(self * UInt64(centsPerCoin) / UInt64(Formatting.valueDenominator)) / Decimal(Formatting.centsDenominator)
    
    guard let val = formatter.string(from: value as NSNumber) else { throw ConversionFailure.expectedFormatted }

    return " (\(val) \(CurrencyType.testUnitedStatesDollars.symbol))"
  }
}
