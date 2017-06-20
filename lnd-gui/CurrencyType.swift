//
//  CurrencyType.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/23/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Currency types
 */
enum CurrencyType {
  case testBitcoin
  case testUnitedStatesDollars

  /** Currency symbol used on exchanges
   */
  var exchangeSymbol: String {
    switch self {
    case .testBitcoin:
      return "BTC"
      
    case .testUnitedStatesDollars:
      return "USD"
    }
  }
  
  /** Short currency symbol
   */
  var symbol: String {
    switch self {
    case .testBitcoin:
      return "tBTC"
      
    case .testUnitedStatesDollars:
      return "tUSD"
    }
  }
  
  /** Create from symbol
   */
  init?(from symbol: String) {
    switch symbol {
    case CurrencyType.testBitcoin.symbol:
      self = .testBitcoin
      
    case CurrencyType.testUnitedStatesDollars.symbol:
      self = .testUnitedStatesDollars
      
    default:
      return nil
    }
  }
}
