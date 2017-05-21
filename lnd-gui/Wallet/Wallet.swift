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
  
  // MARK: - Propertiesvar
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

extension Wallet {
  /** Determine if a payment is present
   */
  func invoice(_ invoice: Invoice) -> Transaction? {
    return transactions.first { transaction in
      guard case .received(_) = transaction.destination else { return false }
      
      return transaction.id == invoice.id
    }
  }
}
