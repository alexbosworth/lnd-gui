//
//  CurrencyAmount.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 6/11/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

enum CurrencyAmount {
  case testBitcoins(Tokens)
  case testUnitedStatesDollars(Decimal)
  
  init(fromTestBitcoins amount: String) {
    self = .testBitcoins(Tokens(from: amount))
  }
  
  init(fromTestUnitedStatesDollars amount: String) {
    let numbers = amount.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()

    // Parse string into cents value
    let cents = (NSDecimalNumber(string: numbers) as Decimal)

    self = .testUnitedStatesDollars(cents.isNaN ? Decimal() : cents)
  }
}

extension CurrencyAmount {
  enum ConversionError: Error {
    case invalidConversion
  }
  
  func converted(to currency: CurrencyType, rate: Int) throws -> String {
    let formatted: String
    
    switch (self, currency) {
    case (.testBitcoins(_), .testBitcoin), (.testUnitedStatesDollars(_), .testUnitedStatesDollars):
      throw ConversionError.invalidConversion
      
    case (.testBitcoins(let bitcoins), .testUnitedStatesDollars):
      formatted = try bitcoins.converted(to: .testUnitedStatesDollars, with: rate)
      
    case (.testUnitedStatesDollars(let dollars), .testBitcoin):
      let cents = dollars * Decimal(100)
      
      let coins = !cents.isNaN ? cents / Decimal(rate) : Decimal()
      
      let formatter = NumberFormatter()
      
      formatter.locale = Locale(identifier: Locale.current.identifier)
      formatter.maximumFractionDigits = 8
      formatter.minimumFractionDigits = 8
      formatter.minimumIntegerDigits = 1
      
      guard let converted = formatter.string(from: coins as NSNumber) else { formatted = String(); break }

      formatted = "\(converted) \(currency.exchangeSymbol)"
    }
    
    return formatted
  }
}

