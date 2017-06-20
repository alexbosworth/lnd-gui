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

  @IBOutlet weak var sendPaymentButton: NSButton?
  
  // MARK: - Properties
  
  var centsPerCoin: (() -> (Int?))?
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }

  var transaction: Transaction? { didSet { do { try updatedTransaction() } catch { reportError(error) } } }
}

// MARK: - NSViewController
extension PaymentViewController {
  func updatedTransaction() throws {
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
    
    guard let centsPerCoin = self.centsPerCoin?() else { return }
    
    amountTextField?.stringValue += try transaction.tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
  }
}
