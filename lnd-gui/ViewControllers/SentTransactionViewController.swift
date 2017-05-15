//
//  SentTransactionViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/14/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

class SentTransactionViewController: NSViewController {
  // MARK: - @IBOutlets
  
  @IBOutlet weak var amountTextField: NSTextField?
  
  @IBOutlet weak var destinationTextField: NSTextField?

  @IBOutlet weak var feeTextField: NSTextField?

  @IBOutlet weak var settlementTextField: NSTextField?
  
  // MARK: - Properties

  var settledTransaction: Transaction? { didSet { updatedSettledTransaction() } }
}

extension SentTransactionViewController {
  fileprivate func updatedSettledTransaction() {
    guard let transaction = settledTransaction else { return }

    amountTextField?.stringValue = "\(transaction.tokens.formatted) tBTC"
    
    let destination: String
    let fee: Tokens
    
    switch transaction.destination {
    case .chain:
      destination = transaction.id
      fee = 225
      settlementTextField?.stringValue = transaction.confirmed ? "Settled on chain" : "Waiting for confirmation"
      
    case .received(_):
      print("ERROR", "expected outgoing transaction")
      destination = String()
      fee = Tokens()
      
    case .sent(publicKey: let publicKey, _):
      destination = publicKey
      fee = Tokens()
      settlementTextField?.stringValue = transaction.confirmed ? "Settled over Lightning" : "Waiting for settlement"
    }
    
    destinationTextField?.stringValue = destination
    feeTextField?.stringValue = fee > Tokens() ? "\(fee.formatted) tBTC" : "Free"
  }
}
