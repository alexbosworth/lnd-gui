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
  
  /** Description text field
   */
  @IBOutlet weak var descriptionTextField: NSTextField?
  
  /** Heading text field
   */
  @IBOutlet weak var headingTextField: NSTextField?
  
  /** Payment request text field
   */
  @IBOutlet weak var paymentRequestTextField: NSTextField?
  
  // MARK: - Properties
  
  /** Cents per coin
   */
  var centsPerCoin: (() -> (Int?))?
  
  /** Invoice
   */
  var invoice: Invoice? { didSet { do { try updatedInvoice() } catch { reportError(error) } } }

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
  func updatedInvoice() throws {
    guard let invoice = invoice else { return reportError(Failure.expectedInvoice) }
    
    amountTextField?.stringValue = (invoice.tokens?.formatted(with: .testBitcoin) ?? String()) as String
    
    let invoiceLabelComment = "Invoice payment state description"
    let invoiceLabel = invoice.confirmed ? "Received Payment" : "Unpaid Invoice"

    let localizedInvoiceState = NSLocalizedString(invoiceLabel, comment: invoiceLabelComment)

    descriptionTextField?.stringValue = (invoice.memo ?? String()) as String
    paymentRequestTextField?.stringValue = invoice.paymentRequest
    headingTextField?.stringValue = localizedInvoiceState
    paymentRequestTextField?.textColor = invoice.confirmed ? .disabledControlTextColor : .controlTextColor
    paymentRequestTextField?.isSelectable = !invoice.confirmed
    
    // Deselect text in payment request text field
    if invoice.confirmed { paymentRequestTextField?.currentEditor()?.selectedRange = NSMakeRange(Int(), Int()) }
    
    guard let centsPerCoin = self.centsPerCoin?() else { return }
    
    guard let tokens = invoice.tokens else { return }
    
    amountTextField?.stringValue += try tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
  }
  
  /** View appeared
   */
  override func viewDidAppear() {
    super.viewDidLoad()
    
    paymentRequestTextField?.isEditable = true
    paymentRequestTextField?.becomeFirstResponder()
    paymentRequestTextField?.isEditable = false
    
    guard let invoice = invoice, invoice.confirmed else { return }

    DispatchQueue.main.async { [weak self] in self?.paymentRequestTextField?.resignFirstResponder() }
  }
}

// MARK: - WalletListener
extension InvoiceViewController: WalletListener {
  /** Wallet was updated
   */
  func wallet(updated wallet: Wallet) {
    guard let invoice = invoice, let transaction = wallet.invoice(invoice) else { return }
    
    guard case .received(let updatedInvoice) = transaction.destination else { return }
    
    self.invoice = updatedInvoice
  }
}

