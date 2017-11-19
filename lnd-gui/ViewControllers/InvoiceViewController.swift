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
class InvoiceViewController: NSViewController {
  // MARK: - @IBOutlets
  
  /** Address label
   */
  @IBOutlet weak var addressLabel: NSTextField?
  
  /** Address text field
   */
  @IBOutlet weak var addressTextField: NSTextField?
  
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
  var invoice: LightningInvoice? { didSet { do { try updatedInvoice() } catch { reportError(error) } } }
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
  
  /** Wallet
   */
  var wallet: Wallet?
}

// MARK: - ErrorReporting
extension InvoiceViewController: ErrorReporting {
  /** Failures
   */
  enum Failure: Error {
    case expectedInvoice
  }
}

// MARK: - FiatConverting
extension InvoiceViewController: FiatConverting {}

// MARK: - NSViewController
extension InvoiceViewController {
  /** Updated invoice
   */
  func updatedInvoice() throws {
    guard let invoice = invoice else { return reportError(Failure.expectedInvoice) }
    
    amountTextField?.stringValue = invoice.tokens.formatted(with: .testBitcoin)
    
    let invoiceLabelComment = "Invoice payment state description"
    let invoiceLabel = invoice.isConfirmed ? "Received Payment" : "Requested Payment"

    let localizedInvoiceState = NSLocalizedString(invoiceLabel, comment: invoiceLabelComment)
    
    descriptionTextField?.stringValue = (invoice.memo ?? String()) as String
    paymentRequestTextField?.stringValue = (invoice.paymentRequest ?? String()) as String
    headingTextField?.stringValue = localizedInvoiceState
    paymentRequestTextField?.textColor = invoice.isConfirmed ? .disabledControlTextColor : .controlTextColor
    paymentRequestTextField?.isSelectable = !invoice.isConfirmed
    
    // Deselect text in payment request text field
    if invoice.isConfirmed { paymentRequestTextField?.currentEditor()?.selectedRange = NSMakeRange(Int(), Int()) }
    
    guard let centsPerCoin = self.centsPerCoin?() else { return }
    
    amountTextField?.stringValue += try invoice.tokens.converted(to: .testUnitedStatesDollars, with: centsPerCoin)
    
    if let chainAddress = invoice.chainAddress { addressTextField?.stringValue = chainAddress }
    
    [addressLabel, addressTextField].forEach { $0?.isHidden = invoice.chainAddress == nil }
  }
  
  /** View appeared
   */
  override func viewDidAppear() {
    super.viewDidLoad()
    
    paymentRequestTextField?.isEditable = true
    paymentRequestTextField?.becomeFirstResponder()
    paymentRequestTextField?.isEditable = false
    
    do { try updatedInvoice() } catch { reportError(error) }
    
    guard let invoice = invoice, invoice.isConfirmed else { return }
    
    DispatchQueue.main.async { [weak self] in self?.paymentRequestTextField?.resignFirstResponder() }
  }
}

// MARK: - WalletListener
extension InvoiceViewController: WalletListener {
  /** Wallet was updated
   */
  func walletUpdated() {
    guard let invoice = invoice, let updatedInvoice = wallet?.invoice(invoice) else { return }
    
    self.invoice = updatedInvoice
  }
}
