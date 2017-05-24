//
//  SentTransactionViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/14/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Sent transaction view controller
 */
class SentTransactionViewController: NSViewController, ErrorReporting {
  // MARK: - @IBOutlets
  
  /** Amount text field
   */
  @IBOutlet weak var amountTextField: NSTextField?
  
  /** Destination text field
   */
  @IBOutlet weak var destinationTextField: NSTextField?

  /** Fee text field
   */
  @IBOutlet weak var feeTextField: NSTextField?

  /** Settlement text field
   */
  @IBOutlet weak var settlementTextField: NSTextField?
  
  // MARK: - Properties
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }

  /** Settled transaction
   */
  var settledTransaction: Transaction? { didSet { updatedSettledTransaction() } }
}

// MARK: - Failures
extension SentTransactionViewController {
  /** Failures
   */
  enum Failure: Error {
    case expectedOutgoingTransaction
  }
}

// MARK: - NSViewController
extension SentTransactionViewController {
  /** Updated settled transaction
   */
  fileprivate func updatedSettledTransaction() {
    guard let transaction = settledTransaction else { return }
    
    let destination: String
    let fee: Tokens
    let freeLabel = NSLocalizedString("Free", comment: "Label describing a zero fee")
    let settledLabel: String
    
    switch transaction.destination {
    case .chain:
      destination = transaction.id
      fee = 225 // FIXME: - abstract
      settledLabel = transaction.confirmed ? "Settled on chain" : "Waiting for confirmation"
      
    case .received(_):
      return reportError(Failure.expectedOutgoingTransaction)
      
    case .sent(publicKey: let publicKey, _):
      destination = publicKey
      fee = Tokens() // FIXME: - hook up to the real fee
      settledLabel = transaction.confirmed ? "Settled over Lightning" : "Waiting for settlement"
    }
    
    amountTextField?.stringValue = transaction.tokens.formatted(with: .testBitcoin)
    destinationTextField?.stringValue = destination
    feeTextField?.stringValue = fee > Tokens() ? fee.formatted(with: .testBitcoin) : freeLabel
    settlementTextField?.stringValue = NSLocalizedString(settledLabel, comment: "Label describing settlement status")
  }
}
