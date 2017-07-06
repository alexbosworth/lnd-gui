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
  func invoice(_ invoice: LightningInvoice) -> LightningInvoice? {
    guard let tx = (transactions.first { $0.id == invoice.id }) else { return nil }
    
    switch tx {
    case .blockchain(_):
      return nil
      
    case .lightning(let lightningTransaction):
      switch lightningTransaction {
      case .invoice(let invoice):
        return invoice
        
      case .payment(_):
        return nil
      }
    }
  }
}
