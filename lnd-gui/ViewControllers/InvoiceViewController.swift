//
//  InvoiceViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/14/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** Invoice view controller
 */
class InvoiceViewController: NSViewController, ErrorReporting {
  // MARK: - @IBOutlets
  
  /** Amount text field
   */
  @IBOutlet weak var amountTextField: NSTextField?
  
  /** Date text field
   */
  @IBOutlet weak var dateTextField: NSTextField?
  
  /** Description text field
   */
  @IBOutlet weak var descriptionTextField: NSTextField?
  
  /** Payment request text field
   */
  @IBOutlet weak var paymentRequestTextField: NSTextField?
  
  /** Settlement text field
   */
  @IBOutlet weak var settlementTextField: NSTextField?
  
  // MARK: - Properties
  
  /** Invoice
   */
  var invoice: Invoice? { didSet { updatedInvoice() } }

  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
}

// MARK: - Failures
extension InvoiceViewController {
  /** Failures
   */
  enum Failure: Error {
    case expectedInvoice
  }
}

// MARK: - NSViewController
extension InvoiceViewController {
  /** Updated invoice
   */
  func updatedInvoice() {
    guard let invoice = invoice else { return reportError(Failure.expectedInvoice) }
    
    amountTextField?.stringValue = (invoice.tokens?.formatted(with: .testBitcoin) ?? String()) as String
    
    let invoiceLabelComment = "Invoice payment state description"
    let invoiceLabel = invoice.confirmed ? "Invoice was paid" : "Waiting for payment"

    let localizedInvoiceState = NSLocalizedString(invoiceLabel, comment: invoiceLabelComment)

    dateTextField?.stringValue = invoice.createdAt?.formatted(dateStyle: .short, timeStyle: .short) ?? String()
    descriptionTextField?.stringValue = (invoice.memo ?? String()) as String
    paymentRequestTextField?.stringValue = invoice.paymentRequest
    settlementTextField?.stringValue = localizedInvoiceState
    paymentRequestTextField?.textColor = invoice.confirmed ? .disabledControlTextColor : .controlTextColor
    paymentRequestTextField?.isSelectable = !invoice.confirmed
  }
}
