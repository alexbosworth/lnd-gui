//
//  PaymentViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/17/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

class PaymentViewController: NSViewController {
  // MARK: - @IBOutlets
  
  @IBOutlet weak var amountTextField: NSTextField?
  
  @IBOutlet weak var confirmedTextField: NSTextField?
  
  @IBOutlet weak var dateTextField: NSTextField?
  
  @IBOutlet weak var destinationTextField: NSTextField?
  
  @IBOutlet weak var feeTextField: NSTextField?
  
  @IBOutlet weak var idTextField: NSTextField?
  
  // MARK: - Properties
  
  var transaction: Transaction? { didSet { updatedTransaction() } }
}

extension PaymentViewController {
  func updatedTransaction() {
    guard let transaction = transaction else { return }
    
    amountTextField?.stringValue = "\(transaction.tokens.formatted) tBTC"
    
    confirmedTextField?.stringValue = transaction.confirmed ? "Sent Payment" : "Pending Payment"
    
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    dateTextField?.stringValue = formatter.string(from: (transaction.createdAt ?? Date()) as Date)
    
    feeTextField?.stringValue = "Free"

    switch transaction.destination {
    case .chain:
      destinationTextField?.stringValue = "Chain"
      idTextField?.stringValue = transaction.id
      
    case .received(_):
      print("ERROR", "expected chain or sent payment")
      
    case .sent(publicKey: let publicKey, paymentId: let paymentId):
      destinationTextField?.stringValue = publicKey
      idTextField?.stringValue = paymentId
    }
  }
}
