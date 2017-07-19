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

  var payment: LightningPayment? { didSet { do { try updatedPayment() } catch { reportError(error) } } }
}

// MARK: - NSViewController
extension PaymentViewController {
  func updatedPayment() throws {
    guard
      let payment = payment,
      let isConfirmed = payment.isConfirmed,
      let createdAt = payment.createdAt
      else
    {
      return
    }
    
    amountTextField?.stringValue = payment.tokens.formatted(with: .testBitcoin)
    
    confirmedTextField?.stringValue = isConfirmed ? "Sent Payment" : "Pending Payment"
    
    dateTextField?.stringValue = createdAt.formatted(dateStyle: .short, timeStyle: .short)
    
    feeTextField?.stringValue = "Free"

    destinationTextField?.stringValue = (payment.destination?.hexEncoded ?? String()) as String
    
    idTextField?.stringValue = payment.id.hexEncoded
    
    guard let centsPerCoin = self.centsPerCoin?() else { return }
    
    amountTextField?.stringValue += try payment.tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
  }
}
