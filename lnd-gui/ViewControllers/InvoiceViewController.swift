//
//  InvoiceViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/14/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

class InvoiceViewController: NSViewController {
  // MARK: - @IBOutlets
  
  @IBOutlet weak var amountTextField: NSTextField?
  
  @IBOutlet weak var dateTextField: NSTextField?
  
  @IBOutlet weak var descriptionTextField: NSTextField?
  
  @IBOutlet weak var paymentRequestTextField: NSTextField?
  
  @IBOutlet weak var settlementTextField: NSTextField?
  
  // MARK: - Properties
  
  var invoice: Invoice? { didSet { updatedInvoice() } }
}

extension InvoiceViewController {
  func updatedInvoice() {
    guard let invoice = invoice else { return print("ERROR", "expected invoice") }
    
    amountTextField?.stringValue = "\(((invoice.tokens ?? Tokens()) as Tokens).formatted) tBTC"
    
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    
    dateTextField?.stringValue = formatter.string(from: (invoice.createdAt ?? Date()) as Date)
    
    descriptionTextField?.stringValue = (invoice.memo ?? String()) as String
    
    paymentRequestTextField?.stringValue = invoice.paymentRequest
    
    settlementTextField?.stringValue = invoice.confirmed ? "Invoice was paid" : "Waiting for payment"
    
    paymentRequestTextField?.textColor = invoice.confirmed ? .disabledControlTextColor : .controlTextColor
    
    paymentRequestTextField?.isSelectable = !invoice.confirmed
  }
}
