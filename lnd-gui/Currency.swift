//
//  Currency.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/23/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Currency types
 */
enum Currency {
  case testBitcoin
  case testUnitedStatesDollars
  
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
}
