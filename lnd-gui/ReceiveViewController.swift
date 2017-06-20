//
//  ReceiveViewController.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 3/12/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Cocoa

/** ReceiveViewController is a view controller for creating invoices
 
 FIXME: - disable the clear button when there is nothing to clear
 FIXME: - disable the create invoice button when there is nothing to create
 FIXME: - add copy button
 FIXME: - don't allow entering too much or too little Satoshis
 FIXME: - when received, show received notification
 FIXME: - add fiat
 FIXME: - add receive on chain bitcoins method
 */
class ReceiveViewController: NSViewController, ErrorReporting {
  // MARK: - @IBActions
  
  /** Pressed amount options button
   */
  @IBAction func pressedAmountOptionsButton(_ button: NSPopUpButton) {
    guard let currencyTypeMenuItem = button.selectedItem as? CurrencyTypeMenuItem else {
      return reportError(Failure.expectedCurrencyTypeMenuItem)
    }

    currency = currencyTypeMenuItem.currencyType
  }

  /** Pressed clear button triggers clearing the current payment request.
   */
  @IBAction func pressedClearButton(_ button: NSButton) {
    clear()
  }
  
  /** Pressed blockchain item
   */
  @IBAction func pressedInvoiceBlockchainItem(_ item: NSMenuItem) {
    guard let chainAddress = invoice?.chainAddress else { return reportError(Failure.expectedChainAddress) }
    
    paymentRequestTextField?.stringValue = chainAddress
  }

  /** Pressed lightning item
   */
  @IBAction func pressedInvoiceLightningItem(_ item: NSMenuItem) {
    guard let paymentRequest = invoice?.paymentRequest else { return reportError(Failure.expectedPaymentRequest) }
    
    paymentRequestTextField?.stringValue = paymentRequest
  }
  
  /** Pressed request button to trigger the creation of a new request
   */
  @IBAction func pressedRequestButton(_ button: NSButton) {
    guard let amountString = amountTextField?.stringValue else { return }

    do { try addInvoice(amount: Tokens(from: amountString), memo: memoTextField?.stringValue) } catch { print(error) }
  }

  // MARK: - @IBOutlets

  /** amountTextField is the input text field for the invoice amount.
   */
  @IBOutlet weak var amountTextField: NSTextField?
  
  @IBOutlet weak var clearButton: NSButton?
  
  @IBOutlet weak var currencyConversionTextField: NSTextField?
  
  @IBOutlet weak var currencyTextField: NSTextField?
  
  /** Switcher for invoice type
   */
  @IBOutlet weak var invoiceTypeButton: NSPopUpButton?

  /** memoTextField is the input text field for the memo.
   */
  @IBOutlet weak var memoTextField: NSTextField?
  
  /** Invoice date text field
   */
  @IBOutlet weak var paymentInvoiceDate: NSTextField?

  /** Payment received amount
   */
  @IBOutlet weak var paymentReceivedAmount: NSTextField?

  /** Payment received box
   */
  @IBOutlet weak var paymentReceivedBox: NSBox?

  /** Payment received description
   */
  @IBOutlet weak var paymentReceivedDescription: NSTextField?
  
  /** paymentRequestHeadingTextField is the label showing the payment request header.
   */
  @IBOutlet weak var paymentRequestHeadingTextField: NSTextField?
  
  /** paymentRequestTextField is the label showing the full payment request.
   */
  @IBOutlet weak var paymentRequestTextField: NSTextField?
  
  /** requestButton is the button that triggers the creation of a new payment request
   */
  @IBOutlet weak var requestButton: NSButton?
  
  /** Select lightning invoice item
   */
  @IBOutlet weak var selectLightningItem: NSMenuItem?
  
  // MARK: - Properties
  
  var centsPerCoin: (() -> (Int?))?
  
  var creatingInvoice = false { didSet { updatedCreatingInvoice() } }
  
  var currency: CurrencyType = .testBitcoin { didSet { do { try updatedSelectedCurrency() } catch { reportError(error) } } }
  
  /** invoice is the created invoice to receive funds to.
   */
  var invoice: Invoice? { didSet { updatedPaymentRequest() } }

  /** Paid invoice
   */
  var paidInvoice: Transaction? { didSet { updatedPaidInvoice() } }
  
  /** Report error
   */
  lazy var reportError: (Error) -> () = { _ in }
  
  /** Show an invoice
   */
  lazy var showInvoice: (Invoice) -> () = { _ in }
}

// MARK: - Failures
extension ReceiveViewController {
  enum Failure: Error {
    case expectedChainAddress
    case expectedCurrencyTypeMenuItem
    case expectedCurrentEvent
    case expectedInvoiceCreationDate
    case expectedPaymentRequest
  }
}

// MARK: - Networking
extension ReceiveViewController {
  /** Updated creating invoice state
   */
  func updatedCreatingInvoice() {
    switch creatingInvoice {
    case false:
      amountTextField?.isEditable = true
      clearButton?.isEnabled = true
      clearButton?.state = NSOnState
      memoTextField?.isEditable = true
      requestButton?.isEnabled = true
      requestButton?.state = NSOnState
      requestButton?.title = NSLocalizedString("Create Invoice", comment: "Create new invoice button")
      
    case true:
      amountTextField?.isEditable = false
      clearButton?.isEnabled = false
      clearButton?.state = NSOffState
      memoTextField?.isEditable = false
      requestButton?.isEnabled = false
      requestButton?.state = NSOffState
      requestButton?.title = NSLocalizedString("Creating Invoice", comment: "Created invoice, waiting for invoice")
    }
  }
  
  /** Send a request to make an invoice.
   */
  func addInvoice(amount: Tokens, memo: String? = nil) throws {
    // Use defer to avoid setting create invoice to true when the addInvoice method throws an Error
    defer { creatingInvoice = true }

    try Daemon.addInvoice(amount: amount, memo: memo) { [weak self] result in
      self?.clear()
      
      self?.creatingInvoice = false
      
      switch result {
      case .addedInvoice(let invoice):
        self?.showInvoice(invoice)
        
      case .error(let error):
        self?.reportError(error)
      }
    }
  }
}

// MARK: - NSTextViewDelegate
extension ReceiveViewController: NSTextViewDelegate {
  override func controlTextDidChange(_ obj: Notification) {
    do { try updatedSelectedCurrency() } catch { reportError(error) }
  }
}

// MARK: - NSViewController
extension ReceiveViewController {
  /** clear eliminates the input and previous created invoice from the view.
   */
  fileprivate func clear() {
    let addedInvoiceViews: [NSView?] = [paymentRequestHeadingTextField, paymentRequestTextField, invoiceTypeButton]
    let inputTextFields = [amountTextField, memoTextField]
    
    inputTextFields.forEach { $0?.stringValue = String() }
    addedInvoiceViews.forEach { $0?.isHidden = true }
    
    invoiceTypeButton?.select(selectLightningItem)
    
    paidInvoice = nil

    do { try updatedSelectedCurrency() } catch { reportError(error) }
  }
  
  /** Updated paid invoice
   */
  fileprivate func updatedPaidInvoice() {
    guard let paidInvoice = paidInvoice else { paymentReceivedBox?.isHidden = true; return }
    
    guard let invoiceDate = paidInvoice.createdAt else { return reportError(Failure.expectedInvoiceCreationDate) }
    
    paymentInvoiceDate?.stringValue = invoiceDate.formatted(dateStyle: .short, timeStyle: .short)
    paymentReceivedAmount?.stringValue = paidInvoice.tokens.formatted(with: .testBitcoin)
    paymentReceivedBox?.isHidden = false
    
    guard case .received(let invoice) = paidInvoice.destination else { return }
    
    paymentReceivedDescription?.stringValue = (invoice.memo ?? String()) as String
  }
  
  fileprivate func updatedSelectedCurrency() throws {
    let amountPlaceholder: String
    
    switch currency {
    case .testBitcoin:
      amountPlaceholder = "0.00000000"
      
    case .testUnitedStatesDollars:
      amountPlaceholder = "$0.00"
    }
    
    amountTextField?.placeholderString = amountPlaceholder

    currencyConversionTextField?.stringValue = try currencyConverted(from: amountTextField?.stringValue)
  }
  
  func currencyConverted(from amountString: String?) throws -> String {
    guard let amountString = amountString else { return String() }
    
    let numbers = amountString.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
    
    guard let centsPerCoin = centsPerCoin?() else { return String() }
    
    switch currency {
    case .testBitcoin:
      let bitcoins = CurrencyAmount(fromTestBitcoins: numbers)
      
      return try bitcoins.converted(to: .testUnitedStatesDollars, rate: centsPerCoin)
      
    case .testUnitedStatesDollars:
      let dollars = CurrencyAmount(fromTestUnitedStatesDollars: numbers)
      
      return try dollars.converted(to: .testBitcoin, rate: centsPerCoin)
    }
  }
  
  /** Updated the payment request
   */
  fileprivate func updatedPaymentRequest() {
    paymentRequestTextField?.stringValue = (invoice?.paymentRequest ?? String()) as String
    
    let hasNoPaymentRequest = invoice?.paymentRequest == nil
    
    invoiceTypeButton?.isHidden = hasNoPaymentRequest
    
    guard let _ = invoice else { return }
    
    paymentRequestHeadingTextField?.isHidden = false
    paymentRequestTextField?.isHidden = false
    requestButton?.isEnabled = true
    requestButton?.state = NSOnState
    requestButton?.title = NSLocalizedString("Create Invoice", comment: "Button to add a new payment request")
  }
  
  /** viewDidLoad triggers to initialize the view.
   */
  override func viewDidLoad() {
    super.viewDidLoad()
    
    clear()
  }
  
  /** View is going to disappear
   */
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    paidInvoice = nil
  }
}

// MARK: - WalletListener
extension ReceiveViewController: WalletListener {
  /** Wallet was updated
   */
  func wallet(updated wallet: Wallet) {
    guard let invoice = invoice, let currentInvoice = wallet.invoice(invoice), currentInvoice.confirmed else { return }

    paidInvoice = currentInvoice
    
    clear()
  }
}
