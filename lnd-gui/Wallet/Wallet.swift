//
//  Wallet.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/3/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

/** Wallet
 */
struct Wallet {
  // MARK: - Init
  
  /** Init empty wallet
   */
  init() {
    transactions = []
    unconfirmedTransactions = []
  }
  
  // MARK: - Properties
  
  /** Confirmed transactions
   */
  var transactions: [Transaction]
  
  /** Unconfirmed transactions
   */
  var unconfirmedTransactions: [Transaction]
}

/** Wallet protocol triggers on wallet updates
 */
protocol WalletListener {
  func wallet(updated: Wallet)
}
