//
//  CurrencyTypeMenuItem.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 6/18/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Currency type menu item
 */
protocol CurrencyTypeMenuItem {
  var currencyType: CurrencyType { get }
}

/** TestBitcoin menu item
 */
class TestBitcoinMenuItem: NSMenuItem, CurrencyTypeMenuItem {
  /** Currency type
   */
  let currencyType: CurrencyType = .testBitcoin
}

/** TestUnitedStatesDollars menu item
 */
class TestUnitedStatesDollarsMenuItem: NSMenuItem, CurrencyTypeMenuItem {
  /** Currency type
   */
  let currencyType: CurrencyType = .testUnitedStatesDollars
}
